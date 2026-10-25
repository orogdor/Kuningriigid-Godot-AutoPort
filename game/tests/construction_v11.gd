extends SceneTree
## AutoPort 0.11: workers must reach a construction site before gradual work,
## share the existing economy's employees, and survive save/reload.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Builders = preload("res://scripts/construction_v11.gd")
const View = preload("res://content.tscn")

func bad(message: String) -> void:
    printerr("BUILDERS_V11 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    state["pending_site"]={"x":30.0,"z":-10.0}
    if City.build(state,"lumber")!="":
        bad("Unable to build lumber site")
        return
    var job: Dictionary=state["buildings"][1]
    if bool(job["ready"]) or float(job["progress"])!=0.0:
        bad("New buildings should start at foundations")
        return
    if Builders.stage(job,City.definitions()["buildings"]["lumber"])!=0:
        bad("Initial 3D building stage is not foundation")
        return
    # A separate workforce is physically created on the first simulation turn.
    City.tick(state)
    var sim: Dictionary=state["detail_sim"]
    if not sim.has("builders") or sim["builders"].size()!=1:
        bad("Builder did not spawn")
        return
    if bool(job["ready"]):
        bad("Building finished instantly without construction stages")
        return
    if Vector2(float(sim["builders"][0]["x"]),float(sim["builders"][0]["z"])).distance_to(Vector2(30,-10))<0.001:
        bad("Worker spawned by teleporting to the building center")
        return
    var old_progress: float=float(job["progress"])
    City.tick(state)
    if bool(job["ready"]):
        bad("Workers completed a multi-stage building in two turns")
        return
    if float(job["progress"])<old_progress:
        bad("Building construction regressed")
        return
    for n in range(16):
        if bool(job["ready"]):break
        City.tick(state)
    if not bool(job["ready"]):
        bad("Builder never finished a reachable construction site")
        return
    if not is_equal_approx(Builders.phase_fraction(job,City.definitions()["buildings"]["lumber"]),1.0):
        bad("Building fraction not complete after finishing")
        return
    if int(sim.get("version",0))!=4:
        bad("Old 0.10 detail save did not migrate to construction schema v4")
        return
    var count_before: int=sim["builders"].size()
    state["pending_site"]={"x":-30.0,"z":-10.0}
    if City.build(state,"house")!="":
        bad("House construction could not be started")
        return
    for n in range(20):
        if bool(state["buildings"][2]["ready"]):break
        City.tick(state)
    if not bool(state["buildings"][2]["ready"]):
        bad("Erected second structure never finished")
        return
    if sim["builders"].size()!=count_before:
        bad("Idle construction worker not reused for another building")
        return
    var saved: Variant=JSON.parse_string(JSON.stringify(state))
    if not saved is Dictionary:
        bad("Builder's serialized movement invalid")
        return
    if saved["detail_sim"]["builders"].size()!=count_before:
        bad("Builder assignment was lost on save")
        return
    var initial_resources: float=float(saved["realms"][0]["resources"]["wood"])
    Builders.initialize(saved)
    if saved["detail_sim"]["builders"].size()!=count_before or float(saved["realms"][0]["resources"]["wood"])!=initial_resources:
        bad("Builder save migration reset resources or duplicated workers")
        return
    # Validate the actual 3D scene contains foundation models and builder meshes.
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var home: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(home["c"]),int(home["r"]))
    screen._build_at("lumber",30.0,-10.0)
    await process_frame
    var holder: Node=screen.detail_view.construction_root.get_node_or_null("lumber_1")
    if holder==null or holder.get_node_or_null("Stage0Foundation")==null:
        bad("The initial building foundation is not rendered in 3D")
        return
    screen._advance(1)
    await process_frame
    if screen.detail_view.worker_root.get_node_or_null("Builder_1")==null:
        bad("The animated 3D construction worker is not rendered")
        return
    if bool(screen.city["buildings"][1]["ready"]):
        bad("3D view skipped staged construction")
        return
    screen._advance(10)
    await process_frame
    if not bool(screen.city["buildings"][1]["ready"]):
        bad("3D construction never completed")
        return
    if not FileAccess.file_exists("user://autoport_city_v05.json"):
        bad("City save not written by UI controls")
        return
    print("BUILDERS_V11 SUCCESS: A* worksite travel, 3-stage construction, worker reuse, 3D foundation/worker and save")
    quit(0)
