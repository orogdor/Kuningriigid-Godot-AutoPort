extends RefCounted
## AutoPort 0.56: persistent individual Stone Age combatants.
## Port slice: 24 figures per melee/ranged unit (soldier-collision-v90.js),
## source formation slots (formations-v94.js), 0.34 body radius and spear
## reach (combat-contact-v96.js), red-line retreats (battlefield-v88.js).
## Damage, missile trajectory and terrain navigation are deliberately simpler
## than the original Three.js V91 individual-battle engine.
const Mil=preload("res://scripts/military_v54.gd")
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Stones58=preload("res://scripts/projectiles_v58.gd")
const Orders59=preload("res://scripts/battle_orders_v59.gd")
const Individuals60=preload("res://scripts/individual_orders_v60.gd")
const PER_SQUAD: int=24
const MAX_MEN: int=216
const BODY_RADIUS: float=0.34
const LINE_X: float=337.5
const LEAVE_X: float=343.5
const SPACING: float=1.05

static func formation_slot(fighter: Dictionary,index: int,count: int) -> Vector2:
    var formation: String=String(fighter.get("formation","line"))
    var columns: int=mini(count,6 if formation=="shield_wall" else 4)
    var rows: int=int(ceil(float(count)/float(columns)))
    var width: float=1.6 if ["loose","skirmish"].has(formation) else \
        (0.9 if formation=="spear_wall" else SPACING)
    var depth: float=1.6 if ["loose","skirmish"].has(formation) else SPACING
    return Vector2((float(posmod(index,columns))-float(columns-1)*0.5)*width,
        (float(index/columns)-float(rows-1)*0.5)*depth)

static func initialize(b: Dictionary) -> void:
    if int(b.get("individual_version",0))==56:return
    var total: int=0
    for fighter in b.get("fighters",[]):
        var kind: String=String(fighter.get("kind",""))
        var count: int=1 if kind=="scout" else PER_SQUAD
        count=mini(count,maxi(0,MAX_MEN-total))
        total+=count
        var max_hp: float=float(fighter.get("max_hp",fighter.get("hp",0.0)))
        var available: float=maxf(0.0,float(fighter.get("hp",0.0)))
        var man_hp: float=max_hp/float(maxi(1,count))
        var men: Array=[]
        for i in range(count):
            var hp: float=minf(man_hp,available)
            available=maxf(0.0,available-hp)
            var slot: Vector2=formation_slot(fighter,i,count)
            men.append({"id":"%d:%d" % [int(fighter["id"]),i],"index":i,
                "x":float(fighter["x"])+slot.x,
                "z":float(fighter["z"])+slot.y,
                "hp":hp,"max_hp":man_hp,"cool":float(posmod(i,4))*0.11,
                "shots":0,"ammo":12 if kind=="slinger" else -1,
                "escaped":false,"heading":0.0,"moving":false,
                "anim_phase":0.0,"attack_anim":0.0})
        fighter["men"]=men
        fighter["menAlive"]=men.filter(func(m):return float(m["hp"])>0).size()
        fighter["max_hp"]=max_hp
    b["individual_version"]=56

static func living(fighter: Dictionary) -> Array:
    return fighter.get("men",[]).filter(func(m):
        return float(m["hp"])>0.0 and not bool(m.get("escaped",false)))

static func _foe(fighter: Dictionary,b: Dictionary) -> Dictionary:
    var nearest: Dictionary={}
    var dist: float=INF
    for candidate in b.get("fighters",[]):
        if int(candidate["team"])==int(fighter["team"]) or living(candidate).is_empty():continue
        var d: float=Vector2(float(candidate["x"])-float(fighter["x"]),
            float(candidate["z"])-float(fighter["z"])).length()
        if d<dist:dist=d;nearest=candidate
    return nearest

static func _space_clear(who: Dictionary,goal: Vector2,others: Array) -> bool:
    for other in others:
        if other==who or float(other["hp"])<=0 or bool(other.get("escaped",false)):
            continue
        var distance: float=goal.distance_to(Vector2(float(other["x"]),float(other["z"])))
        if distance<BODY_RADIUS*2.0+0.02:return false
    return true

static func _march_man(m: Dictionary,goal: Vector2,step: float,peers: Array) -> void:
    var origin:=Vector2(float(m["x"]),float(m["z"]))
    var movement: Vector2=goal-origin
    if movement.length()<0.05:return
    var target: Vector2=origin+movement.limit_length(step)
    if _space_clear(m,target,peers):
        m["x"]=clampf(target.x,-562.5,562.5)
        m["z"]=clampf(target.y,-487.5,487.5)
        m["heading"]=atan2(movement.x,movement.y)
    # When blocked by a neighbour, remain in the slot instead of teleporting.

