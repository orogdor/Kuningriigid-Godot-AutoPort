extends SceneTree
## V61 end-to-end user flow: new city -> free demo -> actual 3D GLB battle ->
## timed movement and attacks -> result -> lossless real campaign -> replay.
## Old paid skirmish tests (V55/V56) stay in the same mandatory CI suite.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Mil=preload("res://scripts/military_v54.gd")
const Anim=preload("res://scripts/battle_animation_v61.gd")

func fail(why: String) -> void:
    printerr("BATTLE_DEMO_V61 FAIL: "+why)
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
    var world: Dictionary=ui.world_view.world
    var initial_time: float=float(ui.city["time"])
    var original_resources: String=JSON.stringify(ui.city["realms"][0]["resources"])
    var original_pop: float=float(ui.city["realms"][0]["pop"])
    var military: Dictionary=Mil.ensure(ui.city,world)
    if military.is_empty() or not military["armies"].is_empty() or \
            bool(military["camp"].get("ready",false)):
        fail("Free demo requires an empty usable fresh city")
        return
    # The actual city button handler, not a synthetic battle fixture.
    ui._start_demo_battle()
    var b: Dictionary=Battle.current(ui.city,world)
    if b.is_empty() or not Battle.active(ui.city,world) or \
            not bool(b.get("demo_v61",false)) or int(b.get("version",0))!=61:
        fail("One-click free city demo did not create an active V61 battle")
        return
    if not ui.battle_view.visible or not ui.battle_view.auto_play_enabled or \
            ui.battle_view.auto_timer.is_stopped():
        fail("Opening the real demo UI did not start live combat")
        return
    if b["fighters"].size()!=4:
        fail("Free demo needs 3 allied squads and 1 genuine opponent")
        return
    var total: int=0
    for f in b["fighters"]:
        if f["men"].size()!=24 or int(f.get("menAlive",0))!=24:
            fail("One-click demo lost 24 independently controllable soldiers")
            return
        total+=f["men"].size()
    if total!=96 or ui.battle_view.actors_root.get_child_count()!=96:
        fail("Real GLB 3D tactical scene did not render all 96 soldiers")
        return
    if Battle.start_demo(ui.city,world)=="":
        fail("A second click replaced an active battle without confirmation")
        return
    if ui.battle_view.battle_canvas_container.size.y<100.0 or \
            ui.battle_view.cam_size>200.0:
        fail("Combat viewport is too small or starts too zoomed out")
        return
    var stationary: Dictionary=b["fighters"][0]["men"][0]
    var start_x: float=float(stationary["x"])
    var squad_id: int=int(b["fighters"][0]["id"])
    # Prove commands reach actual battle API while auto combat is paused.
    ui.battle_view.set_auto_battle(false)
    if ui.battle_view.auto_play_enabled or not ui.battle_view.auto_timer.is_stopped():
        fail("Demo's pause button did not stop automatic simulation")
        return
    if Battle.command(ui.city,world,squad_id,"attack")!="":
        fail("Human squad cannot be commanded in the free demo")
        return
    ui._battle_tick(6.0)
    if float(b["elapsed"])<=0.0 or \
            absf(float(stationary["x"])-start_x)<0.1:
        fail("Demo fighters did not move when actual UI advanced combat")
        return
    if ui.battle_view.actors_root.get_child_count()<1:
        fail("3D GLB actors disappeared on battle tick")
        return
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "user://autoport_city_v05.json"))
    if not saved is Dictionary or not Battle.active(saved,world) or \
            not bool(Battle.current(saved,world).get("demo_v61",false)):
        fail("Save/restore lost the active free-demo battle")
        return
    # Class-specific poses must be meaningfully different, and hits animated.
    var pose: Dictionary={"moving":true,"anim_phase":PI*0.5,
        "attack_anim":0.18,"hit_anim_v61":0.2}
    var spear: Dictionary=Anim.pose(pose,"spearman")
    var axe: Dictionary=Anim.pose(pose,"axeman")
    var sling: Dictionary=Anim.pose(pose,"slinger")
    if float(axe["rotation"].z)<=float(spear["rotation"].z)+0.15 or \
            float(sling["rotation"].y)<0.4 or \
            float(spear["offset"].z)>-0.3 or \
            not bool(spear["hit"]):
        fail("Spearman, axeman, slinger or hit reaction does not animate distinctly")
        return
    # Complete the same live combat engine; allied squads are attack-ready.
    for i in range(110):
        if not Battle.active(ui.city,world):break
        Battle.tick(ui.city,world,10.0)
    if Battle.active(ui.city,world):
        fail("Free battle is stuck and will not reach a result")
        return
    if String(b["result"])!="victory" or not bool(b["resolved"]):
        fail("Three allied practice squads did not complete the battle")
        return
    ui._battle_tick(1.0) # Redraw and persist the finished actual UI.
    if ui.battle_view.demo_retry_button.disabled:
        fail("Finished demo did not offer a replay button")
        return
    if not military["armies"].is_empty() or \
            JSON.stringify(ui.city["realms"][0]["resources"])!=original_resources or \
            float(ui.city["realms"][0]["pop"])!=original_pop or \
            float(ui.city["time"])!=initial_time:
        fail("Free demo changed real campaign troops, economy or turn counter")
        return
    var replay_snapshot: String=JSON.stringify(military["armies"])
    Battle.tick(ui.city,world,60.0)
    if JSON.stringify(military["armies"])!=replay_snapshot:
        fail("Repeat battle settlement affected the real campaign")
        return
    # Exercise the actual "repeat demo" button signal and UI handler.
    ui.battle_view._restart_demo()
    var next: Dictionary=Battle.current(ui.city,world)
    if next.is_empty() or not Battle.active(ui.city,world) or \
            String(next.get("result",""))!="" or \
            not bool(next.get("demo_v61",false)) or \
            not ui.battle_view.visible or not ui.battle_view.auto_play_enabled:
        fail("Replay button did not start a new playable demo")
        return
    ui.battle_view.set_auto_battle(false)
    print("BATTLE_DEMO_V61 SUCCESS: one-click free city demo, 96 real GLBs, auto play/pause, player orders, 3D zoom, save/restore, distinct strikes, decisive victory, no campaign damage, restart")
    quit(0)
