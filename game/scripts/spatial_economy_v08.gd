extends RefCounted
## AutoPort 0.8: optional spatial economy for an actual capital detail tile.
## No change to legacy 0.5 JS parity: this activates only when detail_sim exists.
## Workers walk to finite nearby tree/stone deposits and return to their
## workshop before wood/stone is credited to the same town warehouse.
const STEP: float = 10.0
const WALK_PER_TURN: float = 24.0
const GATHER_AMOUNT: float = 5.0
const HALF_SIZE: float = 78.0
const STARTING_SITES: Array[Vector2] = [
    Vector2(60,-30),Vector2(74,4),Vector2(64,42),Vector2(35,-69),
    Vector2(37,66),Vector2(-58,-42),Vector2(-70,2),Vector2(-62,47),
    Vector2(-38,-68),Vector2(-30,72)
]

static func make_site(kind: String, point: Vector2, index: int) -> Dictionary:
    var amount: float = 35.0 if kind == "wood" else 48.0
    return {"id":index,"kind":kind,"x":point.x,"z":point.y,"remaining":amount}

static func initialize(state: Dictionary) -> void:
    if state.has("detail_sim") and state["detail_sim"] is Dictionary:
        return
    var sites: Array = []
    for i in range(STARTING_SITES.size()):
        sites.append(make_site("wood" if i<5 else "stone",STARTING_SITES[i],i))
    var buildings: Array=state.get("buildings",[])
    for i in range(buildings.size()):
        var building: Dictionary=buildings[i]
        if i==0:
            building["x"]=0.0
            building["z"]=0.0
        else:
            # Saved 0.5/0.7 cities used index-based placeholder positions.
            # Migrate them into deterministic, separate construction plots.
            var spot: Vector2=Vector2(-40.0+float(i%5)*20.0,-40.0+float(i/5)*20.0)
            building["x"]=spot.x
            building["z"]=spot.y
    state["detail_sim"]={"version":1,"sites":sites,"workers":[],"delivered_wood":0.0,
        "delivered_stone":0.0,"turns":0}

static func snap(point: Vector2) -> Vector2:
    return Vector2(roundf(point.x/STEP)*STEP,roundf(point.y/STEP)*STEP)

static func can_place(state: Dictionary, point: Vector2) -> bool:
    var p: Vector2=snap(point)
    if absf(p.x)>HALF_SIZE or absf(p.y)>HALF_SIZE:
        return false
    for b in state.get("buildings",[]):
        var pos:=Vector2(float(b.get("x",0)),float(b.get("z",0)))
        if pos.distance_to(p)<15.5:return false
    for site in state.get("detail_sim",{}).get("sites",[]):
        if float(site.get("remaining",0))>0.0:
            var node:=Vector2(float(site["x"]),float(site["z"]))
            if node.distance_to(p)<9.0:return false
    return true

static func next_free(state: Dictionary) -> Vector2:
    for radius in range(1,9):
        for z in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if maxi(absi(x),absi(z))!=radius:continue
                var pos:=Vector2(float(x)*STEP,float(z)*STEP)
                if can_place(state,pos):return pos
    return Vector2(INF,INF)

static func count_remaining(state: Dictionary, kind: String) -> float:
    var result: float=0.0
    for s in state.get("detail_sim",{}).get("sites",[]):
        if String(s.get("kind",""))==kind:
            result+=float(s.get("remaining",0))
    return result

static func nearest_site(sim: Dictionary, kind: String, from: Vector2) -> int:
    var index: int=-1
    var dist: float=INF
    var sites: Array=sim.get("sites",[])
    for i in range(sites.size()):
        var site: Dictionary=sites[i]
        if String(site.get("kind",""))!=kind or float(site.get("remaining",0))<=0.0:
            continue
        var p:=Vector2(float(site["x"]),float(site["z"]))
        var d: float=p.distance_squared_to(from)
        if d<dist:
            index=i
            dist=d
    return index

static func walk_agent(worker: Dictionary, target: Vector2, speed: float) -> bool:
    var pos:=Vector2(float(worker["x"]),float(worker["z"]))
    var delta:=target-pos
    var length: float=delta.length()
    if length<0.001 or length<=speed:
        worker["x"]=target.x
        worker["z"]=target.y
        return true
    var next: Vector2=pos+delta/length*speed
    worker["x"]=next.x
    worker["z"]=next.y
    return false

static func tick(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    var sim: Dictionary=state["detail_sim"]
    var builds: Array=state["buildings"]
    var workers: Array=sim.get("workers",[])
    sim["turns"]=int(sim.get("turns",0))+1
    var existing: Dictionary={}
    for agent in workers:
        existing[int(agent["building"])]=true
    for i in range(builds.size()):
        var b: Dictionary=builds[i]
        var typ: String=String(b.get("type",""))
        if typ not in ["lumber","quarry"] or not bool(b.get("ready",false)):
            continue
        if not existing.has(i):
            workers.append({"building":i,"kind":"wood" if typ=="lumber" else "stone",
                "x":float(b.get("x",0)),"z":float(b.get("z",0)),
                "phase":"out","carry":0.0,"site":-1})
            existing[i]=true
    var stock: Dictionary=state["realms"][0]["resources"]
    for agent in workers:
        var idx: int=int(agent["building"])
        if idx>=builds.size():continue
        var b: Dictionary=builds[idx]
        if not bool(b.get("ready",false)) or float(b.get("assigned",0.0))<=0.0:
            continue
        var home:=Vector2(float(b.get("x",0)),float(b.get("z",0)))
        var speed: float=WALK_PER_TURN*clampf(float(b.get("efficiency",1.0)),0.2,1.0)
        if String(agent["phase"])=="return":
            if walk_agent(agent,home,speed):
                var cargo: float=float(agent.get("carry",0))
                if cargo>0:
                    var resource: String=String(agent["kind"])
                    stock[resource]=float(stock.get(resource,0))+cargo
                    var total_key: String="delivered_wood" if resource=="wood" else "delivered_stone"
                    sim[total_key]=float(sim.get(total_key,0))+cargo
                agent["carry"]=0.0
                agent["phase"]="out"
                agent["site"]=-1
            continue
        var chosen: int=int(agent.get("site",-1))
        var nodes: Array=sim["sites"]
        if chosen<0 or chosen>=nodes.size() or float(nodes[chosen]["remaining"])<=0:
            chosen=nearest_site(sim,String(agent["kind"]),home)
            agent["site"]=chosen
        if chosen<0:continue
        var node: Dictionary=nodes[chosen]
        var place:=Vector2(float(node["x"]),float(node["z"]))
        if walk_agent(agent,place,speed):
            var gathered: float=minf(GATHER_AMOUNT*clampf(float(b.get("efficiency",1)),0,1),
                float(node["remaining"]))
            node["remaining"]=maxf(0.0,float(node["remaining"])-gathered)
            agent["carry"]=gathered
            agent["phase"]="return"
    sim["workers"]=workers
