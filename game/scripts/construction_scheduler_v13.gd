extends RefCounted
## AutoPort 0.13 scheduling: stable high/normal/low construction priorities.
## The economic engine still allocates employees; this scheduler only assigns
## the finite available builder avatars across unfinished physical projects.
## Loaded cargo must arrive at its original site before reassignment.
const LIMIT_PER_SITE: int=2
const LEVELS: Dictionary={"low":1,"normal":2,"high":3}

static func normalize(value: String) -> String:
    var kind: String=value.to_lower()
    return kind if LEVELS.has(kind) else "normal"

static func initialize(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    for b in state.get("buildings",[]):
        if not bool(b.get("ready",false)):
            b["priority"]=normalize(String(b.get("priority","normal")))
    var sim: Dictionary=state["detail_sim"]
    sim["version"]=maxi(6,int(sim.get("version",0)))

static func change_priority(state: Dictionary,index: int,value: String) -> bool:
    if not state.has("detail_sim"):return false
    if index<=0 or index>=state.get("buildings",[]).size():return false
    var b: Dictionary=state["buildings"][index]
    if bool(b.get("ready",false)):return false
    var kind: String=value.to_lower()
    if not LEVELS.has(kind):return false
    b["priority"]=kind
    return true

static func _idle(worker: Dictionary) -> void:
    worker["building"]=-1
    worker["phase"]="idle"
    worker["route"]=[]
    worker["target_x"]=99999.0
    worker["target_z"]=99999.0
    worker["cargo_kind"]=""
    worker["cargo_amount"]=0.0

static func _quota(b: Dictionary) -> int:
    if bool(b.get("ready",false)) or float(b.get("hp",0))<=0.0:return 0
    if float(b.get("assigned",0))<=0.000001:return 0
    return mini(LIMIT_PER_SITE,maxi(1,int(ceil(float(b["assigned"])-0.000001))))

static func assign(state: Dictionary) -> void:
    initialize(state)
    var sim: Dictionary=state["detail_sim"]
    var workers: Array=sim["builders"]
    var buildings: Array=state["buildings"]
    var capacity: int=maxi(0,int(state["realms"][0].get("pop",0)))
    var quotas: Dictionary={}
    var ordered: Array=[]
    for i in range(1,buildings.size()):
        var qty: int=_quota(buildings[i])
        if qty>0:
            quotas[i]=qty
            ordered.append(i)
    ordered.sort_custom(func(a,b):
        var ap: int=int(LEVELS[normalize(String(buildings[a].get("priority","normal")))])
        var bp: int=int(LEVELS[normalize(String(buildings[b].get("priority","normal")))])
        return ap>bp if ap!=bp else a<b
    )
    var desired: Dictionary={}
    for idx in ordered:
        var slots: int=mini(int(quotas[idx]),capacity)
        desired[idx]=slots
        capacity-=slots
    # Carrying materials remains reserved for the original construction even
    # if priority changes mid-journey. Do not throw paid cargo away.
    var pinned: Dictionary={}
    for agent in workers:
        var idx: int=int(agent.get("building",-1))
        var quantity: float=float(agent.get("cargo_amount",0.0))
        if idx>=1 and idx<buildings.size() and not bool(buildings[idx].get("ready",false)) and quantity>0.00001:
            pinned[idx]=int(pinned.get(idx,0))+1
    var pop_limit: int=maxi(0,int(state["realms"][0].get("pop",0)))
    var counts: Dictionary={}
    # Reuse existing assignments where possible; adjust quotas around pinned
    # deliveries. A high-priority site gets its remaining available crew first.
    for agent in workers:
        var idx: int=int(agent.get("building",-1))
        if idx<1 or idx>=buildings.size() or bool(buildings[idx].get("ready",false)):
            _idle(agent)
            continue
        if float(agent.get("cargo_amount",0.0))>0.00001:
            counts[idx]=int(counts.get(idx,0))+1
            continue
        _idle(agent)
    var available: int=maxi(0,pop_limit-workers.filter(func(w):return int(w.get("building",-1))>=0).size())
    for idx in ordered:
        var needed: int=maxi(0,int(desired.get(idx,0))-int(counts.get(idx,0)))
        while needed>0 and available>0:
            var agent: Variant=null
            for worker in workers:
                if int(worker.get("building",-1))<0:
                    agent=worker
                    break
            if agent==null:
                sim["builder_ids"]=int(sim.get("builder_ids",0))+1
                agent={"id":int(sim["builder_ids"]),"x":0.0,"z":0.0,
                    "building":-1,"phase":"idle","route":[],
                    "cargo_kind":"","cargo_amount":0.0}
                workers.append(agent)
            agent["building"]=idx
            agent["phase"]="to_hall"
            agent["route"]=[]
            agent["target_x"]=99999.0
            agent["target_z"]=99999.0
            counts[idx]=int(counts.get(idx,0))+1
            available-=1
            needed-=1
    sim["builders"]=workers

static func report(state: Dictionary) -> Dictionary:
    var results: Dictionary={"high":0,"normal":0,"low":0,"active":0}
    for b in state.get("buildings",[]):
        if bool(b.get("ready",false)):continue
        var priority: String=normalize(String(b.get("priority","normal")))
        results[priority]=int(results[priority])+1
        results["active"]=int(results["active"])+1
    return results
