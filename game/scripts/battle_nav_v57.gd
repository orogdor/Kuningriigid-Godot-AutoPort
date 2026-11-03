extends RefCounted
## V57: light deterministic battlefield obstacles and local crowd steering.
## Retains V88 3x3 battlefield / V90 body clearance; this is a first
## Godot tactical navigation slice, not full source navmesh parity.
const RADIUS: float=0.34 # combat-contact-v96.js / soldier-collision-v90.js
const GRID: float=1.6
const MARGIN: float=0.12
const OBSTACLES: Array=[
    {"x":0.0,"z":0.0,"r":2.2,"height":2.0,"kind":"boulder"},
    {"x":-12.0,"z":-10.0,"r":2.8,"height":2.2,"kind":"boulder"},
    {"x":14.0,"z":11.0,"r":3.0,"height":2.6,"kind":"boulder"}
]
const MIN_X: float=-562.5
const MAX_X: float=562.5
const MIN_Z: float=-487.5
const MAX_Z: float=487.5
const ANGLES: Array=[0.0,0.45,-0.45,0.9,-0.9,1.4,-1.4,2.0,-2.0,PI]

static func ensure(battle: Dictionary) -> Dictionary:
    var arena: Variant=battle.get("terrain_v57",null)
    if arena is Dictionary and int(arena.get("version",0))==57:
        return arena
    # Terrain must persist in battle saves: saved positions and obstacles
    # must not disagree after reopening an interrupted fight.
    battle["terrain_v57"]={"version":57,"obstacles":OBSTACLES.duplicate(true)}
    return battle["terrain_v57"]

static func _at(subject: Dictionary) -> Vector2:
    return Vector2(float(subject.get("x",0.0)),float(subject.get("z",0.0)))

static func open_at(p: Vector2,arena: Dictionary,margin: float=RADIUS+MARGIN) -> bool:
    if p.x<MIN_X+margin or p.x>MAX_X-margin or \
            p.y<MIN_Z+margin or p.y>MAX_Z-margin:return false
    for obstacle in arena.get("obstacles",[]):
        var delta: Vector2=p-_at(obstacle)
        var clearance: float=float(obstacle["r"])+margin
        if delta.length_squared()<clearance*clearance:return false
    return true

static func clear_segment(start: Vector2,goal: Vector2,arena: Dictionary) -> bool:
    var distance: float=start.distance_to(goal)
    var intervals: int=maxi(1,int(ceil(distance/0.65)))
    for i in range(intervals+1):
        if not open_at(start.lerp(goal,float(i)/float(intervals)),arena):
            return false
    return true

static func _cell(pos: Vector2) -> Vector2i:
    return Vector2i(int(floor(pos.x/GRID)),int(floor(pos.y/GRID)))

static func _key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x,cell.y]

static func index_people(battle: Dictionary) -> Dictionary:
    var grid: Dictionary={}
    for fighter in battle.get("fighters",[]):
        for man in fighter.get("men",[]):
            if float(man.get("hp",0))<=0 or bool(man.get("escaped",false)):
                continue
            var key: String=_key(_cell(_at(man)))
            if not grid.has(key):grid[key]=[]
            grid[key].append(man)
    return grid

static func _remove_from_grid(man: Dictionary,cell: Vector2i,grid: Dictionary) -> void:
    var key: String=_key(cell)
    if not grid.has(key):return
    var entry: Array=grid[key]
    for i in range(entry.size()-1,-1,-1):
        if entry[i]==man:
            entry.remove_at(i)
            break
    if entry.is_empty():grid.erase(key)

static func _insert_grid(man: Dictionary,cell: Vector2i,grid: Dictionary) -> void:
    var key: String=_key(cell)
    if not grid.has(key):grid[key]=[]
    grid[key].append(man)

static func _crowd_clear(man: Dictionary,p: Vector2,grid: Dictionary) -> bool:
    var cell: Vector2i=_cell(p)
    var clearance: float=2.0*RADIUS+0.02
    for dz in range(-1,2):
        for dx in range(-1,2):
            for peer in grid.get(_key(cell+Vector2i(dx,dz)),[]):
                if peer==man or float(peer.get("hp",0))<=0 or \
                        bool(peer.get("escaped",false)):continue
                if p.distance_squared_to(_at(peer))<clearance*clearance:
                    return false
    return true

