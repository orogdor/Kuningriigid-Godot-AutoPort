extends SceneTree
## V98: unchanged authoritative snapshots should not reanimate 216 settled
## GLBs. New movement, attack/hit sequences, and a moved/rotated soldier
## must still wake correctly without mutating the saved battle state.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_IDLE_SNAPSHOT_V98 FAIL: "+reason)
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
    var view: Control=ui.battle_view
    view.set_auto_battle(false)
    view.auto_timer.stop()
    var battle: Dictionary=Battle.current(ui.city,ui.world_view.world)
    if view.actors_root.get_child_count()!=216:
        fail("real 216-soldier demo failed to spawn")
        return
    # Create an authoritative snapshot with every combatant settled. This
    # preserves original source GLB instances instead of using mock rigs.
    for fighter in battle["fighters"]:
        for man in fighter["men"]:
            man["moving"]=false
            man["attack_anim"]=0.0
            man["hit_anim_v61"]=0.0
    view.set_battle(battle)
    view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0:
        fail("stationary source actors never settled into the idle cache")
        return
    var first: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900101_0") as Node3D
    if first==null:
        fail("first real source soldier model is missing")
        return
    var source: Node3D=first.get_child(0) as Node3D
    if source==null or not source.has_meta("source_glb"):
        fail("test did not load the real source GLB")
        return
    var phases: Dictionary={}
    for actor in view.actors_root.get_children():
        phases[actor.name]=float(actor.get_meta("interpolation_v63")["phase"])
    var saved_json: String=JSON.stringify(battle)
    view.auto_play_enabled=true
    var same: Dictionary=battle.duplicate(true)
    same["elapsed"]=float(battle.get("elapsed",0.0))+0.2
    view.set_battle(same)
    if view.active_battle_render_count_v97()!=0:
        fail("unchanged simulation step unnecessarily woke idle soldiers")
        return
    for actor in view.actors_root.get_children():
        var interp: Dictionary=actor.get_meta("interpolation_v63")
        if not bool(interp.get("idle_pose_ready_v92",false)) or \
                absf(float(interp["phase"])-float(phases[actor.name]))>0.00001:
            fail("unchanged snapshot invalidated cached rig pose")
            return
    view._render_soldier_motion_v65(0.3)
    if view.active_battle_render_count_v97()!=0 or \
            JSON.stringify(battle)!=saved_json:
        fail("empty render frame changed source battle state")
        return
    # A same-clock user command must also keep the idle cache.
    view.set_battle(same.duplicate(true),true)
    if view.active_battle_render_count_v97()!=0:
        fail("same-clock command needlessly woke stationary soldiers")
        return

    # Only the moved soldier should enter the next frame worker.
    var next: Dictionary=same.duplicate(true)
    next["elapsed"]=float(same["elapsed"])+0.2
    var mover: Dictionary=next["fighters"][0]["men"][0]
    mover["x"]=float(mover["x"])+2.0
    mover["moving"]=true
    view.set_battle(next)
    if view.active_battle_render_count_v97()!=1:
        fail("moving one of 216 soldiers woke additional idle actors")
        return
    var old_position: Vector3=first.position
    view._render_soldier_motion_v65(1.0/60.0)
    if first.position.distance_to(old_position)<0.00001:
        fail("moved GLB soldier failed to interpolate after waking")
        return

    # An attack sequence event must wake even with legacy attack clock zero.
    var actions: Dictionary=next.duplicate(true)
    actions["elapsed"]=float(next["elapsed"])+0.2
    var actor: Dictionary=actions["fighters"][0]["men"][1]
    actor["strike_seq_v70"]=int(actor.get("strike_seq_v70",0))+1
    actor["attack_anim"]=0.0
    view.set_battle(actions)
    if view.active_battle_render_count_v97()<2:
        fail("new action sequence was incorrectly skipped as idle")
        return
    var hit: Dictionary=actions.duplicate(true)
    hit["elapsed"]=float(actions["elapsed"])+0.2
    var victim: Dictionary=hit["fighters"][5]["men"][0]
    victim["hit_seq_v70"]=int(victim.get("hit_seq_v70",0))+1
    victim["hit_anim_v61"]=0.0
    view.set_battle(hit)
    if view.active_battle_render_count_v97()<3:
        fail("new hit sequence was incorrectly skipped as idle")
        return
    view.set_auto_battle(false)
    print("BATTLE_IDLE_SNAPSHOT_V98 SUCCESS: 216 GLBs, unchanged tick/command stays asleep, movement and action events wake, saved state unchanged")
    quit(0)
