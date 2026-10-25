extends RefCounted
## 0.29 - same water, ground heights and passable crossings in rendering
## and A*. Only combined/annexed districts carry this small JSON-safe record.
## Old standalone cities retain detail_terrain_v10 unchanged.
const World=preload("res://scripts/world_gen_v06.gd")
const Draw=preload("res://scripts/continuous_terrain_v28.gd")
const Legacy=preload("res://scripts/detail_terrain_v10.gd")
const RIVER_WIDTH: float=Draw.RIVER_HALF_WIDTH
const FORDS: Array[float]=[-60.0,0.0,60.0]
const BRIDGES: Array[float]=[-30.0,30.0]
const WIDTH_CROSSING: float=7.5
const STEP: float=10.0
const MAX_STEP: float=Legacy.MAX_STEP

static func configure(sim: Dictionary,world: Dictionary,tile: Vector2i) -> void:
    var desc: Array=[]
    for s in Draw.segments(world,tile):
        var a: Vector2=s["start"]
        var b: Vector2=s["end"]
        desc.append({"ax":a.x,"az":a.y,"bx":b.x,"bz":b.y})
    sim["terrain_v29"]={"seed":int(world.get("seed",0)),"c":tile.x,"r":tile.y,"segments":desc}

static func enabled(sim: Dictionary) -> bool:
    return sim.get("terrain_v29",{}) is Dictionary and not sim.get("terrain_v29",{}).is_empty()

static func _segments(sim: Dictionary) -> Array:
    return sim.get("terrain_v29",{}).get("segments",[])

static func ground(sim: Dictionary,x: float,z: float) -> float:
    if not enabled(sim):return Legacy.height_at(sim,x,z)
    var record: Dictionary=sim["terrain_v29"]
    return Draw.height_from_segments(int(record["seed"]),
        Vector2i(int(record["c"]),int(record["r"])),record.get("segments",[]),x,z)

static func _endpoints(s: Dictionary) -> Array[Vector2]:
    var result: Array[Vector2]=[Vector2(float(s["ax"]),float(s["az"])),Vector2(float(s["bx"]),float(s["bz"]))]
    return result

static func underwater(sim: Dictionary,pos: Vector2) -> bool:
    if not enabled(sim):
        return Legacy.river_lane(sim,pos.x,pos.y)
    for s in _segments(sim):
        var ends: Array[Vector2]=_endpoints(s)
        if Draw._distance_to_segment(pos,ends[0],ends[1])<=RIVER_WIDTH:
            return true
    return false

static func crossings(sim: Dictionary) -> Array:
    var result: Array=[]
    if not enabled(sim):
        if not Legacy.river_at(sim,0.0,0.0):return result
        for f in Legacy.FORDS:
            result.append({"x":float(f)*STEP,"z":25.0,"kind":"ford","axis":"x"})
        for bridge in sim.get("bridges",[]):
            result.append({"x":float(bridge["x"])*STEP,"z":25.0,"kind":"bridge","axis":"x"})
        return result
    var unique: Dictionary={}
    for segment in _segments(sim):
        var ends: Array[Vector2]=_endpoints(segment)
        var a: Vector2=ends[0]
        var b: Vector2=ends[1]
        var horizontal: bool=absf(b.x-a.x)>=absf(b.y-a.y)
        var axis: String="x" if horizontal else "z"
        var begin: float=a.x if horizontal else a.y
        var finish: float=b.x if horizontal else b.y
        var length: float=finish-begin
        if absf(length)<0.0001:continue
        for candidate in FORDS:
            var t: float=(candidate-begin)/length
            if t<0.0 or t>1.0:continue
            var pos: Vector2=a.lerp(b,t)
            var id: String="ford:"+str(snappedf(pos.x,0.1))+":"+str(snappedf(pos.y,0.1))
            if unique.has(id):continue
            unique[id]=true
            result.append({"x":pos.x,"z":pos.y,"kind":"ford","axis":axis})
        for bridge in sim.get("bridges",[]):
            var saved_axis: String=String(bridge.get("axis","x"))
            if saved_axis!=axis:continue
            var chosen: float=float(bridge.get("x",999))*STEP
            if not BRIDGES.has(chosen):continue
            var t: float=(chosen-begin)/length
            if t<0.0 or t>1.0:continue
            var pos: Vector2=a.lerp(b,t)
            var id: String="bridge:"+str(snappedf(pos.x,0.1))+":"+str(snappedf(pos.y,0.1))
            if unique.has(id):continue
            unique[id]=true
            result.append({"x":pos.x,"z":pos.y,"kind":"bridge","axis":axis})
    return result

