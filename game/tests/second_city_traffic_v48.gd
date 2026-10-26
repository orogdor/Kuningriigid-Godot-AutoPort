extends SceneTree
## AutoPort 0.48 checks that genuine spatial traffic, finite tree gathering
## and the second town's moving workers appear while viewing from next tile.
const Scene=preload("res://content.tscn")
const City=preload("res://scripts/city_sim_v05.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Activity=preload("res://scripts/detail_neighbor_activity_v48.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Locator=preload("res://scripts/second_city_detail_v47.gd")

func fail(why: String) -> void:
    printerr("SECOND_CITY_TRAFFIC_V48 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._found_trade_city()
    var location: Dictionary=ui._satellite_tile()
    var world: Dictionary=ui.world_view.world
    var second: Vector2i=Locator.satellite_position(location,world)
    if second.x<0:
        fail("actual second-city world coordinates missing")
        return
    ui._open_satellite()
    ui._toggle_satellite_ai() # A manual player builds the town in this fixture.
    var satellite: Dictionary=Trade.ensure_city(ui.city)
    var stock: Dictionary=satellite["realms"][0]["resources"]
    var capital_buildings: int=ui.city["buildings"].size()
    var original_wood: float=float(stock.get("wood",0))
    if Trade.send(ui.city,"outpost","wood",15.0)!="":
        fail("could not finance worker hut through real caravan")
        return
    var route_time: int=int(ui.city["trade_v15"]["route_v17"]["duration"])
    for i in range(route_time):
        City.tick(ui.city)
    if float(stock.get("wood",0))<original_wood+14.9:
        fail("caravan did not deliver real materials")
        return
    ui._show_detail(second.x,second.y)
    ui._build_at("lumber",30,-10,90)
    if satellite["buildings"].size()!=2:
        fail("independent town lumber building failed")
        return
    var sim: Dictionary=satellite.get("detail_sim",{})
    if sim.is_empty() or sim.get("sites",[]).is_empty():
        fail("second town isn't using finite local tree/stone deposits")
        return
    var delivered: bool=false
    var naturally_traveled: bool=false
    for turn in range(130):
        City.tick(ui.city)
        if float(sim.get("delivered_wood",0.0))>0.0:delivered=true
        if not sim.get("roads",{}).is_empty():naturally_traveled=true
        if delivered and naturally_traveled and not Paths.road_tiles(sim).is_empty():
            break
    if not delivered:
        fail("second-city workers never returned harvested wood to local warehouse")
        return
    if not naturally_traveled:
        fail("second-city real workers did not record walking traffic")
        return
    var roads: Array=Paths.road_tiles(sim)
    if roads.is_empty():
        fail("workers didn't wear visible footpaths from repeated walking")
        return
    var sampled: Dictionary=Activity.snapshot(satellite)
    if sampled["roads"].size()!=mini(Activity.MAX_ROADS,roads.size()):
        fail("neighbor preview did not use exact worn spatial road tiles")
        return
    if sampled["workers"].is_empty():
        fail("town workers missing from neighbor preview data")
        return
    var old_age: Dictionary=sim.duplicate(true)
    old_age["turns"]=int(old_age["turns"])+Paths.ROAD_FADE_TURNS*30
    var faded_town: Dictionary={"detail_sim":old_age}
    if not Activity.snapshot(faded_town)["roads"].is_empty():
        fail("roads didn't disappear after no one used them")
        return
    var capital_stock: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    var second_stock: Dictionary=stock.duplicate(true)
    var neighbor: Vector2i=second+Vector2i(1,0)
    if World.cell(world,neighbor.x,neighbor.y).is_empty():
        fail("neighbor detail square doesn't exist")
        return
    ui._show_detail(neighbor.x,neighbor.y)
    await process_frame
    var view=ui.detail_view
    if view.can_build:
        fail("neighbor road preview illegally allowed town construction")
        return
    var part: Node3D=view.seam_preview_root.get_node_or_null(
        "DetailNeighbor_-1_0") as Node3D
    var group: Node3D=part.get_node_or_null("ActualNeighborActivity") as Node3D if part!=null else null
    if group==null:
        fail("town traffic was not visible from the next tile")
        return
    var drawn_roads: MultiMeshInstance3D=group.get_node_or_null(
        "ActualNeighborRoadTiles") as MultiMeshInstance3D
    var drawn_workers: MultiMeshInstance3D=group.get_node_or_null(
        "ActualNeighborWorkers") as MultiMeshInstance3D
    if drawn_roads==null or drawn_workers==null:
        fail("real footpaths or workers are missing 3D meshes")
        return
    if drawn_roads.multimesh.instance_count!=sampled["roads"].size() or \
            drawn_workers.multimesh.instance_count!=sampled["workers"].size():
        fail("3D previews duplicated or removed simulated worker/road data")
        return
    view._refresh_seam_neighbor_buildings()
    if part.get_node_or_null("ActualNeighborActivity")!=group:
        fail("unchanged visual road/worker groups regenerate unnecessarily")
        return
    if stock!=second_stock or ui.city["realms"][0]["resources"]!=capital_stock:
        fail("read-only neighboring 3D activity altered either town's resources")
        return
    if ui.city["buildings"].size()!=capital_buildings:
        fail("viewing satellite workers modified capital buildings")
        return
    var copy: Variant=JSON.parse_string(JSON.stringify(ui.city))
    if not copy is Dictionary:
        fail("two-town road saves aren't serializable")
        return
    var loaded: Dictionary=Trade.ensure_city(copy)
    if loaded.get("detail_sim",{}).get("roads",{}).size()!=sim.get("roads",{}).size():
        fail("second city's worn paths did not survive save/reload")
        return
    print("SECOND_CITY_TRAFFIC_V48 SUCCESS: real satellite harvest delivery, autonomous walked/fading footpaths, neighbor workers+roads, no ghost activity or stock transfer, save")
    quit(0)
