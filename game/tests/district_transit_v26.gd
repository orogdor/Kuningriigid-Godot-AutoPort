extends SceneTree
## 0.26: physically timed door-to-door movement between independent local
## 3D squares, freight custody, real builder supplies and resumed saves.
const Screen=preload("res://content.tscn")
const City=preload("res://scripts/city_sim_v05.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const Freight=preload("res://scripts/freight_v14.gd")
const Access=preload("res://scripts/building_access_v22.gd")

func fail(reason: String) -> void:
    printerr("DISTRICT_TRANSIT_V26 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    if world.is_empty():
        ui.world_view._generate()
        world=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    ui._show_detail(home.x,home.y)
    await process_frame
    var city: Dictionary=ui.city
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=500.0
    stock["stone"]=500.0
    stock["bread"]=5000.0
    stock["water"]=5000.0
    city["realms"][0]["pop"]=18
    var destination: Vector2i=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var candidate: Vector2i=home+delta
        var tile: Dictionary=World.cell(world,candidate.x,candidate.y)
        if tile.is_empty() or not bool(tile.get("land",false)) or String(tile.get("biome",""))=="hills":
            continue
        if Districts.expand(city,world,candidate.x,candidate.y)!="":continue
        Transit.configure(city,world)
        var agent: Dictionary=Transit._new_agent(city,"builder",-1,
            Transit.home_key(city),Vector2(0,20),"",0.0)
        if not Transit._choose_gate(city,agent,Districts.key(candidate)).is_empty():
            destination=candidate
            break
        # No safe seam, undo only the temporary test annex and its charge.
        city.erase("districts_v25")
        city.erase("transport_v26")
        stock["wood"]=500.0
        stock["stone"]=500.0
    if destination.x<0:
        fail("world has no adjacent tile with a safe passable street gate")
        return
    var home_id: String=Transit.home_key(city)
    var next_id: String=Districts.key(destination)
    if not city["transport_v26"]["surfaces"].has(next_id):
        fail("adjacent square lacks a separate 3D terrain/resource record")
        return
    var route: Array[String]=Transit.route(city,home_id,next_id)
    if route.size()!=2 or route[0]!=home_id or route[1]!=next_id:
        fail("two adjacent districts did not form a shared road network")
        return
    if not Transit.route(city,next_id,home_id)==[next_id,home_id]:
        fail("district road was not bidirectional")
        return
    var walker: Dictionary=Transit._new_agent(city,"test",-1,
        home_id,Vector2(0,20),"",0.0)
    var seen_crossing: bool=false
    var ticks: int=0
    var arrived: bool=false
    for turn in range(45):
        ticks+=1
        if walker.has("cross_left"):seen_crossing=true
        if Transit.advance_agent(city,walker,next_id,Vector2(30,-10)):
            arrived=true
            break
    if not arrived or not seen_crossing or ticks<5:
        fail("walker crossed the world tile border without a timed 20m gate")
        return
    if String(walker["district"])!=next_id or walker["route"].size()>0:
        fail("walker did not end on the correct local map at the destination")
        return
    # Load a real annex house. Its materials were already prepaid in City.build
    # and must not be deducted again by district transit.
    ui._show_detail(destination.x,destination.y)
    await process_frame
    if not ui.detail_view.can_build or ui.detail_view.district_id!=next_id:
        fail("annex was not available for local 3D construction")
        return
    var before_count: int=city["buildings"].size()
    ui._build_at("house",30,-10,90)
    await process_frame
    if city["buildings"].size()!=before_count+1:
        fail("did not order an annex house")
        return
    var house_index: int=before_count
    var house: Dictionary=city["buildings"][house_index]
    var after_order_wood: float=float(stock["wood"])
    # Create production at the annex door; the shared warehouse cannot
    # receive any output until a physical wagon has completed its route.
    stock["test_cargo_v26"]=0.0
    Freight.enqueue(city,house_index,"test_cargo_v26",7.0)
    if float(stock["test_cargo_v26"])!=0.0 or not Freight.conserved(city,"test_cargo_v26"):
        fail("annex production appeared immediately or violated cargo conservation")
        return
    var wagon_id: int=-1
    for agent in city["transport_v26"]["agents"]:
        if String(agent.get("role",""))=="wagon":wagon_id=int(agent["id"])
    if wagon_id<0:
        fail("freight failed to spawn a physical inter-district wagon")
        return
    ui.detail_view.refresh_buildings()
    await process_frame
    if ui.detail_view.freight_root.get_node_or_null("DistrictWagon_"+str(wagon_id))==null:
        fail("3D annex did not display a real loaded district goods wagon")
        return
    var delivered: bool=false
    var finished: bool=false
    for n in range(180):
        # The UI's advance button uses City.tick. Skip repeated costly 3D
        # scene rebuilds here; validate visual objects separately above.
        City.tick(city)
        if n%20==0:ui.detail_view.refresh_buildings()
        if not Freight.conserved(city,"test_cargo_v26"):
            fail("produced cargo duplicated or vanished during transport")
            return
        if float(stock["test_cargo_v26"])>=7.0:delivered=true
        if bool(house.get("ready",false)):finished=true
        if delivered and finished:break
    if not delivered or not finished:
        fail("annex goods or prepaid house materials did not reach completion")
        return
    if not is_equal_approx(float(stock["test_cargo_v26"]),7.0):
        fail("warehouse did not receive the exact dispatched amount")
        return
    # Constructor materials are prepaid once, while trip progress takes
    # time and their delivery is tracked separately on the annex building.
    for material in house.get("supply_total",{}):
        if float(house.get("supply_delivered",{}).get(material,0))+0.00001<float(house["supply_total"][material]):
            fail("builder completed a house with unpaid physical materials")
            return
    if float(stock["wood"])>after_order_wood+0.00001:
        fail("builder duplicated prepaid wood")
        return
    if int(city["transport_v26"].get("trips",0))<1:
        fail("no constructor travel was recorded")
        return
    ui._save()
    var reloaded: Dictionary=ui._load_city()
    if not reloaded.has("transport_v26") or not bool(reloaded["buildings"][house_index].get("ready",false)):
        fail("world district agents or built annex were lost on JSON reload")
        return
    if not is_equal_approx(float(reloaded["realms"][0]["resources"]["test_cargo_v26"]),7.0):
        fail("freight ledger changed after save/reload")
        return
    ui._show_world()
    if ui.world_view.map_canvas.city_district_links.size()!=1:
        fail("inter-district road was not present on the strategic atlas")
        return
    var old: Dictionary=ui.city.duplicate(true)
    old.erase("transport_v26")
    if Transit.home_key(old)!="" or not Transit.route(old,"","").is_empty():
        fail("older saves without transit were not backwards compatible")
        return
    print("DISTRICT_TRANSIT_V26 SUCCESS: timed A* gates, visible cart, physical delivery, prepaid builder, freight conservation, JSON save")
    quit(0)