static func _update_anchor(fighter: Dictionary,target: Dictionary,dt: float,
        battle: Dictionary={}) -> void:
    var mode: String=String(fighter.get("mode","hold"))
    var kind: String=String(fighter.get("kind","spearman"))
    var profile: Dictionary=Mil.TROOPS[kind]
    var speed: float=float(profile["speed"])
    var formation: String=String(fighter.get("formation","line"))
    if formation=="hold":speed*=0.8
    elif formation=="spear_wall":speed*=0.35
    if mode=="move" and int(battle.get("version",56))>=59:
        Orders59.advance(fighter,battle,dt)
        return
    if mode=="retreat":
        var goal_x: float=-LEAVE_X if int(fighter["team"])==0 else LEAVE_X
        if int(battle.get("version",56))>=57:
            Nav57.step(fighter,Vector2(goal_x,float(fighter["z"])),
                speed*dt,Nav57.ensure(battle))
        else:
            fighter["x"]=move_toward(float(fighter["x"]),goal_x,speed*dt)
        return
    if mode!="attack" or target.is_empty():return
    var p:=Vector2(float(fighter["x"]),float(fighter["z"]))
    var q:=Vector2(float(target["x"]),float(target["z"]))
    var reach: float=8.0 if kind=="slinger" else 1.8
    if p.distance_to(q)>reach:
        if int(battle.get("version",56))>=57:
            # Avoid static battlefield boulders as one formation anchor;
            # the individual men then steer toward reachable slots.
            Nav57.step(fighter,q,speed*dt,Nav57.ensure(battle))
            fighter["x"]=clampf(float(fighter["x"]),-LINE_X,LINE_X)
            fighter["z"]=clampf(float(fighter["z"]),-292.5,292.5)
        else:
            var moved: Vector2=p.move_toward(q,speed*dt)
            fighter["x"]=clampf(moved.x,-LINE_X,LINE_X)
            fighter["z"]=clampf(moved.y,-292.5,292.5)

static func _move_men(fighter: Dictionary,dt: float,
        battle: Dictionary={},grid: Dictionary={}) -> void:
    var men: Array=fighter.get("men",[])
    var peers: Array=[]
    for m in men:
        if float(m["hp"])>0 and not bool(m.get("escaped",false)):
            peers.append(m)
    var speed: float=float(Mil.TROOPS[String(fighter["kind"])]["speed"])
    var formation: String=String(fighter.get("formation","line"))
    if formation=="hold":speed*=0.8
    elif formation=="spear_wall":speed*=0.35
    # March the foremost soldiers first so the back ranks do not remain
    # pinned against stationary men immediately ahead of them.
    var walkers: Array=men.duplicate()
    if int(battle.get("version",56))>=57:
        var facing: float=float(fighter.get("heading",0.0))
        var forward:=Vector2(sin(facing),cos(facing))
        walkers.sort_custom(func(a,b):
            var pa:=Vector2(float(a["x"]),float(a["z"]))
            var pb:=Vector2(float(b["x"]),float(b["z"]))
            return pa.dot(forward)>pb.dot(forward))
    for m in walkers:
        if float(m["hp"])<=0 or bool(m.get("escaped",false)):continue
        # V60 independent orders override only this person's formation slot.
        # Other soldiers still use the existing V57 collision grid.
        if int(battle.get("version",56))>=60 and \
                Individuals60.advance(m,fighter,battle,dt,grid):
            continue
        var slot: Vector2=formation_slot(fighter,int(m["index"]),men.size())
        var goal:=Vector2(float(fighter["x"])+slot.x,float(fighter["z"])+slot.y)
        if int(battle.get("version",56))>=57:
            var mode: String=String(fighter.get("mode","hold"))
            if mode=="attack":
                var reach: float=9.0 if fighter["kind"]=="slinger" else \
                    (1.73 if fighter["kind"]=="spearman" else 1.06)
                var opponent: Dictionary=Nav57.nearest_opponent(
                    m,battle,int(fighter["team"]),reach+5.0)
                if not opponent.is_empty():
                    var offset: Vector2=Vector2(float(m["x"]),float(m["z"]))-\
                        Vector2(float(opponent["x"]),float(opponent["z"]))
                    if offset.length()>reach*0.95:
                        goal=Vector2(float(opponent["x"]),float(opponent["z"]))+\
                            offset.normalized()*maxf(0.73,reach*0.9)
            Nav57.step(m,goal,speed*dt,Nav57.ensure(battle),grid)
        else:
            _march_man(m,goal,speed*dt,peers)
        if String(fighter.get("mode",""))=="retreat":
            if (int(fighter["team"])==0 and float(m["x"]) < -LINE_X) or \
                    (int(fighter["team"])==1 and float(m["x"]) > LINE_X):
                m["escaped"]=true
    if String(fighter.get("mode",""))=="retreat" and peers.all(func(m):
            return bool(m.get("escaped",false))):
        fighter["mode"]="retreated"

