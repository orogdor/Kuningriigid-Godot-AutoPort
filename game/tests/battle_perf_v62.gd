extends SceneTree
## V62 end-to-end regression: 30 real-time seconds of the FREE demo,
## adaptive mobile viewport, low-frequency saving, true pause/finish state.
## CI is headless: this validates work and state, NOT device-specific FPS.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const View=preload("res://scripts/battle_view_v55.gd")

func fail(why: String) -> void:
    printerr("BATTLE_PERF_V62 FAIL: "+why)
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
    var world: Dictionary=ui.world_view.world
    var battle: Dictionary=Battle.current(ui.city,world)
    if battle.is_empty() or not view.visible or \
            not view.auto_play_enabled or \
            not bool(battle.get("demo_v61",false)):
        fail("Actual one-click demo is not automatically running")
        return
    if view.actors_root.get_child_count()!=96 or \
            view.result_label==null or view.fps_label==null:
        fail("96 original 3D soldiers, end banner or FPS overlay missing")
        return
    if absf(float(view.auto_timer.wait_time)-0.25)>0.001:
        fail("Unexpected auto battle timer interval")
        return
    view.set_fast_graphics(true)
    await process_frame
    await process_frame
    var low_pixels: Vector2i=view.viewport.size
    if view.battle_canvas_container.stretch_shrink!=2 or \
            not view.fast_graphics or low_pixels.x<100 or low_pixels.y<50:
        fail("Low mode did not activate actual 2x viewport shrinking")
        return
    view.set_fast_graphics(false)
    await process_frame
    await process_frame
    var full_pixels: Vector2i=view.viewport.size
    if view.battle_canvas_container.stretch_shrink!=1 or \
            full_pixels.x<=low_pixels.x or full_pixels.y<=low_pixels.y:
        fail("Full detail mode did not restore render resolution")
        return
    var rock_count: int=view.obstacles_root.get_child_count()
    var old_rock: int=-1
    if rock_count>0:old_rock=view.obstacles_root.get_child(0).get_instance_id()
    view.set_battle(battle)
    if rock_count!=view.obstacles_root.get_child_count() or \
            (old_rock>=0 and old_rock!=view.obstacles_root.get_child(0).get_instance_id()):
        fail("Static rocks are regenerated on every view update")
        return
    # Put the opponent far enough away to check 30 real seconds without
    # an ordinary victory being misinterpreted as a simulator freeze.
    var foe: Dictionary=battle["fighters"][3]
    foe["x"]=230.0
    for man in foe["men"]:man["x"]=float(man["x"])+196.0
    view.set_battle(battle)
    var initial: float=float(battle["fighters"][0]["x"])
    var start_saves: int=ui.auto_battle_save_count
    for i in range(120):
        if not view.auto_play_enabled:
            fail("Automatic demo paused before 30 real-time seconds")
            return
        view._automatic_battle_step()
        if String(battle.get("result",""))!="":
            fail("Combat ended prematurely with an out-of-reach opponent")
            return
    # At v61 four times this much simulated time elapsed (1.0 per 0.25).
    if absf(float(battle["elapsed"])-15.0)>0.21 or \
            not Battle.active(ui.city,world) or not view.auto_play_enabled:
        fail("Auto battle does not continue beyond 30 seconds at real speed")
        return
    if float(battle["fighters"][0]["x"])<initial+5.0:
        fail("Attack-ordered soldiers stopped moving while battle was active")
        return
    if ui.auto_battle_save_count-start_saves>9:
        fail("Battle still serialises the entire city every 0.25 seconds")
        return
    if view.actors_root.get_child_count()!=96:
        fail("Original 3D soldier actors vanished during long-running battle")
        return
    # A manual pause must flush unsaved state before leaving the screen.
    view.set_auto_battle(false)
    if view.auto_play_enabled or not view.auto_timer.is_stopped():
        fail("Pause did not stop the timed simulation")
        return
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "user://autoport_city_v05.json"))
    if not saved is Dictionary:
        fail("Pause did not write a valid JSON save")
        return
    var saved_battle: Dictionary=Battle.current(saved,world)
    if saved_battle.is_empty() or \
            absf(float(saved_battle.get("elapsed",0.0))-float(battle["elapsed"]))>0.01:
        fail("Pause did not flush the most recent active battle")
        return
    # Defeat the remaining opponent through actual battle settlement, and
    # ensure the apparent freeze has an explicit visible END / RESTART state.
    foe["hp"]=0.0
    for man in foe["men"]:man["hp"]=0.0
    ui._battle_tick(1.0)
    if String(battle.get("result",""))!="victory" or \
            not view.result_label.visible or view.demo_retry_button.disabled or \
            not view.result_label.text.contains("VÕIT"):
        fail("Finished demo lacks an unmistakable outcome and replay button")
        return
    var old_elapsed: float=float(battle["elapsed"])
    view._automatic_battle_step()
    if float(battle["elapsed"])!=old_elapsed:
        fail("Finished demo advanced despite its terminal result")
        return
    print("BATTLE_PERF_V62 SUCCESS: mobile viewport scaling, 96 GLBs, static terrain reuse, 30 s auto combat, no premature pause, periodic saves, pause flush, visible result and replay")
    quit(0)
