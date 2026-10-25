extends SceneTree
## 0.15: sawmill inputs must ride from hall to workshop before production.
## Two city warehouse demo caravans travel 6 turns, conserve stocks and save.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Freight=preload("res://scripts/freight_v14.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const View=preload("res://content.tscn")

func fail(msg: String) -> void:
    printerr("LOGISTICS_V15 FAIL: "+msg)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var realm: Dictionary=state["realms"][0]
    realm["pop"]=6
    var stock: Dictionary=realm["resources"]
    stock["wood"]=100.0
    stock["plank"]=0.0
    stock["bread"]=1000.0
    stock["water"]=1000.0
    state["buildings"].append({"type":"saw","team":0,"x":30.0,"z":-10.0,
        "hp":350,"ready":true,"timer":0.0,"progress":0.0})
    City.tick(state)
    var saw: Dictionary=state["buildings"][1]
    if not saw.has("input_shipment"):
        fail("sawmill did not reserve physically transported wood")
        return
    if float(stock["wood"])!=96.0:
        fail("sawmill input was not reserved exactly once at the hall")
        return
    if float(stock["plank"])!=0.0:
        fail("sawmill produced boards before its wood arrived")
        return
    if int(state["detail_sim"].get("version",0))<8:
        fail("spatial freight save schema version did not migrate")
        return
    var saw_delivery: bool=false
    var completed: bool=false
    var haul_labor: bool=false
    for turn in range(25):
        City.tick(state)
        if int(realm.get("freightEmployed",0))>0:
            haul_labor=true
        if saw.has("input_shipment"):
            var shipment: Dictionary=saw["input_shipment"]
            if float(shipment.get("delivered",{}).get("wood",0))>0.0:
                saw_delivery=true
        if float(state["detail_sim"]["freight_produced"].get("plank",0))>0.0:
            completed=true
        if not Freight.conserved(state,"plank"):
            fail("boards duplicated or disappeared in outbound freight")
            return
    if not saw_delivery:
        fail("inbound wood never physically reached sawmill")
        return
    if not completed:
        fail("sawmill failed to produce after wood delivery")
        return
    if not haul_labor:
        fail("active haulers did not consume workforce capacity")
        return
    if float(state["detail_sim"]["freight_delivered"].get("plank",0))<=0:
        fail("outbound boards did not reach the town warehouse")
        return
    if float(stock["plank"])!=float(state["detail_sim"]["freight_delivered"]["plank"]):
        fail("boards credited without a completed trip")
        return
    # The second settlement has a genuinely independent inventory and
    # a time-delayed caravan; it does not have a second construction map yet.
    var second: Dictionary=City.default_state()
    second["realms"][0]["resources"]["bread"]=200.0
    second["realms"][0]["resources"]["water"]=200.0
    if Trade.found(second)!="":
        fail("second settlement prototype cannot be founded")
        return
    var cstock: Dictionary=second["realms"][0]["resources"]
    var other: Dictionary=second["trade_v15"]["outpost"]["resources"]
    var capital_wood: float=float(cstock["wood"])
    var outpost_wood: float=float(other["wood"])
    if Trade.send(second,"outpost","wood",5.0)!="":
        fail("manual caravan was rejected despite sufficient stock")
        return
    if not is_equal_approx(float(cstock["wood"]),capital_wood-5.0) or float(other["wood"])!=outpost_wood:
        fail("caravan was not debited once at origin or arrived instantly")
        return
    for turn in range(5):
        City.tick(second)
    if float(other["wood"])!=outpost_wood:
        fail("caravan arrived before its six-turn journey")
        return
    var persisted: Variant=JSON.parse_string(JSON.stringify(second))
    if not persisted is Dictionary:
        fail("two-town caravan JSON save failed")
        return
    if persisted["trade_v15"]["caravans"].size()!=1:
        fail("in-progress caravan was lost on save")
        return
    City.tick(persisted)
    if float(persisted["trade_v15"]["outpost"]["resources"]["wood"])!=outpost_wood+5.0:
        fail("saved caravan never credited destination")
        return
    if float(persisted["realms"][0]["resources"]["wood"])!=capital_wood-5.0:
        fail("caravan duplicated original town resources")
        return
    if Trade.send(persisted,"capital","wood",5.0)!="":
        fail("return caravan from second town could not be dispatched")
        return
    for turn in range(6):City.tick(persisted)
    if float(persisted["realms"][0]["resources"]["wood"])!=capital_wood:
        fail("return caravan did not restore original capital stock")
        return
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    screen._found_trade_city()
    if not Trade.has_outpost(screen.city):
        fail("UI could not found trade settlement")
        return
    screen._trade_send("outpost","wood",5.0)
    if screen.city["trade_v15"]["caravans"].size()!=1:
        fail("UI caravan action did not create a shipment")
        return
    if screen._load_city()["trade_v15"]["caravans"].size()!=1:
        fail("UI failed to persist new trade route")
        return
    print("LOGISTICS_V15 SUCCESS: inbound goods, hauling employees, outgoing freight, 6-turn two-town trade and saved UI")
    quit(0)
