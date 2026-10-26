extends SceneTree
## 0.33: zero-flicker distance bands, cached medium-detail houses,
## released far meshes and economy-preserving camera-only transitions.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Stable=preload("res://scripts/city_lod_stability_v33.gd")

func fail(why: String) -> void:
    printerr("CITY_LOD_STABILITY_V33 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if Stable.detail(160.0,76.0)!=2 or Stable.detail(260.0,76.0)!=1 or Stable.detail(450.0,76.0)!=0:
        fail("new city LOD changed initial 0.32 thresholds")
        return
    var level: int=Stable.detail(160,76)
    for d in [189.0,197.0,205.0,195.0,210.0]:
        level=Stable.detail(d,76,level)
        if level!=2:
            fail("near-detail LOD flickered inside 20m exit hysteresis")
            return
    level=Stable.detail(225.0,76,level)
    if level!=1:return fail("near-detail did not switch to medium after leaving hysteresis")
    for d in [200.0,185.0,195.0]:
        level=Stable.detail(d,76,level)
        if level!=1:return fail("medium-detail model flickered too early")
    level=Stable.detail(160.0,76,level)
    if level!=2:return fail("near detail did not recover within return threshold")
    level=Stable.detail(370.0,76,1)
    if level!=0:return fail("medium to far transition failed")
    level=Stable.detail(335.0,76,level)
    if level!=0:return fail("far detail flickered near threshold")
    level=Stable.detail(300.0,76,level)
    if level!=1:return fail("far-detail mesh did not recover when approaching")
    var shown: bool=Stable.displayed(500.0,76,false)
    if not shown:return fail("baseline tile unexpectedly culled")
    shown=Stable.displayed(530.0,76,false,shown)
    if not shown:return fail("tile culling flickered within visibility hysteresis")
    shown=Stable.displayed(560.0,76,false,shown)
    if shown:return fail("tile was not culled beyond viewport hysteresis")
    shown=Stable.displayed(500.0,76,false,shown)
    if shown:return fail("culled tile appeared too early")
    shown=Stable.displayed(450.0,76,false,shown)
    if not shown:return fail("tile did not reappear near camera")
    if not Stable.displayed(9999.0,76,true,false):
        return fail("active tile can never be culled")
    if Stable.low_detail_policy(2)!="full" or Stable.low_detail_policy(1)!="retain_hidden" or Stable.low_detail_policy(0)!="release":
        return fail("detail caching policy changed unexpectedly")
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world.duplicate(true)
    var home: Vector2i=Districts.origin(world)
    var neighbor:=home+Vector2i(1,0)
    if neighbor.x>=World.COLS:neighbor=home+Vector2i(-1,0)
    if neighbor.x<0 or neighbor.x>=World.COLS:
        return fail("no horizontally adjacent test district")
    for tile in [home,neighbor]:
        var cell: Dictionary=world["cells"][tile.y*World.COLS+tile.x]
        cell["land"]=true
        cell["biome"]="plains"
        cell["river"]=false
    var city: Dictionary=ui.city
    Spatial.initialize(city)
    city["districts_v25"]={"seed":int(world["seed"]),
        "tiles":[{"c":neighbor.x,"r":neighbor.y}]}
    Transit.configure(city,world)
    var district: String=Districts.key(neighbor)
    var building_index: int=city["buildings"].size()
    city["buildings"].append({"type":"house","x":20.0,"z":-10.0,
        "district":district,"hp":100.0,"ready":true,"rotation":0})
    ui.world_view.world=world
    ui._show_detail(home.x,home.y)
    await process_frame
    var view: Control=ui.detail_view
    var label: String="DistrictTile_"+district.replace(":","_")
    var part: Node3D=view.combined_root.get_node_or_null(label) as Node3D
    if part==null:return fail("neighbor not displayed in the complete 3D town")
    var holder: Node3D=part.get_node_or_null("house_"+str(building_index)) as Node3D
    if holder==null:return fail("near district house did not render")
    var built_count: int=view.passive_building_mesh_builds
    var direction: float=float(neighbor.x-home.x)
    view.controller.look_at=Vector3(-direction*40.0,0,0)
    view._render_neighbors()
    if part.get_node_or_null("house_"+str(building_index))!=holder:
        return fail("camera jitter rebuilt detailed building too early")
    view.controller.look_at=Vector3(-direction*80.0,0,0)
    view._render_neighbors()
    if part.get_node_or_null("house_"+str(building_index))!=holder or holder.visible:
        return fail("medium-detail transition discarded reusable near mesh")
    var proxies: Node3D=part.get_node_or_null("BuildingLODs") as Node3D
    if proxies==null or proxies.get_child_count()==0 or not proxies.visible:
        return fail("medium-detail GPU house silhouette is missing")
    var first_proxy: Node=proxies.get_child(0)
    view.controller.look_at=Vector3(-direction*40.0,0,0)
    view._render_neighbors()
    if part.get_node_or_null("house_"+str(building_index))!=holder or holder.visible:
        return fail("medium-detail model flickered during close pan")
    view.controller.look_at=Vector3.ZERO
    view._render_neighbors()
    if part.get_node_or_null("house_"+str(building_index))!=holder or not holder.visible:
        return fail("cached house was not restored after camera return")
    if view.passive_building_mesh_builds!=built_count:
        return fail("threshold oscillation unnecessarily reconstructed near building")
    view.controller.look_at=Vector3(-direction*80.0,0,0)
    view._render_neighbors()
    if proxies.get_child(0)!=first_proxy:
        return fail("cached medium-detail GPU batch changed without economic edits")
    view.controller.look_at=Vector3(-direction*250.0,0,0)
    view._render_neighbors()
    view._render_neighbors()
    if part.get_node_or_null("house_"+str(building_index))!=null:
        return fail("far district retained detailed model despite memory-release policy")
    if part.get_node_or_null("BuildingLODs")==null:
        return fail("far city lost its silhouette")
    var before_count: int=city["buildings"].size()
    view.controller.look_at=Vector3.ZERO
    view._render_neighbors()
    view._render_neighbors()
    if view.passive_building_mesh_builds<=built_count:
        return fail("returning from far district did not rebuild cleared house mesh")
    if city["buildings"].size()!=before_count:
        return fail("pure visual LOD changed real building count")
    var save: Variant=JSON.parse_string(JSON.stringify(city))
    if not save is Dictionary or int(save["buildings"].size())!=before_count:
        return fail("render cache affected saved economic city state")
    print("CITY_LOD_STABILITY_V33 SUCCESS: no jitter on 195m/335m boundaries, medium cached model, far memory release, economy-safe restoration")
    quit(0)
