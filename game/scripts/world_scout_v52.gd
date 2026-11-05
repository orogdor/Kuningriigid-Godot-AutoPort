extends RefCounted
## AutoPort 0.52: first playable world-map scout. Travel physics ported from
## Three.js world-movement-v258.js and detail-scale-v123.js.
## A world tile is 225 x 195 detail units; the original scout moves at 4.3/s.
## Routing currently uses the existing 4-neighbour land BFS from v0.17.
## Battles, fog of war and army recruitment are deliberately not claimed here.
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const Auto79=preload("res://scripts/scout_auto_v79.gd")
const DETAIL_TILE_X: float=225.0
const DETAIL_TILE_Z: float=195.0
const SCOUT_SPEED: float=4.3
const KEY: String="world_scout_v52"

static func segment_seconds(from_tile: Dictionary,to_tile: Dictionary,
        speed: float=SCOUT_SPEED,road_multiplier: float=1.0) -> float:
    var dx: float=float(int(to_tile["c"])-int(from_tile["c"]))*DETAIL_TILE_X
    var dz: float=float(int(to_tile["r"])-int(from_tile["r"]))*DETAIL_TILE_Z
    return Vector2(dx,dz).length()/(maxf(0.01,speed)*maxf(0.01,road_multiplier))

static func rescale_travel(entity: Dictionary,duration: float) -> void:
    # Three.js V258 preserves the fractional position of older saved journeys.
    var old: float=float(entity.get("travelDuration",0.0))
    if old>0.0 and duration>0.0 and not is_equal_approx(old,duration):
        entity["travelClock"]=float(entity.get("travelClock",0.0))*duration/old
    entity["travelDuration"]=duration

static func _home(world: Dictionary) -> Dictionary:
    var starts: Array=world.get("starts",[])
    if starts.is_empty():return {}
    return starts[0]

static func _new(world: Dictionary) -> Dictionary:
    var start: Dictionary=_home(world)
    return {"seed":int(world.get("seed",-1)),"team":0,"kind":"scout",
        "c":int(start.get("c",-1)),"r":int(start.get("r",-1)),
        "speed":SCOUT_SPEED,"path":[],"travelClock":0.0,
        "travelDuration":0.0,"worldArrivalV258":{}}

static func ensure(state: Dictionary,world: Dictionary) -> Dictionary:
    if world.is_empty() or _home(world).is_empty():return {}
    var entity: Variant=state.get(KEY)
    if not entity is Dictionary or int(entity.get("seed",-1))!=int(world.get("seed",-2)) or \
            not Routes.passable(world,int(entity.get("c",-1)),int(entity.get("r",-1))):
        state[KEY]=_new(world)
        Auto79.ensure(state[KEY])
        return state[KEY]
    # Old/corrupt save protection; never follow paths over sea or across rows.
    if not entity.get("path",null) is Array or entity["path"].size()>World.COLS*World.ROWS:
        entity["path"]=[]
    var current:=Vector2i(int(entity["c"]),int(entity["r"]))
    var valid: bool=true
    for segment in entity["path"]:
        if not segment is Dictionary:
            valid=false
            break
        var next:=Vector2i(int(segment.get("c",-1)),int(segment.get("r",-1)))
        if absi(next.x-current.x)+absi(next.y-current.y)!=1 or \
                not Routes.passable(world,next.x,next.y):
            valid=false
            break
        current=next
    if not valid:entity["path"]=[]
    if not entity.has("speed"):entity["speed"]=SCOUT_SPEED
    if not entity.has("travelClock"):entity["travelClock"]=0.0
    if not entity.has("travelDuration"):entity["travelDuration"]=0.0
    if entity["path"].is_empty():
        entity["travelClock"]=0.0
        entity["travelDuration"]=0.0
    Auto79.ensure(entity)
    return entity

