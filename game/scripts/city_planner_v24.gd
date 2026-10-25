extends RefCounted
## 0.24 deterministic compact urban growth suggestions for the 160m town tile.
## A suggestion is advisory only. All actual building orders continue through
## City.build and Spatial.can_place, with unchanged costs and saved city schema.
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Access=preload("res://scripts/building_access_v22.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const MAX_EVALUATED: int=20

static func _family(kind: String) -> String:
    if ["farm","forester","lumber","quarry","mine","fisher","harbor"].has(kind):
        return "production"
    if ["house","market","well","bakery","cellar","warehouse"].has(kind):
        return "residential"
    return "craft"

static func _deposit_distance(state: Dictionary,kind: String,site: Vector2) -> float:
    var deposit_kind: String="stone" if ["quarry","mine"].has(kind) else "wood"
    var closest: float=160.0
    for item in state.get("detail_sim",{}).get("sites",[]):
        if String(item.get("kind",""))!=deposit_kind or float(item.get("remaining",0.0))<=0.0:continue
        var loc:=Vector2(float(item.get("x",0.0)),float(item.get("z",0.0)))
        closest=minf(closest,site.distance_to(loc))
    return closest

static func score(state: Dictionary, kind: String, cell: Vector2) -> float:
    var distance: float=cell.length()
    var family: String=_family(kind)
    var closest_neighbor: float=200.0
    var residents: int=0
    for b in state.get("buildings",[]):
        if float(b.get("hp",1.0))<=0.0:continue
        var pos:=Vector2(float(b.get("x",0.0)),float(b.get("z",0.0)))
        closest_neighbor=minf(closest_neighbor,cell.distance_to(pos))
        if String(b.get("type",""))=="house":residents+=1
    # Avoid placing houses in long straight future approaches from the hall:
    # leave a few corridors rather than sealing every 10m ring around it.
    var corridor_penalty: float=15.0 if (absf(cell.x)<5.0 or absf(cell.y)<5.0) and distance>20.0 else 0.0
    var density_penalty: float=maxf(0.0,closest_neighbor-32.0)*0.45
    var location: float=0.0
    if family=="residential":
        # Small blocks around the old centre; fill the next ring as pop rises.
        var ideal_radius: float=28.0+minf(25.0,float(residents)*3.0)
        location=absf(distance-ideal_radius)*0.7
    elif family=="production":
        # Keep noisy/resource-dependent workshops slightly outside homes.
        location=absf(distance-55.0)*0.5
        if ["lumber","forester","quarry","mine"].has(kind):
            location+=_deposit_distance(state,kind,cell)*0.22
    else:
        location=absf(distance-40.0)*0.5
    return location+corridor_penalty+density_penalty

static func plan(state: Dictionary, kind: String, district: String="") -> Dictionary:
    if not state.has("detail_sim") or state.get("buildings",[]).is_empty():
        return {}
    # A neighboring world tile is a separate set of local building plots
    # but belongs to the same economic state.
    var planning: Dictionary=state
    if district!="":
        planning=state.duplicate()
        var structures: Array=[{"type":"hall","x":0.0,"z":0.0,"hp":1200.0,"ready":true}]
        for building in state.get("buildings",[]):
            if String(building.get("district",""))==district:structures.append(building)
        planning["buildings"]=structures
    var proposals: Array=[]
    for z in range(-7,8):
        for x in range(-7,8):
            var cell:=Vector2(float(x)*Spatial.STEP,float(z)*Spatial.STEP)
            if not Spatial.can_place(state,cell,district):continue
            proposals.append({"position":cell,"score":score(planning,kind,cell)})
    if proposals.is_empty():return {}
    proposals.sort_custom(func(a,b):
        if not is_equal_approx(float(a["score"]),float(b["score"])):
            return float(a["score"])<float(b["score"])
        var pa: Vector2=a["position"]
        var pb: Vector2=b["position"]
        return pa.y<pb.y if pa.y!=pb.y else pa.x<pb.x
    )
    # Probe only the best-scoring plots for an actual A* connection.
    # Never mutate the source city (not even the buildings array).
    var trial: Dictionary=planning.duplicate()
    trial["buildings"]=planning["buildings"].duplicate()
    var hall: Vector2=Access.entrance(planning["buildings"][0])
    for i in range(mini(proposals.size(),MAX_EVALUATED)):
        var proposal: Dictionary=proposals[i]
        var position: Vector2=proposal["position"]
        for facing in [0,90,180,270]:
            trial["buildings"].append({"type":kind,"x":position.x,
                "z":position.y,"hp":350.0,"ready":false,"rotation":facing})
            var proposed_index: int=trial["buildings"].size()-1
            var doorway: Vector2=Access.reachable(trial,proposed_index,hall,0)
            trial["buildings"].pop_back()
            if doorway.x>1000.0:continue
            return {"position":position,"rotation":facing,"entry":doorway,
                "score":proposal["score"],"plots":proposals.size()}
    return {}
