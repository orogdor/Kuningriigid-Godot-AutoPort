extends RefCounted
## AutoPort 0.11: physical construction crews for spatial (3D) cities only.
## Original economy.js-parity one-city scenarios are unaffected.
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const WALK_SPEED: float = 24.0
const MIN_WORK_TURNS: int = 3

static func initialize(state: Dictionary) -> void:
    if not state.has("detail_sim"):return
    var sim: Dictionary=state["detail_sim"]
    if not sim.has("builders"):sim["builders"]=[]
    if not sim.has("builder_ids"):sim["builder_ids"]=0
    sim["version"]=4

static func required_turns(spec: Dictionary) -> int:
    return maxi(MIN_WORK_TURNS,int(ceil(float(spec.get("time",12.0))/15.0)))

static func phase_fraction(building: Dictionary, spec: Dictionary) -> float:
    if bool(building.get("ready",false)):return 1.0
    var required: float=maxf(1.0,float(spec.get("time",1.0)))
    return clampf(float(building.get("progress",0.0))/required,0.0,1.0)

static func stage(building: Dictionary, spec: Dictionary) -> int:
    if bool(building.get("ready",false)):return 3
    var ratio: float=phase_fraction(building,spec)
    if ratio<0.01:return 0
    if ratio<0.34:return 1
    return 2

static func _approach(state: Dictionary, from: Vector2, b: Dictionary) -> Vector2:
    var center:=Vector2(float(b.get("x",0)),float(b.get("z",0)))
    var best: float=INF
    var selected:=Vector2(99999.0,99999.0)
    for delta in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20),
        Vector2(20,20),Vector2(-20,20),Vector2(20,-20),Vector2(-20,-20)]:
        var target: Vector2=center+delta
        var point: Vector2i=Paths.grid(target)
        if not Paths.bounded(point) or Paths.blocked(state,point,0):continue
        var path: Array=Paths.find_path(state,from,target,0)
        if path.is_empty():continue
        var cost: float=from.distance_to(target)
        if cost<best:
            selected=target
            best=cost
    return selected

static func _match_jobs(state: Dictionary) -> void:
    var sim: Dictionary=state["detail_sim"]
    var builders: Array=sim["builders"]
    var reserved: Dictionary={}
    for worker in builders:
        var idx: int=int(worker.get("building",-1))
        var active: bool=idx>=0 and idx<state["buildings"].size()
        if active:
            active=not bool(state["buildings"][idx].get("ready",false))
        if not active:
            worker["building"]=-1
            worker["phase"]="idle"
            worker["route"]=[]
            worker["target_x"]=99999.0
            worker["target_z"]=99999.0
        else:
            reserved[idx]=true
    for idx in range(state["buildings"].size()):
        var site: Dictionary=state["buildings"][idx]
        if bool(site.get("ready",false)) or float(site.get("hp",0))<=0.0:
            continue
        if reserved.has(idx):continue
        var agent: Variant=null
        for w in builders:
            if int(w.get("building",-1))<0:
                agent=w
                break
        if agent==null:
            sim["builder_ids"]=int(sim.get("builder_ids",0))+1
            agent={"id":int(sim["builder_ids"]),"x":0.0,"z":0.0,"building":-1,
                "phase":"idle","route":[]}
            builders.append(agent)
        agent["building"]=idx
        agent["phase"]="walking"
        agent["route"]=[]
        agent["target_x"]=99999.0
        agent["target_z"]=99999.0
        reserved[idx]=true

static func tick(state: Dictionary, recipes: Dictionary) -> void:
    if not state.has("detail_sim"):return
    initialize(state)
    _match_jobs(state)
    var sim: Dictionary=state["detail_sim"]
    var builds: Array=state["buildings"]
    for worker in sim["builders"]:
        var idx: int=int(worker.get("building",-1))
        if idx<0 or idx>=builds.size():continue
        var building: Dictionary=builds[idx]
        if bool(building.get("ready",false)) or float(building.get("hp",0))<=0.0:
            continue
        # Real economy allocates construction labor before the crew moves.
        var efficiency: float=clampf(float(building.get("efficiency",0.0)),0.0,1.0)
        if float(building.get("assigned",0.0))<=0.0 or efficiency<=0.0:
            worker["phase"]="waiting_for_workers"
            continue
        var current:=Vector2(float(worker.get("x",0)),float(worker.get("z",0)))
        var target:=Vector2(float(worker.get("target_x",INF)),float(worker.get("target_z",INF)))
        var target_invalid: bool=absf(target.x)>1000.0 or Paths.blocked(state,Paths.grid(target),0)
        if target_invalid:
            target=_approach(state,current,building)
            worker["route"]=[]
            worker["target_x"]=target.x
            worker["target_z"]=target.y
        if absf(target.x)>1000.0:
            worker["phase"]="no_route"
            continue
        if current.distance_to(target)>0.01:
            worker["phase"]="walking"
            var reached: bool=Paths.move(worker,target,WALK_SPEED*maxf(0.25,efficiency),state,0)
            if not reached:continue
        worker["phase"]="building"
        var spec: Dictionary=recipes.get(building.get("type",""),{})
        var duration: float=maxf(1.0,float(spec.get("time",1.0)))
        var increment: float=duration/required_turns(spec)*efficiency
        building["progress"]=minf(duration,float(building.get("progress",0))+increment)
        if float(building["progress"])+0.000001>=duration:
            building["ready"]=true
            building["progress"]=duration
            worker["phase"]="finished"
            worker["building"]=-1
            worker["route"]=[]

static func progress_report(state: Dictionary, recipes: Dictionary) -> Dictionary:
    var underway: int=0
    var working: int=0
    var walking: int=0
    for b in state.get("buildings",[]):
        if not bool(b.get("ready",false)):
            underway+=1
    for w in state.get("detail_sim",{}).get("builders",[]):
        if String(w.get("phase",""))=="building":working+=1
        if String(w.get("phase",""))=="walking":walking+=1
    return {"under_construction":underway,"working":working,"walking":walking,
        "builders":state.get("detail_sim",{}).get("builders",[]).size()}
