extends RefCounted
## AutoPort 0.9: deterministic 10 m grid, eight-direction A* with
## obstacle/corner checks. Traffic emerges on traveled cells and fades when idle.
## This approximates detail-map travel, not yet a 1:1 Three.js pathfinder.
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const STEP: float = 10.0
const EXTENT: int = 8
const WIDTH: int = 2 * EXTENT + 1
const ROAD_THRESHOLD: int = 3
const ROAD_FADE_TURNS: int = 35
const DIRS: Array[Vector2i] = [
    Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),
    Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)
]

static func grid(point: Vector2) -> Vector2i:
    return Vector2i(clampi(int(roundf(point.x / STEP)),-EXTENT,EXTENT),
        clampi(int(roundf(point.y / STEP)),-EXTENT,EXTENT))

static func world(cell: Vector2i) -> Vector2:
    return Vector2(float(cell.x)*STEP,float(cell.y)*STEP)

static func cell_key(cell: Vector2i) -> String:
    return str(cell.x)+":"+str(cell.y)

static func bounded(cell: Vector2i) -> bool:
    return absi(cell.x)<=EXTENT and absi(cell.y)<=EXTENT

static func blocked(state: Dictionary, cell: Vector2i, home_index: int) -> bool:
    if not bounded(cell):return true
    var point: Vector2=world(cell)
    for i in range(state.get("buildings",[]).size()):
        if i==home_index:continue
        var building: Dictionary=state["buildings"][i]
        if float(building.get("hp",1))<=0.0:continue
        var occupied:=Vector2(float(building.get("x",0)),float(building.get("z",0)))
        if point.distance_to(occupied)<11.5:
            return true
    var sim: Dictionary=state.get("detail_sim",{})
    if Terrain.blocked_cell(sim,cell):return true
    return false

static func traffic_strength(sim: Dictionary, key: String) -> int:
    var record: Dictionary=sim.get("roads",{}).get(key,{})
    if record.is_empty():return 0
    var elapsed: int=maxi(0,int(sim.get("turns",0))-int(record.get("last",0)))
    return maxi(0,int(record.get("count",0))-int(elapsed/ROAD_FADE_TURNS))

static func touch(sim: Dictionary, cell: Vector2i) -> void:
    var roads: Dictionary=sim.get("roads",{})
    var key: String=cell_key(cell)
    var amount: int=traffic_strength(sim,key)
    roads[key]={"count":mini(20,amount+1),"last":int(sim.get("turns",0))}
    sim["roads"]=roads

static func road_tiles(sim: Dictionary) -> Array:
    var tiles: Array=[]
    for key in sim.get("roads",{}).keys():
        var strength: int=traffic_strength(sim,String(key))
        if strength<ROAD_THRESHOLD:continue
        var parts: PackedStringArray=String(key).split(":")
        if parts.size()!=2:continue
        var cell:=Vector2i(int(parts[0]),int(parts[1]))
        if bounded(cell):
            tiles.append({"x":cell.x*STEP,"z":cell.y*STEP,"strength":strength})
    return tiles

static func distance_cost(start: Vector2i, finish: Vector2i) -> float:
    var dx: int=absi(start.x-finish.x)
    var dy: int=absi(start.y-finish.y)
    return float(dx+dy)*10.0-6.0*minf(dx,dy)

