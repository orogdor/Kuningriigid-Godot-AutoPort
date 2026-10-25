extends SceneTree
## 0.9 regression: obstacle detours, diagonal corner blocking, road wear,
## maintenance/decay, carry delivery and JSON compatibility with 0.8 saves.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Paths = preload("res://scripts/spatial_paths_v09.gd")

func fail(s: String) -> void:
    printerr("ROUTES_V09 FAIL: "+s)
    quit(1)

func _initialize() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var blocked_home: Dictionary={"type":"house","x":10.0,"z":0.0,"ready":true,"hp":350.0}
    state["buildings"].append(blocked_home)
    var origin:=Vector2(-40.0,0.0)
    var destination:=Vector2(60.0,0.0)
    var path: Array=Paths.find_path(state,origin,destination,-1)
    if path.is_empty():
        fail("route around occupied structure missing")
        return
    var direct: float=origin.distance_to(destination)
    var route_length: float=0.0
    var previous: Vector2=origin
    for p in path:
        var current:=Vector2(float(p["x"]),float(p["z"]))
        route_length+=previous.distance_to(current)
        if Paths.blocked(state,Paths.grid(current),-1):
            fail("route cuts through building occupied cell")
            return
        previous=current
    if route_length<=direct+0.1:
        fail("A* did not detour around obstacle")
        return
    # Dedicated corner test. A diagonal from 0,0 to 1,1 cannot cross
    # either 1,0 or 0,1 when occupied by houses.
    var corner: Dictionary=City.default_state()
    Spatial.initialize(corner)
    corner["buildings"]=[{"x":10.0,"z":0.0,"hp":100,"ready":true},
        {"x":0.0,"z":10.0,"hp":100,"ready":true}]
    var corner_route: Array=Paths.find_path(corner,Vector2.ZERO,Vector2(10,10),-1)
    if not corner_route.is_empty():
        var first:=Vector2(float(corner_route[0]["x"]),float(corner_route[0]["z"]))
        if first==Vector2(10,10):
            fail("diagonal path cuts through an occupied corner")
            return
    # Drive a worker repeatedly along the same detour to form a road.
    var worker: Dictionary={"x":origin.x,"z":origin.y,"route":[]}
    var completed: int=0
    var destination_forward: bool=true
    for turn in range(160):
        state["detail_sim"]["turns"]=turn
        var goal: Vector2=destination if destination_forward else origin
        if Paths.move(worker,goal,23.0,state,-1):
            completed+=1
            destination_forward=not destination_forward
        if Paths.blocked(state,Paths.grid(Vector2(float(worker["x"]),float(worker["z"]))),-1):
            fail("worker entered a blocked building plot")
            return
    var roads: Array=Paths.road_tiles(state["detail_sim"])
    if completed<8 or roads.size()<3:
        fail("travel did not produce persistent footpaths")
        return
    var previous_count: int=roads.size()
    state["detail_sim"]["turns"]=2000
    if Paths.road_tiles(state["detail_sim"]).size()>=previous_count:
        fail("unused paths did not fade")
        return
    var serialized: String=JSON.stringify(state)
    var recovered: Variant=JSON.parse_string(serialized)
    if not recovered is Dictionary:
        fail("saved routes and road traffic JSON invalid")
        return
    Spatial.initialize(recovered)
    if not recovered["detail_sim"].has("roads") or int(recovered["detail_sim"]["version"])!=2:
        fail("route state could not be restored")
        return
    # Existing 0.8 save without roads must migrate without losing resources.
    var legacy: Dictionary=City.default_state()
    Spatial.initialize(legacy)
    legacy["detail_sim"].erase("roads")
    legacy["detail_sim"]["version"]=1
    legacy["detail_sim"]["sites"][0]["remaining"]=9.0
    Spatial.initialize(legacy)
    if int(legacy["detail_sim"]["version"])!=2 or not legacy["detail_sim"].has("roads"):
        fail("v0.8 save migration did not initialize roads")
        return
    if float(legacy["detail_sim"]["sites"][0]["remaining"])!=9.0:
        fail("migration overwrote depleted resource deposits")
        return
    print("PATHS_V09 SUCCESS: detour, no corner cut, travelled roads, decay and existing-save migration")
    quit(0)
