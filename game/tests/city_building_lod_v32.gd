extends SceneTree
## 0.32: 72 buildings become a few real GPU-instanced meshes at distance.
## Frustum-distance culling stays render-only. Live city, saved houses and
## physical transport rules are untouched by zoom/LOD and camera motion.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const LOD=preload("res://scripts/city_building_lod_v32.gd")

func fail(why: String) -> void:
    printerr("CITY_BUILDING_LOD_V32 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var houses: Array=[]
    for n in range(72):
        houses.append({"type":"house" if n%3!=0 else "farm","district":"1:1",
            "x":float(n%9)*9.0-40.0,"z":float(n/9)*9.0-32.0,
            "rotation":int(n%4)*90,"ready":true,"hp":100.0})
    var root_node:=Node3D.new()
    root.add_child(root_node)
    var total: int=LOD.populate(root_node,houses,"1:1",1)
    if total!=72 or root_node.get_child_count()!=2:
        fail("72 near-passive houses should use two real MultiMesh batches")
        return
    var instances: int=0
    for group in root_node.get_children():
        if not group is MultiMeshInstance3D:
            fail("passive district house silhouettes are not GPU instanced")
            return
        instances+=(group as MultiMeshInstance3D).multimesh.instance_count
    if instances!=72 or root_node.get_child_count()!=LOD.expected_batches(houses,"1:1",1):
        fail("batched building instances do not match economic building count")
        return
    var far:=Node3D.new()
    root.add_child(far)
    if LOD.populate(far,houses,"1:1",0)!=72 or far.get_child_count()!=1:
        fail("distant city lost houses or failed to merge them into one GPU batch")
        return
    var signature: String=LOD.signature(houses,"1:1",1)
    houses[0]["time"]=5000
    houses[0]["workers"]=900
    if signature!=LOD.signature(houses,"1:1",1):
        fail("LOD was invalidated by a nonvisual economy or time change")
        return
    houses[0]["rotation"]=45
    if signature==LOD.signature(houses,"1:1",1):
        fail("LOD did not invalidate after a visible building rotation")
        return
    houses[0]["ready"]=false
    if LOD.expected_batches(houses,"1:1",1)!=3:
        fail("unfinished building should use a separate construction silhouette")
        return
    if not LOD.visible_at(400.0,76.0) or LOD.visible_at(700.0,76.0):
        fail("small camera view does not cull distant city geometry")
        return
    if not LOD.visible_at(700.0,500.0) or not LOD.visible_at(900.0,500.0,true):
        fail("overview camera or active district became unexpectedly invisible")
        return
    if LOD.level_for_distance(100,76)!=2 or LOD.level_for_distance(260,76)!=1 or LOD.level_for_distance(450,76)!=0:
        fail("three building-detail levels are not distance ordered")
        return
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
        fail("no horizontal neighbor on generated world map")
        return
    for p in [home,neighbor]:
        var cell: Dictionary=world["cells"][p.y*World.COLS+p.x]
        cell["land"]=true
        cell["biome"]="plains"
        cell["river"]=false
    var city: Dictionary=ui.city
    Spatial.initialize(city)
    city["districts_v25"]={"seed":int(world["seed"]), "tiles":[{"c":neighbor.x,"r":neighbor.y}]}
    Transit.configure(city,world)
    var district: String=Districts.key(neighbor)
    var initial_houses: int=city["buildings"].size()
    for item in houses:
        var b: Dictionary=item.duplicate(true)
        b["district"]=district
        city["buildings"].append(b)
    ui.world_view.world=world
    ui._show_detail(home.x,home.y)
    await process_frame
    var view: Control=ui.detail_view
    var part: Node3D=view.combined_root.get_node_or_null("DistrictTile_"+district.replace(":","_")) as Node3D
    if part==null or not view.combined_city:
        fail("neighbor tile not constructed in continuous 3D scene")
        return
    var first_house: Node=part.get_node_or_null("farm_"+str(initial_houses))
    if first_house==null:
        fail("nearby buildings no longer show detailed geometry")
        return
    var dir: int=neighbor.x-home.x
    view.controller.look_at=Vector3(-float(dir)*280.0,0,0)
    view.controller.update_camera()
    view._render_neighbors()
    var proxies: Node3D=part.get_node_or_null("BuildingLODs") as Node3D
    if proxies==null or not proxies.visible or proxies.get_child_count()!=1:
        fail("moving camera away did not switch district buildings to one distant MultiMesh")
        return
    if part.get_node_or_null("farm_"+str(initial_houses))!=null:
        fail("detailed building meshes were retained beneath the far GPU batch")
        return
    var silhouettes: MultiMeshInstance3D=proxies.get_child(0) as MultiMeshInstance3D
    if silhouettes==null or silhouettes.multimesh.instance_count!=72:
        fail("distant city silhouettes lost economic houses")
        return
    var before: Node=proxies.get_child(0)
    view._process(1.0)
    if not view.performance_last.has("lod_batches") or not view.performance_last.has("culled_districts"):
        fail("on-device FPS diagnostics omit the new building LOD and culling counts")
        return
    var saved_count: int=city["buildings"].size()
    view._render_neighbors()
    if proxies.get_child(0)!=before:
        fail("unchanged distant buildings recreate GPU data on every turn")
        return
    view.controller.look_at=Vector3(-float(dir)*700.0,0,0)
    view.controller.update_camera()
    view._process(0.36)
    if part.visible:
        fail("camera culling did not hide a world tile far outside nearby view")
        return
    view.controller.look_at=Vector3.ZERO
    view.controller.update_camera()
    view._process(0.36)
    if not part.visible or part.get_node_or_null("farm_"+str(initial_houses))==null:
        fail("reentering the district did not restore detailed houses")
        return
    if city["buildings"].size()!=saved_count:
        fail("visual culling removed saved/economic houses")
        return
    var old_distance: float=view.controller.distance
    var wheel:=InputEventMouseButton.new()
    wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
    wheel.pressed=true
    view.controller._gui_input(wheel)
    if not view.controller.wheel_target>old_distance or not view.controller.distance<view.controller.wheel_target:
        fail("wheel zoom jumps to final distance without interpolation")
        return
    view.controller._process(0.50)
    if absf(view.controller.distance-view.controller.wheel_target)>0.5:
        fail("camera did not converge smoothly on requested zoom")
        return
    view.controller.focus_smooth(Vector3(float(dir)*130,0,0))
    var initial: Vector3=view.controller.look_at
    view.controller._process(0.05)
    if view.controller.look_at.is_equal_approx(initial) or view.controller.look_at.distance_to(Vector3(float(dir)*130,0,0))>=initial.distance_to(Vector3(float(dir)*130,0,0)):
        fail("district camera focus did not ease toward its destination")
        return
    var json: Variant=JSON.parse_string(JSON.stringify(city))
    if not json is Dictionary or json["buildings"].size()!=saved_count:
        fail("visual LOD polluted JSON save or changed economy buildings")
        return
    print("CITY_BUILDING_LOD_V32 SUCCESS: 72 houses in 2/1 GPU meshes, live LOD switch/culling/restoration, persistent signatures, smoothed camera and economy-safe JSON")
    quit(0)
