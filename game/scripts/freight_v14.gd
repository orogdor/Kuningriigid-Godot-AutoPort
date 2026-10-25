extends RefCounted
## AutoPort 0.14: queued factory/farm goods physically travel to the town hall.
## The original 0.5 economy only uses this in an activated 3D capital.
## Unlike v0.8 forest/quarry collection, this transports finished output
## from workplaces and does not re-charge resources or duplicate stock.
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const MAX_HAULERS: int=2
const LOAD_CAPACITY: float=12.0
const WALK_DISTANCE: float=24.0

static func initialize(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    var sim: Dictionary=state["detail_sim"]
    if not sim.has("freight_queue"):sim["freight_queue"]=[]
    if not sim.has("haulers"):sim["haulers"]=[]
    if not sim.has("freight_next_id"):sim["freight_next_id"]=0
    if not sim.has("freight_produced"):sim["freight_produced"]={}
    if not sim.has("freight_delivered"):sim["freight_delivered"]={}
    if not sim.has("freight_trips"):sim["freight_trips"]=0
    sim["version"]=maxi(8,int(sim.get("version",0)))

static func enqueue(state: Dictionary, origin: int, product: String, amount: float) -> void:
    if not state.has("detail_sim") or amount<=0.0:return
    initialize(state)
    var sim: Dictionary=state["detail_sim"]
    if origin<0 or origin>=state.get("buildings",[]).size():return
    sim["freight_queue"].append({"origin":origin,"kind":product,"amount":amount})
    var made: Dictionary=sim["freight_produced"]
    made[product]=float(made.get(product,0))+amount

static func _target(state: Dictionary, origin: int, start: Vector2) -> Vector2:
    if origin<0 or origin>=state.get("buildings",[]).size():return Vector2(99999,99999)
    var b: Dictionary=state["buildings"][origin]
    var center:=Vector2(float(b.get("x",0)),float(b.get("z",0)))
    # Work around buildings (never pathfind through the building's footprint).
    var best:=Vector2(99999,99999)
    var best_dist: float=INF
    for offset in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20),
        Vector2(20,20),Vector2(-20,20),Vector2(20,-20),Vector2(-20,-20)]:
        var candidate: Vector2=center+offset
        if not Paths.bounded(Paths.grid(candidate)):continue
        if Paths.blocked(state,Paths.grid(candidate),0):continue
        if Paths.find_path(state,start,candidate,0).is_empty():continue
        var d: float=start.distance_squared_to(candidate)
        if d<best_dist:
            best_dist=d
            best=candidate
    return best

static func _speed(state: Dictionary, pos: Vector2) -> float:
    var traffic: int=Paths.traffic_strength(state["detail_sim"],Paths.cell_key(Paths.grid(pos)))
    return WALK_DISTANCE*(1.20 if traffic>=Paths.ROAD_THRESHOLD else 1.0)

static func request_inputs(state: Dictionary, origin: int, needed: Dictionary) -> bool:
    if not state.has("detail_sim") or origin<0 or origin>=state["buildings"].size():return false
    initialize(state)
    var stock: Dictionary=state["realms"][0]["resources"]
    for key in needed:
        if float(stock.get(key,0))<float(needed[key]):return false
    var building: Dictionary=state["buildings"][origin]
    if building.has("input_shipment"):return true
    var total: Dictionary={}
    for key in needed:
        var value: float=float(needed[key])
        if value<=0.0:continue
        stock[key]=float(stock.get(key,0))-value
        total[key]=value
        # Materials are reserved ONCE and wait in a physical queue at the hall.
        state["detail_sim"]["freight_queue"].append({"origin":origin,
            "kind":String(key),"amount":value,"direction":"input"})
    building["input_shipment"]={"total":total,"delivered":{}}
    return true

static func inputs_delivered(building: Dictionary) -> bool:
    if not building.has("input_shipment"):return false
    var shipment: Dictionary=building["input_shipment"]
    for key in shipment["total"]:
        if float(shipment["delivered"].get(key,0))+0.000001<float(shipment["total"][key]):
            return false
    return true

static func staffed_count(state: Dictionary) -> int:
    if not state.has("detail_sim"):return 0
    var sim: Dictionary=state["detail_sim"]
    var waiting: bool=not sim.get("freight_queue",[]).is_empty()
    for h in sim.get("haulers",[]):
        if String(h.get("phase","idle"))!="idle":waiting=true
    if not waiting:return 0
    var pop: int=int(state["realms"][0].get("pop",0))
    return mini(MAX_HAULERS,1 if pop<8 else 2)

static func _pick(queue: Array,origin: int,direction: String) -> Dictionary:
    for i in range(queue.size()):
        var q: Dictionary=queue[i]
        if int(q.get("origin",-1))!=origin or String(q.get("direction","output"))!=direction:continue
        var qty: float=minf(LOAD_CAPACITY,float(q.get("amount",0)))
        if qty<=0.0:continue
        var kind: String=String(q["kind"])
        q["amount"]=float(q["amount"])-qty
        if float(q["amount"])<0.000001:queue.remove_at(i)
        return {"kind":kind,"amount":qty}
    return {}

