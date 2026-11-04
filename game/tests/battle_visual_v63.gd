extends SceneTree
## V63 regression: the GLB scene renders intermediate soldier positions
## every frame even when 0.2 simulation steps arrive at only ~2.5 Hz.
## This is headless: test interpolation logic, not Android GPU performance.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")

func fail(message: String) -> void:
    printerr("BATTLE_VISUAL_V63 FAIL: "+message)
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
    if not view.auto_play_enabled or view.actors_root.get_child_count()!=96:
        fail("Cannot start the real 96-person automatic battle")
        return
    # We invoke the real game tick ourselves; keep playback enabled to
    # exercise the same interpolation path without a stray timer callback.
    view.auto_timer.stop()
    var before: Dictionary=Battle.current(ui.city,ui.world_view.world)
    var old_time: float=float(before["elapsed"])
    ui._battle_tick(0.5)
    var battle: Dictionary=Battle.current(ui.city,ui.world_view.world)
    if float(battle["elapsed"])<=old_time:
        fail("Half-second wall-time tick did not advance simulation")
        return
    var chosen: Node3D=null
    var selected_delta: float=0.0
    for node in view.actors_root.get_children():
        if not node.has_meta("interpolation_v63"):continue
        var state: Dictionary=node.get_meta("interpolation_v63")
        var distance: float=(state["target"] as Vector3).distance_to(
            state["origin"] as Vector3)
        if distance>selected_delta:
            selected_delta=distance
            chosen=node
    if chosen==null or selected_delta<0.10:
        fail("One battle simulation tick supplied no interpolatable movement")
        return
    var state: Dictionary=chosen.get_meta("interpolation_v63")
    var start: Vector3=state["origin"]
    var target: Vector3=state["target"]
    if chosen.position.distance_to(start)>0.005 or \
            chosen.position.distance_to(target)<0.08:
        fail("Actors were snapped to the next sim step before rendering")
        return
    var frame_movements: int=0
    var last_pos: Vector3=chosen.position
    for frame in range(6):
        view._process(0.04)
        var now: Vector3=chosen.position
        if now.distance_to(last_pos)>0.005:
            frame_movements+=1
        last_pos=now
        if now.distance_to(target)>start.distance_to(target)+0.001:
            fail("Visual interpolation moved away from the authoritative point")
            return
    if frame_movements<5:
        fail("A 56-FPS renderer still displays only 1-2 motion updates per second")
        return
    var mid: Vector3=chosen.position
    if mid.distance_to(start)<0.04 or mid.distance_to(target)<0.04:
        fail("Interpolation skipped intermediate soldier positions")
        return
    if float(battle["elapsed"])<=old_time or \
            absf(float(battle["elapsed"])-0.2)>0.01:
        fail("Visual animation modified the deterministic simulation")
        return
    state=chosen.get_meta("interpolation_v63")
    if float(state["phase"])==float(battle["fighters"][0]["men"][0].get(
            "anim_phase",0.0)) and float(state["fraction"])<=0.0:
        fail("Locomotion pose was not animated between sim ticks")
        return
    view._process(0.4)
    # V65 carries forward a short, strictly visual extrapolation instead of
    # freezing at the last snapshot. The exact target may be passed slightly
    # while awaiting the next authoritative simulation update.
    if chosen.position.distance_to(target)>selected_delta*0.55+0.02:
        fail("Visual prediction wandered too far from the saved target")
        return
    var completed: Dictionary=chosen.get_meta("interpolation_v63")
    if float(completed["fraction"])<0.999:
        fail("Visual interpolation did not finalize")
        return
    # Manual redraw (or pause/load) must reflect the true state immediately.
    view.set_auto_battle(false)
    var current: Dictionary=Battle.current(ui.city,ui.world_view.world)
    current["fighters"][0]["men"][0]["x"]=float(
        current["fighters"][0]["men"][0]["x"])+15.0
    view.set_battle(current)
    var soldier: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900001_0") as Node3D
    if soldier==null or absf(soldier.position.x-float(
            current["fighters"][0]["men"][0]["x"]))>0.001:
        fail("A paused/manual battle incorrectly delays its actual positions")
        return
    if view.actors_root.get_child_count()!=96:
        fail("New interpolation removed any of the 96 original GLB soldiers")
        return
    print("BATTLE_VISUAL_V63 SUCCESS: 96 GLBs, six distinct render frames per 0.2 s sim step, smooth position and pose interpolation, no simulation changes, pause snaps safely")
    quit(0)
