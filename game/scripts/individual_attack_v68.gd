extends RefCounted
## Godot AutoPort 0.68: saveable attack-target orders for one human soldier.
## Separate from 0.60 personal move orders. Uses the existing V57 collision
## and V64 damage/projectile systems; no teleports and no changes to old saves.
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Mil=preload("res://scripts/military_v54.gd")
const Personal60=preload("res://scripts/individual_orders_v60.gd")
const KEY: String="attack_target_v68"

static func _position(man: Dictionary) -> Vector2:
    return Vector2(float(man.get("x",0.0)),float(man.get("z",0.0)))

static func enemy(battle: Dictionary,team: int,enemy_squad: int,
        enemy_index: int) -> Dictionary:
    for fighter in battle.get("fighters",[]):
        if int(fighter.get("id",-999))!=enemy_squad or \
                int(fighter.get("team",-1))==team or \
                float(fighter.get("hp",0.0))<=0.0:
            continue
        if String(fighter.get("mode",""))=="retreated":return {}
        for man in fighter.get("men",[]):
            if int(man.get("index",-1))!=enemy_index:continue
            if float(man.get("hp",0.0))<=0.0 or \
                    bool(man.get("escaped",false)):return {}
            return man
    return {}

static func issue(battle: Dictionary,squad: int,index: int,
        enemy_squad: int,enemy_index: int) -> String:
    if int(battle.get("version",0))<68:
        return "Üksiksõduri sihitud rünnak vajab 0.68 lahingut."
    if String(battle.get("result",""))!="":
        return "Lahing on lõppenud."
    var soldier: Dictionary=Personal60.soldier(battle,squad,index)
    if soldier.is_empty():
        return "Sinu sõdur puudub, on langenud või põgenenud."
    if enemy(battle,0,enemy_squad,enemy_index).is_empty():
        return "Vastane on langenud või pole enam lahingus."
    Personal60.clear(soldier)
    soldier[KEY]={"squad":enemy_squad,"index":enemy_index}
    soldier["nav_route"]=[]
    soldier["nav_target"]={}
    return ""

static func cancel(man: Dictionary) -> void:
    man.erase(KEY)
    man["nav_route"]=[]
    man["nav_target"]={}

static func target(battle: Dictionary,man: Dictionary,team: int) -> Dictionary:
    if not man.has(KEY):return {}
    var target_id: Variant=man.get(KEY,null)
    if not target_id is Dictionary or not target_id.has("squad") or \
            not target_id.has("index"):
        cancel(man)
        return {}
    var found: Dictionary=enemy(battle,team,int(target_id["squad"]),
        int(target_id["index"]))
    if found.is_empty():cancel(man)
    return found

static func reach_for(kind: String) -> float:
    if kind=="slinger":return float(Mil.TROOPS[kind]["range"])
    return 0.68+(1.05 if kind=="spearman" else 0.38)

static func advance(man: Dictionary,fighter: Dictionary,
        battle: Dictionary,dt: float,grid: Dictionary) -> bool:
    if int(battle.get("version",0))<68 or not man.has(KEY):return false
    if String(fighter.get("mode","")) in ["retreat","retreated"]:
        cancel(man)
        return false
    var foe: Dictionary=target(battle,man,int(fighter.get("team",0)))
    if foe.is_empty():return false
    var kind: String=String(fighter.get("kind","spearman"))
    if not Mil.TROOPS.has(kind):
        cancel(man)
        return false
    var p: Vector2=_position(man)
    var q: Vector2=_position(foe)
    var toward: Vector2=q-p
    var reach: float=reach_for(kind)
    var arena: Dictionary=Nav57.ensure(battle)
    if toward.length()<reach*0.92 and \
            Nav57.clear_segment(p,q,arena):
        man["moving"]=false
        if toward.length_squared()>0.001:
            man["heading"]=atan2(toward.x,toward.y)
        return true
    var direction: Vector2=toward.normalized()
    if direction.length_squared()<0.0001:
        man["moving"]=false
        return true
    # Stop just outside the enemy collision radius, not inside its mesh.
    # For slingers the original 3D projectile system still owns line of sight.
    var destination: Vector2=q-direction*maxf(0.75,reach*0.82)
    var speed: float=float(Mil.TROOPS[kind]["speed"])
    var formation: String=String(fighter.get("formation","line"))
    if formation=="spear_wall":speed*=0.35
    elif formation=="hold":speed*=0.8
    Nav57.step(man,destination,speed*maxf(dt,0.0),arena,grid)
    return true
