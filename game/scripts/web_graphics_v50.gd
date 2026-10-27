extends RefCounted
## Imported geometry from the very same original Three.js GLB files.
## Draw-only: no economics, routes or map seed mutations.
const World=preload("res://scripts/world_gen_v06.gd")
const OAK=preload("res://assets/web50/oak.glb")
const PINE=preload("res://assets/web50/pine.glb")
const ROCK=preload("res://assets/web50/rock.glb")
const HOUSE=preload("res://assets/web50/timber_house.glb")
const MARKET=preload("res://assets/web50/market.glb")
const WINDMILL=preload("res://assets/web50/windmill.glb")
const FOREST=preload("res://assets/web50/forest_cluster.glb")
const OUTCROP=preload("res://assets/web50/rock_outcrop.glb")
const VILLAGE=preload("res://assets/web50/world_village.glb")
const RUIN=preload("res://assets/web50/ancient_ruin.glb")
const MAX_ATLAS_FORESTS: int=190
const MAX_ATLAS_ROCKS: int=90

static func asset(kind: String) -> PackedScene:
    match kind:
        "oak":return OAK
        "pine":return PINE
        "rock":return ROCK
        "timber_house":return HOUSE
        "market":return MARKET
        "windmill":return WINDMILL
        "forest_cluster":return FOREST
        "rock_outcrop":return OUTCROP
        "world_village":return VILLAGE
        "ancient_ruin":return RUIN
    return null

static func place(parent: Node3D,kind: String,position: Vector3,
        size: float=1.0,label: String="OriginalWebModel") -> Node3D:
    var group:=Node3D.new()
    group.name=label
    group.position=position
    parent.add_child(group)
    var packed: PackedScene=asset(kind)
    if packed!=null:
        var model: Node3D=packed.instantiate() as Node3D
        model.name="WebGLB"
        model.scale=Vector3.ONE*size
        group.add_child(model)
    return group

static func _pieces(node: Node,accumulated: Transform3D,result: Array) -> void:
    var tx: Transform3D=accumulated
    if node is Node3D:
        tx=accumulated*(node as Node3D).transform
    if node is MeshInstance3D:
        var mesh: Mesh=(node as MeshInstance3D).mesh
        if mesh!=null:
            result.append({"mesh":mesh,"transform":tx})
    for child in node.get_children():
        _pieces(child,tx,result)

static func add_batch(parent: Node3D,kind: String,poses: Array,
        label: String="OriginalWebBatch") -> Node3D:
    var group:=Node3D.new()
    group.name=label
    group.set_meta("web_model",kind)
    group.set_meta("placements",poses.size())
    parent.add_child(group)
    var packed: PackedScene=asset(kind)
    if packed==null or poses.is_empty():return group
    var original: Node=packed.instantiate()
    var components: Array=[]
    _pieces(original,Transform3D.IDENTITY,components)
    original.free()
    for index in range(components.size()):
        var part: Dictionary=components[index]
        var batch:=MultiMesh.new()
        batch.transform_format=MultiMesh.TRANSFORM_3D
        batch.mesh=part["mesh"]
        batch.instance_count=poses.size()
        var local: Transform3D=part["transform"]
        for i in range(poses.size()):
            var placement: Transform3D=poses[i]
            batch.set_instance_transform(i,placement*local)
        var draw:=MultiMeshInstance3D.new()
        draw.name="WebMesh_"+str(index)
        draw.multimesh=batch
        draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        group.add_child(draw)
    return group

static func _corner(world: Dictionary,c: int,r: int) -> float:
    var height: float=0.0
    var count: int=0
    for dz in [-1,0]:
        for dx in [-1,0]:
            var cell: Dictionary=World.cell(world,c+dx,r+dz)
            if cell.is_empty():continue
            height+=maxf(-4.0,float(cell.get("h",0))*0.33)
            count+=1
    return height/float(maxi(count,1))

static func atlas_y(world: Dictionary,c: int,r: int) -> float:
    return (_corner(world,c,r)+_corner(world,c+1,r)+
        _corner(world,c,r+1)+_corner(world,c+1,r+1))*0.25

static func atlas_decor(parent: Node3D,world: Dictionary) -> Dictionary:
    var forests: Array=[]
    var outcrops: Array=[]
    var ruins: Array=[]
    var settlements: Array=[]
    var seed: int=int(world.get("seed",82026))
    # Spatially sparse and GPU-instanced. Native material and colours remain
    # embedded in the imported Web assets (not one draw call per tree).
    for r in range(4,World.ROWS-4,5):
        for c in range(4,World.COLS-4,5):
            var cell: Dictionary=World.cell(world,c,r)
            if cell.is_empty() or not bool(cell.get("land",false)) or \
                    bool(cell.get("river",false)):continue
            var biome: String=String(cell.get("biome",""))
            var rand:=RandomNumberGenerator.new()
            rand.seed=seed+c*7213+r*14489
            var site:=Vector3(float(c)+rand.randf_range(0.2,0.8),
                atlas_y(world,c,r)+0.1,float(r)+rand.randf_range(0.2,0.8))
            if biome=="forest" and forests.size()<MAX_ATLAS_FORESTS:
                forests.append(Transform3D(
                    Basis(Vector3.UP,rand.randf_range(-PI,PI)).scaled(
                        Vector3.ONE*rand.randf_range(0.09,0.14)),site))
            elif biome=="hills" and outcrops.size()<MAX_ATLAS_ROCKS:
                outcrops.append(Transform3D(
                    Basis(Vector3.UP,rand.randf_range(-PI,PI)).scaled(
                        Vector3.ONE*rand.randf_range(0.10,0.15)),site))
            elif biome=="plains" and ruins.size()<10 and rand.randf()<0.016:
                ruins.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.13),site))
    # Only actual starting locations get Web settlement icons; never add fake
    # economic towns or make the procedural ruin decorations navigable cities.
    for entry in world.get("starts",[]):
        var c: int=int(entry.get("c",-1))
        var r: int=int(entry.get("r",-1))
        if World.cell(world,c,r).is_empty():continue
        settlements.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.11),
            Vector3(float(c)+0.5,atlas_y(world,c,r)+0.1,float(r)+0.5)))
    add_batch(parent,"forest_cluster",forests,"WebForestClusters")
    add_batch(parent,"rock_outcrop",outcrops,"WebRockOutcrops")
    add_batch(parent,"ancient_ruin",ruins,"WebAncientRuins")
    add_batch(parent,"world_village",settlements,"WebWorldSettlements")
    return {"forest":forests.size(),"rocks":outcrops.size(),
        "ruins":ruins.size(),"settlements":settlements.size()}
