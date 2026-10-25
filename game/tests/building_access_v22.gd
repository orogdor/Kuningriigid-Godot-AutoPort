extends SceneTree
## 0.22 rotated building doors, reachable A* routing, freight delivery,
## access fallbacks and real 3D entrance-path visual regression.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Access=preload("res://scripts/building_access_v22.gd")
const Freight=preload("res://scripts/freight_v14.gd")
const Materials=preload("res://scripts/construction_v12.gd")
const Screen=preload("res://content.tscn")

func fail(msg: String) -> void:
    printerr("BUILDING_ACCESS_V22 FAIL: "+msg)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    Freight.initialize(state)
    var workplace: Dictionary={"type":"farm","team":0,"x":30.0,"z":-10.0,
        "hp":350.0,"ready":true,"rotation":0}
    state["buildings"].append(workplace)
    var expected: Array[Vector2]=[
        Vector2(30,10),Vector2(50,-10),Vector2(30,-30),Vector2(10,-10)]
    var origin: Vector2=Access.entrance(state["buildings"][0])
    if origin!=Vector2(0,20):
        fail("legacy town hall entrance did not face +Z")
        return
    for quarter in range(4):
        workplace["rotation"]=quarter*90
        var doorway: Vector2=Access.entrance(workplace)
        if doorway!=expected[quarter]:
            fail("rotated entrance was wrong for quarter turn "+str(quarter))
            return
        var freight_destination: Vector2=Freight._target(state,1,origin)
        if freight_destination!=doorway:
            fail("freight did not choose the rotated entrance "+str(quarter))
            return
        var constructor_destination: Vector2=Materials._approach(state,{"x":origin.x,"z":origin.y},1)
        if constructor_destination!=doorway:
            fail("construction workers did not choose the rotated entrance")
            return
        var path: Array=Paths.find_path(state,origin,doorway,0)
        if path.is_empty():
            fail("no A* path to rotated doorway")
            return
        for p in path:
            if Paths.blocked(state,Paths.grid(Vector2(float(p["x"]),float(p["z"]))),0):
                fail("door path crossed an occupied building plot")
                return
    workplace["rotation"]=0
    # Another building blocks the main entrance: use a different service
    # side, without walking through its blocking footprint.
    state["buildings"].append({"type":"house","x":30.0,"z":10.0,"hp":350.0,"ready":true})
    var fallback: Vector2=Access.reachable(state,1,origin,0)
    if fallback==Access.entrance(workplace) or fallback.x>1000.0:
        fail("blocked front entrance did not use a reachable fallback")
        return
    state["buildings"].pop_back()
    # Freight must still obey the original production/accounting invariant.
    state["realms"][0]["resources"]["grain"]=0.0
    Freight.enqueue(state,1,"grain",6.0)
    for turn in range(30):
        state["detail_sim"]["turns"]=turn
        Freight.tick(state)
    if float(state["realms"][0]["resources"]["grain"])!=6.0:
        fail("freight did not deliver six grain through the door")
        return
    if not Freight.conserved(state,"grain"):
        fail("door routing duplicated or dropped freight cargo")
        return
    var json: Variant=JSON.parse_string(JSON.stringify(state))
    if not json is Dictionary:
        fail("access-aware freight data was not JSON serializable")
        return
    workplace.erase("rotation")
    if Access.entrance(workplace)!=Vector2(30,10):
        fail("a legacy building without rotation changed orientation")
        return
    # Visible 3D doorstep and link at the same world coordinates.
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var capital: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(capital["c"]),int(capital["r"]))
    await process_frame
    ui.city["buildings"].append({"type":"farm","team":0,"x":30.0,"z":-10.0,
        "hp":350.0,"ready":true,"rotation":90})
    ui.detail_view.refresh_buildings()
    await process_frame
    var farm: Node3D=ui.detail_view.construction_root.get_node_or_null("farm_1") as Node3D
    if farm==null or farm.get_node_or_null("FrontDoorStep")==null:
        fail("3D farm has no visible oriented threshold")
        return
    if not is_equal_approx(farm.rotation_degrees.y,90.0):
        fail("door marker was not rotated with the building")
        return
    if ui.detail_view.roads_root.get_node_or_null("DoorAccessPath_1")==null or ui.detail_view.roads_root.get_node_or_null("DoorAccessPoint_1")==null:
        fail("3D doorway was not visibly linked to a walking path")
        return
    print("BUILDING_ACCESS_V22 SUCCESS: four orientations, A* door routing, backup, freight conservation, legacy saves, visible links")
    quit(0)
