extends SceneTree
## V71: enemy squad selection by touching a real imported GLB, balanced
## 24-on-24 attack assignments, live retarget, individual override,
## orders cancellation, deterministic save, and 216 original 3D models.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Squad=preload("res://scripts/squad_attack_v71.gd")
const Attack=preload("res://scripts/individual_attack_v68.gd")
const Personal=preload("res://scripts/individual_orders_v60.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")

func fail(message: String) -> void:
    printerr("BATTLE_SQUAD_V71 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_large_demo_battle()
    var world: Dictionary=ui.world_view.world
    var battle: Dictionary=Battle.current(ui.city,world)
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    if int(battle.get("version",0))!=71 or \
            not bool(battle.get("large_demo_v64",false)) or \
            view.actors_root.get_child_count()!=216 or \
            view.squad_attack_toggle_v71==null:
        fail("Real 216-GLB V71 large battle UI is missing")
        return

    # Input test: user selects a friendly squad through the existing picker,
    # arms the group attack, and left-clicks a 3D enemy from that exact squad.
    var enemy_actor: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_-900101_0") as Node3D
    var own_actor: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900101_0") as Node3D
    if enemy_actor==null or own_actor==null:
        fail("Missing original 3D GLB source soldiers")
        return
    var before_visual: Vector3=own_actor.position
    view.battle_camera.position=enemy_actor.position+Vector3(0,670,520)
    view.battle_camera.look_at(enemy_actor.position,Vector3.UP)
    view.battle_camera.size=10.0
    view.cam_size=10.0
    var point: Vector2=view.battle_camera.unproject_position(
        enemy_actor.global_position+Vector3(0,2.5,0))*Vector2(
        view.battle_canvas_container.size.x/maxf(1.0,float(view.viewport.size.x)),
        view.battle_canvas_container.size.y/maxf(1.0,float(view.viewport.size.y)))
    view._toggle_squad_attack_v71()
    if not view.squad_attack_mode_v71:
        fail("Cannot arm squad-targeting touch mode")
        return
    var click:=InputEventMouseButton.new()
    click.button_index=MOUSE_BUTTON_LEFT
    click.pressed=true
    click.position=point
    view._on_battle_canvas_input(click)
    if view.squad_attack_mode_v71:
        fail("Enemy touch failed to submit and clear squad attack mode")
        return
    var own: Dictionary=battle["fighters"][0]
    var enemy: Dictionary=battle["fighters"][5]
    if int(own.get(Squad.KEY,0))!=-900101 or \
            String(own.get("mode",""))!="attack":
        fail("Click did not save correct friendly-to-hostile squad order")
        return
    if own_actor.position.distance_to(before_visual)>0.0001:
        fail("Issuing an order snapped the currently interpolated soldier")
        return
    var matches: Dictionary={}
    for man in own["men"]:
        if not man.has(Attack.KEY):
            fail("One of the 24 living attackers lacks a personal target")
            return
        var lock: Dictionary=man[Attack.KEY]
        if int(lock.get("squad",0))!=-900101:
            fail("Squad order aimed a soldier at the wrong hostile squad")
            return
        matches[int(lock["index"])]=true
    if matches.size()!=24:
        fail("Attack formation did not distribute 24 fighters over 24 targets")
        return
    var highlighted: int=0
    for actor in view.actors_root.get_children():
        if int(actor.get_meta("team_v67",-1))!=1 or \
                int(actor.get_meta("squad_v67",0))!=-900101:continue
        var marker: MeshInstance3D=actor.get_node("TeamMarker") as MeshInstance3D
        var tint: StandardMaterial3D=marker.material_override as StandardMaterial3D
        if tint!=null and tint.albedo_color==Color("#ff9b32"):
            highlighted+=1
    if highlighted!=24:
        fail("The chosen enemy formation is not highlighted on all 24 GLBs")
        return

    # Verify the persisted JSON contains the squad's tactical directive.
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "user://autoport_city_v05.json"))
    if not saved is Dictionary or \
            int(Battle.current(saved,world)["fighters"][0].get(Squad.KEY,0))!=-900101:
        fail("Saving and loading the group attack lost its enemy ID")
        return

    # Live retarget after the first enemy man falls. No teleport or orders
    # to a friendly squad; V68 obstacle-aware individual pursuit owns motion.
    var first: Dictionary=own["men"][0]
    var previously_locked: int=int(first[Attack.KEY]["index"])
    enemy["men"][previously_locked]["hp"]=0.0
    var before_sim:=Vector2(float(first["x"]),float(first["z"]))
    Squad.refresh(own,battle)
    if not first.has(Attack.KEY) or \
            int(first[Attack.KEY]["index"])==previously_locked or \
            Attack.enemy(battle,0,-900101,int(first[Attack.KEY]["index"])).is_empty():
        fail("Losing an enemy did not produce a valid replacement target")
        return
    var after_sim:=Vector2(float(first["x"]),float(first["z"]))
    if before_sim.distance_to(after_sim)>0.00001:
        fail("Assigning a replacement foe teleported a soldier")
        return

    # A manual personal movement order overrides a group command.
    var person: Dictionary=own["men"][1]
    var goal:=Vector2(float(person["x"])-3.0,float(person["z"])+3.0)
    var arena: Dictionary=Nav.ensure(battle)
    if not Nav.open_at(goal,arena):
        goal=Vector2.ZERO
    if Battle.move_individual(ui.city,world,900101,1,goal)!="":
        fail("Personal movement was rejected under a group target")
        return
    Squad.refresh(own,battle)
    if not bool(person.get(Squad.MANUAL,false)) or \
            not person.has(Personal.KEY) or person.has(Attack.KEY):
        fail("Group targeting overwrote manually issued personal movement")
        return
    if Battle.rejoin_individual(ui.city,world,900101,1)!="":
        fail("Rejoin failed while entire squad was focusing an enemy")
        return
    Squad.refresh(own,battle)
    if bool(person.get(Squad.MANUAL,false)) or \
            not person.has(Attack.KEY):
        fail("Rejoined soldier failed to resume squad attack")
        return

    # An explicit personal enemy command against *another squad* must win.
    if Battle.attack_individual(ui.city,world,900101,1,-900102,0)!="":
        fail("The user cannot override squad order with personal target")
        return
    Squad.refresh(own,battle)
    if not bool(person.get(Squad.MANUAL,false)) or \
            int(person.get(Attack.KEY,{}).get("squad",0))!=-900102:
        fail("Group refresh erased a hand-picked independent enemy")
        return

    # New group move order cancels existing group attack and manual flags.
    if Battle.move(ui.city,world,900101,Vector2(0,0))!="":
        fail("Cannot give the selected squad a replacement move order")
        return
    if own.has(Squad.KEY) or person.has(Squad.MANUAL):
        fail("Replacement squad move did not cancel focused attack")
        return

    # Resume focus, then eliminate the target squad to verify that soldiers
    # do not charge another squad without a new user order.
    if Battle.attack_squad(ui.city,world,900101,-900101)!="":
        fail("Cannot reissue squad attack after movement")
        return
    for victim in enemy["men"]:
        victim["hp"]=0.0
    Squad.refresh(own,battle)
    if own.has(Squad.KEY) or String(own.get("mode",""))!="hold":
        fail("A defeated enemy group left the squad attacking unrelated foes")
        return
    for man in own["men"]:
        if man.has(Attack.KEY):
            fail("Defeated group's individual targets were not cleared")
            return

    # Reject old saves, allied targets and invalid group IDs without edits.
    var legacy: Dictionary=JSON.parse_string(JSON.stringify(battle))
    legacy["version"]=70
    if Squad.issue(legacy,900101,-900102)=="" or \
            Squad.issue(battle,900101,900102)=="" or \
            Squad.issue(battle,999999,-900102)=="":
        fail("Group-order validation accepted an invalid or older command")
        return

    # Without an explicit group order, V71 is exactly as V70: no economic,
    # pathfinding, damage, projectile, or personal-order side effects.
    var old: Dictionary=JSON.parse_string(JSON.stringify(battle))
    var modern: Dictionary=JSON.parse_string(JSON.stringify(battle))
    old["version"]=70
    modern["version"]=71
    for k in range(3):
        Men.tick(old,0.2)
        Men.tick(modern,0.2)
    if JSON.stringify(old["fighters"])!=JSON.stringify(modern["fighters"]) or \
            JSON.stringify(old.get("projectiles_v58",[]))!=\
                JSON.stringify(modern.get("projectiles_v58",[])):
        fail("No-command V71 combat changed original V70 battle rules")
        return
    view.set_auto_battle(false)
    print("BATTLE_SQUAD_V71 SUCCESS: 216 original GLBs, 24 distributed targets, 3D tap selection, saved group order, fall retarget, manual override, rejoin, move/retreat cancellation, V70 combat parity")
    quit(0)
