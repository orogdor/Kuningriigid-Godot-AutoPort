extends RefCounted
## AutoPort 0.12: multi-crew construction and delivery of prepaid materials.
## All logistics is optional and runs only for the capital with detail_sim.
## The build cost remains deducted ONCE in City.build; workers move those
## already-reserved resources from town hall to a construction site.
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Old = preload("res://scripts/construction_v11.gd")
const Scheduler = preload("res://scripts/construction_scheduler_v13.gd")
const MAX_CREW_PER_SITE: int=2
const LOAD_LIMIT: float=10.0
const WALK_SPEED: float=24.0

static func initialize(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    Old.initialize(state)
    var sim: Dictionary=state["detail_sim"]
    for site in state.get("buildings",[]):
        if bool(site.get("ready",false)):continue
        # Earlier saves paid for these buildings when ordered; upgrading
        # must not re-charge or freeze their partially completed progress.
        if not site.has("supply_total"):
            site["supply_total"]={}
            site["supply_delivered"]={}
    for worker in sim.get("builders",[]):
        if not worker.has("cargo_kind"):worker["cargo_kind"]=""
        if not worker.has("cargo_amount"):worker["cargo_amount"]=0.0
        if not worker.has("route"):worker["route"]=[]
        if String(worker.get("phase","")) in ["walking","building","waiting_for_workers","no_route"]:
            worker["phase"]="to_site"
    sim["version"]=maxi(5,int(sim.get("version",0)))

static func reserved(building: Dictionary) -> Dictionary:
    var result: Dictionary={}
    # Unlike v0.12, every prepaid non-food construction good can now be
    # delivered. Food costs are consumed when the order is placed.
    var all_materials: Dictionary=building.get("supply_total",{})
    for key in all_materials.keys():
        if float(all_materials[key])>0.0:
            result[key]=float(all_materials[key])
    return result

static func delivered(building: Dictionary, key: String) -> float:
    return float(building.get("supply_delivered",{}).get(key,0.0))

static func fully_supplied(building: Dictionary) -> bool:
    for key in reserved(building):
        if delivered(building,key)+0.00001<float(building["supply_total"][key]):
            return false
    return true

static func _in_flight(sim: Dictionary, building_index: int, kind: String) -> float:
    var total: float=0.0
    for worker in sim.get("builders",[]):
        if int(worker.get("building",-1))==building_index and String(worker.get("cargo_kind",""))==kind:
            total+=float(worker.get("cargo_amount",0.0))
    return total

static func _remaining_to_load(state: Dictionary, building_index: int) -> Dictionary:
    var site: Dictionary=state["buildings"][building_index]
    var sim: Dictionary=state["detail_sim"]
    var remaining: Dictionary={}
    for key in reserved(site):
        var amount: float=float(site["supply_total"][key])-delivered(site,key)-_in_flight(sim,building_index,key)
        if amount>0.00001:remaining[key]=amount
    return remaining

static func _idle(worker: Dictionary) -> void:
    worker["building"]=-1
    worker["phase"]="idle"
    worker["route"]=[]
    worker["target_x"]=99999.0
    worker["target_z"]=99999.0
    worker["cargo_kind"]=""
    worker["cargo_amount"]=0.0

static func _assign(state: Dictionary) -> void:
    Scheduler.assign(state)

static func _approach(state: Dictionary, worker: Dictionary, building: Dictionary) -> Vector2:
    var center:=Vector2(float(building.get("x",0)),float(building.get("z",0)))
    var current:=Vector2(float(worker.get("x",0)),float(worker.get("z",0)))
    var candidate:=Vector2(99999.0,99999.0)
    var best: float=INF
    for dx in [-20.0,0.0,20.0]:
        for dz in [-20.0,0.0,20.0]:
            if dx==0.0 and dz==0.0:continue
            var position:=center+Vector2(dx,dz)
            if not Paths.bounded(Paths.grid(position)) or Paths.blocked(state,Paths.grid(position),0):
                continue
            if Paths.find_path(state,current,position,0).is_empty():continue
            var score: float=current.distance_to(position)
            if score<best:
                best=score
                candidate=position
    return candidate

static func _move(worker: Dictionary, position: Vector2, state: Dictionary, effort: float) -> bool:
    if absf(position.x)>1000:return false
    return Paths.move(worker,position,WALK_SPEED*maxf(0.3,effort),state,0)

static func _deposit(worker: Dictionary, site: Dictionary, sim: Dictionary) -> void:
    var key: String=String(worker.get("cargo_kind",""))
    var qty: float=float(worker.get("cargo_amount",0.0))
    if key!="" and qty>0:
        var existing: Dictionary=site.get("supply_delivered",{})
        existing[key]=minf(float(site.get("supply_total",{}).get(key,0)),float(existing.get(key,0))+qty)
        site["supply_delivered"]=existing
        sim["construction_delivered"]=float(sim.get("construction_delivered",0))+qty
    worker["cargo_kind"]=""
    worker["cargo_amount"]=0.0
    worker["route"]=[]

static func tick(state: Dictionary, specs: Dictionary) -> void:
    if not state.has("detail_sim"):return
    initialize(state)
    _assign(state)
    var sim: Dictionary=state["detail_sim"]
    var buildings: Array=state["buildings"]
    for worker in sim["builders"]:
        var idx: int=int(worker.get("building",-1))
        if idx<0 or idx>=buildings.size():continue
        var b: Dictionary=buildings[idx]
        if bool(b.get("ready",false)) or float(b.get("hp",0))<=0:continue
        var efficiency: float=clampf(float(b.get("efficiency",0.0)),0.0,1.0)
        if efficiency<=0 or float(b.get("assigned",0))<=0:
            worker["phase"]="waiting_for_workers"
            continue
        var phase: String=String(worker.get("phase","to_hall"))
        var pos:=Vector2(float(worker.get("x",0)),float(worker.get("z",0)))
        # Hall is a permitted A* origin; the path planner ignores its
        # collision hull only for these resident construction crews.
        if phase=="to_hall":
            if not _move(worker,Vector2.ZERO,state,efficiency):continue
            worker["phase"]="loading"
            phase="loading"
        if phase=="loading":
            var available: Dictionary=_remaining_to_load(state,idx)
            if available.is_empty():
                worker["phase"]="to_site"
            else:
                var kind: String=String(available.keys()[0])
                worker["cargo_kind"]=kind
                worker["cargo_amount"]=minf(LOAD_LIMIT,float(available[kind]))
                worker["phase"]="to_site"
                worker["route"]=[]
            phase="to_site"
        if phase=="to_site" or phase=="working" or phase=="waiting_material":
            var site_position: Vector2=_approach(state,worker,b)
            if absf(site_position.x)>1000:
                worker["phase"]="no_route"
                continue
            if not _move(worker,site_position,state,efficiency):
                worker["phase"]="to_site"
                continue
            if float(worker.get("cargo_amount",0))>0:
                _deposit(worker,b,sim)
            if not fully_supplied(b):
                if not _remaining_to_load(state,idx).is_empty():
                    worker["phase"]="to_hall"
                else:
                    worker["phase"]="waiting_material"
                continue
            worker["phase"]="working"
            var recipe: Dictionary=specs.get(b.get("type",""),{})
            var duration: float=maxf(1.0,float(recipe.get("time",1.0)))
            # Each extra staffed builder contributes progress without
            # bypassing the real worksite journey or material deliveries.
            var contribution: float=duration/Old.required_turns(recipe)*efficiency
            b["progress"]=minf(duration,float(b.get("progress",0))+contribution)
            if float(b["progress"])+0.00001>=duration:
                b["ready"]=true
                b["progress"]=duration
                worker["phase"]="finished"
                worker["building"]=-1
                worker["route"]=[]

static func report(state: Dictionary) -> Dictionary:
    var sim: Dictionary=state.get("detail_sim",{})
    var construction: int=0
    var in_transit: int=0
    var working: int=0
    var delivered_sum: float=float(sim.get("construction_delivered",0))
    for site in state.get("buildings",[]):
        if not bool(site.get("ready",false)):construction+=1
    for w in sim.get("builders",[]):
        var p: String=String(w.get("phase",""))
        if p in ["to_hall","loading","to_site"]:in_transit+=1
        if p=="working":working+=1
    return {"sites":construction,"in_transit":in_transit,"working":working,
        "delivered":delivered_sum,"builders":sim.get("builders",[]).size()}
