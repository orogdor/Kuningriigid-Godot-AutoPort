extends SceneTree
## 0.29 regression: A* really obeys the same 3D river/water and slopes.
## Legacy one-tile saves use unchanged 0.10 rules; annexed tiles have a
## compact world-seeded river descriptor, never a duplicated world array.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const Draw=preload("res://scripts/continuous_terrain_v28.gd")
const Legacy=preload("res://scripts/detail_terrain_v10.gd")
const Nav=preload("res://scripts/terrain_navigation_v29.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")

func fail(reason: String) -> void:
    printerr("TERRAIN_NAVIGATION_V29 FAIL: "+reason)
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
    # The spatial simulation is initialized on first opening the capital.
    # Earlier 0.29 test omitted this and crashed before assertions started.
    ui._show_detail(home.x,home.y)
    await process_frame
    var city: Dictionary=ui.city
    var neighbor:=home+Vector2i(1,0)
    if neighbor.x>=World.COLS:
        neighbor=home+Vector2i(-1,0)
    # Inject a controlled, connected straight river. Only these two
    # adjacent world tiles need a river; no brittle random-map assumptions.
    for p in [home,neighbor]:
        var cell: Dictionary=world["cells"][p.y*World.COLS+p.x]
        cell["land"]=true
        cell["biome"]="plains"
        cell["river"]=true
    city["districts_v25"]={"seed":world["seed"],"tiles":[{"c":neighbor.x,"r":neighbor.y}]}
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=500.0
    stock["stone"]=500.0
    Transit.configure(city,world)
    var sim: Dictionary=city["detail_sim"]
    var second: Dictionary=city["transport_v26"]["surfaces"][Districts.key(neighbor)]
    if not Nav.enabled(sim) or not Nav.enabled(second):
        fail("both physical district pathfinders lack shared river profile")
        return
    if sim["terrain_v29"].has("world") or JSON.stringify(sim["terrain_v29"]).length()>700:
        fail("river metadata copies nonserializable or entire world-map data")
        return
    for step in range(-8,9):
        var z: float=float(step)*10.0
        var first: float=Nav.ground(sim,80.0,z)
        var next: float=Nav.ground(second,-80.0,z)
        if not is_equal_approx(first,next):
            fail("A-star height mismatches across 3D district border")
            return
        if not is_equal_approx(Nav.ground(sim,30.0,z),Draw.height(world,home,30.0,z)):
            fail("pathfinder elevation differs from rendered surface")
            return
    var bridge_cell:=Vector2i(3,2)
    var other:=Vector2i(3,3)
    if not Nav.underwater(sim,Vector2(30,25)):
        fail("rendered river centerline is not in A-star water mask")
        return
    if not Nav.blocked(sim,bridge_cell):
        fail("A-star permits a cell inside the visible river without crossing")
        return
    if Nav.passable_step(sim,bridge_cell,other):
        fail("A-star jumped across a 12m-wide river despite no bridge")
        return
    if Nav.passable_step(sim,Vector2i(3,2),Vector2i(4,3)):
        fail("diagonal A-star jump crossed the same visible river")
        return
    # Natural ford x=0 exists in both visible models; x=30 is reserved
    # for a player-built bridge, and must be closed until payment.
    var ford: Vector2=Vector2(0,25)
    if Nav.crossing_at(sim,ford).get("kind","")!="ford":
        fail("known ford not present in visible/navigable crossing list")
        return
    if not Nav.passable_step(sim,Vector2i(0,2),Vector2i(0,3)):
        fail("ford does not allow the actual river crossing")
        return
    if not Nav.can_bridge(sim,"x",3) or Nav.bridge_position(sim,"x",3).distance_to(Vector2(30,25))>0.1:
        fail("bridge position is inconsistent with the river centerline")
        return
    var prior_wood: float=float(stock["wood"])
    var prior_stone: float=float(stock["stone"])
    if Nav.build_bridge(city,sim,"x",3)!="":
        fail("valid bridge could not be constructed")
        return
    if not is_equal_approx(float(stock["wood"]),prior_wood-28.0) or not is_equal_approx(float(stock["stone"]),prior_stone-18.0):
        fail("bridge did not deduct correct shared resources")
        return
    if not Nav.passable_step(sim,bridge_cell,other) or Nav.blocked(sim,bridge_cell):
        fail("paid bridge failed to unlock physical A-star crossing")
        return
    if Nav.can_bridge(sim,"x",3):
        fail("duplicate bridge position incorrectly remains buildable")
        return
    var nav_state: Dictionary={"buildings":[],"detail_sim":sim}
    var path: Array=Paths.find_path(nav_state,Vector2(30,0),Vector2(30,50),-1)
    if path.is_empty():
        fail("real A-star cannot cross the player's finished bridge")
        return
    var serialized: Variant=JSON.parse_string(JSON.stringify(city))
    if not serialized is Dictionary or not Nav.passable_step(serialized["detail_sim"],bridge_cell,other):
        fail("shared physical bridge and river metadata lost in JSON save")
        return
    # Materialize actual Godot 3D bridge from the same descriptor.
    ui.world_view.world=world
    ui._show_detail(home.x,home.y)
    await process_frame
    var detail: Control=ui.detail_view
    var bridge_visible: bool=false
    var ford_visible: bool=false
    for node in detail.bridge_root.get_children():
        if String(node.name).begins_with("TimberBridge_"):bridge_visible=true
        if String(node.name).begins_with("StoneFord_"):ford_visible=true
    if not bridge_visible or not ford_visible:
        fail("3D river crossings are not generated from A-star descriptor")
        return
    # Existing standalone saves must not be reinterpreted as 0.29 rivers.
    var standalone: Dictionary={"terrain":"plains","river":true,"bridges":[]}
    if Nav.enabled(standalone) or Nav.blocked(standalone,Vector2i(1,2))!=Legacy.blocked_cell(standalone,Vector2i(1,2)):
        fail("old one-tile river/navigation rules were changed")
        return
    print("TERRAIN_NAVIGATION_V29 SUCCESS: 17 seam/height points, physical no-swim A-star, natural ford, paid bridge, serialized cargo paths and 3D geometry")
    quit(0)
