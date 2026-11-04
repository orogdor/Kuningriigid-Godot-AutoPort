extends RefCounted
## AutoPort 0.60: individually addressed Stone Age soldier movement.
## Individual holds at the chosen point until Rejoin or a new squad order.
## Each order lives in the same saved battle dictionary as wounds/ammunition.
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Orders59=preload("res://scripts/battle_orders_v59.gd")
const KEY: String="individual_target_v60"
const STATUS: String="individual_state_v60"
const ARRIVAL: float=0.65

static func _pos(entry: Dictionary) -> Vector2:
    return Vector2(float(entry.get("x",0.0)),float(entry.get("z",0.0)))

static func soldier(battle: Dictionary,squad_id: int,index: int) -> Dictionary:
    for fighter in battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=squad_id or \
                int(fighter.get("team",-1))!=0:continue
        if float(fighter.get("hp",0))<=0:return {}
        for man in fighter.get("men",[]):
            if int(man.get("index",-1))!=index:continue
            if float(man.get("hp",0))<=0 or bool(man.get("escaped",false)):
                return {}
            return man
    return {}

static func issue(battle: Dictionary,squad_id: int,index: int,
        destination: Vector2) -> String:
    if int(battle.get("version",0))<60:
        return "Üksiksõduri liikumine vajab Godot 0.60 lahingut."
    if String(battle.get("result",""))!="":
        return "Lahing on lõppenud."
    if not Orders59.valid_target(battle,destination):
        return "Sihtpunkt on takistuse sees või lahingualast väljas."
    var man: Dictionary=soldier(battle,squad_id,index)
    if man.is_empty():
        return "Sõdur puudub, on langenud või pole sinu üksus."
    man[KEY]={"x":destination.x,"z":destination.y}
    man[STATUS]="move"
    man["nav_route"]=[]
    man["nav_target"]={}
    return ""

static func clear(man: Dictionary) -> void:
    man.erase(KEY)
    man.erase(STATUS)
    man["nav_route"]=[]
    man["nav_target"]={}

static func clear_squad(fighter: Dictionary) -> void:
    for man in fighter.get("men",[]):
        if man is Dictionary and (man.has(KEY) or man.has(STATUS)):
            clear(man)

static func rejoin(battle: Dictionary,squad_id: int,index: int) -> String:
    if int(battle.get("version",0))<60:
        return "Üksiksõduri juhtimine vajab Godot 0.60 lahingut."
    if String(battle.get("result",""))!="":
        return "Lahing on lõppenud."
    var man: Dictionary=soldier(battle,squad_id,index)
    if man.is_empty():
        return "Sõdur puudub või on langenud."
    clear(man)
    return ""

static func advance(man: Dictionary,fighter: Dictionary,
        battle: Dictionary,dt: float,grid: Dictionary) -> bool:
    if not man.has(KEY):return false
    var target: Variant=man.get(KEY,null)
    if not target is Dictionary or not Orders59.valid_target(battle,_pos(target)):
        clear(man)
        return false
    if String(man.get(STATUS,""))=="hold":
        man["moving"]=false
        return true
    var kind: String=String(fighter.get("kind","spearman"))
    var speed: float=float(fighter.get("individual_speed_v60",0.0))
    if speed<=0.0:
        # Keep the source unit's actual speed, passed from individual_v56.
        return false
    var distance: float=_pos(man).distance_to(_pos(target))
    if distance>ARRIVAL:
        Nav57.step(man,_pos(target),speed*maxf(dt,0.0),Nav57.ensure(battle),grid)
    else:
        man["moving"]=false
    if _pos(man).distance_to(_pos(target))<=ARRIVAL:
        man[STATUS]="hold"
        man["moving"]=false
    return true
