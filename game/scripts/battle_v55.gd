extends RefCounted
## First playable, explicitly opt-in Stone Age skirmish slice.
## Accurate upstream battlefield scale, basic unit stats, grades and
## formations; the original 24-man collision/ballistics/siege model is NOT
## included. The opposing raider is a demo combatant, not a full enemy AI.
const Mil=preload("res://scripts/military_v54.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const Men56=preload("res://scripts/individual_v56.gd")
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Orders59=preload("res://scripts/battle_orders_v59.gd")
const Individuals60=preload("res://scripts/individual_orders_v60.gd")
const Attack68=preload("res://scripts/individual_attack_v68.gd")
const Raider56=preload("res://scripts/raider_v56.gd")
const KEY: String="skirmish_v55"
const SCALE: float=0.5 # battle-pacing-v93.js
const STEP: float=0.2
const HALF_X: float=337.5 # battlefield-v88.js: 3 * 225 / 2
const HALF_Z: float=292.5 # battlefield-v88.js: 3 * 195 / 2
const OUTER_X: float=562.5
const OUTER_Z: float=487.5
const FORMATIONS: Dictionary={
    "line":{"speed":1.0,"defense":1.0},
    "hold":{"speed":0.8,"defense":1.0},
    "spear_wall":{"speed":0.35,"defense":0.80},
    "loose":{"speed":1.0,"defense":0.87},
    "skirmish":{"speed":1.0,"defense":0.87}
}
const MAX_ALLIES: int=8
const MAX_LOG: int=24

static func current(state: Dictionary,world: Dictionary) -> Dictionary:
    var military: Dictionary=Mil.ensure(state,world)
    if military.is_empty():return {}
    var b: Variant=military.get(KEY,null)
    if not b is Dictionary:return {}
    if int(b.get("seed",-1))!=int(world.get("seed",-2)):
        military.erase(KEY)
        return {}
    return b

static func active(state: Dictionary,world: Dictionary) -> bool:
    var b: Dictionary=current(state,world)
    return not b.is_empty() and String(b.get("result",""))==""

static func _message(b: Dictionary,message: String) -> void:
    var messages: Array=b.get("log",[])
    messages.append(message)
    while messages.size()>MAX_LOG:messages.pop_front()
    b["log"]=messages

static func _faction_fighters(b: Dictionary,team: int) -> Array:
    return b.get("fighters",[]).filter(func(f):return int(f["team"])==team)

static func start(state: Dictionary,world: Dictionary,ids: Array) -> String:
    var military: Dictionary=Mil.ensure(state,world)
    if military.is_empty():return "Maailmakaart pole valmis."
    if active(state,world):return "Lõpeta praegune lahing."
    if ids.is_empty() or ids.size()>MAX_ALLIES:
        return "Vali 1–8 väesalka."
    var chosen: Array=[]
    var seen: Dictionary={}
    var tile:=Vector2i(-1,-1)
    for raw_id in ids:
        var id: int=int(raw_id)
        if seen.has(id):return "Väesalka ei saa kaks korda valida."
        seen[id]=true
        var army: Dictionary=Mil.army_by_id(state,world,id)
        if army.is_empty() or float(army.get("hp",0))<=0.0:
            return "Valitud üksus puudub või on langenud."
        if not army.get("path",[]).is_empty():
            return "Enne lahingut peavad väesalgad seisma."
        var here:=Vector2i(int(army["c"]),int(army["r"]))
        if tile.x>=0 and here!=tile:return "Lahingusse saab minna ühe ruudu väesalkadega."
        tile=here
        chosen.append(army)
    if not Routes.passable(world,tile.x,tile.y):
        return "Lahingut ei saa alustada merel ega mäestikus."
    var soldiers: Array=[]
    for i in range(chosen.size()):
        var army: Dictionary=chosen[i]
        var kind: String=String(army["kind"])
        var hp: float=float(army["hp"])
        var max_hp: float=float(Mil.TROOPS[kind]["hp"])*float(
            Mil.GRADES[String(army.get("grade","standard"))]["strength"])
        soldiers.append({"id":int(army["id"]),"source_id":int(army["id"]),
            "team":0,"kind":kind,"grade":String(army.get("grade","standard")),
            "hp":hp,"max_hp":max_hp,"x":-49.0 if kind=="slinger" else -34.0,
            "z":float(i-(chosen.size()-1)*0.5)*8.0,"mode":"hold","formation":"line",
            "cool":0.0,"shots":0,"ammo":18 if kind=="slinger" else -1})
    # A deliberately opt-in test opponent. It is not silently added to
    # normal campaign armies or granted any player resources.
    soldiers.append({"id":-1,"source_id":-1,"team":1,"kind":"spearman",
        "grade":"standard","hp":float(Mil.TROOPS["spearman"]["hp"]),
        "max_hp":float(Mil.TROOPS["spearman"]["hp"]),
        "x":34.0,"z":0.0,"mode":"attack","formation":"line",
        "cool":0.0,"shots":0,"ammo":-1})
    military[KEY]={"version":70,"seed":int(world["seed"]),
        "cell":{"c":tile.x,"r":tile.y},"fighters":soldiers,
        "source_ids":ids.duplicate(),"elapsed":0.0,"fraction":0.0,
        "result":"","resolved":false,"log":[],
        "battlefield":{"columns":3,"rows":3,"ring":1,
            "tileWidth":225.0,"tileDepth":195.0}}
    Men56.initialize(military[KEY])
    Nav57.ensure(military[KEY])
    _message(military[KEY],"Harjutusvastasega kokkupõrge. Kaotused on päris, saaki ei jagata.")
    return ""

## One-click non-destructive battle, independent of research, barracks, pay,
## population, or strategic army ownership. Actual soldiers are used only in
## the tactical state and never carried into the campaign ledger.
static func start_demo(state: Dictionary,world: Dictionary) -> String:
    var military: Dictionary=Mil.ensure(state,world)
    if military.is_empty():return "Maailmakaart ei ole veel valmis."
    if active(state,world):
        return "Lõpeta olemasolev lahing enne uut proovilahingut."
    var troops: Array=[]
    var formation_kinds: Array=["spearman","axeman","slinger"]
    for i in range(formation_kinds.size()):
        var kind: String=String(formation_kinds[i])
        var hp: float=float(Mil.TROOPS[kind]["hp"])
        troops.append({"id":900001+i,"source_id":900001+i,
            "team":0,"kind":kind,"grade":"standard",
            "hp":hp,"max_hp":hp,
            "x":-49.0 if kind=="slinger" else -34.0,
            "z":float(i-1)*7.0,"mode":"attack","formation":"line",
            "cool":0.0,"shots":0,"ammo":18 if kind=="slinger" else -1})
    var foe_hp: float=float(Mil.TROOPS["spearman"]["hp"])
    troops.append({"id":-900001,"source_id":-900001,
        "team":1,"kind":"spearman","grade":"standard",
        "hp":foe_hp,"max_hp":foe_hp,
        "x":34.0,"z":0.0,"mode":"attack","formation":"line",
        "cool":0.0,"shots":0,"ammo":-1})
    military[KEY]={"version":70,"seed":int(world["seed"]),
        "demo_v61":true,"fighters":troops,"source_ids":[],
        "elapsed":0.0,"fraction":0.0,"result":"","resolved":false,
        "log":[],"battlefield":{"columns":3,"rows":3,"ring":1,
            "tileWidth":225.0,"tileDepth":195.0}}
    Men56.initialize(military[KEY])
    Nav57.ensure(military[KEY])
    _message(military[KEY],
        "Tasuta proovilahing: kolm oma väesalka ja üks vastane. " + \
        "Kaotused ei mõjuta päris armeed ega ressursse.")
    return ""

## V64 real-scale, free 5-v-4 army combat stress test (9 x 24 = 216).
## This is also a playable alternative; never touches strategic soldiers.
static func start_large_demo(state: Dictionary,world: Dictionary) -> String:
    var military: Dictionary=Mil.ensure(state,world)
    if military.is_empty():return "Maailmakaart ei ole veel valmis."
    if active(state,world):
        return "Lõpeta olemasolev lahing enne uut proovilahingut."
    var fighters: Array=[]
    var allied: Array=["spearman","axeman","slinger","spearman","axeman"]
    var hostile: Array=["spearman","axeman","slinger","spearman"]
    for team in [0,1]:
        var kinds: Array=allied if team==0 else hostile
        for i in range(kinds.size()):
            var kind: String=String(kinds[i])
            var hp: float=float(Mil.TROOPS[kind]["hp"])
            var x: float=-52.0 if kind=="slinger" else -38.0
            if team==1:x=-x
            fighters.append({"id":900101+i if team==0 else -900101-i,
                "source_id":900101+i if team==0 else -900101-i,
                "team":team,"kind":kind,"grade":"standard",
                "hp":hp,"max_hp":hp,"x":x,
                "z":float(i-(kinds.size()-1)*0.5)*11.0,
                "mode":"attack","formation":"line",
                "cool":0.0,"shots":0,
                "ammo":18 if kind=="slinger" else -1})
    military[KEY]={"version":70,"seed":int(world["seed"]),
        "demo_v61":true,"large_demo_v64":true,
        "fighters":fighters,"source_ids":[],
        "elapsed":0.0,"fraction":0.0,"result":"","resolved":false,
        "log":[],"battlefield":{"columns":3,"rows":3,"ring":1,
            "tileWidth":225.0,"tileDepth":195.0}}
    Men56.initialize(military[KEY])
    Nav57.ensure(military[KEY])
    _message(military[KEY],
        "Suur proovilahing: 5 oma ja 4 vastase väesalka, kokku 216 sõdurit. " + \
        "Tulemused ei mõjuta päris kampaaniat.")
    return ""

static func start_campaign(state: Dictionary,world: Dictionary,ids: Array) -> String:
    var raider: Dictionary=Raider56.current(state,world)
    if raider.is_empty() or bool(raider.get("defeated",false)):
        return "Kampaania vastane puudub."
    if raider.get("engaged",false) or int(raider.get("cooldown",0))>0:
        return "Vastasel on ajutine kaitseaeg."
    if ids.is_empty():return "Vali väesalk."
    for id in ids:
        var army: Dictionary=Mil.army_by_id(state,world,int(id))
        if army.is_empty() or int(army["c"])!=int(raider["c"]) or \
                int(army["r"])!=int(raider["r"]):
            return "Väesalgad ei ole vaenlasega samal ruudul."
    # Ambushed marching armies stop in this tile; never teleport or finish
    # the remaining strategic path while individual soldiers fight.
    for id in ids:
        var army: Dictionary=Mil.army_by_id(state,world,int(id))
        army["path"]=[]
        army["travelClock"]=0.0
        army["travelDuration"]=0.0
    var result: String=start(state,world,ids)
    if result!="":return result
    var b: Dictionary=current(state,world)
    b["campaign_v56"]=true
    b["opponent_id"]=int(raider["id"])
    b["fighters"][b["fighters"].size()-1]["hp"]=float(raider["hp"])
    b["fighters"][b["fighters"].size()-1]["max_hp"]=float(raider["max_hp"])
    b["fighters"][b["fighters"].size()-1]["id"]=int(raider["id"])
    b["fighters"][b["fighters"].size()-1]["source_id"]=int(raider["id"])
    b["individual_version"]=0
    Men56.initialize(b)
    raider["engaged"]=true
    _message(b,"Kampaanialahing: vaenulik väesalk. Tulemused säilivad maailmakaardil.")
    return ""

static func command(state: Dictionary,world: Dictionary,id: int,kind: String) -> String:
    var b: Dictionary=current(state,world)
    if b.is_empty() or String(b.get("result",""))!="":
        return "Aktiivset lahingut ei ole."
    for fighter in b["fighters"]:
        if int(fighter["id"])!=id or int(fighter["team"])!=0:continue
        if float(fighter["hp"])<=0:return "See väesalk on langenud."
        if ["attack","hold","retreat"].has(kind):
            fighter["mode"]=kind
            if kind=="hold":fighter["formation"]="hold"
            elif String(fighter["formation"])=="hold":fighter["formation"]="line"
        elif FORMATIONS.has(kind):
            if kind=="spear_wall" and fighter["kind"]!="spearman":
                return "Odarivi saavad võtta vaid odamehed."
            if ["loose","skirmish"].has(kind) and fighter["kind"]!="slinger":
                return "Hajurivi saavad võtta vaid kiviviskajad."
            fighter["formation"]=kind
            if kind=="hold":fighter["mode"]="hold"
        else:return "Tundmatu lahingukäsk."
        if String(fighter.get("mode",""))!="move":Orders59.cancel(fighter)
        if int(b.get("version",0))>=60:
            Individuals60.clear_squad(fighter)
        _message(b,"%s: %s" % [String(fighter["kind"]),kind])
        return ""
    return "Väesalka ei leitud."

static func move(state: Dictionary,world: Dictionary,id: int,
        destination: Vector2) -> String:
    var battle: Dictionary=current(state,world)
    if battle.is_empty() or String(battle.get("result",""))!="":
        return "Aktiivset lahingut ei ole."
    var result: String=Orders59.issue(battle,id,destination)
    if result=="":
        for fighter in battle["fighters"]:
            if int(fighter.get("id",-1))==id and int(fighter.get("team",-1))==0:
                Individuals60.clear_squad(fighter)
                break
        _message(battle,"Väesalk #%d liigub sihtpunkti." % id)
    return result

static func move_individual(state: Dictionary,world: Dictionary,
        squad_id: int,index: int,destination: Vector2) -> String:
    var battle: Dictionary=current(state,world)
    if battle.is_empty():return "Aktiivset lahingut ei ole."
    var result: String=Individuals60.issue(battle,squad_id,index,destination)
    if result=="":
        _message(battle,"Sõdur #%d:%d liigub iseseisvalt." % [squad_id,index])
    return result

static func rejoin_individual(state: Dictionary,world: Dictionary,
        squad_id: int,index: int) -> String:
    var battle: Dictionary=current(state,world)
    if battle.is_empty():return "Aktiivset lahingut ei ole."
    var result: String=Individuals60.rejoin(battle,squad_id,index)
    if result=="":
        _message(battle,"Sõdur #%d:%d naaseb rivvi." % [squad_id,index])
    return result

## Focus a specific hostile 3D man while preserving normal combat damage,
## collision, cover, slinger ammunition and JSON battle persistence.
static func attack_individual(state: Dictionary,world: Dictionary,
        squad_id: int,index: int,enemy_squad: int,enemy_index: int) -> String:
    var battle: Dictionary=current(state,world)
    if battle.is_empty():return "Aktiivset lahingut ei ole."
    var result: String=Attack68.issue(battle,squad_id,index,
        enemy_squad,enemy_index)
    if result=="":
        _message(battle,"Sõdur #%d:%d ründab vastast #%d:%d." % [
            squad_id,index,enemy_squad,enemy_index])
    return result

static func _nearest(from: Dictionary,foes: Array) -> Dictionary:
    var best: Dictionary={}
    var best_d: float=INF
    for enemy in foes:
        if float(enemy["hp"])<=0:return best if not best.is_empty() else {}
        var delta: float=Vector2(float(enemy["x"])-float(from["x"]),
            float(enemy["z"])-float(from["z"])).length()
        if delta<best_d:
            best_d=delta
            best=enemy
    return best

static func _tick_unit(b: Dictionary,fighter: Dictionary,dt: float) -> void:
    if float(fighter["hp"])<=0.0:return
    var team: int=int(fighter["team"])
    var mode: String=String(fighter.get("mode","hold"))
    var stat: Dictionary=Mil.TROOPS[String(fighter["kind"])]
    var foes: Array=_faction_fighters(b,1-team).filter(
        func(f):return float(f["hp"])>0.0 and String(f.get("mode",""))!="retreated")
    if mode=="retreated":return
    if mode=="retreat":
        var edge: float=-HALF_X-6.0 if team==0 else HALF_X+6.0
        fighter["x"]=move_toward(float(fighter["x"]),edge,float(stat["speed"])*dt)
        if (team==0 and float(fighter["x"])<-HALF_X) or \
                (team==1 and float(fighter["x"])>HALF_X):
            fighter["mode"]="retreated"
        return
    if foes.is_empty():return
    var enemy: Dictionary=_nearest(fighter,foes)
    if enemy.is_empty():return
    var offset:=Vector2(float(enemy["x"])-float(fighter["x"]),
        float(enemy["z"])-float(fighter["z"]))
    var length: float=offset.length()
    var distance: float=float(stat["range"])
    if mode=="attack" and length>distance:
        var formation: Dictionary=FORMATIONS.get(fighter.get("formation","line"),
            FORMATIONS["line"])
        var speed: float=float(stat["speed"])*float(formation["speed"])
        var move: Vector2=offset.normalized()*minf(speed*dt,maxf(0.0,length-distance))
        fighter["x"]=clampf(float(fighter["x"])+move.x,-OUTER_X,OUTER_X)
        fighter["z"]=clampf(float(fighter["z"])+move.y,-OUTER_Z,OUTER_Z)
        return
    if mode=="hold" and length>distance:return
    fighter["cool"]=maxf(0.0,float(fighter.get("cool",0.0))-dt)
    if float(fighter["cool"])>0:return
    if int(fighter.get("ammo",-1))==0:return
    fighter["cool"]=2.5 if fighter["kind"]=="slinger" else 1.7
    fighter["shots"]=int(fighter.get("shots",0))+1
    if fighter["kind"]=="slinger":
        fighter["ammo"]=int(fighter["ammo"])-1
        # Reproducible shot sequence and finite stone ammunition.
        if posmod(int(fighter["shots"])*17+int(fighter["id"])*7,10)>=7:return
    var power: float=float(stat["damage"])*3.0*float(
        Mil.GRADES[String(fighter.get("grade","standard"))]["strength"])
    var formation_id: String=String(enemy.get("formation","line"))
    if formation_id=="spear_wall" and fighter["kind"]!="slinger":
        power*=0.8
    if ["loose","skirmish"].has(formation_id) and fighter["kind"]=="slinger":
        power*=0.78
    enemy["hp"]=maxf(0.0,float(enemy["hp"])-power)
    if float(enemy["hp"])<=0:
        _message(b,"%s langes." % String(enemy["kind"]))

static func _finish(state: Dictionary,world: Dictionary,b: Dictionary) -> void:
    if bool(b.get("resolved",false)):return
    if bool(b.get("demo_v61",false)):
        # The disposable tactical demo must not touch campaign armies,
        # resources, research progress, raider settlements or statistics.
        b["resolved"]=true
        return
    var m: Dictionary=Mil.ensure(state,world)
    var survivors: Array=[]
    for army in m["armies"]:
        if not b["source_ids"].has(int(army.get("id",-1))):
            survivors.append(army)
            continue
        var matching_fighter: Dictionary={}
        for fighter in b["fighters"]:
            if int(fighter.get("source_id",-1))==int(army["id"]):
                matching_fighter=fighter
                break
        if matching_fighter.is_empty():continue
        var remaining: float=clampf(float(matching_fighter["hp"]),0.0,float(army.get("hp",0)))
        if remaining<=0.0:continue
        army["hp"]=remaining
        army["path"]=[]
        army["travelClock"]=0.0
        army["travelDuration"]=0.0
        survivors.append(army)
    m["armies"]=survivors
    if bool(b.get("campaign_v56",false)):
        var opponent_hp: float=0.0
        for fighter in b["fighters"]:
            if int(fighter.get("team",-1))==1:
                opponent_hp=float(fighter["hp"])
                break
        Raider56.settle(state,world,opponent_hp)
    m["last_battle_v55"]={"result":b["result"],"elapsed":b["elapsed"],
        "survivors":survivors.size()}
    b["resolved"]=true

static func _outcome(state: Dictionary,world: Dictionary,b: Dictionary) -> void:
    var friendly: Array=_faction_fighters(b,0)
    var enemy: Array=_faction_fighters(b,1)
    var enemy_live: bool=enemy.any(func(f):return float(f["hp"])>0)
    var own_live: bool=friendly.any(func(f):return float(f["hp"])>0 and \
        String(f.get("mode",""))!="retreated")
    if not enemy_live:b["result"]="victory"
    elif not own_live:
        b["result"]="retreat" if friendly.any(func(f):return float(f["hp"])>0) else "defeat"
    if String(b["result"])!="":
        _message(b,"Lahing lõppes: "+String(b["result"]))
        _finish(state,world,b)

static func tick(state: Dictionary,world: Dictionary,wall_seconds: float) -> void:
    if wall_seconds<=0:return
    var b: Dictionary=current(state,world)
    if b.is_empty() or String(b.get("result",""))!="":return
    var pool: float=float(b.get("fraction",0.0))+wall_seconds*SCALE
    var steps: int=mini(600,int(floor((pool+0.00000001)/STEP)))
    b["fraction"]=maxf(0.0,pool-steps*STEP)
    for unused in range(steps):
        if String(b["result"])!="":break
        b["elapsed"]=float(b["elapsed"])+STEP
        # Resolve simultaneous engagements in alternating order to avoid a
        # permanent player/AI first-strike advantage.
        var fighters: Array=b["fighters"]
        if posmod(int(roundf(float(b["elapsed"])/STEP)),2)==0:
            fighters=fighters.duplicate()
            fighters.reverse()
        if int(b.get("version",55))>=56:
            Men56.tick(b,STEP)
        else:
            for f in fighters:
                _tick_unit(b,f,STEP)
        _outcome(state,world,b)

static func status(state: Dictionary,world: Dictionary) -> String:
    var b: Dictionary=current(state,world)
    if b.is_empty():return "Lahingut ei toimu."
    var lines: Array[String]=[]
    lines.append("3×3 lahinguväli | %.1f s | %s" % [
        float(b["elapsed"]),"Käimas" if String(b["result"])=="" else String(b["result"])])
    for fighter in b["fighters"]:
        lines.append("#%d %s HP %.0f/%.0f | %s | %s" % [
            int(fighter["id"]),String(fighter["kind"]),
            float(fighter["hp"]),float(fighter["max_hp"]),
            String(fighter.get("mode","hold")),String(fighter.get("formation","line"))])
    return "\n".join(lines)
