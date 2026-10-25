extends RefCounted
## 0.15 first *satellite settlement prototype*: it has an independent
## warehouse but not yet a 3D construction map, citizen economy or AI.
## Manual caravans move goods between the capital and the satellite.
const MAX_LOAD: float=20.0
const TRAVEL_TURNS: int=6
const FOUND_COST: Dictionary={"wood":18.0,"stone":8.0}

static func has_outpost(state: Dictionary) -> bool:
    return state.has("trade_v15") and state["trade_v15"] is Dictionary

static func found(state: Dictionary) -> String:
    if has_outpost(state):return "Teine kaubalinn on juba asutatud"
    var capital: Dictionary=state["realms"][0]["resources"]
    for kind in FOUND_COST:
        if float(capital.get(kind,0))<float(FOUND_COST[kind]):
            return "Teise linna asutamiseks on vaja 18 puitu ja 8 kivi"
    for kind in FOUND_COST:
        capital[kind]=float(capital.get(kind,0))-float(FOUND_COST[kind])
    state["trade_v15"]={"version":1,"outpost":{"name":"Teine linn (kaubapunkt)",
        "resources":{"wood":8.0,"stone":2.0,"bread":6.0,"grain":0.0,
            "flour":0.0,"plank":0.0,"water":12.0}},
        "caravans":[],"next_id":0,"delivered":0.0,"trips":0}
    return ""

static func stock(state: Dictionary, place: String) -> Dictionary:
    if place=="capital":return state["realms"][0]["resources"]
    return state["trade_v15"]["outpost"]["resources"]

static func send(state: Dictionary, destination: String, kind: String, quantity: float) -> String:
    if not has_outpost(state):return "Asuta kõigepealt teine linn"
    if destination not in ["capital","outpost"]:return "Tundmatu sihtkoht"
    if kind not in ["wood","stone","plank","bread","grain","flour","water"]:
        return "Seda kaupa veel kaubelda ei saa"
    if quantity<=0.0 or quantity>MAX_LOAD:return "Karavan mahutab kuni 20 ühikut"
    var source: String="outpost" if destination=="capital" else "capital"
    var origin_stock: Dictionary=stock(state,source)
    if float(origin_stock.get(kind,0))<quantity:
        return "Lähtepunktis pole piisavalt kaupa"
    origin_stock[kind]=float(origin_stock.get(kind,0))-quantity
    var trade: Dictionary=state["trade_v15"]
    trade["next_id"]=int(trade["next_id"])+1
    trade["caravans"].append({"id":int(trade["next_id"]),"from":source,"to":destination,
        "kind":kind,"quantity":quantity,"progress":0,"duration":TRAVEL_TURNS})
    return ""

static func tick(state: Dictionary) -> void:
    if not has_outpost(state):return
    var trade: Dictionary=state["trade_v15"]
    var outstanding: Array=[]
    for caravan in trade["caravans"]:
        caravan["progress"]=int(caravan.get("progress",0))+1
        if int(caravan["progress"])<int(caravan.get("duration",TRAVEL_TURNS)):
            outstanding.append(caravan)
            continue
        var dest_stock: Dictionary=stock(state,String(caravan["to"]))
        var kind: String=String(caravan["kind"])
        var quantity: float=float(caravan["quantity"])
        dest_stock[kind]=float(dest_stock.get(kind,0))+quantity
        trade["delivered"]=float(trade.get("delivered",0))+quantity
        trade["trips"]=int(trade.get("trips",0))+1
    trade["caravans"]=outstanding

static func overview(state: Dictionary) -> String:
    if not has_outpost(state):return "Teist linna veel pole (0.15 kaubapunkti prototüüp)."
    var data: Dictionary=state["trade_v15"]
    var outpost: Dictionary=data["outpost"]["resources"]
    return "Teise linna ladu: puit %.0f, kivi %.0f, leib %.0f | Teel %d karavani | Saabunud %d" % [
        float(outpost.get("wood",0)),float(outpost.get("stone",0)),float(outpost.get("bread",0)),
        data["caravans"].size(),int(data.get("trips",0))]
