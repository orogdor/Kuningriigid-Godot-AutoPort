extends RefCounted
## AutoPort v0.54. First real Stone Age military loop (separate from 0.5 economy).
## Mirrors final Three.js V287/V128 balances for the military camp and first
## three troops, including v99 doubled HP and V88 grade multipliers.
## Source: civilization-core.js, ai-development-v128.js, military-v88.js.
## The real worker/trainer pathfinding and battles remain future work.
const City=preload("res://scripts/city_sim_v05.gd")
const Research=preload("res://scripts/research_v35.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const Movement=preload("res://scripts/world_scout_v52.gd")
const KEY: String="military_v54"
const CAMP_COST: Dictionary={"wood":20.0,"stone":9.0}
const CAMP_SECONDS: float=18.0
const MAX_QUEUE: int=4
const MAX_ARMIES: int=36
const GRADES: Dictionary={
    "mobilized":{"cost":0.5,"strength":0.4},
    "standard":{"cost":1.0,"strength":1.0},
    "elite":{"cost":1.3,"strength":1.4}
}
const TROOPS: Dictionary={
    "slinger":{"name":"Kiviviskaja","cost":{"wood":6.0,"stone":12.0},
        "seconds":19.0,"hp":170.0,"speed":2.7,"range":10.0,"damage":7.0},
    "spearman":{"name":"Puuodamees","cost":{"wood":15.0,"stone":3.0},
        "seconds":23.0,"hp":250.0,"speed":2.8,"range":3.0,"damage":10.0},
    "axeman":{"name":"Kivikirvemees","cost":{"wood":10.0,"stone":10.0},
        "seconds":27.0,"hp":280.0,"speed":2.7,"range":2.5,"damage":12.0}
}

static func _start(world: Dictionary) -> Dictionary:
    var starts: Array=world.get("starts",[])
    return starts[0] if not starts.is_empty() else {}

static func ensure(state: Dictionary,world: Dictionary) -> Dictionary:
    if world.is_empty() or _start(world).is_empty():return {}
    var military: Variant=state.get(KEY,null)
    if not military is Dictionary or int(military.get("seed",-1))!=int(world.get("seed",-2)):
        state[KEY]={"seed":int(world["seed"]),
            "camp":{"under_construction":false,"ready":false,"progress":0.0},
            "queue":[],"armies":[],"next_id":1}
    var saved: Dictionary=state[KEY]
    if not saved.get("camp",null) is Dictionary:
        saved["camp"]={"under_construction":false,"ready":false,"progress":0.0}
    for key in ["queue","armies"]:
        if not saved.get(key,null) is Array:saved[key]=[]
    if not saved.has("next_id"):saved["next_id"]=1
    var sane: Array=[]
    for entry in saved["armies"]:
        if not entry is Dictionary:continue
        if not TROOPS.has(String(entry.get("kind",""))):continue
        if not Routes.passable(world,int(entry.get("c",-1)),int(entry.get("r",-1))):continue
        if not entry.get("path",null) is Array:entry["path"]=[]
        if entry["path"].size()>World.COLS*World.ROWS:entry["path"]=[]
        if not entry.has("travelClock"):entry["travelClock"]=0.0
        if not entry.has("travelDuration"):entry["travelDuration"]=0.0
        var previous:=Vector2i(int(entry["c"]),int(entry["r"]))
        var valid: bool=true
        for tile in entry["path"]:
            if not tile is Dictionary:
                valid=false
                break
            var next:=Vector2i(int(tile.get("c",-1)),int(tile.get("r",-1)))
            if absi(previous.x-next.x)+absi(previous.y-next.y)!=1 or \
                    not Routes.passable(world,next.x,next.y):
                valid=false
                break
            previous=next
        if not valid:
            entry["path"]=[]
            entry["travelClock"]=0.0
            entry["travelDuration"]=0.0
        sane.append(entry)
    saved["armies"]=sane
    return saved

static func can_build(state: Dictionary,world: Dictionary) -> bool:
    var military: Dictionary=ensure(state,world)
    if military.is_empty():return false
    var camp: Dictionary=military["camp"]
    if bool(camp.get("ready",false)) or bool(camp.get("under_construction",false)):
        return false
    if not Research.ensure(state)["known"].has("warfare"):return false
    var hall: bool=false
    for building in state.get("buildings",[]):
        if String(building.get("type",""))=="hall" and bool(building.get("ready",false)):
            hall=true
    return hall and City.can_afford(state["realms"][0]["resources"],CAMP_COST)

static func build(state: Dictionary,world: Dictionary) -> String:
    var military: Dictionary=ensure(state,world)
    if military.is_empty():return "Maailmakaart pole valmis."
    var camp: Dictionary=military["camp"]
    if bool(camp.get("ready",false)) or bool(camp.get("under_construction",false)):
        return "Sõdalaste laager on juba olemas."
    if not Research.ensure(state)["known"].has("warfare"):
        return "Uuri kõigepealt sõjapidamine."
    if not can_build(state,world):return "Vaja valmis peahoonet ning 20 puitu ja 9 kivi."
    City.spend(state["realms"][0]["resources"],CAMP_COST)
    camp["under_construction"]=true
    camp["progress"]=0.0
    return ""

static func cost(kind: String,grade: String="standard") -> Dictionary:
    if not TROOPS.has(kind) or not GRADES.has(grade):return {}
    var multiplier: float=float(GRADES[grade]["cost"])
    var result: Dictionary={}
    for key in TROOPS[kind]["cost"].keys():
        # Exact upstream military-v88.js troopCost: round to six decimals.
        result[key]=roundf(float(TROOPS[kind]["cost"][key])*multiplier*1000000.0)/1000000.0
    return result

static func recruit(state: Dictionary,world: Dictionary,kind: String,
        grade: String="standard") -> String:
    var m: Dictionary=ensure(state,world)
    if m.is_empty():return "Maailmakaart pole valmis."
    if not TROOPS.has(kind) or not GRADES.has(grade):return "Tundmatu sõdur või varustustase."
    if not Research.ensure(state)["known"].has("warfare"):return "Uuri kõigepealt sõjapidamine."
    if not bool(m["camp"].get("ready",false)):return "Ehita ja lõpeta kõigepealt sõdalaste laager."
    if m["queue"].size()>=MAX_QUEUE:return "Väljaõppe järjekord on täis (4)."
    if m["armies"].size()+m["queue"].size()>=MAX_ARMIES:return "Üksuste piir on täis."
    var realm: Dictionary=state["realms"][0]
    if float(realm.get("pop",0))<6.0:return "Värbamiseks peab linnas olema vähemalt 6 elanikku."
    var amount: Dictionary=cost(kind,grade)
    if not City.can_afford(realm["resources"],amount):return "Värbamiseks ei jätku materjale."
    City.spend(realm["resources"],amount)
    realm["pop"]=float(realm["pop"])-1.0
    m["queue"].append({"kind":kind,"grade":grade,"progress":0.0,
        "total":float(TROOPS[kind]["seconds"]),"paidCost":amount,"populationSpent":1})
    return ""

static func army_by_id(state: Dictionary,world: Dictionary,id: int) -> Dictionary:
    var m: Dictionary=ensure(state,world)
    for army in m.get("armies",[]):
        if int(army.get("id",-1))==id:return army
    return {}

static func _in_battle(m: Dictionary,id: int) -> bool:
    var b: Dictionary=m.get("skirmish_v55",{})
    return not b.is_empty() and String(b.get("result",""))=="" and \
        b.get("source_ids",[]).has(id)

static func rally(state: Dictionary,world: Dictionary,id: int) -> String:
    # Three.js rallyArmies: order friendly detachments to an id, preserving
    # their independent units and HP. Group only once they physically arrive.
    var m: Dictionary=ensure(state,world)
    var target: Dictionary=army_by_id(state,world,id)
    if target.is_empty():return "Väesalka ei leitud."
    if _in_battle(m,id):return "Lõpeta enne lahing."
    if not target.get("path",[]).is_empty():return "Kogunemispunkt peab olema paigal."
    target["group_id"]=id
    var destination:=Vector2i(int(target["c"]),int(target["r"]))
    var ordered: int=0
    for army in m["armies"]:
        if int(army["id"])==id or float(army.get("hp",0))<=0:continue
        var army_id: int=int(army["id"])
        if _in_battle(m,army_id):continue
        var start:=Vector2i(int(army["c"]),int(army["r"]))
        var path: Array=Routes.build_path(world,start,destination)
        if start!=destination and path.size()<2:continue
        army["rally_target"]=id
        if start==destination:
            army["group_id"]=id
            army["path"]=[]
            army["travelClock"]=0.0
            army["travelDuration"]=0.0
        else:
            army["path"]=path.slice(1)
            army["travelClock"]=0.0
            army["travelDuration"]=Movement.segment_seconds(
                army,army["path"][0],float(army["speed"]))
        ordered+=1
    return "" if ordered>0 else "Ühtegi teist väesalka ei saanud koondada."

static func order(state: Dictionary,world: Dictionary,id: int,at: Vector2i) -> String:
    var army: Dictionary=army_by_id(state,world,id)
    if army.is_empty():return "Sellist sõjaväeüksust ei leitud."
    if _in_battle(ensure(state,world),id):return "Seda väesalka juhitakse lahinguväljal."
    if not Routes.passable(world,at.x,at.y):return "Armee ei saa liikuda merre või mägedesse."
    var origin:=Vector2i(int(army["c"]),int(army["r"]))
    # One order for a physically gathered formation moves all linked units.
    # Each paid squad retains its own ID and HP; slowest member sets pace.
    var m: Dictionary=ensure(state,world)
    var group_id: int=int(army.get("group_id",army["id"]))
    var members: Array=[]
    for candidate in m["armies"]:
        var same_group: bool=int(candidate.get("group_id",candidate.get("id",-1)))==group_id
        var here: bool=int(candidate["c"])==origin.x and int(candidate["r"])==origin.y
        if same_group and here and not _in_battle(m,int(candidate["id"])):
            members.append(candidate)
    if members.is_empty():members.append(army)
    if origin==at:
        for member in members:
            member["path"]=[]
            member["travelClock"]=0.0
            member["travelDuration"]=0.0
        return ""
    var route: Array=Routes.build_path(world,origin,at)
    if route.size()<2:return "Maismaateed sihtkohta ei leitud."
    var slowest: float=INF
    for member in members:
        slowest=minf(slowest,float(member.get("speed",2.7)))
    for member in members:
        member["path"]=route.slice(1)
        member["travelClock"]=0.0
        member["march_speed"]=slowest
        member["travelDuration"]=Movement.segment_seconds(
            member,member["path"][0],slowest)
    return ""

static func _march(army: Dictionary,world: Dictionary,seconds: float) -> void:
    var remaining: float=maxf(0.0,seconds)
    while not army["path"].is_empty() and remaining>=0.0:
        var next: Dictionary=army["path"][0]
        if not Routes.passable(world,int(next["c"]),int(next["r"])):
            army["path"]=[]
            break
        var duration: float=Movement.segment_seconds(
            army,next,float(army.get("march_speed",army["speed"])))
        if duration<=0.0 or not is_finite(duration):break
        Movement.rescale_travel(army,duration)
        var pending: float=maxf(0.0,duration-float(army.get("travelClock",0)))
        if remaining+0.0000001<pending:
            army["travelClock"]=float(army["travelClock"])+remaining
            break
        remaining=maxf(0.0,remaining-pending)
        army["c"]=int(next["c"])
        army["r"]=int(next["r"])
        army["path"].pop_front()
        army["travelClock"]=0.0
        army["travelDuration"]=0.0
        if army["path"].is_empty():break

static func tick(state: Dictionary,world: Dictionary,seconds: float) -> void:
    if seconds<=0.0:return
    var m: Dictionary=ensure(state,world)
    if m.is_empty():return
    var camp: Dictionary=m["camp"]
    if bool(camp.get("under_construction",false)):
        camp["progress"]=minf(CAMP_SECONDS,float(camp["progress"])+seconds)
        if float(camp["progress"])+0.000001>=CAMP_SECONDS:
            camp["under_construction"]=false
            camp["ready"]=true
    # One first-in-first-out training job per tick, as in Three.js.
    if bool(camp.get("ready",false)) and not m["queue"].is_empty():
        var job: Dictionary=m["queue"][0]
        job["progress"]=minf(float(job["total"]),float(job["progress"])+seconds)
        if float(job["progress"])+0.000001>=float(job["total"]):
            var home: Dictionary=_start(world)
            var kind: String=String(job["kind"])
            var grade: String=String(job["grade"])
            var id: int=int(m["next_id"])
            m["next_id"]=id+1
            m["armies"].append({"id":id,"team":0,"kind":kind,"grade":grade,
                "c":int(home["c"]),"r":int(home["r"]),"path":[],
                "speed":float(TROOPS[kind]["speed"]),
                "hp":float(TROOPS[kind]["hp"])*float(GRADES[grade]["strength"]),
                "morale":100.0,"travelClock":0.0,"travelDuration":0.0})
            m["queue"].pop_front()
    for army in m["armies"]:
        var id: int=int(army.get("id",-1))
        if _in_battle(m,id):continue
        _march(army,world,seconds)
        if army.has("rally_target") and army.get("path",[]).is_empty():
            var target: Dictionary=army_by_id(state,world,int(army["rally_target"]))
            if not target.is_empty() and int(army["c"])==int(target["c"]) and \
                    int(army["r"])==int(target["r"]):
                army["group_id"]=int(target["id"])
            army.erase("rally_target")

static func sample(army: Dictionary) -> Dictionary:
    return Movement.sample(army)

static func summary(state: Dictionary,world: Dictionary) -> String:
    var m: Dictionary=ensure(state,world)
    if m.is_empty():return "Sõjavägi: maailm puudub."
    var camp: Dictionary=m["camp"]
    var status: String="valmis" if bool(camp.get("ready",false)) else \
        ("ehitamisel" if bool(camp.get("under_construction",false)) else "puudub")
    var result: String="Sõdalaste laager: %s | üksusi %d | väljaõppes %d" % [
        status,m["armies"].size(),m["queue"].size()]
    if not m["queue"].is_empty():
        var job: Dictionary=m["queue"][0]
        result+=" | %s %.0f/%.0f s" % [String(job["kind"]),
            float(job["progress"]),float(job["total"])]
    return result
