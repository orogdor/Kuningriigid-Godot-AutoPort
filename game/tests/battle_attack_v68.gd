extends SceneTree
## V68: focus an enemy through the real mobile battle UI, chase without
## teleport, use the existing actual combat damage/projectile logic, and
## preserve orders across saves. Older saved battles keep their old rules.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Attack=preload("res://scripts/individual_attack_v68.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")
const Targets=preload("res://scripts/battle_targets_v64.gd")
const Stones=preload("res://scripts/projectiles_v58.gd")

func fail(message: String) -> void:
    printerr("BATTLE_ATTACK_V68 FAIL: "+message)
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
    ui._start_demo_battle()
    var world: Dictionary=ui.world_view.world
    var battle: Dictionary=Battle.current(ui.city,world)
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    if int(battle.get("version",0))<68 or \
            view.actors_root.get_child_count()!=96 or \
            view.attack_toggle_v68==null:
        fail("V68 active 96-GLB battle and attack UI are not ready")
        return
    var own: Dictionary=battle["fighters"][0]["men"][0]
    var before: Vector3=view.actors_root.get_node(
        "TacticalMan_900001_0").position
    var actor: Node3D=view.actors_root.get_node(
        "TacticalMan_900001_0") as Node3D
    actor.position+=Vector3(0.31,0.0,0.18)
    var visual_before: Vector3=actor.position
    var foe_actor: Node3D=view.actors_root.get_node(
        "TacticalMan_-900001_7") as Node3D
    if foe_actor==null:
        fail("A real enemy model is missing")
        return
    # Bring hostile models on screen and tap exactly their projected 3D
    # positions. The selected friendly soldier is already squad 900001 #0.
    var foe: Vector3=foe_actor.position
    view.battle_camera.position=Vector3(foe.x,670.0,foe.z+520.0)
    view.battle_camera.look_at(foe,Vector3.UP)
    view.cam_size=10.0
    view.battle_camera.size=10.0
    var p: Vector2=view.battle_camera.unproject_position(
        foe_actor.global_position+Vector3(0,2.5,0))*Vector2(
        view.battle_canvas_container.size.x/maxf(1.0,float(view.viewport.size.x)),
        view.battle_canvas_container.size.y/maxf(1.0,float(view.viewport.size.y)))
    view._toggle_individual_attack_v68()
    if not view.individual_attack_mode_v68:
        fail("Cannot arm the touch-to-target attack order")
        return
    var mouse:=InputEventMouseButton.new()
    mouse.pressed=true
    mouse.button_index=MOUSE_BUTTON_LEFT
    mouse.position=p
    view._on_battle_canvas_input(mouse)
    if view.individual_attack_mode_v68:
        fail("Enemy tap did not finish the attack selection")
        return
    var command: Dictionary=own.get(Attack.KEY,{})
    if int(command.get("squad",0))!=-900001 or \
            int(command.get("index",-1))!=7:
        fail("3D enemy selection did not save the exact enemy target")
        return
    if actor.position.distance_to(visual_before)>0.0001:
        fail("Issuing an attack order snapped a smoothly rendered soldier")
        return
    var marker: MeshInstance3D=foe_actor.get_node("TeamMarker") as MeshInstance3D
    var tint: StandardMaterial3D=marker.material_override as StandardMaterial3D
    if tint==null or tint.albedo_color!=Color("#ff9b32"):
        fail("The targeted hostile soldier is not highlighted orange")
        return
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "user://autoport_city_v05.json"))
    if not saved is Dictionary:
        fail("Battle attack order was not serialised")
        return
    var saved_person: Dictionary=Battle.current(saved,world)[
        "fighters"][0]["men"][0]
    if int(saved_person.get(Attack.KEY,{}).get("index",-1))!=7:
        fail("Save and reload lost the personal attack order")
        return
    if Battle.attack_individual(ui.city,world,900001,0,900001,2)=="":
        fail("Cannot issue focused attacks against friendly soldiers")
        return
    if Battle.attack_individual(ui.city,world,900001,99,-900001,0)=="":
        fail("Cannot direct a dead or non-existent friendly soldier")
        return
    var legacy: Dictionary=JSON.parse_string(JSON.stringify(battle))
    legacy["version"]=67
    if Attack.issue(legacy,900001,0,-900001,0)=="":
        fail("An old saved battle incorrectly accepts new V68 commands")
        return

    # Use independent battle copies to confirm that an unassigned V68
    # individual still gets the same movement, damage, and ammunition.
    var old: Dictionary=JSON.parse_string(JSON.stringify(battle))
    var modern: Dictionary=JSON.parse_string(JSON.stringify(battle))
    old["version"]=67
    modern["version"]=68
    old["fighters"][0]["men"][0].erase(Attack.KEY)
    modern["fighters"][0]["men"][0].erase(Attack.KEY)
    for k in range(3):
        Men.tick(old,0.2)
        Men.tick(modern,0.2)
    if JSON.stringify(old["fighters"])!=JSON.stringify(modern["fighters"]) or \
            JSON.stringify(old.get("projectiles_v58",[]))!=\
            JSON.stringify(modern.get("projectiles_v58",[])):
        fail("Normal V68 combat no longer matches V67 when no target is set")
        return

    var combat: Dictionary=JSON.parse_string(JSON.stringify(battle))
    var first: Dictionary=combat["fighters"][0]["men"][0]
    var victim: Dictionary=combat["fighters"][3]["men"][0]
    var decoy: Dictionary=combat["fighters"][3]["men"][1]
    # Search a clear, obstacle-free location so the test exercises exact
    # target preference rather than the random rock generator.
    var arena: Dictionary=Nav.ensure(combat)
    var spot: Vector2=Vector2.ZERO
    var site_found: bool=false
    for x in range(-22,23,4):
        if site_found:break
        for z in range(-22,23,4):
            var p0:=Vector2(float(x),float(z))
            var p1:=p0+Vector2(1.4,0.0)
            var p2:=p0+Vector2(0.8,0.0)
            if Nav.open_at(p0,arena) and Nav.open_at(p1,arena) and \
                    Nav.open_at(p2,arena) and Stones.clear_line(p0,p1,arena):
                spot=p0
                site_found=true
                break
    if not site_found:
        fail("Cannot find clear 3D battlefield space to test focused damage")
        return
    first["x"]=spot.x
    first["z"]=spot.y
    victim["x"]=spot.x+1.4
    victim["z"]=spot.y
    decoy["x"]=spot.x+0.8
    decoy["z"]=spot.y
    for person in combat["fighters"][0]["men"]:
        person["cool"]=20.0
    first["cool"]=0.0
    if Attack.issue(combat,900001,0,-900001,0)!="":
        fail("Spear soldier cannot focus a valid hostile target")
        return
    var hp_target: float=float(victim["hp"])
    var hp_decoy: float=float(decoy["hp"])
    Men._attack(combat,combat["fighters"][0],0.2,Targets.build(combat))
    if float(victim["hp"])>=hp_target or \
            absf(float(decoy["hp"])-hp_decoy)>0.0001:
        fail("Focused attack hit the nearer unrelated hostile soldier")
        return

    # Pursuit advances using V57 steering, never teleports to the enemy.
    first["x"]=spot.x-5.0
    first["z"]=spot.y
    var before_chase:=Vector2(float(first["x"]),float(first["z"]))
    var target_pos:=Vector2(float(victim["x"]),float(victim["z"]))
    Attack.advance(first,combat["fighters"][0],combat,0.2,
        Nav.index_people(combat))
    var after_chase:=Vector2(float(first["x"]),float(first["z"]))
    if after_chase.distance_to(target_pos)>=\
            before_chase.distance_to(target_pos) or \
            after_chase.distance_to(before_chase)>3.0:
        fail("Focused soldier did not walk toward target with collision navigation")
        return

    victim["hp"]=0.0
    if not Attack.target(combat,first,0).is_empty() or first.has(Attack.KEY):
        fail("A fallen enemy remains locked as an attack target")
        return
    if Attack.issue(combat,900001,0,-900001,1)!="":
        fail("Cannot assign another living target")
        return
    if Battle.rejoin_individual(ui.city,world,900001,0)!="":
        fail("Rejoin command is unavailable after targeting")
        return
    var assigned: Dictionary=ui.city["military_v54"]["skirmish_v55"][
        "fighters"][0]["men"][0]
    if assigned.has(Attack.KEY):
        fail("Rejoin did not clear the personal focused attack")
        return
    print("BATTLE_ATTACK_V68 SUCCESS: 96 GLBs, 3D enemy tap, saved target, visual continuity, friendly rejection, precise hits, obstacle-safe chase, fallen-target expiry, V67 compatibility")
    quit(0)
