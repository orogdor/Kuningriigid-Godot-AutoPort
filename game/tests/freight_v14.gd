extends SceneTree
## AutoPort 0.14: physical farm/sawmill freight must not credit stock
## until carried home. Verify path/road use, multiple goods, save & 3D cart.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Freight = preload("res://scripts/freight_v14.gd")
const View = preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("FREIGHT_V14 FAIL: "+message)
    quit(1)

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    Freight.initialize(state)
    var stock: Dictionary=state["realms"][0]["resources"]
    stock["bread"]=2000.0
    stock["water"]=2000.0
    stock["grain"]=0.0
    state["buildings"].append({"type":"farm","team":0,"x":30.0,"z":-10.0,
        "hp":350,"ready":true,"timer":0.0,"progress":0.0})
    var before: float=float(stock.get("grain",0))
    City.tick(state)
    var sim: Dictionary=state["detail_sim"]
    if int(sim.get("version",0))<7:
        fail("v0.14 saved freight schema missing")
        return
    if not Freight.conserved(state,"grain"):
        fail("farm output duplicated or lost on first dispatch")
        return
    if not is_equal_approx(float(stock["grain"]),before):
        fail("production appeared in warehouse before cart returned")
        return
    if sim["haulers"].is_empty() or Freight.summary(state)["in_transit"]<=0.0:
        fail("no physical cart picked up initial farm harvest")
        return
    for turn in range(20):
        City.tick(state)
        if not Freight.conserved(state,"grain"):
            fail("grain was destroyed or duplicated in transit on turn %d" % turn)
            return
    var delivered: float=float(sim["freight_delivered"].get("grain",0))
    if delivered<=0.0:
        fail("farm goods never reached the town hall")
        return
    if not is_equal_approx(float(stock["grain"]),before+delivered):
        fail("warehouse differs from goods delivered by cart")
        return
    if sim["freight_queue"].size()<1:
        fail("test production did not sustain a physical freight queue")
        return
    # Existing walkways increase movement speed; the same route-usage
    # tracking is shared by workers and freight carts.
    var plain_speed: float=Freight._speed(state,Vector2.ZERO)
    var cell: Vector2i=Paths.grid(Vector2.ZERO)
    for n in range(4):Paths.touch(sim,cell)
    var road_speed: float=Freight._speed(state,Vector2.ZERO)
    if road_speed<=plain_speed:
        fail("established footpaths did not speed up loaded transport")
        return
    # Add a processing-workshop shipment with a different product and
    # ensure it can coexist with agricultural output.
    state["buildings"].append({"type":"saw","team":0,"x":-30.0,"z":-10.0,
        "hp":350,"ready":true,"timer":0.0,"progress":0.0})
    stock["wood"]=500.0
    for turn in range(30):
        City.tick(state)
        if not Freight.conserved(state,"plank"):
            fail("planks not conserved between sawmill and town hall")
            return
    if float(sim["freight_produced"].get("plank",0))<=0:
        fail("sawmill never dispatched processed materials")
        return
    var save: Variant=JSON.parse_string(JSON.stringify(state))
    if not save is Dictionary:
        fail("freight in-transit state cannot be serialized")
        return
    Freight.initialize(save)
    if not Freight.conserved(save,"grain") or not Freight.conserved(save,"plank"):
        fail("saved cargo/queues were lost during reload")
        return
    var old: Dictionary=City.default_state()
    Spatial.initialize(old)
    old["detail_sim"]["version"]=6
    Freight.initialize(old)
    if int(old["detail_sim"]["version"])!=7 or old["detail_sim"]["haulers"].size()!=0:
        fail("v0.13 save migrated with bogus deliveries")
        return
    # An actual 3D viewport, with a truck/cart containing visible cargo.
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    screen.city["realms"][0]["resources"]["bread"]=2000.0
    screen.city["buildings"].append({"type":"farm","team":0,"x":30.0,"z":-10.0,
        "hp":350,"ready":true,"timer":0.0,"progress":0.0})
    var start: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(start["c"]),int(start["r"]))
    screen._advance(1)
    await process_frame
    var vehicles: Node3D=screen.detail_view.freight_root
    if vehicles==null or vehicles.get_node_or_null("GoodsWagon_1")==null:
        fail("visible freight wagon not placed in Godot scene")
        return
    if vehicles.get_node("GoodsWagon_1").get_node_or_null("VisibleGoodsCargo")==null:
        fail("transport unit did not show physical cargo")
        return
    if not FileAccess.file_exists("user://autoport_city_v05.json"):
        fail("transporting goods prevented city saving")
        return
    print("FREIGHT_V14 SUCCESS: farm and sawmill freight, road bonus, finite carts, conservation, JSON migration and visual wagon")
    quit(0)

func _initialize() -> void:
    call_deferred("_test")
