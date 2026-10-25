extends SceneTree
## 0.30: the roads in the 3D scene must be REAL A*-passable physical
## gates, not decorative centered rectangles. Moving cargo may not force
## static streets or unchanged building meshes to be regenerated.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const Visuals=preload("res://scripts/district_visuals_v30.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")

func fail(reason: String) -> void:
    printerr("DISTRICT_VISUALS_V30 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world.duplicate(true)
    var home: Vector2i=Districts.origin(world)
    var other:=home+Vector2i(1,0)
    if other.x>=World.COLS:other=home+Vector2i(-1,0)
    if other.x<0 or other.x>=World.COLS:
        fail("world fixture has no east-west neighbor")
        return
    # Deterministic flat river-free fixture with the same real 160m seam.
    # It uses production A* and district travel code, not a mocked path.
    for tile in [home,other]:
        var cell: Dictionary=world["cells"][tile.y*World.COLS+tile.x]
        cell["land"]=true
        cell["biome"]="plains"
        cell["river"]=false
    var city: Dictionary=ui.city
    city["districts_v25"]={"seed":int(world["seed"]),
        "tiles":[{"c":other.x,"r":other.y}]}
    Spatial.initialize(city)
    Transit.configure(city,world)
    var area: Array[Vector2i]=[home,other]
    var links: Array=Visuals.connections(city,world,home,area)
    if links.size()!=1:
        fail("two safe adjacent districts did not produce one reachable 3D road")
        return
    var link: Dictionary=links[0]
    if not is_equal_approx(float(link["length"]),20.0):
        fail("crossing road length differs from the real 20m travel budget")
        return
    var gate_from: Vector2=link["gate_a"]
    if not gate_from.is_equal_approx(Vector2(70,0)) and not gate_from.is_equal_approx(Vector2(-70,0)):
        fail("street does not start at the physical border gate")
        return
    # Obstruct only the central gate, so A* must choose an offset gate
    # and the visual connection must move to exactly that offset.
    var source: String=String(link["from"])
    var origin_district: String="" if source==Transit.home_key(city) else source
    var blocker: Dictionary={"type":"house","x":gate_from.x,"z":0.0,"hp":300.0,
        "ready":true,"district":origin_district}
    city["buildings"].append(blocker)
    var moved: Array=Visuals.connections(city,world,home,area)
    if moved.size()!=1 or is_zero_approx(float(moved[0]["gate_a"].y)):
        fail("visible street did not follow A* around a blocked center gate")
        return
    # Block every offered gate along that border. There must be no false
    # roadway passing through houses on the visual world.
    for z in [-60.0,-40.0,-20.0,20.0,40.0,60.0]:
        city["buildings"].append({"type":"house","x":gate_from.x,"z":z,
            "hp":300.0,"ready":true,"district":origin_district})
    if not Visuals.connections(city,world,home,area).is_empty():
        fail("decorative road remains after all real physical gates are blocked")
        return
    var signature: String=Visuals.static_signature(city,world)
    city["transport_v26"]["agents"].append({"id":99991,"role":"wagon",
        "district":Transit.home_key(city),"x":0.0,"z":0.0,"load":5.0})
    city["transport_v26"]["agents"][0]["x"]=20.0
    city["time"]=float(city.get("time",0))+5.0
    if Visuals.static_signature(city,world)!=signature:
        fail("static gate cache changed for moving cargo or advancing time")
        return
    city["buildings"].pop_back()
    if Visuals.static_signature(city,world)==signature:
        fail("static gate cache did not invalidate after a building changed")
        return
    if Visuals.detail_level(Vector3.ZERO,Vector3(100,0,0))!=2 or Visuals.resource_limit(2)!=14:
        fail("near-view resource LOD is incorrect")
        return
    if Visuals.detail_level(Vector3.ZERO,Vector3(270,0,0))!=1 or Visuals.resource_limit(1)!=5:
        fail("medium-distance resource LOD is incorrect")
        return
    if Visuals.detail_level(Vector3.ZERO,Vector3(450,0,0))!=0 or Visuals.resource_limit(0)!=0:
        fail("far city block did not remove decorative resource models")
        return
    # Test the actual 3D scene independently of the temporary blocked
    # gate fixture, which is deliberately not a legal buildable village.
    var live: Dictionary=ui.city
    live["buildings"]=[live["buildings"][0]]
    live["districts_v25"]={"seed":int(world["seed"]), "tiles":[{"c":other.x,"r":other.y}]}
    live.erase("transport_v26")
    Transit.configure(live,world)
    ui.world_view.world=world
    ui._show_detail(home.x,home.y)
    await process_frame
    var detail: Control=ui.detail_view
    if not detail.combined_city or detail.combined_root==null:
        fail("combined 3D city was not opened")
        return
    var hall: Node3D=detail.construction_root.get_node_or_null("hall_0") as Node3D
    if hall==null:
        fail("capital hall was not visible")
        return
    var built: int=detail.active_building_mesh_builds
    var ground_count: int=detail.terrain_mesh_builds
    var static_roads: Array=[]
    for node in detail.combined_root.get_children():
        if String(node.name).begins_with("ContinuousStreet_"):static_roads.append(node)
    detail.refresh_buildings()
    detail.refresh_buildings()
    if not is_instance_valid(hall) or detail.construction_root.get_node_or_null("hall_0")!=hall:
        fail("unchanged active building was rebuilt on every simulation tick")
        return
    if detail.active_building_mesh_builds!=built or detail.terrain_mesh_builds!=ground_count:
        fail("static 3D city meshes were rebuilt after two identical refreshes")
        return
    if static_roads.size()!=Visuals.connections(live,world,home,detail.shown_district_tiles).size():
        fail("3D roads do not match the tested physical gate count")
        return
    for node in static_roads:
        if not is_instance_valid(node):
            fail("unchanged road object was discarded between ticks")
            return
    var before: int=detail.active_building_mesh_builds
    live["buildings"][0]["rotation"]=90
    detail.refresh_buildings()
    if detail.active_building_mesh_builds!=before+1:
        fail("rotating an actual building failed to invalidate its 3D mesh")
        return
    var saved: Variant=JSON.parse_string(JSON.stringify(live))
    if not saved is Dictionary or not Districts.owns(saved,world,other.x,other.y):
        fail("visual cache polluted the economic save file")
        return
    print("DISTRICT_VISUALS_V30 SUCCESS: physical 20m streets, rerouted center blocker, closed gate, stable static meshes, 3-level LOD, JSON")
    quit(0)
