extends SceneTree
## v0.16: two actual cities share original source rules, but not stores,
## citizens, workers or build plots. Both render on separate world tiles.
const City = preload("res://scripts/city_sim_v05.gd")
const Trade = preload("res://scripts/two_city_trade_v15.gd")
const View = preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("SATELLITE_V16 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var state: Dictionary=City.default_state()
    if Trade.found(state)!="":
        fail("founding second town failed")
        return
    var satellite: Dictionary=Trade.ensure_city(state)
    if satellite["buildings"].size()!=1 or int(satellite["realms"][0]["pop"])!=3:
        fail("second city did not start with hall and own three inhabitants")
        return
    var old_stock: Dictionary=state["realms"][0]["resources"]
    var new_stock: Dictionary=satellite["realms"][0]["resources"]
    var outpost_before: float=float(new_stock.get("wood",0))
    if not is_equal_approx(outpost_before,8.0):
        fail("founding minted supplies instead of preserving 0.15 warehouse")
        return
    new_stock["bread"]=150.0
    new_stock["water"]=150.0
    var capital_pop: int=int(state["realms"][0]["pop"])
    var outpost_time: float=float(satellite["time"])
    var main_time: float=float(state["time"])
    for t in range(12):City.tick(state)
    if satellite["time"]!=outpost_time+12.0*City.DT or state["time"]!=main_time+12.0*City.DT:
        fail("both cities did not advance exactly one minute per game turn")
        return
    if int(satellite["realms"][0]["pop"])<=3:
        fail("independent satellite population never grew with ample food and water")
        return
    if int(state["realms"][0]["pop"])<capital_pop:
        fail("satellite economy damaged capital population")
        return
    if Trade.send(state,"outpost","wood",15.0)!="":
        fail("could not ship missing construction wood to new town")
        return
    var after_send: float=float(old_stock["wood"])
    for t in range(5):City.tick(state)
    if not is_equal_approx(float(new_stock["wood"]),outpost_before):
        fail("intercity wood appeared before caravan arrived")
        return
    City.tick(state)
    if not is_equal_approx(float(new_stock["wood"]),outpost_before+15):
        fail("intercity wood failed to reach actual satellite economy warehouse")
        return
    if not is_equal_approx(float(old_stock["wood"]),after_send):
        fail("wood was subtracted twice or returned to origin")
        return
    # Verify that a satellite construction spends only the satellite's stock.
    var capital_wood: float=float(old_stock["wood"])
    satellite["pending_site"]={"x":30.0,"z":-10.0}
    if City.build(satellite,"lumber")!="":
        fail("satellite could not build independent lumber hut")
        return
    if state["buildings"].size()!=1 or satellite["buildings"].size()!=2:
        fail("satellite construction was incorrectly added to capital")
        return
    if not is_equal_approx(float(old_stock["wood"]),capital_wood):
        fail("satellite construction spent capital stock")
        return
    for t in range(35):
        if bool(satellite["buildings"][1]["ready"]):break
        City.tick(state)
    if not bool(satellite["buildings"][1]["ready"]):
        fail("satellite worker crew could not finish lumber construction")
        return
    var serialized: Variant=JSON.parse_string(JSON.stringify(state))
    if not serialized is Dictionary:
        fail("two-city save cannot be read as JSON")
        return
    var recovered: Dictionary=Trade.ensure_city(serialized)
    if not is_equal_approx(float(recovered["realms"][0]["resources"]["wood"]),
        float(satellite["realms"][0]["resources"]["wood"])):
        fail("satellite local stock disappeared in saved game")
        return
    if recovered["buildings"].size()!=2:
        fail("satellite buildings disappeared after save/reload")
        return
    if int(recovered["realms"][0]["pop"])!=int(satellite["realms"][0]["pop"]):
        fail("satellite population not persisted")
        return
    # Legacy v0.15 trading-post-only saves migrate without adding resources.
    var old: Dictionary=City.default_state()
    Trade.found(old)
    old["trade_v15"]["outpost"].erase("city")
    old["trade_v15"]["version"]=1
    var stock_before: float=float(old["trade_v15"]["outpost"]["resources"]["wood"])
    var migrated: Dictionary=Trade.ensure_city(old)
    if not is_equal_approx(float(migrated["realms"][0]["resources"]["wood"]),stock_before):
        fail("legacy outpost migration minted or erased items")
        return
    # The actual UI must open a second physical 3D map with its own hall.
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    screen._found_trade_city()
    screen._open_satellite()
    await process_frame
    if screen.detail_town!="outpost" or not screen.detail_view.can_build:
        fail("3D screen did not open second city as buildable")
        return
    var second_hall: Node=screen.detail_view.construction_root.get_node_or_null("hall_0")
    if second_hall==null:
        fail("independent second-city town hall missing from 3D world")
        return
    var location: Dictionary=screen.city["trade_v15"].get("position",{})
    if location.is_empty():
        fail("second city did not receive stable separate world coordinates")
        return
    var original: Dictionary=screen.world_view.world["starts"][0]
    if int(location["c"])==int(original["c"]) and int(location["r"])==int(original["r"]):
        fail("two city details overlapped the same world tile")
        return
    screen._advance(1)
    await process_frame
    if float(Trade.ensure_city(screen.city)["time"])<=0:
        fail("second city did not simulate when advancing from its detail map")
        return
    if not FileAccess.file_exists("user://autoport_city_v05.json"):
        fail("two-city game did not persist")
        return
    print("SATELLITE_V16 SUCCESS: independent production population, construction, 3D world tile, caravans, save and v0.15 migration")
    quit(0)
