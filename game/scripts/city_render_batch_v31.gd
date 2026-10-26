extends RefCounted
## 0.31 render-only MultiMesh batches. Never changes finite resource sites,
## resource ownership or the 0.26 worker navigation.
const Terrain=preload("res://scripts/continuous_terrain_v28.gd")
const MAX_INSTANCES: int=1024

static func _material(color: Color) -> StandardMaterial3D:
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=0.95
    return mat

static func _mesh(kind: String) -> PrimitiveMesh:
    if kind=="trunks":
        var cyl:=CylinderMesh.new()
        cyl.top_radius=0.47
        cyl.bottom_radius=0.47
        cyl.height=4.4
        cyl.material=_material(Color("#6d4a2b"))
        return cyl
    var ball:=SphereMesh.new()
    if kind=="foliage":
        ball.radius=2.4
        ball.height=4.8
        ball.material=_material(Color("#315e37"))
    else:
        ball.radius=1.6
        ball.height=1.6
        ball.material=_material(Color("#787b76"))
    ball.radial_segments=8
    ball.rings=4
    return ball

static func eligible(sites: Array,limit: int) -> Array:
    var result: Array=[]
    if limit<=0:return result
    for site in sites:
        if result.size()>=limit:break
        if float(site.get("remaining",0))<=0.0:continue
        if String(site.get("kind","")) not in ["wood","stone"]:continue
        result.append(site)
    return result

static func signature(sites: Array,limit: int) -> String:
    var signature_parts: Array=[]
    for site in eligible(sites,limit):
        signature_parts.append([site.get("id",0),String(site.get("kind","")),
            int(floor(float(site.get("remaining",0))/10.0))])
    return JSON.stringify(signature_parts)

static func _batch(parent: Node3D,label: String,kind: String,positions: Array) -> void:
    if positions.is_empty():return
    var count: int=mini(positions.size(),MAX_INSTANCES)
    var mm:=MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.mesh=_mesh(kind)
    mm.instance_count=count
    for n in range(count):
        var data: Dictionary=positions[n]
        var factor: float=float(data.get("scale",1.0))
        var position: Vector3=data["position"]
        mm.set_instance_transform(n,Transform3D(Basis().scaled(Vector3.ONE*factor),position))
    var node:=MultiMeshInstance3D.new()
    node.name=label
    node.multimesh=mm
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)

static func populate(parent: Node3D,sites: Array,limit: int,
        world: Dictionary={},tile: Vector2i=Vector2i(-1,-1),
        use_elevation: bool=false) -> int:
    var wood: Array=[]
    var leaves: Array=[]
    var stones: Array=[]
    var drawn: int=0
    for site in eligible(sites,limit):
        var pos:=Vector3(float(site.get("x",0)),0.0,float(site.get("z",0)))
        if use_elevation:
            pos.y=Terrain.height(world,tile,pos.x,pos.z)
        var remain: float=float(site.get("remaining",0))
        if String(site.get("kind",""))=="wood":
            var factor: float=clampf(remain/35.0,0.3,1.1)
            wood.append({"position":pos+Vector3(0,2.2*factor,0),"scale":factor})
            leaves.append({"position":pos+Vector3(0,5.5*factor,0),"scale":factor})
        else:
            var factor: float=clampf(remain/45.0,0.4,1.0)
            for i in range(3):
                stones.append({"position":pos+Vector3((i-1)*1.9,0.35*factor,
                    ((i%2)*2-1)*1.4),"scale":factor})
        drawn+=1
    _batch(parent,"BatchTrunks","trunks",wood)
    _batch(parent,"BatchFoliage","foliage",leaves)
    _batch(parent,"BatchRocks","rocks",stones)
    return drawn

static func draw_units_for(sites: Array,limit: int) -> int:
    var has_wood: bool=false
    var has_stone: bool=false
    for site in eligible(sites,limit):
        if String(site.get("kind",""))=="wood":has_wood=true
        else:has_stone=true
    return (2 if has_wood else 0)+(1 if has_stone else 0)

static func node_count(root: Node) -> int:
    if root==null:return 0
    var total: int=1
    for child in root.get_children():total+=node_count(child)
    return total