static func crossing_at(sim: Dictionary,pos: Vector2) -> Dictionary:
    if not underwater(sim,pos):return {}
    for crossing in crossings(sim):
        var center:=Vector2(float(crossing["x"]),float(crossing["z"]))
        if center.distance_to(pos)<=WIDTH_CROSSING:return crossing
    return {}

static func blocked(sim: Dictionary,cell: Vector2i) -> bool:
    if not enabled(sim):return Legacy.blocked_cell(sim,cell)
    var pos:=Vector2(float(cell.x)*STEP,float(cell.y)*STEP)
    return underwater(sim,pos) and crossing_at(sim,pos).is_empty()

static func passable_step(sim: Dictionary,from: Vector2i,to: Vector2i) -> bool:
    if not enabled(sim):
        return not Legacy.too_steep(sim,from,to)
    var a:=Vector2(float(from.x)*STEP,float(from.y)*STEP)
    var b:=Vector2(float(to.x)*STEP,float(to.y)*STEP)
    if absf(ground(sim,a.x,a.y)-ground(sim,b.x,b.y))>MAX_STEP:return false
    # A fast 10m step can jump completely over 12m of visible water if only
    # endpoints are checked. Sample the whole edge, including diagonals.
    for i in range(9):
        var p: Vector2=a.lerp(b,float(i)/8.0)
        if underwater(sim,p) and crossing_at(sim,p).is_empty():
            return false
    return true

static func bridge_position(sim: Dictionary,axis: String,coordinate: int) -> Vector2:
    var missing:=Vector2(INF,INF)
    if not enabled(sim):
        return Vector2(float(coordinate)*STEP,25.0) if axis=="x" and Legacy.can_place_bridge(sim,coordinate) else missing
    var chosen: float=float(coordinate)*STEP
    if not BRIDGES.has(chosen) or axis not in ["x","z"]:return missing
    var check: Dictionary=sim.duplicate(true)
    if not check.has("bridges"):check["bridges"]=[]
    check["bridges"].append({"x":coordinate,"axis":axis})
    for c in crossings(check):
        if String(c["kind"])!="bridge" or String(c["axis"])!=axis:continue
        if is_equal_approx(float(c["x"] if axis=="x" else c["z"]),chosen):
            return Vector2(float(c["x"]),float(c["z"]))
    return missing

static func can_bridge(sim: Dictionary,crossing_axis: String,coordinate: int) -> bool:
    if not enabled(sim):
        return crossing_axis=="x" and Legacy.can_place_bridge(sim,coordinate)
    for record in sim.get("bridges",[]):
        if int(record.get("x",999))==coordinate and String(record.get("axis","x"))==crossing_axis:
            return false
    var p: Vector2=bridge_position(sim,crossing_axis,coordinate)
    return is_finite(p.x) and is_finite(p.y)

static func build_bridge(city: Dictionary,sim: Dictionary,axis: String,coordinate: int) -> String:
    if not can_bridge(sim,axis,coordinate):return "Silda ei saa sinna jõelõigule ehitada."
    var stock: Dictionary=city.get("realms",[])[0].get("resources",{})
    if float(stock.get("wood",0))<Legacy.BRIDGE_COST["wood"] or float(stock.get("stone",0))<Legacy.BRIDGE_COST["stone"]:
        return "Silla jaoks on vaja 28 puitu ja 18 kivi."
    stock["wood"]=float(stock["wood"])-float(Legacy.BRIDGE_COST["wood"])
    stock["stone"]=float(stock["stone"])-float(Legacy.BRIDGE_COST["stone"])
    if not sim.has("bridges"):sim["bridges"]=[]
    sim["bridges"].append({"x":coordinate,"axis":axis})
    # Every old route may have crossed a new obstacle/previous crossing.
    # Invalidate route caches on all local transit agents separately.
    for agent in city.get("transport_v26",{}).get("agents",[]):
        agent["route"]=[]
        agent.erase("path_version")
    return ""

static func elevation(sim: Dictionary,x: float,z: float) -> float:
    if not enabled(sim):return Legacy.elevation(sim,x,z)
    var point:=Vector2(x,z)
    var cross: Dictionary=crossing_at(sim,point)
    if not cross.is_empty() and String(cross["kind"])=="bridge":
        return maxf(0.55,ground(sim,x,z)+0.55)
    return ground(sim,x,z)
