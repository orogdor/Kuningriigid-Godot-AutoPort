extends RefCounted
## AutoPort 0.5: the first one-city, one-minute economy loop.
## Matches the deterministic subset of economy.js::tickEconomy for dt=60:
## no physical delivery paths, terrain deposits, districts, AI or battle.
const Logic = preload("res://scripts/logic_v02.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Rules = preload("res://scripts/generated_rules.gd")
const FOOD_KEYS: Array[String] = [
    "bread", "grain", "flour", "meat", "fish", "berries",
    "vegetables", "fruit", "cheese", "spices", "coffee"
]
const FOOD_NUTRITION: Dictionary = {"bread":1.0, "flour":0.85, "grain":0.70}
const DT: float = 60.0
const RESOURCE_MULTIPLIER: float = 1.0 / 4.5

static func definitions() -> Dictionary:
    return Rules.read_table("city_buildings")

static func default_state() -> Dictionary:
    var defs: Dictionary = definitions()
    var start: Dictionary = defs.get("start", {})
    if start.is_empty():
        return {}
    var stock: Dictionary = start.duplicate(true)
    return {"time":0.0, "age":0, "buildings":[{"type":"hall", "team":0, "x":0.0, "z":0.0, "hp":1200, "ready":true, "timer":0.0, "progress":0.0}],
        "realms":[{"pop":3, "resources":stock, "growthProgress":0.0,
        "shortageTurns":0, "tech":0}], "cargo":[], "ended":false}

static func housing_capacity(buildings: Array) -> float:
    var count: int = 0
    for b in buildings:
        if String(b.get("type","")) == "house" and bool(b.get("ready",false)) and float(b.get("hp",0)) > 0.0 and not bool(b.get("virtual",false)):
            count += 1
    return 4.0 + 1.5 * count

static func _has_ready(buildings: Array, building_type: String) -> bool:
    for b in buildings:
        if String(b.get("type","")) == building_type and bool(b.get("ready",false)) and float(b.get("hp",0)) > 0:
            return true
    return false

static func take_food(stock: Dictionary, meals: float) -> float:
    var ranked: Array = []
    for i in range(FOOD_KEYS.size()):
        ranked.append({"key":FOOD_KEYS[i], "value":float(stock.get(FOOD_KEYS[i],0)), "index":i})
    ranked.sort_custom(func(a,b): return a["index"] < b["index"] if is_equal_approx(a["value"],b["value"]) else a["value"] > b["value"])
    var need: float = maxf(0.0,meals)
    var served: float = 0.0
    for item in ranked:
        if need <= 0.0000001:
            break
        var key: String = item["key"]
        var nutrition: float = float(FOOD_NUTRITION.get(key,1.0))
        var available: float = maxf(0.0,float(stock.get(key,0)))
        var units: float = minf(available,need / nutrition)
        stock[key] = maxf(0.0, available - units)
        served += units * nutrition
        need -= units * nutrition
    return served

static func can_afford(stock: Dictionary, cost: Dictionary) -> bool:
    for key in cost.keys():
        if String(key) != "bread" and float(stock.get(key,0.0)) + 0.000000001 < float(cost[key]):
            return false
    if cost.has("bread"):
        var food: float = 0.0
        for key in FOOD_KEYS:
            food += maxf(0.0,float(stock.get(key,0))) * float(FOOD_NUTRITION.get(key,1.0))
        if food + 0.000000001 < float(cost["bread"]):
            return false
    return true

static func spend(stock: Dictionary, cost: Dictionary) -> void:
    for key in cost.keys():
        if String(key) != "bread":
            stock[key] = float(stock.get(key,0)) - float(cost[key])
    if cost.has("bread"):
        take_food(stock,float(cost["bread"]))

static func build(state: Dictionary, building_type: String) -> String:
    var defs: Dictionary = definitions().get("buildings",{})
    if building_type == "hall" or not defs.has(building_type):
        return "Tundmatu hoone"
    var spec: Dictionary = defs[building_type]
    if int(spec.get("age",0)) > int(state.get("age",0)):
        return "Ajastu pole avatud"
    for req in spec.get("requires",[]):
        if not _has_ready(state["buildings"],String(req)):
            return "Kõigepealt on vaja: " + String(req)
    var stock: Dictionary = state["realms"][0]["resources"]
    var cost: Dictionary = spec.get("cost",{})
    if not can_afford(stock,cost):
        return "Ehitusmaterjale ei jätku"
    var count: int = state["buildings"].size()
    var place: Vector2=Vector2(float(count)*2.0,0.0)
    if state.has("detail_sim"):
        var proposed: Variant=state.get("pending_site",null)
        if proposed is Dictionary:
            place=Spatial.snap(Vector2(float(proposed.get("x",0)),float(proposed.get("z",0))))
        else:
            place=Spatial.next_free(state)
        if not is_finite(place.x) or not Spatial.can_place(state,place):
            return "Ehituskoht on hõivatud või väljaspool linna"
    spend(stock,cost)
    state.erase("pending_site")
    state["buildings"].append({"type":building_type,"team":0,"x":place.x,"z":place.y,
        "hp":350,"ready":false,"progress":0.0,"timer":0.0})
    return ""

static func _demand(b: Dictionary, d: Dictionary) -> float:
    if bool(b.get("disabled",false)) or bool(b.get("virtual",false)) or float(b.get("hp",0)) <= 0:
        return 0.0
    if not bool(b.get("ready",false)):
        return 1.0
    if d.has("out") or ["forester","warehouse","market","harbor"].has(String(b.get("type",""))):
        return float(d.get("workers",0))
    return 0.0

static func _market_bonus(buildings: Array, stock: Dictionary, pop: float, age: int, goods: Dictionary) -> Dictionary:
    if not _has_ready(buildings,"market"):
        return {"varieties":[], "multiplier":1.0, "bonus":0.0}
    var threshold: float = maxf(0.5,pop*0.1)
    var varieties: Array = []
    if float(stock.get("bread",0)) + float(stock.get("grain",0)) + float(stock.get("flour",0)) >= threshold:
        varieties.append("cereal")
    for key in goods.keys():
        var d: Dictionary = goods[key]
        if bool(d.get("food",false)) and int(d.get("age",0)) <= age and float(stock.get(key,0)) >= threshold:
            varieties.append(key)
    var bonus: float = 0.05 * varieties.size()
    return {"varieties":varieties,"multiplier":1.0 + bonus, "bonus":bonus}

static func tick(state: Dictionary, defs: Dictionary = {}) -> void:
    if bool(state.get("ended",false)):
        return
    if defs.is_empty():
        defs = definitions()
    var recipes: Dictionary = defs.get("buildings",{})
    var goods: Dictionary = defs.get("goods",{})
    var realm: Dictionary = state["realms"][0]
    var stock: Dictionary = realm["resources"]
    var buildings: Array = state["buildings"]
    var pop: float = float(realm.get("pop",3))
    var total_demand: float = 0.0
    for b in buildings:
        total_demand += _demand(b, recipes.get(b.get("type",""),{}))
    var ratio: float = minf(1.0,pop/total_demand) if total_demand > 0.0 else 0.0
    var employed: float = 0.0
    var cargo: Array = []
    # Mirror tickEconomy: run every workplace before unloading any cargo.
    for b in buildings:
        var d: Dictionary = recipes.get(b.get("type",""),{})
        var need: float = _demand(b,d)
        var assigned: float = need * ratio
        var efficiency: float = pow(minf(1.0,maxf(0.0,assigned/need)),0.85) if need > 0.0 else 1.0
        b["assigned"] = assigned
        b["efficiency"] = efficiency
        employed += assigned
        if bool(b.get("disabled",false)) or (need > 0.0 and assigned <= 0.0):
            continue
        var work_dt: float = DT * efficiency
        if not bool(b.get("ready",false)):
            b["progress"] = float(b.get("progress",0)) + work_dt
            if float(b["progress"]) + 0.00000001 >= float(d.get("time",0)):
                b["ready"] = true
            continue
        if not d.has("out"):
            continue
        # On spatial-enabled capitals, lumber and quarry receive stock ONLY
        # when 3D workers deliver finite tree/stone cargo to the workshop.
        if state.has("detail_sim") and String(b.get("type","")) in ["lumber","quarry"]:
            continue
        var input: Dictionary = d.get("input",{})
        if not input.is_empty() and not can_afford(stock,input):
            continue
        b["timer"] = float(b.get("timer",0)) + work_dt * RESOURCE_MULTIPLIER
        if float(b["timer"]) + 0.00000001 >= float(d.get("cycle",1)):
            b["timer"] = maxf(0.0,float(b["timer"]) - float(d.get("cycle",1)))
            if not input.is_empty():
                spend(stock,input)
            cargo.append({"key":String(d["out"]),"amount":float(d.get("rate",0))})
    realm["employed"] = employed
    # All producers use the local delivery shortcut in the 0.5 single-city model.
    # The upstream reference has all buildings placed at the hall to force immediate delivery.
    for c in cargo:
        var resource_key: String = c["key"]
        stock[resource_key] = float(stock.get(resource_key,0)) + float(c["amount"])
    if state.has("detail_sim"):
        Spatial.tick(state)
    state["time"] = float(state.get("time",0)) + DT
    var cap: float = housing_capacity(buildings)
    var food_need: float = floor(pop * 0.60 * 100.0 + 0.5) / 100.0
    var water_need: float = floor(pop * 0.45 * 100.0 + 0.5) / 100.0
    stock["gold"] = float(stock.get("gold",0)) + pop
    realm["housingCapacity"] = cap
    realm["householdNeed"] = food_need
    realm["foodNeed"] = food_need
    realm["waterNeed"] = water_need
    var food: float = take_food(stock,food_need)
    var water: float = minf(water_need,float(stock.get("water",0)))
    stock["water"] = maxf(0.0,float(stock.get("water",0)) - water)
    var supplied: bool = food + 0.000001 >= food_need and water + 0.000001 >= water_need
    realm["housingShortage"] = not supplied
    var growth: Dictionary = _market_bonus(buildings,stock,pop,int(state.get("age",0)),goods)
    realm["marketFoodVarietiesV137"] = growth["varieties"].size()
    realm["marketFoodBonusV137"] = growth["bonus"]
    var free_housing: float = cap - pop
    var prosperous: float = Logic.prosperous_town_growth({"age":int(state.get("age",0)),"pop":pop,
        "stock":stock,"marketVarieties":growth["varieties"].size(),"housingFree":free_housing})
    var growth_need: float = (2.3 + pop * 0.28) / (maxf(1.0,float(growth["multiplier"])) * maxf(1.0,prosperous))
    realm["growthNeed"] = growth_need
    var progress: float = float(realm.get("growthProgress",0))
    if supplied:
        realm["shortageTurns"] = 0
        if pop < floor(cap):
            var reserves: float = 1.2 if float(stock.get("bread",0)) >= pop*2.0 and float(stock.get("water",0)) >= pop*1.5 else 1.0
            progress += reserves
            if progress >= growth_need:
                progress -= growth_need
                realm["pop"] = int(pop)+1
        else:
            progress = minf(progress,growth_need)
    else:
        progress = maxf(0.0,progress-0.7)
        var shortage: int = int(realm.get("shortageTurns",0))+1
        if shortage >= 3:
            shortage=0
            realm["pop"] = maxi(3,int(minf(cap,pop-1.0)))
        realm["shortageTurns"] = shortage
    realm["growthProgress"] = progress

static func snapshot(state: Dictionary) -> Dictionary:
    var realm: Dictionary = state["realms"][0]
    var stock: Dictionary = realm["resources"]
    var buildings_out: Array = []
    for b in state["buildings"]:
        buildings_out.append({"type":String(b.get("type","")),"ready":bool(b.get("ready",false)),
            "timer":float(b.get("timer",0)),"progress":float(b.get("progress",0)),
            "assigned":float(b.get("assigned",0)),"efficiency":float(b.get("efficiency",0))})
    var picked: Dictionary = {}
    for k in ["bread","grain","flour","water","wood","plank","stone","berries","meat","fish","gold"]:
        picked[k] = float(stock.get(k,0))
    return {"time":float(state.get("time",0)),"pop":float(realm.get("pop",3)),
        "stock":picked,"housing":float(realm.get("housingCapacity",0)),
        "shortage":int(realm.get("shortageTurns",0)),"growthProgress":float(realm.get("growthProgress",0)),
        "growthNeed":float(realm.get("growthNeed",0)),"employed":float(realm.get("employed",0)),
        "marketVarieties":int(realm.get("marketFoodVarietiesV137",0)),
        "marketBonus":float(realm.get("marketFoodBonusV137",0)),"buildings":buildings_out}
