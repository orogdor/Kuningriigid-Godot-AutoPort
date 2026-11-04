extends SceneTree
## V69: play real GLB skeletal death clip while keeping deterministic
## casualties, saved battle and old snapshots unchanged. Visual corpse nodes
## expire in render time and never re-enter collision or targeting.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Animation65=preload("res://scripts/battle_animation_v65.gd")

func fail(message: String) -> void:
    printerr("BATTLE_DEATH_V69 FAIL: "+message)
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
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    var battle: Dictionary=Battle.current(ui.city,ui.world_view.world)
    if int(battle.get("version",0))<69 or \
            view.actors_root.get_child_count()!=96:
        fail("The live 96-GLB demo is not running V69")
        return
    var actor: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900001_0") as Node3D
    if actor==null:
        fail("Original GLB soldier missing")
        return
    var model: Node3D=actor.get_child(0) as Node3D
    if model==null or not model.has_meta("source_glb"):
        fail("Casualty test is not using the real GLB source model")
        return
    var info: Dictionary=model.get_meta("source_animator_v65",{})
    var clips: Dictionary=Animation65.available_clips(model)
    if not clips.has("death"):
        fail("Original GLB death clip was not imported")
        return
    info=model.get_meta("source_animator_v65",{})
    var player: AnimationPlayer=info.get("player",null)
    if player==null:
        fail("Original glTF Skeleton3D AnimationPlayer missing")
        return
    var original_position: Vector3=actor.position
    var soldier: Dictionary=battle["fighters"][0]["men"][0]
    var original_hp: float=float(soldier["hp"])
    soldier["hp"]=0.0
    var state_before: String=JSON.stringify(ui.city)
    var original_id: int=actor.get_instance_id()
    view.set_battle(battle)
    var fallen: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900001_0") as Node3D
    if fallen==null or fallen.get_instance_id()!=original_id or \
            not fallen.has_meta("fallen_since_v69"):
        fail("First casualty frame removed/replaced the GLB before death pose")
        return
    if not bool(fallen.get_meta("death_clip_v69",false)) or \
            player.current_animation!=String(clips["death"]) or \
            not player.is_playing():
        fail("Real GLB death animation did not start")
        return
    var animation: Animation=player.get_animation(String(clips["death"]))
    if animation==null or animation.loop_mode!=Animation.LOOP_NONE:
        fail("Death GLB animation loops instead of playing once")
        return
    var foot: Node3D=fallen.get_node_or_null("TeamMarker") as Node3D
    if foot==null or foot.visible:
        fail("A dead soldier still displays an active team marker")
        return
    if fallen.position.distance_to(original_position)>0.2:
        fail("Death animation teleported a model in the battlefield")
        return
    view._process(0.35)
    if not is_instance_valid(fallen) or \
            float(fallen.get_meta("fallen_since_v69",0.0))<0.34 or \
            player.current_animation!=String(clips["death"]):
        fail("Skeletal death did not remain visible during render frames")
        return
    view.set_battle(battle)
    if float(fallen.get_meta("fallen_since_v69",0.0))<0.34:
        fail("Repeated battle snapshots restarted the death animation")
        return
    if JSON.stringify(ui.city)!=state_before:
        fail("Purely visual death effects modified deterministic saved battle")
        return

    # A replay/new fight can reuse the same soldier ID before visual expiry.
    soldier["hp"]=original_hp
    view.set_battle(battle)
    if fallen.has_meta("fallen_since_v69") or \
            fallen.get_node("TeamMarker").visible==false:
        fail("Reusing a soldier ID failed to restore the living GLB")
        return
    soldier["hp"]=0.0
    view.set_battle(battle)
    if not fallen.has_meta("fallen_since_v69"):
        fail("Second death did not start another legitimate animation")
        return
    view._process(1.0)
    if view.actors_root.get_node_or_null("TacticalMan_900001_0")==null:
        fail("Death animation was cut off during the first second")
        return
    view._process(0.85)
    if view.actors_root.get_node_or_null("TacticalMan_900001_0")!=null:
        fail("Expired corpse did not leave the 3D renderer")
        return
    if view.actors_root.get_child_count()!=95:
        fail("Corpse clean-up removed other original soldiers")
        return
    view.set_battle(battle)
    if view.actors_root.get_node_or_null("TacticalMan_900001_0")!=null:
        fail("Dead combatant respawned after visual expiry")
        return

    # Retreat is not a casualty; it must remove the model at once.
    var escaped: Dictionary=battle["fighters"][0]["men"][1]
    escaped["escaped"]=true
    view.set_battle(battle)
    if view.actors_root.get_node_or_null("TacticalMan_900001_1")!=null:
        fail("Retreating soldier incorrectly remains as corpse")
        return

    # Historical V68 battles retain their immediate death/retreat display.
    var old_version: Dictionary=JSON.parse_string(JSON.stringify(battle))
    old_version["version"]=68
    var old_man: Dictionary=old_version["fighters"][0]["men"][2]
    old_man["hp"]=0.0
    view.set_battle(old_version)
    if view.actors_root.get_node_or_null("TacticalMan_900001_2")!=null:
        fail("An old-version save was unexpectedly changed by V69 visuals")
        return
    if int(battle["fighters"][0]["men"][0].get("shots",0))!=\
            int(soldier.get("shots",0)):
        fail("Rendering effects changed personal attack state")
        return
    view.set_auto_battle(false)
    print("BATTLE_DEATH_V69 SUCCESS: real GLB Skeleton3D non-looping death, 1.8s render expiry, replay revival, retreat removal, old save compatible, no simulation changes")
    quit(0)