static func find_path(state: Dictionary, start: Vector2, destination: Vector2, home_index: int) -> Array:
    var origin: Vector2i=grid(start)
    var goal: Vector2i=grid(destination)
    if blocked(state,goal,home_index):return []
    if origin==goal:return [{"x":destination.x,"z":destination.y}]
    var frontier: Array=[origin]
    var costs: Dictionary={cell_key(origin):0.0}
    var parents: Dictionary={}
    var seen: Dictionary={}
    var expanded: int=0
    while not frontier.is_empty() and expanded<WIDTH*WIDTH:
        var winner: int=0
        var best: float=INF
        for i in range(frontier.size()):
            var candidate: Vector2i=frontier[i]
            var score: float=float(costs[cell_key(candidate)])+distance_cost(candidate,goal)
            if score<best:
                best=score
                winner=i
        var node: Vector2i=frontier.pop_at(winner)
        var key: String=cell_key(node)
        if seen.has(key):continue
        seen[key]=true
        expanded+=1
        if node==goal:break
        for direction in DIRS:
            var other: Vector2i=node+direction
            if blocked(state,other,home_index):continue
            var sim: Dictionary=state.get("detail_sim",{})
            if Terrain.too_steep(sim,node,other):continue
            if direction.x!=0 and direction.y!=0:
                if blocked(state,node+Vector2i(direction.x,0),home_index) or blocked(state,node+Vector2i(0,direction.y),home_index):
                    continue
                if Terrain.too_steep(sim,node,node+Vector2i(direction.x,0)) or Terrain.too_steep(sim,node,node+Vector2i(0,direction.y)):
                    continue
            var next_key: String=cell_key(other)
            if seen.has(next_key):continue
            var factor: float=0.70 if traffic_strength(sim,next_key)>=ROAD_THRESHOLD else 1.0
            var rise: float=absf(Terrain.height_at(sim,other.x*STEP,other.y*STEP)-Terrain.height_at(sim,node.x*STEP,node.y*STEP))
            var move: float=((14.0 if direction.x!=0 and direction.y!=0 else 10.0)+rise*3.0)*factor
            var next_cost: float=float(costs[key])+move
            if not costs.has(next_key) or next_cost+0.0001<float(costs[next_key]):
                costs[next_key]=next_cost
                parents[next_key]=node
                frontier.append(other)
    if not seen.has(cell_key(goal)):return []
    var reverse: Array=[]
    var cursor: Vector2i=goal
    while cursor!=origin:
        reverse.append(cursor)
        var key: String=cell_key(cursor)
        if not parents.has(key):return []
        cursor=parents[key]
        if reverse.size()>WIDTH*WIDTH:return []
    reverse.reverse()
    var route: Array=[]
    for cell in reverse:
        var p: Vector2=world(cell)
        route.append({"x":p.x,"z":p.y})
    if route.is_empty() or world(goal).distance_to(destination)>0.01:
        route.append({"x":destination.x,"z":destination.y})
    return route

static func move(worker: Dictionary, destination: Vector2, budget: float, state: Dictionary, home_index: int) -> bool:
    var current:=Vector2(float(worker["x"]),float(worker["z"]))
    if current.distance_to(destination)<0.001:
        worker["route"]=[]
        return true
    var path: Array=worker.get("route",[])
    var old_goal:=Vector2(float(worker.get("goal_x",INF)),float(worker.get("goal_z",INF)))
    var current_version: int=state.get("buildings",[]).size()
    if path.is_empty() or old_goal.distance_to(destination)>0.01 or int(worker.get("path_version",-1))!=current_version:
        path=find_path(state,current,destination,home_index)
        worker["route"]=path
        worker["path_version"]=current_version
        worker["goal_x"]=destination.x
        worker["goal_z"]=destination.y
    if path.is_empty():
        worker["stuck"]=true
        return false
    worker["stuck"]=false
    var moved: float=0.0
    while not path.is_empty() and budget>0.0:
        var next: Dictionary=path[0]
        var point:=Vector2(float(next["x"]),float(next["z"]))
        var delta: Vector2=point-current
        var remaining: float=delta.length()
        if remaining>budget:
            current+=delta/remaining*budget
            moved+=budget
            budget=0.0
        else:
            current=point
            moved+=remaining
            budget-=remaining
            touch(state["detail_sim"],grid(current))
            path.pop_front()
    worker["x"]=current.x
    worker["z"]=current.y
    worker["route"]=path
    worker["distance_walked"]=float(worker.get("distance_walked",0))+moved
    return current.distance_to(destination)<0.001

static func roads_summary(sim: Dictionary) -> Dictionary:
    var visible: Array=road_tiles(sim)
    var sum: float=0.0
    for p in visible:sum+=float(p["strength"])
    return {"tiles":visible.size(),"traffic":sum}
