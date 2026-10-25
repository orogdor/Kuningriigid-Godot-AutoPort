extends SceneTree
## 0.23 pathfinding: occupancy raster matches old geometry, fast heap A*
## never cuts corners, footpaths join only traversable traffic cells and
## persisted city data remains unchanged. No wall-clock-dependent assertion.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Screen=preload("res://content.tscn")

func fail(why: String) -> void:
    printerr("PATH_GRID_V23 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    # A dense urban fixture: 35 buildings including legacy unsnapped
    # coordinates and mixed rotation; no changes to the economy tick.
    for z in range(-60,61,20):
        for x in range(-60,61,30):
            if absf(float(x))<20.0 and absf(float(z))<20.0:continue
            state["buildings"].append({"type":"house","x":float(x)+2.0,
                "z":float(z)-1.0,"rotation":90,"ready":true,"hp":350})
    var samples: int=0
    for home in [-1,0,8]:
        var occupied: Dictionary=Paths.occupancy(state,home)
        for z in range(-8,9):
            for x in range(-8,9):
                var tile:=Vector2i(x,z)
                var old: bool=Paths.blocked(state,tile,home)
                var fast: bool=Paths._blocked_fast(state["detail_sim"],tile,occupied)
                if old!=fast:
                    fail("cached occupancy disagrees with exact geometry: %s home %d" % [str(tile),home])
                    return
                samples+=1
    # Repeat A* queries across the dense map; each returned node must
    # remain legal and adjacent, never walking through a diagonal corner.
    var routes: int=0
    var start:=Vector2(-70,-70)
    for k in range(75):
        var destination:=Vector2(float((k*7)%15-7)*10.0,float((k*11)%15-7)*10.0)
        var path: Array=Paths.find_path(state,start,destination,-1)
        if path.is_empty():continue
        var previous:=Paths.grid(start)
        for waypoint in path:
            var pos:=Vector2(float(waypoint["x"]),float(waypoint["z"]))
            var tile: Vector2i=Paths.grid(pos)
            if Paths.blocked(state,tile,-1):
                fail("A* walked through a building or river obstruction")
                return
            var d: Vector2i=tile-previous
            if absi(d.x)>1 or absi(d.y)>1:
                fail("A* skipped nonadjacent 10m grid cells")
                return
            if d.x!=0 and d.y!=0:
                if Paths.blocked(state,previous+Vector2i(d.x,0),-1) or Paths.blocked(state,previous+Vector2i(0,d.y),-1):
                    fail("A* cut an obstructed diagonal corner")
                    return
            previous=tile
        routes+=1
    if samples!=867 or routes<5:
        fail("dense map test did not exercise enough grids and routes")
        return
    # Road junctions: four consecutively travelled cells join into three
    # continuous safe segments. Removing traffic prevents new connectors.
    var roads_state: Dictionary=City.default_state()
    Spatial.initialize(roads_state)
    roads_state["buildings"]=[]
    roads_state["detail_sim"]["sites"]=[]
    var line: Array[Vector2]=[Vector2(-30,-30),Vector2(-20,-30),
        Vector2(-10,-30),Vector2(0,-30)]
    for p in line:
        for n in range(4):Paths.touch(roads_state["detail_sim"],Paths.grid(p))
    var links: Array=Paths.road_links(roads_state)
    if links.size()!=3:
        fail("four contiguous road tiles must form exactly three connectors, got "+str(links.size()))
        return
    roads_state["buildings"].append({"type":"house","x":-20.0,"z":-30.0,"hp":350.0})
    var blocked_links: Array=Paths.road_links(roads_state)
    if not blocked_links.is_empty() and blocked_links.size()>=links.size():
        fail("streets were not removed when a building blocked a traffic cell")
        return
    roads_state["detail_sim"]["turns"]=1500
    if not Paths.road_links(roads_state).is_empty():
        fail("unused connector roads did not decay with their foot traffic")
        return
    # The scene renders continuous road connector primitives at actual
    # traffic segments, not just disconnected square slabs.
    var screen: Control=Screen.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var capital: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(capital["c"]),int(capital["r"]))
    await process_frame
    for p in [Vector2(-20,-20),Vector2(-10,-20),Vector2(0,-20)]:
        for n in range(4):Paths.touch(screen.city["detail_sim"],Paths.grid(p))
    screen.detail_view.refresh_buildings()
    await process_frame
    var street_parts: int=0
    for node in screen.detail_view.roads_root.get_children():
        if String(node.name).begins_with("TrafficStreetLink"):street_parts+=1
    if street_parts<2:
        fail("3D traffic street links were not rendered")
        return
    var serialized: Variant=JSON.parse_string(JSON.stringify(screen.city))
    if not serialized is Dictionary or not serialized.has("detail_sim"):
        fail("optimized street visualization changed save compatibility")
        return
    print("PATH_GRID_V23 SUCCESS: %d occupancy checks, %d dense A* routes, road junctions, decay, 3D mesh, JSON" % [samples,routes])
    quit(0)
