extends SceneTree
## AutoPort 0.13: finite crews must honor priority, preserve in-transit
## prepaid cargo, carry arbitrary non-food goods and survive save/reload.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Logistics = preload("res://scripts/construction_v12.gd")
const Scheduler = preload("res://scripts/construction_scheduler_v13.gd")
const View = preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("CONSTRUCTION_V13 FAIL: "+reason)
    quit(1)

func worker_count(sim: Dictionary, index: int) -> int:
    var count: int=0
    for w in sim.get("builders",[]):
        if int(w.get("building",-1))==index:count+=1
    return count

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    state["pending_site"]={"x":30,"z":-10}
    if City.build(state,"house")!="":
        fail("cannot order first project")
        return
    state["pending_site"]={"x":-30,"z":-10}
    if City.build(state,"well")!="":
        fail("cannot order second project")
        return
    if not Scheduler.change_priority(state,2,"high") or not Scheduler.change_priority(state,1,"low"):
        fail("priorities could not be changed")
        return
    if Scheduler.change_priority(state,1,"urgent"):
        fail("invalid priority unexpectedly accepted")
        return
    City.tick(state)
    var sim: Dictionary=state["detail_sim"]
    if worker_count(sim,2)!=2 or worker_count(sim,1)!=1:
        fail("three workers not correctly allocated high=2, low=1")
        return
    if sim["builders"].size()>int(state["realms"][0]["pop"]):
        fail("builder actors exceed available population")
        return
    if int(sim.get("version",0))<6:
        fail("spatial construction schema not upgraded")
        return
    var safe_positions: Dictionary={}
    var carried: Dictionary={}
    for worker in sim["builders"]:
        safe_positions[int(worker["id"])]=Vector2(float(worker["x"]),float(worker["z"]))
        if float(worker.get("cargo_amount",0))>0.0:
            carried[int(worker["id"])]=int(worker["building"])
    Scheduler.change_priority(state,1,"high")
    Scheduler.change_priority(state,2,"low")
    City.tick(state)
    for worker in sim["builders"]:
        var wid: int=int(worker["id"])
        if carried.has(wid) and int(worker.get("building",-1))!=carried[wid] and float(worker.get("cargo_amount",0))>0:
            fail("in-flight materials moved to a different project")
            return
        if not safe_positions.has(wid):
            fail("reassignment unnecessarily spawned an extra builder")
            return
        if Vector2(float(worker["x"]),float(worker["z"])).distance_to(safe_positions[wid])>25.0:
            fail("reassigned worker teleported to a new construction site")
            return
    for i in range(70):
        if bool(state["buildings"][1]["ready"]) and bool(state["buildings"][2]["ready"]):
            break
        City.tick(state)
    if not bool(state["buildings"][1]["ready"]) or not bool(state["buildings"][2]["ready"]):
        fail("multiple projects never finished using shared crew")
        return
    if sim["builders"].size()>3:
        fail("new workers were created instead of reusing the existing crew")
        return
    var supply_conserved: bool=true
    for idx in [1,2]:
        var b: Dictionary=state["buildings"][idx]
        for material in Logistics.reserved(b):
            if not is_equal_approx(float(b["supply_total"][material]),float(b["supply_delivered"].get(material,0))):
                supply_conserved=false
    if not supply_conserved:
        fail("paid materials were lost or duplicated across projects")
        return
    # A fabricated non-food material cost demonstrates the generic freight
    # interface independently of the historical source's limited 13 recipes.
    var extra: Dictionary=City.default_state()
    Spatial.initialize(extra)
    extra["buildings"].append({"type":"house","team":0,"x":30.0,"z":-10.0,"hp":350,
        "ready":false,"progress":0.0,"timer":0.0,
        "supply_total":{"iron":6.0,"cloth":4.0},"supply_delivered":{},
        "priority":"high"})
    if Logistics.reserved(extra["buildings"][1]).size()!=2:
        fail("nonwood materials were not registered as freight")
        return
    for turn in range(30):
        if bool(extra["buildings"][1]["ready"]):break
        City.tick(extra)
    if not bool(extra["buildings"][1]["ready"]):
        fail("multi-good delivery did not unblock construction")
        return
    if not is_equal_approx(float(extra["buildings"][1]["supply_delivered"].get("iron",0)),6.0) or not is_equal_approx(float(extra["buildings"][1]["supply_delivered"].get("cloth",0)),4.0):
        fail("generic goods never reached the work site")
        return
    var json: Variant=JSON.parse_string(JSON.stringify(state))
    if not json is Dictionary:
        fail("priorities/workforce state could not be saved")
        return
    Logistics.initialize(json)
    Scheduler.initialize(json)
    if String(json["buildings"][1].get("priority",""))!="high" or String(json["buildings"][2].get("priority",""))!="low":
        fail("priority was lost after save/reload")
        return
    # Old 0.12 saves without any priorities retain all pre-paid stock.
    var old: Dictionary=City.default_state()
    Spatial.initialize(old)
    old["pending_site"]={"x":30,"z":-10}
    City.build(old,"house")
    var stock: float=float(old["realms"][0]["resources"]["wood"])
    old["detail_sim"]["version"]=5
    old["buildings"][1].erase("priority")
    Scheduler.initialize(old)
    if String(old["buildings"][1].get("priority",""))!="normal" or float(old["realms"][0]["resources"]["wood"])!=stock:
        fail("migration from 0.12 changed paid stock or priority")
        return
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var home: Dictionary=screen.world_view.world["starts"][0]
    screen._show_detail(int(home["c"]),int(home["r"]))
    screen._build_at("house",30,-10)
    screen._change_priority(1,"high")
    await process_frame
    if String(screen.city["buildings"][1].get("priority",""))!="high":
        fail("3D UI could not change priority")
        return
    if String(screen._load_city()["buildings"][1].get("priority",""))!="high":
        fail("3D priority setting did not persist")
        return
    print("CONSTRUCTION_V13 SUCCESS: priority allocation, cargo safety, generic freight, multi-project crews, 3D UI and save migration")
    quit(0)
