extends RefCounted
## AutoPort V59: persistent, player-directed tactical movement for paid squads.
## The destination is a world-space point inside the original V88 3x3 arena;
## every living individual still follows its formation using V57 local steering.
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Mil=preload("res://scripts/military_v54.gd")
const HALF_X: float=337.5
const HALF_Z: float=292.5
const EDGE: float=2.0
const ARRIVAL: float=0.75
const KEY: String="move_target_v59"

static func _point(entry: Dictionary) -> Vector2:
    return Vector2(float(entry.get("x",0.0)),float(entry.get("z",0.0)))

static func valid_target(battle: Dictionary,position: Vector2) -> bool:
    if absf(position.x)>HALF_X-EDGE or absf(position.y)>HALF_Z-EDGE:
        return false
    return Nav57.open_at(position,Nav57.ensure(battle))

static func issue(battle: Dictionary,squad_id: int,destination: Vector2) -> String:
    if int(battle.get("version",0))<59:
        return "Sihtpunkti liikumine vajab Godot 0.59 lahingut."
    if String(battle.get("result",""))!="":
        return "Lahing on lõppenud."
    if not valid_target(battle,destination):
        return "Sihtpunkt on lahingualast väljas või takistuse sees."
    for fighter in battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=squad_id or \
                int(fighter.get("team",-1))!=0:continue
        if float(fighter.get("hp",0.0))<=0.0 or \
                String(fighter.get("mode",""))=="retreated":
            return "Seda väesalka ei saa enam juhtida."
        fighter[KEY]={"x":destination.x,"z":destination.y}
        fighter["mode"]="move"
        fighter["nav_route"]=[]
        fighter["nav_target"]={}
        return ""
    return "Valitud oma väesalka ei leitud."

static func cancel(fighter: Dictionary) -> void:
    fighter.erase(KEY)
    fighter["nav_route"]=[]
    fighter["nav_target"]={}

static func advance(fighter: Dictionary,battle: Dictionary,dt: float) -> void:
    if String(fighter.get("mode",""))!="move":return
    var waypoint: Variant=fighter.get(KEY,null)
    if not waypoint is Dictionary or waypoint.is_empty():
        fighter["mode"]="hold"
        cancel(fighter)
        return
    var target: Vector2=_point(waypoint)
    if not valid_target(battle,target):
        fighter["mode"]="hold"
        cancel(fighter)
        return
    var current: Vector2=_point(fighter)
    if current.distance_to(target)<=ARRIVAL:
        fighter["mode"]="hold"
        cancel(fighter)
        return
    var kind: String=String(fighter.get("kind","spearman"))
    if not Mil.TROOPS.has(kind):
        fighter["mode"]="hold"
        cancel(fighter)
        return
    var speed: float=float(Mil.TROOPS[kind]["speed"])
    var formation: String=String(fighter.get("formation","line"))
    if formation=="spear_wall":speed*=0.35
    elif formation=="hold":speed*=0.8
    Nav57.step(fighter,target,speed*maxf(0.0,dt),Nav57.ensure(battle))
    if _point(fighter).distance_to(target)<=ARRIVAL:
        fighter["mode"]="hold"
        cancel(fighter)
