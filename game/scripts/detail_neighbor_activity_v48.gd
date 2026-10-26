extends RefCounted
## AutoPort 0.48: read-only live road / worker 3D previews for BOTH towns.
## Traffic must originate from the same A* traversals and spatial simulation
## as the active detail view. Nothing here writes to the saved game state.
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Relief=preload("res://scripts/detail_neighbor_terrain_v42.gd")
const MAX_ROADS: int=120
const MAX_WORKERS: int=24

static func snapshot(town: Dictionary,district: String="") -> Dictionary:
    var result: Dictionary={"roads":[],"workers":[]}
    if district!="":return result # Annexed district uses its own city renderer.
    var sim: Dictionary=town.get("detail_sim",{})
    if sim.is_empty():return result
    var roads: Array=[]
    for item in Paths.road_tiles(sim):
        if roads.size()>=MAX_ROADS:break
        roads.append({"x":float(item["x"]),"z":float(item["z"]),
            "strength":int(item["strength"])})
    result["roads"]=roads
    var people: Array=[]
    for worker in sim.get("workers",[]):
        if people.size()>=MAX_WORKERS:break
        var x: float=float(worker.get("x",0.0))
        var z: float=float(worker.get("z",0.0))
        if not is_finite(x) or not is_finite(z):continue
        people.append({"x":x,"z":z,"kind":String(worker.get("kind","worker"))})
    for worker in sim.get("builders",[]):
        if people.size()>=MAX_WORKERS:break
        var x: float=float(worker.get("x",0.0))
        var z: float=float(worker.get("z",0.0))
        if not is_finite(x) or not is_finite(z):continue
        people.append({"x":x,"z":z,"kind":"builder"})
    result["workers"]=people
    return result

static func signature(data: Dictionary) -> String:
    return JSON.stringify(data)

static func _color(hex: String) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=Color(hex)
    m.roughness=0.95
    return m

static func _instances(parent: Node3D,label: String,geometry: Mesh,
        material: Material,positions: Array,world: Dictionary,tile: Vector2i,
        sim: Dictionary,scale: Vector3,y_offset: float) -> void:
    if positions.is_empty():return
    var mm:=MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.mesh=geometry
    mm.instance_count=positions.size()
    for i in range(positions.size()):
        var obj: Dictionary=positions[i]
        var x: float=float(obj["x"])
        var z: float=float(obj["z"])
        var y: float=Relief.city_height_at(world,tile,sim,x,z)
        mm.set_instance_transform(i,Transform3D(Basis().scaled(scale),
            Vector3(x,y+y_offset,z)))
    var drawing:=MultiMeshInstance3D.new()
    drawing.name=label
    drawing.multimesh=mm
    drawing.material_override=material
    drawing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(drawing)

static func populate(parent: Node3D,data: Dictionary,world: Dictionary,
        tile: Vector2i,town: Dictionary) -> void:
    var sim: Dictionary=town.get("detail_sim",{})
    if sim.is_empty():return
    var roads: Array=data.get("roads",[])
    var people: Array=data.get("workers",[])
    var path_shape:=BoxMesh.new()
    path_shape.size=Vector3.ONE
    _instances(parent,"ActualNeighborRoadTiles",path_shape,_color("#b89b70"),
        roads,world,tile,sim,Vector3(7.5,0.12,7.5),0.18)
    var worker_shape:=CylinderMesh.new()
    worker_shape.top_radius=0.42
    worker_shape.bottom_radius=0.55
    worker_shape.height=2.35
    _instances(parent,"ActualNeighborWorkers",worker_shape,_color("#8e7659"),
        people,world,tile,sim,Vector3.ONE,1.24)
