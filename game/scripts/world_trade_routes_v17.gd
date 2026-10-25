extends RefCounted
## AutoPort 0.17: traversable 4-neighbour land route between two towns.
## A compact route is saved in trade_v15 and drawn on the world atlas.
## It does not create a second nation or cross ocean/mountain tiles.
const World=preload("res://scripts/world_gen_v06.gd")
const MAX_RADIUS: int=13
const MIN_RADIUS: int=6
const STEP_COST: int=3 # Land world tiles traveled per game turn.

static func passable(world: Dictionary,c: int,r: int) -> bool:
    var cell: Dictionary=World.cell(world,c,r)
    return not cell.is_empty() and bool(cell.get("land",false)) and String(cell.get("biome",""))!="hills"

static func build_path(world: Dictionary,start: Vector2i,finish: Vector2i) -> Array:
    if not passable(world,start.x,start.y) or not passable(world,finish.x,finish.y):return []
    var total: int=World.COLS*World.ROWS
    var parents:=PackedInt32Array()
    parents.resize(total)
    parents.fill(-1)
    var queue:=PackedInt32Array()
    queue.resize(total)
    var first: int=start.y*World.COLS+start.x
    var goal: int=finish.y*World.COLS+finish.x
    var front: int=0
    var end: int=1
    queue[0]=first
    parents[first]=first
    var dirs: Array[Vector2i]=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
    while front<end:
        var pos: int=queue[front]
        front+=1
        if pos==goal:break
        var c: int=pos%World.COLS
        var r: int=pos/World.COLS
        for delta in dirs:
            var nc: int=c+delta.x
            var nr: int=r+delta.y
            if not passable(world,nc,nr):continue
            var ni: int=nr*World.COLS+nc
            if parents[ni]!=-1:continue
            parents[ni]=pos
            queue[end]=ni
            end+=1
    if parents[goal]==-1:return []
    var reversed: Array=[]
    var pos: int=goal
    while pos!=first:
        reversed.append({"c":pos%World.COLS,"r":pos/World.COLS})
        pos=parents[pos]
    reversed.append({"c":start.x,"r":start.y})
    reversed.reverse()
    return reversed

static func choose_site(world: Dictionary,home: Vector2i) -> Dictionary:
    if not passable(world,home.x,home.y):return {}
    # Land-search seeded near the capital and pick a genuinely reachable site,
    # not a land tile across an impassable mountain range or sea.
    var reached:=PackedByteArray()
    reached.resize(World.COLS*World.ROWS)
    reached.fill(0)
    var que:=PackedInt32Array()
    que.resize(World.COLS*World.ROWS)
    var initial: int=home.y*World.COLS+home.x
    var front: int=0
    var end: int=1
    que[0]=initial
    reached[initial]=1
    var occupied: Dictionary={}
    for start in world.get("starts",[]):
        occupied[str(int(start["c"]))+":"+str(int(start["r"]))]=true
    var dirs: Array[Vector2i]=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
    while front<end:
        var n: int=que[front]
        front+=1
        var c: int=n%World.COLS
        var r: int=n/World.COLS
        var d: int=maxi(absi(c-home.x),absi(r-home.y))
        if d>=MIN_RADIUS and d<=MAX_RADIUS and not occupied.has(str(c)+":"+str(r)):
            return {"c":c,"r":r,"seed":int(world.get("seed",0))}
        if d>=MAX_RADIUS:continue
        for dir in dirs:
            var nc: int=c+dir.x
            var nr: int=r+dir.y
            if not passable(world,nc,nr):continue
            var next: int=nr*World.COLS+nc
            if reached[next]!=0:continue
            reached[next]=1
            que[end]=next
            end+=1
    return {}

static func configure(state: Dictionary,world: Dictionary,home: Dictionary,site: Dictionary) -> bool:
    if not state.has("trade_v15"):return false
    var path: Array=build_path(world,Vector2i(int(home["c"]),int(home["r"])),
        Vector2i(int(site["c"]),int(site["r"])))
    if path.size()<2:return false
    var trade: Dictionary=state["trade_v15"]
    trade["position"]=site
    trade["route_v17"]={"seed":int(world.get("seed",0)),"tiles":path,
        "distance_tiles":path.size()-1,
        "duration":maxi(2,int(ceil(float(path.size()-1)/STEP_COST)))}
    return true