static func _next_job(state: Dictionary,hauler: Dictionary) -> bool:
    var sim: Dictionary=state["detail_sim"]
    var queue: Array=sim["freight_queue"]
    var pos:=Vector2(float(hauler.get("x",0)),float(hauler.get("z",0)))
    for job in queue:
        var origin: int=int(job.get("origin",-1))
        var direction: String=String(job.get("direction","output"))
        if float(job.get("amount",0))<=0.0:continue
        if _target(state,origin,pos).x>1000:continue
        hauler["origin"]=origin
        hauler["route"]=[]
        if direction=="input":
            # Inbound material is picked up from the town hall, not fabricated at the factory.
            var cargo: Dictionary=_pick(queue,origin,"input")
            if cargo.is_empty():continue
            hauler["kind"]=cargo["kind"]
            hauler["load"]=cargo["amount"]
            hauler["phase"]="input_delivery"
        else:
            hauler["kind"]=""
            hauler["load"]=0.0
            hauler["phase"]="outbound"
        return true
    return false

static func _assign(state: Dictionary) -> void:
    var sim: Dictionary=state["detail_sim"]
    var haulers: Array=sim["haulers"]
    var maximum: int=mini(MAX_HAULERS,maxi(0,int(state["realms"][0].get("pop",0))))
    for h in haulers:
        if String(h.get("phase",""))=="idle" and not sim["freight_queue"].is_empty():
            _next_job(state,h)
    while haulers.size()<maximum and not sim["freight_queue"].is_empty():
        sim["freight_next_id"]=int(sim["freight_next_id"])+1
        var worker: Dictionary={"id":int(sim["freight_next_id"]),"x":0.0,"z":0.0,
            "phase":"idle","origin":-1,"kind":"","load":0.0,"route":[]}
        if not _next_job(state,worker):break
        haulers.append(worker)

static func tick(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    initialize(state)
    _assign(state)
    var sim: Dictionary=state["detail_sim"]
    var stock: Dictionary=state["realms"][0]["resources"]
    var queue: Array=sim["freight_queue"]
    for h in sim["haulers"]:
        var phase: String=String(h.get("phase","idle"))
        var current:=Vector2(float(h.get("x",0)),float(h.get("z",0)))
        if phase=="outbound":
            var destination: Vector2=_target(state,int(h.get("origin",-1)),current)
            if destination.x>1000:
                h["phase"]="blocked"
                continue
            if not Paths.move(h,destination,_speed(state,current),state,0):continue
            var cargo: Dictionary=_pick(queue,int(h["origin"]),"output")
            if cargo.is_empty():
                h["phase"]="return_empty"
                h["route"]=[]
                continue
            h["kind"]=cargo["kind"]
            h["load"]=cargo["amount"]
            h["phase"]="returning"
            h["route"]=[]
        elif phase=="returning" or phase=="return_empty":
            if not Paths.move(h,Vector2.ZERO,_speed(state,current),state,0):continue
            if phase=="returning":
                var kind: String=String(h.get("kind",""))
                var amount: float=float(h.get("load",0))
                if kind!="" and amount>0.0:
                    stock[kind]=float(stock.get(kind,0))+amount
                    var delivered: Dictionary=sim["freight_delivered"]
                    delivered[kind]=float(delivered.get(kind,0))+amount
                    sim["freight_trips"]=int(sim["freight_trips"])+1
            h["load"]=0.0
            h["kind"]=""
            h["origin"]=-1
            h["route"]=[]
            h["phase"]="idle"
        elif phase=="input_delivery":
            var idx: int=int(h.get("origin",-1))
            var destination: Vector2=_target(state,idx,current)
            if destination.x>1000:
                h["phase"]="input_blocked"
                continue
            if not Paths.move(h,destination,_speed(state,current),state,0):continue
            if idx>=0 and idx<state["buildings"].size():
                var b: Dictionary=state["buildings"][idx]
                if b.has("input_shipment"):
                    var delivered: Dictionary=b["input_shipment"]["delivered"]
                    var kind: String=String(h.get("kind",""))
                    delivered[kind]=float(delivered.get(kind,0))+float(h.get("load",0))
                    sim["freight_trips"]=int(sim["freight_trips"])+1
            h["kind"]=""
            h["load"]=0.0
            h["phase"]="return_empty"
            h["route"]=[]
        elif phase=="blocked":
            h["phase"]="outbound"
        elif phase=="input_blocked":
            h["phase"]="input_delivery"

static func summary(state: Dictionary) -> Dictionary:
    var sim: Dictionary=state.get("detail_sim",{})
    var waiting: float=0.0
    var moving: float=0.0
    for item in sim.get("freight_queue",[]):
        waiting+=float(item.get("amount",0))
    for h in sim.get("haulers",[]):
        moving+=float(h.get("load",0))
    return {"haulers":sim.get("haulers",[]).size(),"waiting":waiting,
        "in_transit":moving,"trips":int(sim.get("freight_trips",0)),
        "workers":staffed_count(state)}

static func conserved(state: Dictionary, kind: String) -> bool:
    var sim: Dictionary=state.get("detail_sim",{})
    var created: float=float(sim.get("freight_produced",{}).get(kind,0))
    var arrived: float=float(sim.get("freight_delivered",{}).get(kind,0))
    var remaining: float=0.0
    for q in sim.get("freight_queue",[]):
        if String(q.get("direction","output"))=="output" and String(q.get("kind",""))==kind:remaining+=float(q.get("amount",0))
    for h in sim.get("haulers",[]):
        if String(h.get("phase",""))=="returning" and String(h.get("kind",""))==kind:remaining+=float(h.get("load",0))
    return is_equal_approx(created,arrived+remaining)
