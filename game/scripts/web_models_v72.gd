extends RefCounted
## AutoPort 0.72: the exact V299 Three.js assets. Imported at build time
## from one pinned upstream revision; no 338MB of obsolete test versions.
## V262 TRELLIS warrior meshes are NOT rigged. Use them for atlas/detail
## visuals, keeping animated V148 GLBs in the combat renderer.
const UNIT_PATHS: Dictionary={
    "axeman":"res://assets/web72/unit/axeman.glb",
    "spearman":"res://assets/web72/unit/spearman.glb",
    "slinger":"res://assets/web72/unit/slinger.glb"
}
const BUILDING_MAP: Dictionary={
    "hall":"peamaja", "house":"house", "lumber":"lumber",
    "well":"well", "quarry":"quarry", "farm":"farm",
    "fisher":"fisher", "hunter":"hunter", "barracks":"barracks",
    "archery":"archery", "pasture":"pasture", "mason":"mason",
    "claypit":"claypit", "pottery_kiln":"pottery_kiln",
    "study":"study", "watchtower":"watchtower",
    "palisade":"palisade", "woodgate":"woodgate"
}
const WIDTHS: Dictionary={
    "hall":19.0, "house":12.0, "lumber":14.0,
    "well":8.0, "quarry":13.0, "farm":19.0
}

static func packed(category: String, name: String) -> PackedScene:
    if not ["unit","building","world","nature"].has(category):return null
    if name.find("/")!=-1 or name.find("\\")!=-1 or name.find("..")!=-1:return null
    var path: String="res://assets/web72/"+category+"/"+name+".glb"
    if not ResourceLoader.exists(path):return null
    var resource: Resource=load(path)
    return resource as PackedScene if resource is PackedScene else null

static func _measure(node: Node, transform: Transform3D, result: Dictionary) -> void:
    var tx: Transform3D=transform
    if node is Node3D:tx=transform*(node as Node3D).transform
    if node is MeshInstance3D:
        var mesh: Mesh=(node as MeshInstance3D).mesh
        if mesh!=null:
            var bounds: AABB=mesh.get_aabb()
            for ix in range(2):
                for iy in range(2):
                    for iz in range(2):
                        var pos: Vector3=bounds.position+bounds.size*Vector3(ix,iy,iz)
                        var pt: Vector3=tx*pos
                        result["min"]=(result["min"] as Vector3).min(pt)
                        result["max"]=(result["max"] as Vector3).max(pt)
            result["meshes"]=int(result["meshes"])+1
    for child in node.get_children():_measure(child,tx,result)

static func _instance(category: String, name: String,
        label: String, target: float, vertical: bool) -> Node3D:
    var asset: PackedScene=packed(category,name)
    if asset==null:return null
    var model: Node3D=asset.instantiate() as Node3D
    if model==null:return null
    var bounds: Dictionary={"min":Vector3(INF,INF,INF),
        "max":Vector3(-INF,-INF,-INF), "meshes":0}
    _measure(model,Transform3D.IDENTITY,bounds)
    if int(bounds["meshes"])<1:
        model.free()
        return null
    var bottom: Vector3=bounds["min"]
    var top: Vector3=bounds["max"]
    var original_size: Vector3=top-bottom
    var original_span: float=original_size.y if vertical else \
        maxf(original_size.x,original_size.z)
    if original_span<=0.00001 or not is_finite(original_span):
        model.free()
        return null
    var scale_factor: float=target/original_span
    var group:=Node3D.new()
    group.name=label
    group.set_meta("source_glb","res://assets/web72/"+category+"/"+name+".glb")
    group.set_meta("original_scale",scale_factor)
    group.add_child(model)
    model.scale=Vector3.ONE*scale_factor
    model.position=Vector3(-(bottom.x+top.x)*0.5*scale_factor,
        -bottom.y*scale_factor,-(bottom.z+top.z)*0.5*scale_factor)
    return group

static func unit_instance(kind: String,height: float=2.7) -> Node3D:
    if not UNIT_PATHS.has(kind):return null
    var unit: Node3D=_instance("unit",kind,"WebV299Unit_"+kind,height,true)
    if unit!=null:
        unit.set_meta("unrigged_trellis_v262",true)
    return unit

static func city_instance(kind: String,place: Vector3) -> Node3D:
    if not BUILDING_MAP.has(kind):return null
    var variant: String=String(BUILDING_MAP[kind])
    var model: Node3D=_instance("building",variant,
        "WebV299Building_"+kind,float(WIDTHS.get(kind,12.0)),false)
    if model!=null:model.position=place
    return model
