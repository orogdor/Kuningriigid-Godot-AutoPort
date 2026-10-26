extends RefCounted
## AutoPort 0.37: deterministic second-city plan for playable researched saves.
## Existing 0.5 / old satellite fixtures continue using the prior algorithm.
## All building specs, materials and prerequisites come from generated JS data.
const Unlock=preload("res://scripts/building_unlocks_v36.gd")
const FOOD: Array[String]=["bread","grain","flour","meat","fish","berries","vegetables"]

static func counts(state: Dictionary) -> Dictionary:
    var found: Dictionary={}
    for b in state.get("buildings",[]):
        if bool(b.get("ready",false)) and float(b.get("hp",0))>0.0:
            var key: String=String(b.get("type",""))
            found[key]=int(found.get(key,0))+1
    return found

static func _can_pay(stock: Dictionary,cost: Dictionary) -> bool:
    for good in cost.keys():
        if String(good)=="bread":
            var food: float=0.0
            for kind in FOOD:food+=float(stock.get(kind,0.0))
            if food+0.000001<float(cost[good]):return false
        elif float(stock.get(good,0.0))+0.000001<float(cost[good]):
            return false
    return true

static func _eligible(state: Dictionary,recipes: Dictionary,have: Dictionary,kind: String) -> bool:
    if not recipes.has(kind):return false
    var spec: Dictionary=recipes[kind]
    if int(spec.get("age",0))>int(state.get("age",0)):return false
    if not Unlock.allowed(state,kind):return false
    for req in spec.get("requires",[]):
        if int(have.get(String(req),0))<1:return false
    return _can_pay(state["realms"][0]["resources"],spec.get("cost",{}))

static func choose(state: Dictionary,definitions: Dictionary) -> String:
    var recipes: Dictionary=definitions.get("buildings",{})
    var have: Dictionary=counts(state)
    var pop: float=float(state["realms"][0].get("pop",3))
    var free: float=4.0+1.5*float(have.get("house",0))-pop
    # First build a viable core; never order an inaccessible house/workshop.
    var urgent: Array[String]=[]
    if int(have.get("lumber",0))<1:urgent.append("lumber")
    if int(have.get("well",0))<1:urgent.append("well")
    if int(have.get("house",0))<1 or free<1.5:urgent.append("house")
    if int(have.get("quarry",0))<1:urgent.append("quarry")
    if int(have.get("farm",0))<1:urgent.append("farm")
    for kind in urgent:
        if _eligible(state,recipes,have,kind):return kind
    # During the Bronze Age the AI deliberately builds actual urban services,
    # not endless disconnected houses. Buildings have their original source
    # costs, workforce, inputs/outputs and countrywide technology locks.
    if int(state.get("age",0))>=1:
        for kind in ["saw","warehouse","market","vegetable_garden","cellar"]:
            if int(have.get(kind,0))==0 and _eligible(state,recipes,have,kind):
                return kind
    var max_houses: int=10 if int(state.get("age",0))>=1 else 5
    if int(have.get("house",0))<max_houses and _eligible(state,recipes,have,"house"):
        return "house"
    var farm_goal: int=3 if int(state.get("age",0))>=1 else 2
    if int(have.get("farm",0))<farm_goal and _eligible(state,recipes,have,"farm"):
        return "farm"
    if int(state.get("age",0))>=1 and int(have.get("vegetable_garden",0))<2:
        if _eligible(state,recipes,have,"vegetable_garden"):
            return "vegetable_garden"
    return ""
