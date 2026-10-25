extends RefCounted
## AutoPort 0.9: deterministic 10 m grid, eight-direction A* with
## obstacle/corner checks. Traffic emerges on traveled cells and fades when idle.
## This approximates detail-map travel, not yet a 1:1 Three.js pathfinder.
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const Nav = preload("res://scripts/terrain_navigation_v29.gd")
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
    if Nav.blocked(sim,cell):return true
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

## 0.23: compute occupancy once per A* search instead of repeatedly
## scanning every building for each neighbor on every step.
static func occupancy(state: Dictionary, home_index: int) -> Dictionary:
    var result: Dictionary={}
    var buildings: Array=state.get("buildings",[])
    for i in range(buildings.size()):
        if i==home_index:continue
        var building: Dictionary=buildings[i]
        if float(building.get("hp",1.0))<=0.0:continue
        var center:=Vector2(float(building.get("x",0.0)),float(building.get("z",0.0)))
        var min_x: int=maxi(-EXTENT,int(ceil((center.x-11.5)/STEP)))
        var max_x: int=mini(EXTENT,int(floor((center.x+11.5)/STEP)))
        var min_z: int=maxi(-EXTENT,int(ceil((center.y-11.5)/STEP)))
        var max_z: int=mini(EXTENT,int(floor((center.y+11.5)/STEP)))
        for z in range(min_z,max_z+1):
            for x in range(min_x,max_x+1):
                var cell:=Vector2i(x,z)
                if world(cell).distance_to(center)<11.5:
                    result[cell_key(cell)]=true
    return result

static func _blocked_fast(sim: Dictionary, cell: Vector2i, occupied: Dictionary) -> bool:
    if not bounded(cell):return true
    if occupied.has(cell_key(cell)):return true
    return Nav.blocked(sim,cell)

static func _heap_less(a: Dictionary, b: Dictionary) -> bool:
    var fa: float=float(a["score"])
    var fb: float=float(b["score"])
    return fa<fb if not is_equal_approx(fa,fb) else int(a["order"])<int(b["order"])

static func _heap_push(heap: Array, node: Dictionary) -> void:
    heap.append(node)
    var child: int=heap.size()-1
    while child>0:
        var parent: int=(child-1)/2
        if not _heap_less(heap[child],heap[parent]):break
        var old: Variant=heap[parent]
        heap[parent]=heap[child]
        heap[child]=old
        child=parent

static func _heap_pop(heap: Array) -> Dictionary:
    var best: Dictionary=heap[0]
    var last: Dictionary=heap.pop_back()
    if heap.is_empty():return best
    heap[0]=last
    var parent: int=0
    while true:
        var left: int=parent*2+1
        if left>=heap.size():break
        var right: int=left+1
        var child: int=left
        if right<heap.size() and _heap_less(heap[right],heap[left]):
            child=right
        if not _heap_less(heap[child],heap[parent]):break
        var temp: Variant=heap[parent]
        heap[parent]=heap[child]
        heap[child]=temp
        parent=child
    return best

