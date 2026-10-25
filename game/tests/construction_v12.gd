extends SceneTree
## 0.12 construction logistics: warehouse stock is charged exactly once;
## individual builders physically carry prepaid supplies before work can start.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Logistics = preload("res://scripts/construction_v12.gd")
const View = preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("CONSTRUCTION_V12 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var before: float=float(state["realms"][0]["resources"]["wood"])
    state["pending_site"]={"x":30,"z":-10}
    if City.build(state,"lumber")!="":
        fail("cannot order lumber with available prepaid stock")
        return
    var site: Dictionary=state["buildings"][1]
    if not is_equal_approx(float(state["realms"][0]["resources"]["wood"]),before-20.0):
        fail("city stock was not debited exactly once on order")
        return
    if float(site.get("supply_total",{}).get("wood",0))!=20:
        fail("lumber reservation does not contain its complete 20 wood cost")
        return
    if Logistics.fully_supplied(site):
        fail("new construction is incorrectly fully supplied before delivery")
        return
    City.tick(state)
    var builders: Array=state["detail_sim"].get("builders",[])
    if builders.size()!=2:
        fail("two staffed construction workers not allocated")
        return
    var sum_cargo: float=0.0
    for worker in builders:
        sum_cargo+=float(worker.get("cargo_amount",0))
        if Vector2(float(worker["x"]),float(worker["z"])).distance_to(Vector2(30,-10))<0.001:
            fail("builder teleported to building center")
            return
    if sum_cargo+float(site["supply_delivered"].get("wood",0))>20.00001:
        fail("materials were duplicated in transit")
        return
    var progress_at_first_turn: float=float(site["progress"])
    if progress_at_first_turn>0 and not Logistics.fully_supplied(site):
        fail("worker built without all reserved materials arriving")
        return
    for turn in range(12):
        if bool(site["ready"]):break
        City.tick(state)
        if float(site.get("progress",0))>0 and not Logistics.fully_supplied(site):
            fail("construction progressed ahead of material delivery")
            return
    if not bool(site["ready"]):
        fail("two builders did not finish a reachable structure")
        return
    if not is_equal_approx(float(site["supply_delivered"]["wood"]),20):
        fail("wood deliveries were not conserved in the 3D building")
        return
    if float(state["realms"][0]["resources"]["wood"])<before-20.00001:
        fail("warehouse was charged for prepaid materials twice")
        return
    if int(state["detail_sim"].get("version",0))<5:
        fail("0.12 city save schema migration did not happen")
        return
    # The second building reuses idle builders instead of creating extra citizens.
    var retained: int=state["detail_sim"]["builders"].size()
    state["pending_site"]={"x":-30,"z":-10}
    if City.build(state,"house")!="":
        fail("second building order not possible")
        return
    for t in range(16):
        if bool(state["buildings"][2]["ready"]):break
        City.tick(state)
    if not bool(state["buildings"][2]["ready"]):
        fail("idle builders did not finish second building")
        return
    if state["detail_sim"]["builders"].size()!=retained:
        fail("construction creates unlimited extra builder actors")
        return
    var loaded: Variant=JSON.parse_string(JSON.stringify(state))
    if not loaded is Dictionary:
        fail("builder/material data broke JSON save")
        return
    Logistics.initialize(loaded)
    if loaded["detail_sim"]["builders"].size()!=retained:
        fail("old builder data was lost during reload")
        return
    if not is_equal_approx(float(loaded["buildings"][1]["supply_delivered"]["wood"]),20):
        fail("already delivered resources were lost")
        return
    # V0.11 incomplete buildings were prepaid in old saves: don't charge again.
    var old: Dictionary=City.default_state()
    Spatial.initialize(old)
    old["pending_site"]={"x":30,"z":-10}
    if City.build(old,"lumber")!="":
        fail("legacy 0.11 preparation failed")
        return
    old["buildings"][1].erase("supply_total")
    old["buildings"][1].erase("supply_delivered")
    old["detail_sim"]["version"]=4
    var paid: float=float(old["realms"][0]["resources"]["wood"])
    Logistics.initialize(old)
    if not Logistics.fully_supplied(old["buildings"][1]) or float(old["realms"][0]["resources"]["wood"])!=paid:
        fail("legacy v0.11 prepaid unfinished building was charged again")
        return
    # Confirm actual 3D blueprint renders without premature material pile.
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var capital: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(capital["c"]),int(capital["r"]))
    screen._build_at("lumber",30,-10)
    await process_frame
    var holder: Node=screen.detail_view.construction_root.get_node_or_null("lumber_1")
    if holder==null or holder.get_node_or_null("Stage0Foundation")==null:
        fail("3D worksite foundations missing")
        return
    screen._advance(1)
    await process_frame
    if screen.detail_view.worker_root.get_node_or_null("Builder_1")==null:
        fail("first delivery builder is absent from 3D detail")
        return
    if screen.detail_view.worker_root.get_node_or_null("Builder_2")==null:
        fail("second delivery builder is absent from 3D detail")
        return
    print("CONSTRUCTION_V12 SUCCESS: prepaid delivery, no duplication, two builders, multi-stage work, old saves and 3D actors")
    quit(0)
