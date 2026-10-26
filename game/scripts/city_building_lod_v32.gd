extends RefCounted
## 0.32: combine passive-district building silhouettes into a few MultiMesh
## batches at distance. Economic buildings and real construction remain
## untouched. LOD changes are render-only and never enter JSON saves.
const SIZE_BY_TYPE={
    "hall":Vector3(18,9,16),
    "house":Vector3(10,6,9),
    "lumber":Vector3(13,7,11),
    "quarry":Vector3(13,6,12),
    "well":Vector3(5,4,5),
    "farm":Vector3(17,3,15),
    "market":Vector3(19,7,16),
    "storage":Vector3(15,7,12),
    "fisher":Vector3(12,6,11),
    "shipyard":Vector3(19,7,18),
}
const COLORS={
    "hall":Color("#bca78c"),
    "house":Color("#c29e72"),
    "lumber":Color("#816b49"),
    "quarry":Color("#898b8a"),
    "well":Color("#79a5b0"),
    "farm":Color("#9d9a62"),
    "market":Color("#b98e76"),
    "storage":Color("#a69c87"),
    "fisher":Color("#9a8a73"),
    "shipyard":Color("#8c917f"),
    "far":Color("#b4a18c")
}

static func size_of(kind: String,level: int) -> Vector3:
    var full: Vector3=SIZE_BY_TYPE.get(kind,Vector3(12,6,11))
    if level<=0:return Vector3(11,5,10)
    return full

static func role(kind: String,ready: bool,level: int) -> String:
    if level<=0:return "far"
    return kind if ready else "building_site"

static func _shader(color: Color) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new()
    material.albedo_color=color
    material.roughness=1.0
    material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
    return material

static func eligible(buildings: Array,district: String) -> Array:
    var included: Array=[]
    for building in buildings:
        if String(building.get("district",""))!=district:continue
        if float(building.get("hp",1.0))<=0.0:continue
        included.append(building)
    return included

static func signature(buildings: Array,district: String,level: int) -> String:
    var data: Array=[]
    for b in eligible(buildings,district):
        data.append([String(b.get("type","house")),bool(b.get("ready",false)),
            float(b.get("x",0)),float(b.get("z",0)),
            float(b.get("rotation",0)),int(b.get("hp",1))>0])
    return str(level)+":"+JSON.stringify(data)

static func expected_batches(buildings: Array,district: String,level: int) -> int:
    var roles: Dictionary={}
    for b in eligible(buildings,district):
        roles[role(String(b.get("type","house")),bool(b.get("ready",false)),level)]=true
    return roles.size()

static func populate(parent: Node3D,buildings: Array,district: String,level: int) -> int:
    var clusters: Dictionary={}
    for b in eligible(buildings,district):
        var kind: String=String(b.get("type","house"))
        var name: String=role(kind,bool(b.get("ready",false)),level)
        if not clusters.has(name):clusters[name]=[]
        clusters[name].append(b)
    var total: int=0
    for category in clusters.keys():
        var entries: Array=clusters[category]
        if entries.is_empty():continue
        var cube:=BoxMesh.new()
        cube.size=Vector3.ONE
        cube.material=_shader(COLORS.get(String(category),Color("#9e917e")))
        var mm:=MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.mesh=cube
        mm.instance_count=entries.size()
        for i in range(entries.size()):
            var b: Dictionary=entries[i]
            var size: Vector3=size_of(String(b.get("type","house")),level)
            if not bool(b.get("ready",false)):size.y=maxf(0.45,size.y*0.28)
            var angle: float=deg_to_rad(float(b.get("rotation",0)))
            var basis: Basis=Basis(Vector3.UP,angle).scaled(size)
            var pos:=Vector3(float(b.get("x",0)),size.y*0.5,float(b.get("z",0)))
            mm.set_instance_transform(i,Transform3D(basis,pos))
            total+=1
        var mesh:=MultiMeshInstance3D.new()
        mesh.name="BuildingLOD_"+String(category)
        mesh.multimesh=mm
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(mesh)
    return total

static func visible_at(distance_to_focus: float,zoom: float,is_active: bool=false) -> bool:
    if is_active:return true
    return distance_to_focus<=maxf(515.0,zoom*1.6+195.0)

static func level_for_distance(distance_to_focus: float,zoom: float) -> int:
    # Wide city overviews keep all terrain visible, but use simplified
    # silhouettes for buildings outside the nearby district.
    if distance_to_focus<195.0 and zoom<400.0:return 2
    if distance_to_focus<335.0 and zoom<700.0:return 1
    return 0