static func find_path(state: Dictionary, start: Vector2, destination: Vector2, home_index: int) -> Array:
    var origin: Vector2i=grid(start)
    var goal: Vector2i=grid(destination)
    var sim: Dictionary=state.get("detail_sim",{})
    var occupied: Dictionary=occupancy(state,home_index)
    if _blocked_fast(sim,goal,occupied):return []
    if origin==goal:return [{"x":destination.x,"z":destination.y}]
    var frontier: Array=[]
    var sequence: int=0
    _heap_push(frontier,{"cell":origin,"score":distance_cost(origin,goal),"order":sequence})
    var costs: Dictionary={cell_key(origin):0.0}
    var parents: Dictionary={}
    var seen: Dictionary={}
    var expanded: int=0
    while not frontier.is_empty() and expanded<WIDTH*WIDTH:
        var node: Vector2i=_heap_pop(frontier)["cell"]
        var key: String=cell_key(node)
        if seen.has(key):continue
        seen[key]=true
        expanded+=1
        if node==goal:break
        for direction in DIRS:
            var other: Vector2i=node+direction
            if _blocked_fast(sim,other,occupied):continue
            if not Nav.passable_step(sim,node,other):continue
            if direction.x!=0 and direction.y!=0:
                var corner_x:=node+Vector2i(direction.x,0)
                var corner_y:=node+Vector2i(0,direction.y)
                if _blocked_fast(sim,corner_x,occupied) or _blocked_fast(sim,corner_y,occupied):
                    continue
                if not Nav.passable_step(sim,node,corner_x) or not Nav.passable_step(sim,node,corner_y):
                    continue
            var next_key: String=cell_key(other)
            if seen.has(next_key):continue
            var factor: float=0.70 if traffic_strength(sim,next_key)>=ROAD_THRESHOLD else 1.0
            var rise: float=absf(Nav.ground(sim,other.x*STEP,other.y*STEP)-Nav.ground(sim,node.x*STEP,node.y*STEP))
            var move_cost: float=((14.0 if direction.x!=0 and direction.y!=0 else 10.0)+rise*3.0)*factor
            var next_cost: float=float(costs[key])+move_cost
            if not costs.has(next_key) or next_cost+0.0001<float(costs[next_key]):
                costs[next_key]=next_cost
                parents[next_key]=node
                sequence+=1
                _heap_push(frontier,{"cell":other,"score":next_cost+distance_cost(other,goal),"order":sequence})
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

## Road meshes follow traffic: connect adjacent heavily travelled cells
## without paving through blocked houses or cutting prohibited corners.
## 0.24: a single flood-fill for all visible building entrances is much
## cheaper than running an independent A* for every house every refresh.
static func connected_cells(state: Dictionary, start: Vector2, home_index: int=0) -> Dictionary:
    var origin: Vector2i=grid(start)
    var sim: Dictionary=state.get("detail_sim",{})
    var occupied: Dictionary=occupancy(state,home_index)
    var visited: Dictionary={cell_key(origin):true}
    var frontier: Array[Vector2i]=[origin]
    var head: int=0
    while head<frontier.size():
        var node: Vector2i=frontier[head]
        head+=1
        for direction in DIRS:
            var next: Vector2i=node+direction
            var key: String=cell_key(next)
            if visited.has(key) or _blocked_fast(sim,next,occupied):continue
            if not Nav.passable_step(sim,node,next):continue
            if direction.x!=0 and direction.y!=0:
                var side_x:=node+Vector2i(direction.x,0)
                var side_y:=node+Vector2i(0,direction.y)
                if _blocked_fast(sim,side_x,occupied) or _blocked_fast(sim,side_y,occupied):continue
                if not Nav.passable_step(sim,node,side_x) or not Nav.passable_step(sim,node,side_y):continue
            visited[key]=true
            frontier.append(next)
    return visited

static func road_links(state: Dictionary) -> Array:
    var sim: Dictionary=state.get("detail_sim",{})
    var traffic: Dictionary={}
    for tile in road_tiles(sim):
        var cell: Vector2i=grid(Vector2(float(tile["x"]),float(tile["z"])))
        if not blocked(state,cell,-1):
            traffic[cell_key(cell)]=int(tile["strength"])
    var links: Array=[]
    var occupied: Dictionary=occupancy(state,-1)
    for key in traffic.keys():
        var parts: PackedStringArray=String(key).split(":")
        if parts.size()!=2:continue
        var from:=Vector2i(int(parts[0]),int(parts[1]))
        for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
            var to: Vector2i=from+delta
            if not traffic.has(cell_key(to)):continue
            if _blocked_fast(sim,to,occupied):continue
            if not Nav.passable_step(sim,from,to):continue
            if delta.x!=0 and delta.y!=0:
                var corner_a:=from+Vector2i(delta.x,0)
                var corner_b:=from+Vector2i(0,delta.y)
                if _blocked_fast(sim,corner_a,occupied) or _blocked_fast(sim,corner_b,occupied):continue
                if not Nav.passable_step(sim,from,corner_a) or not Nav.passable_step(sim,from,corner_b):continue
            var a: Vector2=world(from)
            var b: Vector2=world(to)
            links.append({"a":a,"b":b,"strength":mini(int(traffic[key]),int(traffic[cell_key(to)]))})
    return links

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
