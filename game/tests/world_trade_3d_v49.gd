extends SceneTree
## v0.49: 3D roads and moving carts follow the same REAL national
## trade route and arrival clock as the old fallback 2D map.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const Route3D=preload("res://scripts/world_trade_3d_v49.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")

func fail(reason: String) -> void:
    printerr("WORLD_TRADE_3D_V49 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var map=ui.world_view
    var scene=map.terrain_3d
    if not map.map_3d_enabled or not scene.visible:
        fail("world map no longer defaults to 3D")
        return
    if scene.trade_road_root.get_child_count()!=0:
        fail("a non-existent second city generated a ghost road")
        return
    ui._found_trade_city()
    if not Trade.has_outpost(ui.city):
        fail("could not found actual second city")
        return
    var trade: Dictionary=ui.city["trade_v15"]
    var route: Dictionary=trade["route_v17"]
    var points: Array[Vector3]=Route3D.route_points(map.world,route)
    if points.size()!=route["tiles"].size() or points.size()<2:
        fail("3D route differs from exact saved land path")
        return
    for i in range(points.size()):
        var cell: Dictionary=route["tiles"][i]
        if not Routes.passable(map.world,int(cell["c"]),int(cell["r"])):
            fail("3D route crosses a sea or mountain tile")
            return
        if absf(points[i].x-float(cell["c"])-0.5)>0.00001 or \
                absf(points[i].z-float(cell["r"])-0.5)>0.00001:
            fail("3D road isn't centered on the corresponding 2D road tile")
            return
    var road: MultiMeshInstance3D=scene.trade_road_root.get_node_or_null(
        "SavedTradeRoad3D") as MultiMeshInstance3D
    if road==null or road.multimesh.instance_count!=points.size()-1:
        fail("3D trade road didn't use instanced real path segments")
        return
    if scene.trade_road_root.get_node_or_null("CapitalTradePin3D")==null or \
            scene.trade_road_root.get_node_or_null("SatelliteTradePin3D")==null:
        fail("3D markers do not show both actual city ends")
        return
    if map.map_canvas.trade_route.get("tiles",[]).size()!=points.size():
        fail("the 2D and 3D route selections are out of sync")
        return
    var reference: Node=road
    ui._trade_send("outpost","wood",5.0)
    ui._trade_send("capital","wood",5.0)
    if scene.trade_caravans_root.get_child_count()!=2:
        fail("both directions of trade aren't shown in 3D")
        return
    var outward: Node3D=scene.trade_caravans_root.get_node_or_null(
        "TradeCaravan3D_1") as Node3D
    var return_trip: Node3D=scene.trade_caravans_root.get_node_or_null(
        "TradeCaravan3D_2") as Node3D
    if outward==null or return_trip==null:
        fail("missing caravan actor or lost the real saved caravan ID")
        return
    if outward.position.distance_to(points[0])>0.001 or \
            return_trip.position.distance_to(points[points.size()-1])>0.001:
        fail("caravans don't depart from the real source city")
        return
    if outward.get_node_or_null("CaravanCargo")==null or \
            return_trip.get_node_or_null("CaravanBody")==null:
        fail("3D wagon or load geometry is missing")
        return
    var capital_stock: String=JSON.stringify(ui.city["realms"][0]["resources"])
    var second_stock: String=JSON.stringify(
        Trade.ensure_city(ui.city)["realms"][0]["resources"])
    map.set_trade_route(route,trade["caravans"])
    if scene.trade_road_root.get_node_or_null("SavedTradeRoad3D")!=reference:
        fail("unchanged saved road mesh rebuilt at each update")
        return
    if JSON.stringify(ui.city["realms"][0]["resources"])!=capital_stock or \
            JSON.stringify(Trade.ensure_city(ui.city)["realms"][0]["resources"])!=second_stock:
        fail("3D visualization modified the actual city warehouses")
        return
    var duration: int=int(route["duration"])
    ui._advance(1)
    outward=scene.trade_caravans_root.get_node_or_null(
        "TradeCaravan3D_1") as Node3D
    return_trip=scene.trade_caravans_root.get_node_or_null(
        "TradeCaravan3D_2") as Node3D
    if outward==null or return_trip==null:
        fail("caravans disappeared before actual delivery")
        return
    var expected: Array=Route3D.caravan_positions(points,trade["caravans"])
    if expected.size()!=2 or \
            outward.position.distance_to(expected[0]["point"])>0.001 or \
            return_trip.position.distance_to(expected[1]["point"])>0.001:
        fail("3D caravan progress doesn't agree with 2D trade-route progress")
        return
    if outward.position.distance_to(points[0])<0.001 or \
            return_trip.position.distance_to(points[points.size()-1])<0.001:
        fail("caravans weren't animated on the next real game turn")
        return
    if scene.trade_road_root.get_node_or_null("SavedTradeRoad3D")!=reference:
        fail("updating moving caravans rebuilt the full road mesh")
        return
    ui._advance(duration-1)
    if not trade["caravans"].is_empty() or \
            scene.trade_caravans_root.get_child_count()!=0:
        fail("3D caravans continued past their true arrival time")
        return
    if scene.trade_road_root.get_child_count()==0:
        fail("delivered cargo unexpectedly removed the permanent road")
        return
    var stale: Dictionary=route.duplicate(true)
    stale["seed"]=int(route["seed"])+1
    map.set_trade_route(stale,[])
    if scene.trade_road_root.get_child_count()!=0 or \
            not Route3D.route_points(map.world,stale).is_empty():
        fail("a route from an unrelated world was still drawn")
        return
    map.set_trade_route({},[])
    if scene.trade_caravans_root.get_child_count()!=0:
        fail("clearing the trade route left phantom caravans")
        return
    print("WORLD_TRADE_3D_V49 SUCCESS: actual saved path in 3D; 2D parity; bidirectional wagons, ETA and arrival; cached GPU road; unchanged city resources")
    quit(0)
