extends SceneTree
## 0.17 regression: real traversable world-road, distance-derived travel,
## legacy 6-turn shipments, second-town AI, persistence and UI visualization.
const City=preload("res://scripts/city_sim_v05.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const Roads=preload("res://scripts/world_trade_routes_v17.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Screen=preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("WORLD_TRADE_V17 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var map: Dictionary=World.generate(82026,true)
    var start: Dictionary=map["starts"][0]
    var home:=Vector2i(int(start["c"]),int(start["r"]))
    var site: Dictionary=Roads.choose_site(map,home)
    if site.is_empty():
        fail("no reachable location for a second town")
        return
    var state: Dictionary=City.default_state()
    if Trade.found(state)!="":
        fail("cannot found trade city")
        return
    if not Roads.configure(state,map,start,site):
        fail("could not construct a traversable land route")
        return
    var route: Dictionary=state["trade_v15"]["route_v17"]
    var tiles: Array=route["tiles"]
    if tiles.size()<2 or int(route["distance_tiles"])!=tiles.size()-1:
        fail("route length does not match the plotted path")
        return
    for i in range(tiles.size()):
        var tile: Dictionary=tiles[i]
        if not Roads.passable(map,int(tile["c"]),int(tile["r"])):
            fail("road crosses sea or mountains")
            return
        if i>0:
            var prev: Dictionary=tiles[i-1]
            if absi(int(tile["c"])-int(prev["c"]))+absi(int(tile["r"])-int(prev["r"]))!=1:
                fail("road jumps between nonadjacent tiles")
                return
    var stock: Dictionary=state["realms"][0]["resources"]
    var before: float=float(stock["wood"])
    var satellite: Dictionary=Trade.ensure_city(state)
    var other: Dictionary=satellite["realms"][0]["resources"]
    var other_before: float=float(other["wood"])
    if Trade.send(state,"outpost","wood",5)!="":
        fail("cannot send a route-length caravan")
        return
    var caravan: Dictionary=state["trade_v15"]["caravans"][0]
    var journey: int=int(route["duration"])
    if int(caravan["duration"])!=journey or journey<2:
        fail("caravan duration does not match world-route ETA")
        return
    if float(stock["wood"])!=before-5.0:
        fail("dispatch failed to debit source once")
        return
    for n in range(journey-1):
        City.tick(state)
        if float(other["wood"])!=other_before:
            fail("road caravan arrived before ETA")
            return
    City.tick(state)
    if float(other["wood"])!=other_before+5.0:
        fail("road caravan failed to arrive on ETA")
        return
    # Old in-flight shipments keep six turns even if the new road is built.
    var legacy: Dictionary=City.default_state()
    Trade.found(legacy)
    Trade.send(legacy,"outpost","wood",5)
    var old_journey: int=int(legacy["trade_v15"]["caravans"][0]["duration"])
    if old_journey!=6:
        fail("legacy default travel was altered")
        return
    Roads.configure(legacy,map,start,site)
    if int(legacy["trade_v15"]["caravans"][0]["duration"])!=6:
        fail("new road silently altered existing caravan schedule")
        return
    var capital_wood: float=float(legacy["realms"][0]["resources"]["wood"])
    var town: Dictionary=Trade.ensure_city(legacy)
    var supplies: Dictionary=town["realms"][0]["resources"]
    supplies["wood"]=100.0
    supplies["stone"]=100.0
    supplies["bread"]=600.0
    supplies["water"]=600.0
    legacy["trade_v15"]["ai_enabled"]=true
    for turn in range(45):
        City.tick(legacy)
    var history: Array=town.get("ai_log",[])
    if history.is_empty() or String(history[0]["type"])!="lumber":
        fail("satellite AI did not autonomously order first lumber hut")
        return
    if legacy["buildings"].size()!=1:
        fail("AI accidentally built in capital")
        return
    if float(legacy["realms"][0]["resources"]["wood"])!=capital_wood:
        fail("AI spent capital resources")
        return
    if town["buildings"].size()<2:
        fail("AI failed to add physical worksite")
        return
    var saved: Variant=JSON.parse_string(JSON.stringify(legacy))
    if not saved is Dictionary or saved["trade_v15"]["route_v17"]["tiles"].size()!=tiles.size():
        fail("route / AI history not persisted")
        return
    if not bool(saved["trade_v15"].get("ai_enabled",false)):
        fail("auto-construction setting lost on save")
        return
    # UI integration: 3D satellite, road overlay, manual AI toggle.
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._found_trade_city()
    if not bool(ui.city["trade_v15"].get("ai_enabled",false)):
        fail("second-city AI not enabled for fresh UI settlements")
        return
    if ui.world_view.map_canvas.trade_route.get("tiles",[]).size()<2:
        fail("city link road not drawn on world map")
        return
    ui._trade_send("outpost","wood",5)
    if ui.world_view.map_canvas.trade_caravans.size()!=1:
        fail("caravan marker not synchronized with world map")
        return
    ui._toggle_satellite_ai()
    if bool(ui.city["trade_v15"]["ai_enabled"]):
        fail("AI toggle failed to disable")
        return
    if bool(ui._load_city()["trade_v15"]["ai_enabled"]):
        fail("AI toggle not saved")
        return
    print("WORLD_TRADE_V17 SUCCESS: passable mapped roads, ETA, legacy carriages, independent building AI, UI and persistent route")
    quit(0)