static func _detour(start: Vector2,target: Vector2,arena: Dictionary,
        parity: int) -> Array:
    if clear_segment(start,target,arena):return []
    var direction: Vector2=(target-start).normalized()
    if direction.length_squared()<0.01:return []
    var perp:=Vector2(-direction.y,direction.x)
    var nearest: Dictionary={}
    var best: float=INF
    for obstacle in arena.get("obstacles",[]):
        var center: Vector2=_at(obstacle)
        var projection: float=clampf((center-start).dot(direction),0.0,
            start.distance_to(target))
        var separation: float=center.distance_to(start+direction*projection)
        if separation<float(obstacle["r"])+RADIUS+MARGIN and projection<best:
            nearest=obstacle
            best=projection
    if nearest.is_empty():return []
    var center: Vector2=_at(nearest)
    var clearance: float=float(nearest["r"])+RADIUS+0.95
    # Choose the shorter of two tangential corridors, unless both are
    # identical (then alternate by soldier id to reduce bottlenecks).
    var candidate: Array=[]
    for side in [-1.0,1.0]:
        var left: Vector2=center-direction*clearance+perp*clearance*side
        var right: Vector2=center+direction*clearance+perp*clearance*side
        var score: float=start.distance_to(left)+left.distance_to(right)+\
            right.distance_to(target)
        if not clear_segment(start,left,arena):score+=200.0
        if not clear_segment(left,right,arena):score+=200.0
        candidate.append({"score":score,"a":left,"b":right})
    var choice: Dictionary=candidate[0]
    if float(candidate[1]["score"])<float(candidate[0]["score"])-0.001 or \
            (absf(float(candidate[1]["score"])-float(candidate[0]["score"]))<=0.001 \
            and posmod(parity,2)==1):
        choice=candidate[1]
    return [{"x":choice["a"].x,"z":choice["a"].y},
        {"x":choice["b"].x,"z":choice["b"].y}]

static func step(man: Dictionary,goal: Vector2,distance: float,
        arena: Dictionary,grid: Dictionary={}) -> void:
    var current: Vector2=_at(man)
    man["moving"]=false
    if distance<=0:return
    var previous: Dictionary=man.get("nav_target",{})
    var last_goal: Vector2=_at(previous) if not previous.is_empty() else goal
    if previous.is_empty() or last_goal.distance_to(goal)>7.0:
        man["nav_route"]=[]
        man["nav_target"]={"x":goal.x,"z":goal.y}
    var route: Array=man.get("nav_route",[])
    while not route.is_empty() and current.distance_to(_at(route[0]))<0.9:
        route.pop_front()
    # Only plan around terrain when direct travel is blocked and there
    # isn't a previous safe corridor to follow.
    if route.is_empty() and not clear_segment(current,goal,arena):
        route=_detour(current,goal,arena,int(man.get("index",0)))
    var target: Vector2=_at(route[0]) if not route.is_empty() else goal
    var vector: Vector2=target-current
    if vector.length()<0.025:
        man["nav_route"]=route
        return
    var advance: Vector2=vector.limit_length(distance)
    var old_cell: Vector2i=_cell(current)
    for angle in ANGLES:
        var motion: Vector2=advance.rotated(float(angle))
        var next: Vector2=current+motion
        if not clear_segment(current,next,arena):continue
        if not grid.is_empty() and not _crowd_clear(man,next,grid):continue
        man["x"]=next.x
        man["z"]=next.y
        man["moving"]=true
        man["heading"]=atan2(motion.x,motion.y)
        man["anim_phase"]=fposmod(float(man.get("anim_phase",0.0))+\
            motion.length()*2.8,TAU)
        var new_cell: Vector2i=_cell(next)
        if not grid.is_empty() and new_cell!=old_cell:
            _remove_from_grid(man,old_cell,grid)
            _insert_grid(man,new_cell,grid)
        break
    man["nav_route"]=route

static func nearest_opponent(man: Dictionary,battle: Dictionary,
        team: int,max_distance: float=10.0) -> Dictionary:
    var near: Dictionary={}
    var limit: float=max_distance*max_distance
    var p: Vector2=_at(man)
    for fighter in battle.get("fighters",[]):
        if int(fighter["team"])==team or float(fighter.get("hp",0.0))<=0:
            continue
        # Most 24-man squads are many metres apart. Reject the entire
        # opposing squad before entering its inner 24-man loop. Formation
        # footprint + safety margin avoids missing any reachable soldier.
        var border: float=max_distance+12.0
        if absf(float(fighter["x"])-p.x)>border or \
                absf(float(fighter["z"])-p.y)>border:
            continue
        for enemy in fighter.get("men",[]):
            if float(enemy.get("hp",0.0))<=0 or bool(enemy.get("escaped",false)):
                continue
            var gap: float=p.distance_squared_to(_at(enemy))
            if gap<limit:
                limit=gap
                near=enemy
    return near