static func _target_man(m: Dictionary,opponents: Array,reach: float,
        arena: Dictionary={}) -> Dictionary:
    var best: Dictionary={}
    var best_dist: float=reach
    var p:=Vector2(float(m["x"]),float(m["z"]))
    for fighter in opponents:
        for enemy in living(fighter):
            var q:=Vector2(float(enemy["x"]),float(enemy["z"]))
            var dist: float=p.distance_to(q)
            if dist<best_dist:
                if not arena.is_empty() and not Stones58.clear_line(p,q,arena):
                    continue
                best_dist=dist
                best=enemy
    return best

static func _attack(b: Dictionary,fighter: Dictionary,dt: float) -> void:
    if String(fighter.get("mode","hold")) in ["retreat","retreated"]:return
    var kind: String=String(fighter["kind"])
    var stats: Dictionary=Mil.TROOPS[kind]
    var opponent: Array=[]
    for enemy in b["fighters"]:
        if int(enemy["team"])!=int(fighter["team"]) and not living(enemy).is_empty():
            opponent.append(enemy)
    if opponent.is_empty():return
    var grade: String=String(fighter.get("grade","standard"))
    var power: float=float(stats["damage"])*float(Mil.GRADES[grade]["strength"])*0.27
    var reach: float=float(stats["range"]) if kind=="slinger" else \
        (2.0*BODY_RADIUS+(1.05 if kind=="spearman" else 0.38))
    var terrain: Dictionary=Nav57.ensure(b) if int(b.get("version",56))>=58 else {}
    for man in living(fighter):
        man["cool"]=maxf(0.0,float(man["cool"])-dt)
        man["attack_anim"]=maxf(0.0,float(man.get("attack_anim",0.0))-dt)
        if float(man["cool"])>0:continue # independent per-soldier cooldown
        var victim: Dictionary=_target_man(man,opponent,reach,terrain)
        if victim.is_empty():continue
        if kind=="slinger" and int(man["ammo"])<=0:continue
        var hits: bool=true
        if kind=="slinger":
            hits=posmod((int(man["shots"])+1)*17+int(man["index"])*7,10)<7
            if int(b.get("version",56))>=58 and not Stones58.fire(b,man,
                    victim,int(fighter["team"]),power,hits):
                continue # Cover or projectile cap: do not waste ammunition.
        man["shots"]=int(man["shots"])+1
        man["cool"]=1.6 if kind=="slinger" else 1.35
        man["attack_anim"]=0.36
        if kind=="slinger":
            man["ammo"]=int(man["ammo"])-1
            if int(b.get("version",56))>=58 or not hits:continue
        victim["hp"]=maxf(0.0,float(victim["hp"])-power)
        if int(b.get("version",56))>=61:
            victim["hit_anim_v61"]=0.36

static func _aggregate(fighter: Dictionary) -> void:
    var total: float=0.0
    var count: int=0
    for man in fighter.get("men",[]):
        if float(man["hp"])>0:
            total+=float(man["hp"])
            count+=1
    fighter["hp"]=total
    fighter["menAlive"]=count

static func tick(b: Dictionary,dt: float) -> void:
    initialize(b)
    var fighters: Array=b["fighters"]
    if int(b.get("version",56))>=61:
        for fighter in fighters:
            for man in fighter.get("men",[]):
                man["hit_anim_v61"]=maxf(0.0,
                    float(man.get("hit_anim_v61",0.0))-dt)
    # Both sides advance before damage; no entire squad teleports to a target.
    var grid: Dictionary={}
    if int(b.get("version",56))>=57:
        Nav57.ensure(b)
        grid=Nav57.index_people(b)
    for fighter in fighters:
        if float(fighter.get("hp",0))<=0:continue
        var foe: Dictionary=_foe(fighter,b)
        _update_anchor(fighter,foe,dt,b)
        _move_men(fighter,dt,b,grid)
    if int(b.get("version",56))>=58:
        Stones58.step(b,dt) # Existing stones land before fresh shots launch.
    for fighter in fighters:
        _attack(b,fighter,dt)
    for fighter in fighters:
        _aggregate(fighter)
