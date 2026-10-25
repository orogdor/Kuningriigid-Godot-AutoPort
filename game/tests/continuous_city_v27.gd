extends SceneTree
## AutoPort 0.27: adjacent 160m world-tile terrain is visible at once.
## Selecting and building across a seam never leaves the 3D scene, never
## changes the legacy capital plot and preserves the earlier trade save.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Continuous=preload("res://scripts/continuous_city_v27.gd")
const Visuals30=preload("res://scripts/district_visuals_v30.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")

func fail(reason: String) -> void:
    printerr("CONTINUOUS_CITY_V27 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    ui._show_detail(home.x,home.y)
    await process_frame
    if ui.detail_view.combined_city:
        fail("single-city 0.26 save wrongly entered combined view")
        return
    if ui.detail_view.controller.max_distance!=180.0:
        fail("standalone city camera lost its legacy zoom range")
        return
    var city: Dictionary=ui.city
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=500.0
    stock["stone"]=500.0
    city["realms"][0]["pop"]=18
    var annex: Vector2i=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var p: Vector2i=home+delta
        var cell: Dictionary=World.cell(world,p.x,p.y)
        if cell.is_empty() or not bool(cell.get("land",false)) or String(cell.get("biome",""))=="hills":continue
        if Districts.expand(city,world,p.x,p.y)=="":
            annex=p
            break
    if annex.x<0:
        fail("no adjacent land to test continuous district view")
        return
    Transit.configure(city,world)
    var annex_id: String=Districts.key(annex)
    var initial_count: int=city["buildings"].size()
    ui._show_detail(annex.x,annex.y)
    ui._build_at("house",30,-10,90)
    await process_frame
    if city["buildings"].size()!=initial_count+1:
        fail("the annex house did not enter the shared economic state")
        return
    var annex_index: int=initial_count
    ui._show_detail(home.x,home.y)
    await process_frame
    var detail: Control=ui.detail_view
    if not detail.combined_city or detail.shown_district_tiles.size()!=2:
        fail("capital did not load a two-district continuous scene")
        return
    if detail.combined_root==null or detail.combined_bounds.is_empty():
        fail("combined terrain or camera bounds are missing")
        return
    var offset: Vector3=Continuous.offset(annex,home)
    if not is_equal_approx(offset.length(),160.0):
        fail("world tile centers do not share a 160 meter separation")
        return
    if detail.combined_root.get_node_or_null("DistrictTile_"+annex_id.replace(":","_"))==null:
        fail("neighbor terrain was not visible in the capital 3D scene")
        return
    var annex_root: Node3D=detail.combined_root.get_node_or_null(
        "DistrictTile_"+annex_id.replace(":","_")) as Node3D
    if annex_root.get_node_or_null("DistrictTerrain")==null:
        fail("neighbor did not have its own rendered contiguous land plane")
        return
    var size: Vector3=(annex_root.get_node("DistrictTerrain") as MeshInstance3D).mesh.get_aabb().size
    if not is_equal_approx(size.x,160.0) or not is_equal_approx(size.z,160.0):
        fail("adjacent terrain width/depth were not aligned to the exact gate distance")
        return
    if annex_root.get_node_or_null("house_"+str(annex_index))==null:
        fail("annex house was not rendered beside the capital without changing maps")
        return
    var expected_streets: int=Visuals30.connections(city,world,home,detail.shown_district_tiles).size()
    var street_count: int=0
    for node in detail.combined_root.get_children():
        if String(node.name).begins_with("ContinuousStreet_"):street_count+=1
    if street_count!=expected_streets:
        fail("visible 3D streets disagree with physically A*-passable shared gates")
        return
    if detail.controller.max_distance<=180.0:
        fail("multi-district camera stayed restricted to original detail tile")
        return
    detail._overview_city()
    var center: Vector3=detail.combined_bounds["midpoint"]
    if not detail.controller.look_at.is_equal_approx(center):
        fail("overview button did not focus on the whole connected city")
        return
    var ray_position: Vector3=offset+Vector3(30,0,-10)
    if Continuous.at_position(world,city,home,ray_position)!=annex:
        fail("3D screen point could not be mapped to the owned adjacent tile")
        return
    # The first tap focuses a new district but must never accidentally
    # place a structure while a construction preview was open in the capital.
    detail.select_building("house")
    var before: int=city["buildings"].size()
    var before_wood: float=float(stock["wood"])
    detail._ground_clicked(ray_position)
    await process_frame
    if city["buildings"].size()!=before or not is_equal_approx(float(stock["wood"]),before_wood):
        fail("switching 3D district built an unwanted house or spent resources")
        return
    if detail.active_tile!=annex or detail.district_id!=annex_id:
        fail("3D tap did not activate the neighboring construction district")
        return
    if not detail.construction_root.position.is_equal_approx(offset):
        fail("selected tile's 3D buildings failed to rebase to world position")
        return
    if detail.combined_root.get_node_or_null("DistrictTile_Capital")==null:
        fail("capital buildings vanished when focusing its neighbor")
        return
    detail.select_building("house")
    var added: Vector3=offset+Vector3(-30,0,-10)
    detail._ground_clicked(added)
    await process_frame
    if city["buildings"].size()!=before+1:
        fail("could not construct a new house across the 3D tile seam")
        return
    var built: Dictionary=city["buildings"].back()
    if String(built.get("district",""))!=annex_id or int(built.get("x",999))!=-30:
        fail("new cross-tile house lost its local plot or district ownership")
        return
    if float(stock["wood"])>=before_wood:
        fail("building across tile seam did not spend the real shared resources")
        return
    # Existing 0.26 transport agents also remain visible on a passive tile.
    city["transport_v26"]["agents"].append({"id":99001,"district":Transit.home_key(city),
        "role":"wagon","x":0.0,"z":20.0,"load":4.0,"kind":"grain"})
    detail.refresh_buildings()
    await process_frame
    var capital_tile: Node3D=detail.combined_root.get_node_or_null("DistrictTile_Capital") as Node3D
    if capital_tile==null or capital_tile.get_node_or_null("DistrictAgent_99001")==null:
        fail("physical wagon on passive capital tile did not remain visible")
        return
    var view_scene: Node3D=detail.scene_root
    detail._next_city_tile()
    if detail.scene_root!=view_scene or not detail.combined_city:
        fail("next district navigation destroyed or exited the connected 3D scene")
        return
    ui._save()
    var reloaded: Dictionary=ui._load_city()
    if not Districts.owns(reloaded,world,annex.x,annex.y):
        fail("continuous 3D selection changed district ownership on JSON save")
        return
    if String(reloaded["buildings"].back().get("district",""))!=annex_id:
        fail("house placement changed after JSON reload")
        return
    print("CONTINUOUS_CITY_V27 SUCCESS: seamless 160m terrain, 3D linked streets, unbroken camera, in-scene selection, buildings, passive wagons, legacy save")
    quit(0)
