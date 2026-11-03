extends RefCounted
## AutoPort 0.56: first persistent hostile campaign warband.
## This is a deterministic prototype raider, NOT full competing-country AI.
## It does not modify resources, population or historical city turns.
const Mil=preload("res://scripts/military_v54.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const Movement=preload("res://scripts/world_scout_v52.gd")
const KEY: String="warband_v56"
const ENEMY_ID: int=-100
const RAID_DISTANCE: int=12
const RAID_SPEED: float=2.7

static func current(state: Dictionary,world: Dictionary) -> Dictionary:
    var m: Dictionary=Mil.ensure(state,world)
    if m.is_empty():return {}
    var raider: Variant=m.get(KEY,null)
    if not raider is Dictionary:return {}
    if int(raider.get("seed",-1))!=int(world.get("seed",-2)):
        m.erase(KEY)
        return {}
    return raider

static func _path_from_home(world: Dictionary,origin: Vector2i) -> Array:
    # Bound this search to a small local front, independent from the 220x165
    # world map. Works even if a second civilization is across an ocean.
    var frontier: Array=[{"c":origin.x,"r":origin.y}]
    var previous: Dictionary={str(origin.x)+":"+str(origin.y):""}
    var chosen:=origin
    for i in range(RAID_DISTANCE):
        var fresh: Array=[]
        for cell in frontier:
            var from:=Vector2i(int(cell["c"]),int(cell["r"]))
            for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
                var target:=from+offset
                var key: String="%d:%d" % [target.x,target.y]
                if previous.has(key) or not Routes.passable(world,target.x,target.y):continue
                previous[key]="%d:%d" % [from.x,from.y]
                fresh.append({"c":target.x,"r":target.y})
                chosen=target
        if fresh.is_empty():break
        frontier=fresh
    if chosen==origin:return []
    var reverse: Array=[]
    var cursor:=chosen
    while cursor!=origin:
        var name: String="%d:%d" % [cursor.x,cursor.y]
        reverse.append({"c":cursor.x,"r":cursor.y})
        var parts: PackedStringArray=String(previous[name]).split(":")
        cursor=Vector2i(int(parts[0]),int(parts[1]))
    reverse.reverse()
    return reverse

static func ensure(state: Dictionary,world: Dictionary) -> Dictionary:
    var m: Dictionary=Mil.ensure(state,world)
    if m.is_empty():return {}
    var existing: Dictionary=current(state,world)
    if not existing.is_empty():return existing
    if m.get("armies",[]).is_empty():return {}
    var homes: Array=world.get("starts",[])
    if homes.is_empty():return {}
    var home:=Vector2i(int(homes[0]["c"]),int(homes[0]["r"]))
    var route: Array=_path_from_home(world,home)
    if route.is_empty():return {}
    var far: Dictionary=route[route.size()-1]
    var travel: Array=[]
    for i in range(route.size()-2,-1,-1):
        travel.append(route[i])
    travel.append({"c":home.x,"r":home.y})
    m[KEY]={"seed":int(world["seed"]),"id":ENEMY_ID,
        "team":1,"kind":"spearman","grade":"standard",
        "c":int(far["c"]),"r":int(far["r"]),
        "hp":float(Mil.TROOPS["spearman"]["hp"]),
        "max_hp":float(Mil.TROOPS["spearman"]["hp"]),
        "speed":RAID_SPEED,"path":travel,"travelClock":0.0,
        "travelDuration":0.0,"engaged":false,"cooldown":0,
        "defeated":false,"battle_count":0}
    return m[KEY]

static func tick(state: Dictionary,world: Dictionary,seconds: float) -> void:
    if seconds<=0:return
    var enemy: Dictionary=ensure(state,world)
    if enemy.is_empty() or bool(enemy.get("defeated",false)):return
    var m: Dictionary=Mil.ensure(state,world)
    var b: Dictionary=m.get("skirmish_v55",{})
    if not b.is_empty() and String(b.get("result",""))=="":return
    enemy["cooldown"]=maxi(0,int(enemy.get("cooldown",0))-1)
    var remaining: float=seconds
    while remaining>=0.0 and not enemy.get("path",[]).is_empty():
        var next: Dictionary=enemy["path"][0]
        if not Routes.passable(world,int(next["c"]),int(next["r"])):
            enemy["path"]=[]
            break
        var duration: float=Movement.segment_seconds(enemy,next,RAID_SPEED)
        if duration<=0.0:break
        Movement.rescale_travel(enemy,duration)
        var pending: float=maxf(0.0,duration-float(enemy["travelClock"]))
        if remaining+0.000001<pending:
            enemy["travelClock"]=float(enemy["travelClock"])+remaining
            break
        remaining=maxf(0.0,remaining-pending)
        enemy["c"]=int(next["c"])
        enemy["r"]=int(next["r"])
        enemy["path"].pop_front()
        enemy["travelClock"]=0.0
        enemy["travelDuration"]=0.0
        if enemy["path"].is_empty():break

static func colliding_ids(state: Dictionary,world: Dictionary) -> Array:
    var enemy: Dictionary=current(state,world)
    if enemy.is_empty() or bool(enemy.get("defeated",false)) or \
            bool(enemy.get("engaged",false)) or int(enemy.get("cooldown",0))>0:
        return []
    var m: Dictionary=Mil.ensure(state,world)
    var ids: Array=[]
    for army in m.get("armies",[]):
        if float(army.get("hp",0))<=0:continue
        if int(army["c"])!=int(enemy["c"]) or int(army["r"])!=int(enemy["r"]):continue
        # An encounter stops marching troops at the actual shared tile.
        ids.append(int(army["id"]))
        if ids.size()>=8:break
    return ids

static func settle(state: Dictionary,world: Dictionary,enemy_hp: float) -> void:
    var enemy: Dictionary=current(state,world)
    if enemy.is_empty():return
    enemy["hp"]=clampf(enemy_hp,0.0,float(enemy["hp"]))
    enemy["engaged"]=false
    enemy["cooldown"]=4
    enemy["battle_count"]=int(enemy.get("battle_count",0))+1
    if float(enemy["hp"])<=0:
        enemy["defeated"]=true
        enemy["path"]=[]

static func status(state: Dictionary,world: Dictionary) -> String:
    var enemy: Dictionary=current(state,world)
    if enemy.is_empty():return "Vaenulist väesalka pole veel avastatud."
    if bool(enemy.get("defeated",false)):return "Vaenulik väesalk on võidetud."
    return "Vaenulik väesalk: (%d, %d) • %.0f HP • teekond %d ruutu" % [
        int(enemy["c"]),int(enemy["r"]),float(enemy["hp"]),
        enemy.get("path",[]).size()]
