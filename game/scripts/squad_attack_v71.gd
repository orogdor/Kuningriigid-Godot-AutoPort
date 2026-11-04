extends RefCounted
## AutoPort 0.71: persistent whole-squad focused attack on a hostile squad.
## Per-man pursuit and real attack/projectile damage stay in V57/V68/V70.
## The squad order is only a tactical directive in the existing battle save.
const Attack68=preload("res://scripts/individual_attack_v68.gd")
const Personal60=preload("res://scripts/individual_orders_v60.gd")
const Orders59=preload("res://scripts/battle_orders_v59.gd")
const KEY: String="squad_target_v71"
const MANUAL: String="squad_manual_v71"

static func _fighter(battle: Dictionary,id: int,team: int) -> Dictionary:
    for fighter in battle.get("fighters",[]):
        if int(fighter.get("id",-999999))!=id or \
                int(fighter.get("team",-1))!=team:continue
        if float(fighter.get("hp",0.0))<=0.0 or \
                String(fighter.get("mode",""))=="retreated":return {}
        return fighter
    return {}

static func _living(fighter: Dictionary) -> Array:
    var found: Array=[]
    for man in fighter.get("men",[]):
        if float(man.get("hp",0.0))>0.0 and \
                not bool(man.get("escaped",false)):
            found.append(man)
    return found

static func cancel(fighter: Dictionary) -> void:
    fighter.erase(KEY)
    for man in fighter.get("men",[]):
        man.erase(MANUAL)

static func override(man: Dictionary) -> void:
    ## An explicit personal order wins over a previously issued group order.
    man[MANUAL]=true

static func rejoin(man: Dictionary) -> void:
    ## The person rejoins the squad target on the following combat tick.
    man.erase(MANUAL)

static func issue(battle: Dictionary,own_id: int,target_id: int) -> String:
    if int(battle.get("version",0))<71:
        return "Väesalga sihitud rünnak vajab 0.71 lahingut."
    if String(battle.get("result",""))!="":
        return "Lahing on lõppenud."
    var friendly: Dictionary=_fighter(battle,own_id,0)
    if friendly.is_empty() or _living(friendly).is_empty():
        return "Sinu väesalk on langenud või pole enam lahingus."
    var hostile: Dictionary=_fighter(battle,target_id,1)
    if hostile.is_empty() or _living(hostile).is_empty():
        return "Vastase väesalk on langenud või põgenenud."
    friendly[KEY]=target_id
    friendly["mode"]="attack"
    if String(friendly.get("formation",""))=="hold":
        friendly["formation"]="line"
    Orders59.cancel(friendly)
    # A new group order replaces prior individual orders. Future explicitly
    # issued personal commands can override this, per soldier.
    for man in friendly.get("men",[]):
        Personal60.clear(man)
        man.erase(MANUAL)
    refresh(friendly,battle)
    return ""

static func refresh(fighter: Dictionary,battle: Dictionary) -> Dictionary:
    if int(battle.get("version",0))<71 or not fighter.has(KEY):return {}
    var target_id: int=int(fighter.get(KEY,-999999))
    if String(fighter.get("mode","")) in ["retreat","retreated"] or \
            float(fighter.get("hp",0.0))<=0.0:
        cancel(fighter)
        return {}
    var hostile: Dictionary=_fighter(battle,target_id,1)
    var enemies: Array=_living(hostile) if not hostile.is_empty() else []
    if enemies.is_empty():
        # A destroyed target ends the directive; do not silently charge
        # another squad after a player designated this specific enemy.
        for man in fighter.get("men",[]):
            if bool(man.get(MANUAL,false)):continue
            var locked: Variant=man.get(Attack68.KEY,null)
            if locked is Dictionary and int(locked.get("squad",-999999))==target_id:
                Attack68.cancel(man)
        cancel(fighter)
        fighter["mode"]="hold"
        return {}
    var men: Array=_living(fighter)
    # Stable proportional spread over living opponents, avoiding 24 melee
    # soldiers trying to occupy the same point. Identical orders/loadouts
    # and battle seed produce the same assignments in saves and replays.
    for i in range(men.size()):
        var man: Dictionary=men[i]
        if bool(man.get(MANUAL,false)) or \
                man.has(Personal60.KEY):continue
        var locked: Variant=man.get(Attack68.KEY,null)
        if locked is Dictionary and int(locked.get("squad",-999999))==target_id:
            if not Attack68.enemy(battle,0,target_id,
                    int(locked.get("index",-1))).is_empty():
                continue
        var chosen: Dictionary=enemies[i%enemies.size()]
        Attack68.issue(battle,int(fighter["id"]),int(man["index"]),
            target_id,int(chosen["index"]))
    return hostile
