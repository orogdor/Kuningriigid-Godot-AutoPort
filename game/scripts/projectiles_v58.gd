extends RefCounted
## V58 incremental Stone Age slinger port: deterministic, saved stone flights.
## A first physical projectile slice, not full Three.js ballistics parity.
## Shots need clear line of sight around the V57 solid boulders.
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const KEY: String="projectiles_v58"
const SPEED: float=19.0
const STONE_RADIUS: float=0.18
const HIT_RADIUS: float=1.5
const MAX_STONES: int=192

static func _pos(unit: Dictionary) -> Vector2:
    return Vector2(float(unit.get("x",0.0)),float(unit.get("z",0.0)))

static func ensure(battle: Dictionary) -> Array:
    if not battle.get(KEY,null) is Array:
        battle[KEY]=[]
    return battle[KEY]

static func clear_line(start: Vector2,target: Vector2,arena: Dictionary) -> bool:
    var delta: Vector2=target-start
    var d2: float=delta.length_squared()
    for rock in arena.get("obstacles",[]):
        var center: Vector2=_pos(rock)
        var t: float=clampf((center-start).dot(delta)/maxf(0.000001,d2),0.0,1.0)
        var closest: Vector2=start+delta*t
        var clearance: float=float(rock.get("r",0.0))+STONE_RADIUS
        if center.distance_squared_to(closest)<clearance*clearance:
            return false
    return true

static func fire(battle: Dictionary,shooter: Dictionary,target: Dictionary,
        team: int,damage: float,will_hit: bool) -> bool:
    var start: Vector2=_pos(shooter)
    var aimed: Vector2=_pos(target)
    var arena: Dictionary=Nav57.ensure(battle)
    if not clear_line(start,aimed,arena):return false
    var stones: Array=ensure(battle)
    if stones.size()>=MAX_STONES:return false
    var next_id: int=int(battle.get("next_projectile_v58",0))+1
    battle["next_projectile_v58"]=next_id
    var end: Vector2=aimed
    if not will_hit:
        # Deterministic near-miss that is also visible in the 3D battlefield.
        var side: float=-1.0 if posmod(next_id,2)==0 else 1.0
        end+=Vector2(1.9,1.6*side)
    stones.append({"id":next_id,"team":team,
        "target_id":String(target.get("id","")),
        "origin_x":start.x,"origin_z":start.y,
        "dest_x":end.x,"dest_z":end.y,"x":start.x,"z":start.y,
        "height":1.1,"duration":maxf(0.15,start.distance_to(end)/SPEED),
        "elapsed":0.0,"damage":maxf(0.0,damage),"will_hit":will_hit})
    return true

static func step(battle: Dictionary,seconds: float) -> void:
    if seconds<=0.0:return
    var stones: Array=ensure(battle)
    for i in range(stones.size()-1,-1,-1):
        var stone: Dictionary=stones[i]
        var duration: float=maxf(0.15,float(stone.get("duration",0.15)))
        var elapsed: float=minf(duration,float(stone.get("elapsed",0.0))+seconds)
        stone["elapsed"]=elapsed
        var t: float=elapsed/duration
        var start:=Vector2(float(stone["origin_x"]),float(stone["origin_z"]))
        var goal:=Vector2(float(stone["dest_x"]),float(stone["dest_z"]))
        var position: Vector2=start.lerp(goal,t)
        stone["x"]=position.x
        stone["z"]=position.y
        stone["height"]=1.1+sin(PI*t)*minf(3.0,start.distance_to(goal)*0.22)
        if elapsed<duration:continue
        if bool(stone.get("will_hit",false)):
            # Resolve against the SAME saved individual, never a replacement
            # unit or a revived soldier after the target has already died.
            for fighter in battle.get("fighters",[]):
                if int(fighter.get("team",-1))==int(stone["team"]):continue
                for victim in fighter.get("men",[]):
                    if String(victim.get("id",""))!=String(stone["target_id"]):
                        continue
                    if float(victim.get("hp",0.0))<=0.0 or \
                            bool(victim.get("escaped",false)):continue
                    if _pos(victim).distance_to(goal)<=HIT_RADIUS:
                        victim["hp"]=maxf(0.0,float(victim["hp"])-float(stone["damage"]))
                    break
        stones.remove_at(i)
