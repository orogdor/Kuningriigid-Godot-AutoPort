extends RefCounted
## 0.26: persistent world-tile/3D-local transport network. Agents carry cargo
## through physical 10m A* paths on each owned district, then spend 20m of
## travel crossing the shared world-tile boundary. Old one-tile saves are idle.
const World=preload("res://scripts/world_gen_v06.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Access=preload("res://scripts/building_access_v22.gd")
const Terrain=preload("res://scripts/detail_terrain_v10.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const OldConstruction=preload("res://scripts/construction_v11.gd")
const METERS_PER_TURN: float=24.0
const GATE: float=70.0
const BORDER_DISTANCE: float=20.0
const LOAD_LIMIT: float=10.0
const PORTAL_OFFSETS: Array[float]=[0.0,-20.0,20.0,-40.0,40.0,60.0,-60.0]

static func key(c: int,r: int) -> String:
    return str(c)+":"+str(r)

static func _parts(value: String) -> Vector2i:
    var pair: PackedStringArray=value.split(":")
    if pair.size()!=2:return Vector2i(-999,-999)
    return Vector2i(int(pair[0]),int(pair[1]))

static func home_key(state: Dictionary) -> String:
    var network: Dictionary=state.get("transport_v26",{})
    var home: Dictionary=network.get("home",{})
    if home.is_empty():return ""
    return key(int(home.get("c",-999)),int(home.get("r",-999)))

static func all_keys(state: Dictionary) -> Array[String]:
    var keys: Array[String]=[]
    var network: Dictionary=state.get("transport_v26",{})
    var home: String=home_key(state)
    if home=="":return keys
    keys.append(home)
    for entry in network.get("tiles",[]):
        var dest: String=key(int(entry.get("c",-999)),int(entry.get("r",-999)))
        if not keys.has(dest):keys.append(dest)
    return keys

static func configure(state: Dictionary,world: Dictionary) -> void:
    var annexes: Dictionary=state.get("districts_v25",{})
    if annexes.get("tiles",[]).is_empty():return
    if int(annexes.get("seed",-1))!=int(world.get("seed",-2)):return
    var starts: Array=world.get("starts",[])
    if starts.is_empty():return
    var home: Dictionary={"c":int(starts[0]["c"]),"r":int(starts[0]["r"])}
    var network: Dictionary=state.get("transport_v26",{})
    if int(network.get("seed",-1))!=int(world.get("seed",-2)):
        network={"seed":int(world.get("seed",0)),"home":home,
            "tiles":[],"surfaces":{},"agents":[],"next_id":0,"trips":0}
    network["home"]=home
    network["tiles"]=annexes.get("tiles",[]).duplicate(true)
    var surfaces: Dictionary=network.get("surfaces",{})
    for entry in network["tiles"]:
        var c: int=int(entry["c"])
        var r: int=int(entry["r"])
        var id: String=key(c,r)
        if surfaces.has(id):continue
        var cell: Dictionary=World.cell(world,c,r)
        var sites: Array=[]
        for n in range(Spatial.STARTING_SITES.size()):
            sites.append(Spatial.make_site("wood" if n<5 else "stone",Spatial.STARTING_SITES[n],n))
        surfaces[id]={"terrain":String(cell.get("biome","plains")),
            "river":bool(cell.get("river",false)),"sites":sites,
            "roads":{},"bridges":[],"turns":0}
    network["surfaces"]=surfaces
    state["transport_v26"]=network

static func route(state: Dictionary,source: String,target: String) -> Array[String]:
    var keys: Array[String]=all_keys(state)
    var empty: Array[String]=[]
    if not keys.has(source) or not keys.has(target):return empty
    if source==target:return [source]
    var allow: Dictionary={}
    for k in keys:allow[k]=true
    var frontier: Array[String]=[source]
    var prev: Dictionary={source:""}
    var head: int=0
    while head<frontier.size():
        var current: String=frontier[head]
        head+=1
        var p: Vector2i=_parts(current)
        for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
            var candidate: String=key(p.x+d.x,p.y+d.y)
            if not allow.has(candidate) or prev.has(candidate):continue
            prev[candidate]=current
            if candidate==target:
                var reversed: Array[String]=[target]
                var parent: String=current
                while parent!="":
                    reversed.append(parent)
                    parent=String(prev[parent])
                reversed.reverse()
                return reversed
            frontier.append(candidate)
    return empty

static func _local_state(state: Dictionary,district: String) -> Dictionary:
    var local_buildings: Array=[]
    var home: String=home_key(state)
    # Pathfinders may pass through the hall's door, but must still avoid
    # other buildings on THIS world tile, never similarly placed neighbors.
    local_buildings.append({"type":"hall","x":0.0,"z":0.0,"hp":1200.0})
    for b in state.get("buildings",[]):
        var id: String=String(b.get("district",""))
        if (district==home and id=="") or (district!=home and id==district):
            if id!="" or String(b.get("type",""))!="hall":
                local_buildings.append(b)
    var sim: Dictionary=state.get("detail_sim",{})
    if district!=home:
        sim=state.get("transport_v26",{}).get("surfaces",{}).get(district,{})
    return {"buildings":local_buildings,"detail_sim":sim}

static func _at_gate(difference: Vector2i,offset: float) -> Vector2:
    if difference.x==1:return Vector2(GATE,offset)
    if difference.x==-1:return Vector2(-GATE,offset)
    if difference.y==1:return Vector2(offset,GATE)
    return Vector2(offset,-GATE)

static func _opposite_gate(difference: Vector2i,offset: float) -> Vector2:
    if difference.x==1:return Vector2(-GATE,offset)
    if difference.x==-1:return Vector2(GATE,offset)
    if difference.y==1:return Vector2(offset,-GATE)
    return Vector2(offset,GATE)

static func _choose_gate(state: Dictionary,agent: Dictionary, next: String) -> Dictionary:
    var current_id: String=String(agent["district"])
    var delta: Vector2i=_parts(next)-_parts(current_id)
    if absi(delta.x)+absi(delta.y)!=1:return {}
    var here: Dictionary=_local_state(state,current_id)
    var there: Dictionary=_local_state(state,next)
    var start:=Vector2(float(agent["x"]),float(agent["z"]))
    for offset in PORTAL_OFFSETS:
        var gate: Vector2=_at_gate(delta,offset)
        var opposite: Vector2=_opposite_gate(delta,offset)
        if Paths.blocked(here,Paths.grid(gate),0) or Paths.blocked(there,Paths.grid(opposite),0):continue
        if Paths.find_path(here,start,gate,0).is_empty():continue
        # Landing must connect to the neighboring tile's inner streets.
        if Paths.find_path(there,opposite,Vector2.ZERO,0).is_empty():continue
        return {"start":gate,"end":opposite,"district":next}
    return {}

static func _local_move(state: Dictionary,agent: Dictionary,target: Vector2,speed: float) -> bool:
    var local: Dictionary=_local_state(state,String(agent["district"]))
    return Paths.move(agent,target,speed,local,0)

static func advance_agent(state: Dictionary,agent: Dictionary,target_district: String,
        destination: Vector2,speed: float=METERS_PER_TURN) -> bool:
    var current_id: String=String(agent.get("district",home_key(state)))
    if current_id==target_district:
        agent.erase("gate")
        agent.erase("cross_left")
        return _local_move(state,agent,destination,speed)
    var steps: Array[String]=route(state,current_id,target_district)
    if steps.size()<2:
        agent["blocked"]=true
        return false
    var gate: Dictionary=agent.get("gate",{})
    if gate.is_empty() or String(gate.get("district",""))!=steps[1]:
        gate=_choose_gate(state,agent,steps[1])
        if gate.is_empty():
            agent["blocked"]=true
            return false
        agent["gate"]=gate
    agent["blocked"]=false
    if not agent.has("cross_left"):
        if not _local_move(state,agent,gate["start"],speed):return false
        # The physical shared boundary has 20m between both gate endpoints.
        # It consumes movement budget on subsequent turns, never teleporting.
        agent["cross_left"]=BORDER_DISTANCE
        agent["route"]=[]
        return false
    var remaining: float=maxf(0.0,float(agent["cross_left"])-speed)
    if remaining>0.0:
        agent["cross_left"]=remaining
        return false
    agent["district"]=String(gate["district"])
    var arrival: Vector2=gate["end"]
    agent["x"]=arrival.x
    agent["z"]=arrival.y
    agent["route"]=[]
    agent.erase("path_version")
    agent.erase("gate")
    agent.erase("cross_left")
    return false

static func _new_agent(state: Dictionary,role: String,origin: int,district: String,
        position: Vector2,product: String,load: float) -> Dictionary:
    var network: Dictionary=state["transport_v26"]
    network["next_id"]=int(network.get("next_id",0))+1
    return {"id":100000+int(network["next_id"]),"role":role,"origin":origin,
        "district":district,"x":position.x,"z":position.y,"kind":product,
        "load":load,"route":[],"phase":"travel"}

static func enqueue_output(state: Dictionary,origin: int,product: String,amount: float) -> bool:
    if amount<=0.0 or not state.has("transport_v26"):return false
    var buildings: Array=state.get("buildings",[])
    if origin<0 or origin>=buildings.size():return false
    var b: Dictionary=buildings[origin]
    var district: String=String(b.get("district",""))
    if district=="" or not all_keys(state).has(district):return false
    var sim: Dictionary=state.get("detail_sim",{})
    var made: Dictionary=sim.get("freight_produced",{})
    made[product]=float(made.get(product,0))+amount
    sim["freight_produced"]=made
    var remain: float=amount
    while remain>0.000001:
        var n: float=minf(LOAD_LIMIT,remain)
        var agent: Dictionary=_new_agent(state,"wagon",origin,district,Access.entrance(b),product,n)
        state["transport_v26"]["agents"].append(agent)
        remain-=n
    return true

static func enqueue_input(state: Dictionary,origin: int,product: String,amount: float) -> bool:
    if amount<=0.0 or not state.has("transport_v26"):return false
    var buildings: Array=state.get("buildings",[])
    if origin<0 or origin>=buildings.size():return false
    var b: Dictionary=buildings[origin]
    var district: String=String(b.get("district",""))
    if district=="" or not all_keys(state).has(district):return false
    var remain: float=amount
    while remain>0.000001:
        var n: float=minf(LOAD_LIMIT,remain)
        state["transport_v26"]["agents"].append(
            _new_agent(state,"input_wagon",origin,home_key(state),
                Access.entrance(buildings[0]),product,n))
        remain-=n
    return true

static func _spawn_builders(state: Dictionary) -> void:
    var buildings: Array=state.get("buildings",[])
    var home: String=home_key(state)
    for i in range(1,buildings.size()):
        var b: Dictionary=buildings[i]
        var district: String=String(b.get("district",""))
        if district=="" or not all_keys(state).has(district):continue
        if bool(b.get("ready",false)) or bool(b.get("v26_dispatched",false)):continue
        b["v26_dispatched"]=true
        var prepaid: Dictionary=b.get("supply_total",{})
        for product in prepaid.keys():
            var remain: float=float(prepaid[product])
            while remain>0.000001:
                var amount: float=minf(LOAD_LIMIT,remain)
                state["transport_v26"]["agents"].append(
                    _new_agent(state,"material",i,home,Access.entrance(buildings[0]),String(product),amount))
                remain-=amount
        state["transport_v26"]["agents"].append(
            _new_agent(state,"builder",i,home,Access.entrance(buildings[0]),"",0.0))

static func _spawn_gatherers(state: Dictionary) -> void:
    var builds: Array=state.get("buildings",[])
    var net: Dictionary=state["transport_v26"]
    for i in range(1,builds.size()):
        var b: Dictionary=builds[i]
        var d: String=String(b.get("district",""))
        if d=="" or not all_keys(state).has(d) or not bool(b.get("ready",false)):continue
        var kind: String=String(b.get("type",""))
        if kind!="lumber" and kind!="quarry":continue
        var present: bool=false
        for agent in net["agents"]:
            if int(agent.get("origin",-1))==i and String(agent.get("role",""))=="gatherer":
                present=true
                break
        if not present:
            var worker: Dictionary=_new_agent(state,"gatherer",i,home_key(state),
                Access.entrance(builds[0]),"wood" if kind=="lumber" else "stone",0.0)
            worker["phase"]="commute"
            worker["site"]=-1
            net["agents"].append(worker)

static func _gatherer_tick(state: Dictionary,a: Dictionary) -> void:
    var b: Dictionary=state["buildings"][int(a["origin"])]
    if float(b.get("assigned",0))<=0.0:return
    var target: String=String(b.get("district",""))
    if String(a.get("phase",""))=="commute":
        if advance_agent(state,a,target,Access.entrance(b)):
            a["phase"]="to_deposit"
        return
    var surface: Dictionary=state["transport_v26"]["surfaces"].get(target,{})
    var sites: Array=surface.get("sites",[])
    if sites.is_empty():return
    var site_idx: int=int(a.get("site",-1))
    if site_idx<0 or site_idx>=sites.size() or float(sites[site_idx].get("remaining",0))<=0.0:
        site_idx=-1
        var closest: float=INF
        var pos:=Vector2(float(a["x"]),float(a["z"]))
        for i in range(sites.size()):
            var node: Dictionary=sites[i]
            if String(node.get("kind",""))!=String(a.get("kind","")) or float(node.get("remaining",0))<=0.0:continue
            var point:=Vector2(float(node["x"]),float(node["z"]))
            var local: Dictionary=_local_state(state,target)
            if Paths.find_path(local,pos,point,0).is_empty():continue
            var dist: float=pos.distance_to(point)
            if dist<closest:
                closest=dist
                site_idx=i
        a["site"]=site_idx
    if site_idx<0:return
    var site: Dictionary=sites[site_idx]
    var target_position:=Vector2(float(site["x"]),float(site["z"]))
    if String(a["phase"])=="to_deposit":
        if advance_agent(state,a,target,target_position):
            var gathered: float=minf(Spatial.GATHER_AMOUNT*clampf(float(b.get("efficiency",1)),0.0,1.0),
                float(site["remaining"]))
            site["remaining"]=maxf(0.0,float(site["remaining"])-gathered)
            a["load"]=gathered
            a["phase"]="to_workshop"
        return
    if String(a["phase"])=="to_workshop":
        if advance_agent(state,a,target,Access.entrance(b)):
            a["phase"]="return_hall"
        return
    if String(a["phase"])=="return_hall":
        if advance_agent(state,a,home_key(state),Access.entrance(state["buildings"][0])):
            var stock: Dictionary=state["realms"][0]["resources"]
            var kind: String=String(a["kind"])
            stock[kind]=float(stock.get(kind,0))+float(a["load"])
            a["load"]=0.0
            a["phase"]="commute"
            a["route"]=[]
            a["site"]=-1
            var sim: Dictionary=state["detail_sim"]
            var field: String="delivered_wood" if kind=="wood" else "delivered_stone"
            sim[field]=float(sim.get(field,0))+float(Spatial.GATHER_AMOUNT)
        return

static func tick(state: Dictionary,recipes: Dictionary={}) -> void:
    if not state.has("transport_v26") or not state.has("detail_sim"):return
    var net: Dictionary=state["transport_v26"]
    _spawn_builders(state)
    _spawn_gatherers(state)
    var done: Array=[]
    for a in net["agents"]:
        var origin: int=int(a.get("origin",-1))
        if origin<0 or origin>=state["buildings"].size():continue
        var b: Dictionary=state["buildings"][origin]
        var role: String=String(a.get("role",""))
        if role=="gatherer":
            _gatherer_tick(state,a)
            continue
        var go_home: bool=role=="wagon"
        var target: String=home_key(state) if go_home else String(b.get("district",""))
        var end: Vector2=Access.entrance(state["buildings"][0]) if go_home else Access.entrance(b)
        if not advance_agent(state,a,target,end):continue
        if role=="wagon":
            var kind: String=String(a["kind"])
            var stock: Dictionary=state["realms"][0]["resources"]
            stock[kind]=float(stock.get(kind,0))+float(a["load"])
            var sim: Dictionary=state["detail_sim"]
            var delivered: Dictionary=sim.get("freight_delivered",{})
            delivered[kind]=float(delivered.get(kind,0))+float(a["load"])
            sim["freight_delivered"]=delivered
            sim["freight_trips"]=int(sim.get("freight_trips",0))+1
            done.append(a)
        elif role=="input_wagon" or role=="material":
            var store: Dictionary={}
            if role=="material":
                store=b.get("supply_delivered",{})
                store[String(a["kind"])]=float(store.get(String(a["kind"]),0))+float(a["load"])
                b["supply_delivered"]=store
                state["detail_sim"]["construction_delivered"]=float(state["detail_sim"].get("construction_delivered",0))+float(a["load"])
            elif b.has("input_shipment"):
                store=b["input_shipment"]["delivered"]
                store[String(a["kind"])]=float(store.get(String(a["kind"]),0))+float(a["load"])
                state["detail_sim"]["freight_trips"]=int(state["detail_sim"].get("freight_trips",0))+1
            done.append(a)
        elif role=="builder":
            var supplied: bool=true
            for k in b.get("supply_total",{}):
                if float(b.get("supply_delivered",{}).get(k,0))+0.000001<float(b["supply_total"][k]):
                    supplied=false
            if supplied and float(b.get("assigned",0))>0.0:
                var spec: Dictionary=recipes.get(String(b.get("type","")),{})
                var duration: float=maxf(1.0,float(spec.get("time",1.0)))
                var gain: float=duration/maxf(1.0,float(OldConstruction.required_turns(spec)))*clampf(
                    float(b.get("efficiency",1.0)),0.0,1.0)
                b["progress"]=minf(duration,float(b.get("progress",0))+gain)
                if float(b["progress"])+0.000001>=duration:
                    b["ready"]=true
                    done.append(a)
                    net["trips"]=int(net.get("trips",0))+1
    for a in done:net["agents"].erase(a)

static func in_transit(state: Dictionary,kind: String) -> float:
    var net: Dictionary=state.get("transport_v26",{})
    var total: float=0.0
    for a in net.get("agents",[]):
        if String(a.get("role",""))=="wagon" and String(a.get("kind",""))==kind:
            total+=float(a.get("load",0))
    return total