static func order(state: Dictionary,world: Dictionary,destination: Vector2i) -> String:
    var scout: Dictionary=ensure(state,world)
    if scout.is_empty():return "Maailmakaart pole veel valmis."
    if not Routes.passable(world,destination.x,destination.y):
        return "Avastaja ei saa liikuda merre või läbimatusse mäestikku."
    var current:=Vector2i(int(scout["c"]),int(scout["r"]))
    if current==destination:
        scout["auto_explore_v79"]=false
        scout["path"]=[]
        scout["travelClock"]=0.0
        scout["travelDuration"]=0.0
        return ""
    var planned: Array=Routes.build_path(world,current,destination)
    if planned.size()<2:return "Maismaateed sihtkohta ei leitud."
    # A valid manual order takes precedence over automatic exploration.
    scout["auto_explore_v79"]=false
    scout["path"]=planned.slice(1)
    scout["travelClock"]=0.0
    scout["travelDuration"]=segment_seconds(scout,scout["path"][0],float(scout["speed"]))
    return ""

static func set_auto(state: Dictionary,world: Dictionary,enabled: bool) -> bool:
    var scout: Dictionary=ensure(state,world)
    if scout.is_empty():return false
    scout["auto_explore_v79"]=enabled
    # A currently moving scout completes its saved segment even when auto
    # mode is disabled. No mid-tile teleports or lost travel clocks.
    if enabled and scout.get("path",[]).is_empty():
        _plan_auto(scout,world)
    return enabled

static func _plan_auto(scout: Dictionary,world: Dictionary) -> bool:
    if not bool(scout.get("auto_explore_v79",false)) or \
            not scout.get("path",[]).is_empty():return false
    var route: Array=Auto79.route(world,scout)
    if route.is_empty():return false
    scout["path"]=route
    scout["travelClock"]=0.0
    scout["travelDuration"]=segment_seconds(scout,route[0],float(scout["speed"]))
    return true

static func tick(state: Dictionary,world: Dictionary,seconds: float) -> int:
    if world.is_empty() or seconds<=0.0:return 0
    var scout: Dictionary=ensure(state,world)
    if scout.is_empty():return 0
    var passed: int=0
    var remaining: float=seconds
    var transitions: int=0
    while remaining>0.0000001 and transitions<512:
        transitions+=1
        if scout["path"].is_empty():
            if not _plan_auto(scout,world):break
        var next: Dictionary=scout["path"][0]
        var duration: float=segment_seconds(scout,next,float(scout["speed"]))
        if duration<=0.0 or not is_finite(duration):break
        rescale_travel(scout,duration)
        var pending: float=maxf(0.0,duration-float(scout["travelClock"]))
        if remaining+0.0000001<pending:
            scout["travelClock"]=float(scout["travelClock"])+remaining
            break
        remaining=maxf(0.0,remaining-pending)
        scout["c"]=int(next["c"])
        scout["r"]=int(next["r"])
        scout["worldArrivalV258"]={"c":scout["c"],"r":scout["r"]}
        scout["path"].pop_front()
        scout["travelClock"]=0.0
        scout["travelDuration"]=0.0
        Auto79.visit(scout,int(scout["c"]),int(scout["r"]))
        passed+=1
    return passed

static func sample(scout: Dictionary) -> Dictionary:
    if scout.is_empty():return {}
    var c: float=float(scout.get("c",0))
    var r: float=float(scout.get("r",0))
    var path: Array=scout.get("path",[])
    var duration: float=float(scout.get("travelDuration",0.0))
    if path.is_empty() or duration<=0.0:
        return {"c":c,"r":r,"fraction":0.0,"moving":false}
    var next: Dictionary=path[0]
    var fraction: float=clampf(float(scout.get("travelClock",0.0))/duration,0.0,1.0)
    return {"c":lerpf(c,float(next["c"]),fraction),
        "r":lerpf(r,float(next["r"]),fraction),
        "fraction":fraction,"moving":true}
