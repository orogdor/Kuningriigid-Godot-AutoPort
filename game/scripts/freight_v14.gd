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
    sim["version"]=maxi(7,int(sim.get("version",0)))

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

static func _assign(state: Dictionary) -> void:
    var sim: Dictionary=state["detail_sim"]
    var workers: Array=sim["haulers"]
    var queue: Array=sim["freight_queue"]
    if queue.is_empty():return
    var allowed: int=mini(MAX_HAULERS,maxi(1,int(state["realms"][0].get("pop",0))))
    var reserved: Dictionary={}
    for h in workers:
        if int(h.get("origin",-1))>=0 and String(h.get("phase",""))=="outbound":
            reserved[int(h["origin"])]=int(reserved.get(int(h["origin"]),0))+1
    for h in workers:
        if String(h.get("phase",""))!="idle":continue
        for item in queue:
            var origin: int=int(item["origin"])
            if float(item.get("amount",0))<=0.0:continue
            var position:=Vector2(float(h["x"]),float(h["z"]))
            if _target(state,origin,position).x>1000:continue
            h["origin"]=origin
            h["phase"]="outbound"
            h["route"]=[]
            reserved[origin]=int(reserved.get(origin,0))+1
            break
    while workers.size()<allowed:
        var chosen: int=-1
        for item in queue:
            if float(item.get("amount",0))<=0.0:continue
            var origin: int=int(item["origin"])
            if int(reserved.get(origin,0))>=allowed:continue
            if _target(state,origin,Vector2.ZERO).x>1000:continue
            chosen=origin
            break
        if chosen<0:break
        sim["freight_next_id"]=int(sim["freight_next_id"])+1
        workers.append({"id":int(sim["freight_next_id"]),"x":0.0,"z":0.0,
            "phase":"outbound","origin":chosen,"kind":"","load":0.0,"route":[]})
        reserved[chosen]=int(reserved.get(chosen,0))+1

static func _pickup(queue: Array,origin: int) -> Dictionary:
    for i in range(queue.size()):
        var item: Dictionary=queue[i]
        if int(item["origin"])!=origin or float(item["amount"])<=0.0:continue
        var qty: float=minf(LOAD_CAPACITY,float(item["amount"]))
        var kind: String=String(item["kind"])
        item["amount"]=float(item["amount"])-qty
        if float(item["amount"])<=0.000001:queue.remove_at(i)
        return {"kind":kind,"amount":qty}
    return {}

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
            var freight: Dictionary=_pickup(queue,int(h["origin"]))
            if freight.is_empty():
                h["phase"]="idle"
                h["origin"]=-1
                h["route"]=[]
                continue
            h["kind"]=freight["kind"]
            h["load"]=freight["amount"]
            h["phase"]="returning"
            h["route"]=[]
        elif phase=="returning":
            if not Paths.move(h,Vector2.ZERO,_speed(state,current),state,0):continue
            var kind: String=String(h.get("kind",""))
            var load: float=float(h.get("load",0))
            if kind!="" and load>0.0:
                stock[kind]=float(stock.get(kind,0))+load
                var delivered: Dictionary=sim["freight_delivered"]
                delivered[kind]=float(delivered.get(kind,0))+load
                sim["freight_trips"]=int(sim["freight_trips"])+1
            h["load"]=0.0
            h["kind"]=""
            h["origin"]=-1
            h["route"]=[]
            h["phase"]="idle"
        elif phase=="blocked":
            h["phase"]="outbound" # Re-evaluate access after new bridges/roads.
    sim["haulers"]=sim["haulers"]

static func summary(state: Dictionary) -> Dictionary:
    var sim: Dictionary=state.get("detail_sim",{})
    var waiting: float=0.0
    var moving: float=0.0
    for item in sim.get("freight_queue",[]):
        waiting+=float(item.get("amount",0))
    for h in sim.get("haulers",[]):
        moving+=float(h.get("load",0))
    return {"haulers":sim.get("haulers",[]).size(),"waiting":waiting,
        "in_transit":moving,"trips":int(sim.get("freight_trips",0))}

static func conserved(state: Dictionary, kind: String) -> bool:
    var sim: Dictionary=state.get("detail_sim",{})
    var created: float=float(sim.get("freight_produced",{}).get(kind,0))
    var arrived: float=float(sim.get("freight_delivered",{}).get(kind,0))
    var remaining: float=0.0
    for q in sim.get("freight_queue",[]):
        if String(q.get("kind",""))==kind:remaining+=float(q.get("amount",0))
    for h in sim.get("haulers",[]):
        if String(h.get("kind",""))==kind:remaining+=float(h.get("load",0))
    return is_equal_approx(created,arrived+remaining)
