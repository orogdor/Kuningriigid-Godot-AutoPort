extends RefCounted
## V79: deterministic, reachable Stone Age auto-exploration; fog remains a
## separate concern. Visited cells use 1 bit each, ~6 KB of JSON-safe base64.
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const DIRECTIONS: Array[Vector2i]=[
    Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]
const BITS_KEY: String="explored_bits_v79"
const COUNT_KEY: String="visited_count_v79"
const AUTO_KEY: String="auto_explore_v79"

static func _size() -> int:
    return int(ceili(float(World.COLS*World.ROWS)/8.0))

static func _bits(scout: Dictionary) -> PackedByteArray:
    var bytes: PackedByteArray=Marshalls.base64_to_raw(String(scout.get(BITS_KEY,"")))
    if bytes.size()!=_size():
        bytes=PackedByteArray()
        bytes.resize(_size())
        bytes.fill(0)
    return bytes

static func _idx(c: int,r: int) -> int:
    return r*World.COLS+c

static func _has(bytes: PackedByteArray,index: int) -> bool:
    return (int(bytes[int(index/8)]) & (1<<(index%8)))!=0

static func visit(scout: Dictionary,c: int,r: int) -> bool:
    if c<0 or c>=World.COLS or r<0 or r>=World.ROWS:return false
    var bytes: PackedByteArray=_bits(scout)
    var index: int=_idx(c,r)
    if _has(bytes,index):return false
    # Missing or invalid bitmap is a migration; reset the saved counter.
    var old: String=String(scout.get(BITS_KEY,""))
    if old.is_empty() or not scout.has(COUNT_KEY):
        scout[COUNT_KEY]=0
    bytes[int(index/8)]=int(bytes[int(index/8)]) | (1<<(index%8))
    scout[BITS_KEY]=Marshalls.raw_to_base64(bytes)
    scout[COUNT_KEY]=mini(World.COLS*World.ROWS,
        maxi(0,int(scout.get(COUNT_KEY,0)))+1)
    return true

static func ensure(scout: Dictionary) -> void:
    if not scout.get(AUTO_KEY,null) is bool:
        scout[AUTO_KEY]=false
    visit(scout,int(scout.get("c",-1)),int(scout.get("r",-1)))

static func route(world: Dictionary,scout: Dictionary) -> Array:
    if world.is_empty():return []
    var c: int=int(scout.get("c",-1))
    var r: int=int(scout.get("r",-1))
    if not Routes.passable(world,c,r):return []
    var bytes: PackedByteArray=_bits(scout)
    var size: int=World.COLS*World.ROWS
    var parent:=PackedInt32Array()
    parent.resize(size)
    parent.fill(-1)
    var queue:=PackedInt32Array()
    queue.resize(size)
    var origin: int=_idx(c,r)
    var front: int=0
    var end: int=1
    var destination: int=-1
    queue[0]=origin
    parent[origin]=origin
    # BFS expands in a fixed direction order. Visited tiles may be crossed
    # only when needed to reach the nearest *new* land tile.
    while front<end and destination<0:
        var current: int=queue[front]
        front+=1
        for dir in DIRECTIONS:
            var nc: int=current%World.COLS+dir.x
            var nr: int=int(current/World.COLS)+dir.y
            if not Routes.passable(world,nc,nr):continue
            var neighbour: int=_idx(nc,nr)
            if parent[neighbour]!=-1:continue
            parent[neighbour]=current
            queue[end]=neighbour
            end+=1
            if not _has(bytes,neighbour):
                destination=neighbour
                break
    if destination<0:return []
    var steps: Array=[]
    var cursor: int=destination
    while cursor!=origin:
        steps.append({"c":cursor%World.COLS,"r":int(cursor/World.COLS)})
        cursor=parent[cursor]
        if cursor<0:return []
    steps.reverse()
    return steps
