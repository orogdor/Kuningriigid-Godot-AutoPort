extends SceneTree
## 0.37: bronze AI priorities, source recipe outputs, age gates,
## 3D model distinctions, working phone toolbar, and save compatibility.
const City=preload("res://scripts/city_sim_v05.gd")
const Plan=preload("res://scripts/bronze_city_ai_v37.gd")
const Research=preload("res://scripts/research_v35.gd")
const Unlock=preload("res://scripts/building_unlocks_v36.gd")
const Screen=preload("res://content.tscn")
const Districts=preload("res://scripts/world_districts_v25.gd")

func fail(message: String) -> void:
    printerr("BRONZE_CITY_V37 FAIL: "+message)
    quit(1)

func ready(type: String,x: float=0.0,z: float=0.0) -> Dictionary:
    return {"type":type,"team":0,"x":x,"z":z,"hp":350,
        "ready":true,"progress":10000.0,"timer":0.0}

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var source: Dictionary=City.definitions()
    var town: Dictionary=City.default_state()
    town["age"]=1
    town["satellite_town"]=true
    town["realms"][0]["pop"]=7
    var stock: Dictionary=town["realms"][0]["resources"]
    for key in ["wood","stone","plank","bread","water"]:
        stock[key]=1000.0
    Research.ensure(town)
    var research: Dictionary=town["research_v35"]
    for id in ["bronze","stone_tools","water","agriculture","woodworking",
            "storage","commerce","cellaring","milling"]:
        research["known"].append(id)
    town["buildings"]=[ready("hall")]
    if Plan.choose(town,source)!="lumber":
        fail("AI did not prioritize first wood supply")
        return
    town["buildings"].append(ready("lumber",-25,-25))
    if Plan.choose(town,source)!="well":
        fail("AI did not prioritize water after wood")
        return
    town["buildings"].append(ready("well",25,-25))
    for i in range(3):
        town["buildings"].append(ready("house",25+float(i)*12,0))
    town["buildings"].append(ready("quarry",-25,25))
    town["buildings"].append(ready("farm",25,25))
    var expected: Array[String]=["saw","warehouse","market","vegetable_garden","cellar"]
    for kind in expected:
        var actual: String=Plan.choose(town,source)
        if actual!=kind:
            fail("expected researched Bronze service "+kind+", got "+actual)
            return
        town["buildings"].append(ready(kind,0.0,float(town["buildings"].size())*15.0))
    if Plan.choose(town,source)!="house":
        fail("after core facilities the Bronze city failed to grow residences")
        return
    # The planner must not bypass the science gate even when materials are free.
    research["known"].erase("commerce")
    town["buildings"]=town["buildings"].filter(func(b):return b.get("type","")!="market")
    if Plan.choose(town,source)=="market" or Unlock.allowed(town,"market"):
        fail("market can be planned without commerce research")
        return
    research["known"].append("commerce")
    if Plan.choose(town,source)!="market":
        fail("market did not become eligible again after research")
        return
    # Real researched output: the upstream garden recipe produces vegetables
    # during Godot economy ticks; it is not just a decorative building.
    town["buildings"].append(ready("market"))
    var pre: float=float(stock.get("vegetables",0.0))
    for i in range(25):
        City.tick(town)
    if float(stock.get("vegetables",0.0))<=pre:
        fail("Bronze vegetable garden has no working production")
        return
    var restored: Variant=JSON.parse_string(JSON.stringify(town))
    if not restored is Dictionary:
        fail("Bronze town save roundtrip failed")
        return
    if Plan.counts(restored).get("vegetable_garden",0)!=1:
        fail("Bronze town save lost its garden")
        return
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui.city["age"]=1
    Research.ensure(ui.city)["known"]=research["known"].duplicate()
    var storage: Dictionary=ui.city["realms"][0]["resources"]
    storage["wood"]=1000.0
    storage["stone"]=1000.0
    storage["plank"]=1000.0
    for i in range(ui.city["buildings"].size()):
        if i==0:continue
    ui.city["buildings"].append(ready("lumber",-25,-25))
    ui.city["buildings"].append(ready("house",30,0))
    ui.city["buildings"].append(ready("saw",-30,20))
    ui.city["buildings"].append(ready("warehouse",30,30))
    ui.city["buildings"].append(ready("market",-30,-25))
    ui.city["buildings"].append(ready("cellar",0,40))
    ui.city["buildings"].append(ready("vegetable_garden",35,-40))
    var origin: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(origin.x,origin.y)
    await process_frame
    var root3d: Node3D=ui.detail_view.construction_root
    var models: Dictionary={
        "saw_3":"SawBench",
        "warehouse_4":"WarehouseDoor",
        "market_5":"MarketStall",
        "cellar_6":"CellarDoor",
        "vegetable_garden_7":"GardenBed"
    }
    for holder in models.keys():
        var building: Node3D=root3d.get_node_or_null(holder) as Node3D
        if building==null or building.get_node_or_null(String(models[holder]))==null:
            fail("missing distinct Bronze 3D model "+holder)
            return
    if not ui.detail_view._can_build("saw") or not ui.detail_view._can_build("vegetable_garden"):
        fail("3D toolbar cannot build researched Bronze buildings")
        return
    var found_saw: bool=false
    for btn in ui.detail_view.actions.get_children():
        if btn is Button and String(btn.text)=="Ehita saw":found_saw=true
    if not found_saw:
        fail("Bronze workshop not accessible from mobile toolbar")
        return
    print("BRONZE_CITY_V37 SUCCESS: researched AI progression, growing houses, real vegetable production, 5 distinct 3D buildings, 3D build menu and save")
    quit(0)
