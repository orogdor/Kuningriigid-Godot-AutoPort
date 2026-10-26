extends SceneTree
## AutoPort 0.8: test 3D placement + finite resource nodes + warehouse credits.
## Keep JS 0.5 parity tests unchanged (no spatial state -> same calculations).
const Scene = preload("res://content.tscn")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")

func _initialize() -> void:
    call_deferred("_test")

func fail(message: String) -> void:
    printerr("DETAIL_V08 FAIL: "+message)
    quit(1)

func _test() -> void:
    var screen: Control=Scene.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var site: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(site["c"]),int(site["r"]))
    await process_frame
    var detail: Control=screen.detail_view
    if not detail.can_build or not screen.city.has("detail_sim"):
        fail("physical resources not initialized at capital")
        return
    if Spatial.count_remaining(screen.city,"wood")<100.0 or Spatial.count_remaining(screen.city,"stone")<100.0:
        fail("physical deposit starting stock missing")
        return
    if not detail._can_build("lumber"):
        fail("can't select initial lumber")
        return
    detail.select_building("lumber")
    detail._ground_clicked(Vector3(30.0,0.0,-10.0))
    await process_frame
    if screen.city["buildings"].size()!=2:
        fail("3D click did not create lumber building")
        return
    var lumber: Dictionary=screen.city["buildings"][1]
    if not is_equal_approx(float(lumber["x"]),30.0) or not is_equal_approx(float(lumber["z"]),-10.0):
        fail("3D click plot was not persisted")
        return
    var saved_wood: float=float(screen.city["realms"][0]["resources"]["wood"])
    if Spatial.can_place(screen.city,Vector2(0,0)):
        fail("hall area incorrectly buildable")
        return
    screen._advance(10)
    await process_frame
    if not bool(lumber["ready"]):
        fail("lumber failed to complete after 10 turns")
        return
    if screen.city["detail_sim"]["workers"].size()!=1 or detail.worker_root.get_child_count()<1:
        fail("visual gatherer was not spawned")
        return
    # No passive resource credit in spatial mode, workers must deliver.
    var wood_after_10: float=float(screen.city["realms"][0]["resources"]["wood"])
    if wood_after_10 < saved_wood:
        fail("wood inexplicably decreased without construction cost")
        return
    var delivered_at_10: float=float(screen.city["detail_sim"].get("delivered_wood",0.0))
    if not is_equal_approx(wood_after_10,saved_wood+delivered_at_10):
        fail("wood was created by abstract production rather than worker delivery")
        return
    screen._advance(32)
    await process_frame
    var simulated: Dictionary=screen.city["detail_sim"]
    if float(simulated.get("delivered_wood",0))<=0.0:
        fail("workers failed to deliver finite forest resources")
        return
    if Spatial.count_remaining(screen.city,"wood")>=175.0:
        fail("tree sites were never depleted by collection")
        return
    var stock_wood: float=float(screen.city["realms"][0]["resources"]["wood"])
    if not is_equal_approx(stock_wood,saved_wood+float(simulated["delivered_wood"])):
        fail("warehouse resource differs from physically carried cargo")
        return
    var invalid_count: int=screen.city["buildings"].size()
    var stock_before: float=stock_wood
    screen._build_at("house",0,0)
    if screen.city["buildings"].size()!=invalid_count or float(screen.city["realms"][0]["resources"]["wood"])!=stock_before:
        fail("overlapping construction spent stock or placed a building")
        return
    # 0.36: A quarry requires researched Stone Tools, unlike the old
    # 0.8 unresearched sandbox. Keep the physical worker/path test intact.
    var research: Dictionary=screen.city.get("research_v35",{})
    if not research.get("known",[]).has("stone_tools"):
        research["known"].append("stone_tools")
    screen._build_at("quarry",-30,20)
    await process_frame
    if screen.city["buildings"].size()!=invalid_count+1:
        fail("quarry building was not placed")
        return
    screen._advance(35)
    await process_frame
    if float(screen.city["detail_sim"].get("delivered_stone",0))<=0.0:
        fail("quarry worker never delivered stones")
        return
    var old_work=screen.city["detail_sim"]["workers"].size()
    screen._save()
    var loaded: Dictionary=screen._load_city()
    if loaded.get("detail_sim",{}).get("workers",[]).size()!=old_work:
        fail("workers did not survive JSON save/reload")
        return
    screen._show_world()
    if not screen.world_view.visible or detail.visible:
        fail("detail view failed to return to world")
        return
    print("DETAIL_V08 SUCCESS: plot picking, finite sites, worker movement, stock delivery, quarry, valid save, map return")
    quit(0)
