extends RefCounted
## AutoPort 0.35: first playable national research layer for the Stone Age
## and Bronze Age. Uses the exported V118 prerequisite graph, science-rate
## constants and era materials, never modifying the 0.5 economy parity loop.
## Upstream source: research.js + science.js + tech-tree-data-v118.js.
## Research beyond age 1, Eureka and building-specific tech locks are future ports.
const Rules=preload("res://scripts/generated_rules.gd")
const City=preload("res://scripts/city_sim_v05.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const ERA_NAMES: Array[String]=["Kiviaeg","Pronksiaeg"]
# V118 applies turns:3 to technologies without a pre-existing definition.
# Entries below retain the original durations in research.js for ages 0-1.
const TURN_OVERRIDES: Dictionary={
    "hunting":1,"fishing":1,"stone_tools":2,"learning":2,
    "warfare":2,"water":2,"settlement":2,"bronze":4,
    "agriculture":3,"archery":2,"stone_crafts":2,"woodworking":2,
    "milling":2,"fortifications":3,"animal_husbandry":3,
    "pottery":2,"masonry":3,"copper_tin":4,"forestry":2,
    "bronze_crafts":3,"shipbuilding":3,"writing":3,"bridges":3,
    "storage":2,"cellaring":2,"commerce":3,"wheel":3,
    "road_construction":4,"stone_fortifications":4
}

static func ensure(state: Dictionary) -> Dictionary:
    if not state.has("research_v35") or not state["research_v35"] is Dictionary:
        state["research_v35"]={
            "known":[],"active":"","progress":{},"completed":[],
            "rate":0.0,"age_wait":""
        }
    var research: Dictionary=state["research_v35"]
    if not research.get("known",null) is Array:research["known"]=[]
    if not research.get("progress",null) is Dictionary:research["progress"]={}
    if not research.get("completed",null) is Array:research["completed"]=[]
    if research.get("active",null)==null:research["active"]=""
    if not research.has("rate"):research["rate"]=0.0
    if not research.has("age_wait"):research["age_wait"]=""
    return research

static func catalog() -> Dictionary:
    return Rules.read_table("tech_tree")

static func science_rate(state: Dictionary) -> float:
    var per_resident: float=float(Rules.read_table("science_per_resident"))
    var total: float=maxf(0.0,float(state["realms"][0].get("pop",0)))*per_resident
    if Trade.has_outpost(state):
        var satellite: Dictionary=Trade.ensure_city(state)
        if satellite.has("realms") and not satellite["realms"].is_empty():
            total+=maxf(0.0,float(satellite["realms"][0].get("pop",0)))*per_resident
    return total

static func cost(id: String) -> float:
    var techs: Dictionary=catalog()
    if not techs.has(id):return INF
    var turns: float=float(TURN_OVERRIDES.get(id,3))
    return turns*float(Rules.read_table("science_per_turn"))

static func name_of(id: String) -> String:
    return String(catalog().get(id,{}).get("name",id))

static func block(state: Dictionary,id: String) -> String:
    var techs: Dictionary=catalog()
    if not techs.has(id):return "Tundmatu tehnoloogia."
    var r: Dictionary=ensure(state)
    if r["known"].has(id):return "Juba uuritud."
    var item: Dictionary=techs[id]
    var age: int=int(item.get("age",0))
    if age>1:return "Järgmiste ajastute uurimine lisandub hiljem."
    if age>0 and id!="bronze" and not r["known"].has("bronze"):
        return "Enne on vaja pronksiaega."
    for dependency in item.get("requires",[]):
        if not r["known"].has(String(dependency)):
            return "Eeldab: "+name_of(String(dependency))
    var alternatives: Array=item.get("oneOf",[])
    if not alternatives.is_empty():
        var has_one: bool=false
        for choice in alternatives:
            if r["known"].has(String(choice)):has_one=true
        if not has_one:
            var labels: Array[String]=[]
            for choice in alternatives:
                labels.append(name_of(String(choice)))
            return "Eeldab üht: "+", ".join(labels)
    return ""

static func available(state: Dictionary) -> Array[String]:
    var ids: Array[String]=[]
    var keys: Array=catalog().keys()
    keys.sort()
    for id in keys:
        if block(state,String(id))=="":ids.append(String(id))
    return ids

static func start(state: Dictionary,id: String) -> String:
    var error: String=block(state,id)
    if error!="":return error
    var r: Dictionary=ensure(state)
    if String(r["active"])!="":return "Eelmine avastus on veel pooleli."
    r["active"]=id
    r["age_wait"]=""
    if not r["progress"].has(id):r["progress"][id]=0.0
    return ""

static func tick(state: Dictionary) -> Array[String]:
    var completed: Array[String]=[]
    if bool(state.get("ended",false)):return completed
    var r: Dictionary=ensure(state)
    r["rate"]=science_rate(state)
    var id: String=String(r["active"])
    if id=="" or float(r["rate"])<=0.0:return completed
    if block(state,id)!="":return completed
    var total: float=cost(id)
    if total<=0.0 or not is_finite(total):return completed
    var current: float=float(r["progress"].get(id,0.0))
    r["progress"][id]=minf(total,current+float(r["rate"]))
    if float(r["progress"][id])+0.00000001<total:return completed
    # Bronze age is paid atomically; insufficient resources keep fully
    # accumulated science on hold and never spend partial materials.
    if id=="bronze":
        var materials: Dictionary=Rules.read_table("era_costs").get("bronze",{})
        var stock: Dictionary=state["realms"][0]["resources"]
        if not City.can_afford(stock,materials):
            r["age_wait"]="Pronksiaeg ootab materjale: 35 puitu, 25 kivi ja 15 toitu."
            return completed
        City.spend(stock,materials)
        state["age"]=1
        if Trade.has_outpost(state):
            var satellite: Dictionary=Trade.ensure_city(state)
            satellite["age"]=1
    r["age_wait"]=""
    r["known"].append(id)
    r["completed"].append({"id":id,"time":float(state.get("time",0))})
    r["active"]=""
    completed.append(id)
    return completed
