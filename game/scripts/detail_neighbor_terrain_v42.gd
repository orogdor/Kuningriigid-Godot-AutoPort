extends RefCounted
## AutoPort 0.42 — seamless neighboring world-tile relief, using world
## coordinates instead of independent flat proxy boxes. Lightweight 3D
## mesh and instanced environmental props keep 720x420 Android viable.
const World=preload("res://scripts/world_gen_v06.gd")
const Terrain=preload("res://scripts/detail_terrain_v10.gd")
const WebPalette50=preload("res://scripts/web_biomes_v50.gd")
const WebArt50=preload("res://scripts/web_graphics_v50.gd")
const WIDTH: float=225.0
const DEPTH: float=195.0
const NX: int=12
const NZ: int=10

static func base_height(cell: Dictionary) -> float:
    return clampf(float(cell.get("h",0.0))*0.02,-1.0,1.7)

static func _sample_base(world: Dictionary,c: int,r: int) -> float:
    var point: Dictionary=World.cell(world,c,r)
    if point.is_empty():
        point=World.cell(world,clampi(c,0,World.COLS-1),
            clampi(r,0,World.ROWS-1))
    return base_height(point)

static func height_at(world: Dictionary,tile: Vector2i,x: float,z: float) -> float:
    # World-coordinate bilinear sampling gives EXACTLY the same height
    # at two adjacent borders, including diagonal/corner transitions.
    var wx: float=float(tile.x)+x/WIDTH
    var wz: float=float(tile.y)+z/DEPTH
    var cx: int=int(floor(wx))
    var cz: int=int(floor(wz))
    var fx: float=wx-float(cx)
    var fz: float=wz-float(cz)
    var h0: float=lerpf(_sample_base(world,cx,cz),_sample_base(world,cx+1,cz),fx)
    var h1: float=lerpf(_sample_base(world,cx,cz+1),_sample_base(world,cx+1,cz+1),fx)
    var shared: float=lerpf(h0,h1,fz)
    var ripple: float=sin(wx*10.35+float(world.get("seed",0))*0.0001)*cos(wz*12.48)*1.1
    return shared+ripple

# Keep the real simulated (buildable) city floor and its bridges/river fords
# untouched in the central area. Outside that, blend to the world-coordinate
# relief at the shared 225 x 195 m borders. The city can now visibly connect
# to all eight preview squares without a cliff at the map seam.
const CITY_EDGE_BLEND: float=30.0

static func city_edge_weight(x: float,z: float,
        width: float=WIDTH,depth: float=DEPTH) -> float:
    var margin_x: float=width*0.5-absf(x)
    var margin_z: float=depth*0.5-absf(z)
    var margin: float=minf(margin_x,margin_z)
    return 1.0-smoothstep(0.0,CITY_EDGE_BLEND,maxf(0.0,margin))

static func city_height_at(world: Dictionary,tile: Vector2i,
        sim: Dictionary,x: float,z: float) -> float:
    var local_height: float=Terrain.elevation(sim,x,z)
    var blend: float=city_edge_weight(x,z)
    if blend<=0.0:return local_height
    return lerpf(local_height,height_at(world,tile,x,z),blend)

static func color_for(cell: Dictionary) -> Color:
    var biome: String=String(cell.get("biome","sea"))
    if biome=="forest":return Color("#547b4e")
    if biome=="hills":return Color("#999b91")
    if biome=="sea":return Color("#b8ac80")
    return Color("#86a769")

static func surface(world: Dictionary,tile: Vector2i,label: String="NeighborTerrain",
        subdivisions_x: int=NX,subdivisions_z: int=NZ) -> MeshInstance3D:
    var ground:=MeshInstance3D.new()
    ground.name=label
    var cell: Dictionary=World.cell(world,tile.x,tile.y)
    if cell.is_empty():return ground
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for iz in range(subdivisions_z):
        for ix in range(subdivisions_x):
            var x0: float=(-0.5+float(ix)/float(subdivisions_x))*WIDTH
            var x1: float=(-0.5+float(ix+1)/float(subdivisions_x))*WIDTH
            var z0: float=(-0.5+float(iz)/float(subdivisions_z))*DEPTH
            var z1: float=(-0.5+float(iz+1)/float(subdivisions_z))*DEPTH
            var a:=Vector3(x0,height_at(world,tile,x0,z0),z0)
            var b:=Vector3(x1,height_at(world,tile,x1,z0),z0)
            var d:=Vector3(x0,height_at(world,tile,x0,z1),z1)
            var e:=Vector3(x1,height_at(world,tile,x1,z1),z1)
            var tint: Color=WebPalette50.detail(world,tile,
                (x0+x1)*0.5,(z0+z1)*0.5)
            for v in [a,b,d,b,e,d]:
                tool.set_color(tint)
                tool.add_vertex(v)
    tool.generate_normals()
    ground.mesh=tool.commit()
    var mat:=StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo=true
    mat.roughness=0.98
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    ground.material_override=mat
    return ground

static func _instanced(parent: Node3D,world: Dictionary,tile: Vector2i,
        count: int,mesh: Mesh,color: Color,label: String,y_offset: float) -> void:
    if count<=0:return
    var inst:=MultiMeshInstance3D.new()
    inst.name=label
    var batch:=MultiMesh.new()
    batch.transform_format=MultiMesh.TRANSFORM_3D
    batch.mesh=mesh
    batch.instance_count=count
    var rng:=RandomNumberGenerator.new()
    rng.seed=int(world.get("seed",82026))+tile.x*10007+tile.y*19937
    for i in range(count):
        var x: float=rng.randf_range(-WIDTH*0.44,WIDTH*0.44)
        var z: float=rng.randf_range(-DEPTH*0.43,DEPTH*0.43)
        var h: float=height_at(world,tile,x,z)+y_offset
        var scl: float=rng.randf_range(0.82,1.32)
        batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scl),
            Vector3(x,h,z)))
    inst.multimesh=batch
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=1.0
    inst.material_override=mat
    parent.add_child(inst)

static func decorate(parent: Node3D,world: Dictionary,tile: Vector2i) -> void:
    var cell: Dictionary=World.cell(world,tile.x,tile.y)
    if cell.is_empty() or not bool(cell.get("land",false)):return
    # Deterministic, but reuse the REAL Web mesh surfaces rather than
    # paired spheres/cylinders. One MultiMesh per source GLB part.
    var biome: String=String(cell.get("biome","plains"))
    var oak: Array=[]
    var pine: Array=[]
    var rock: Array=[]
    var rng:=RandomNumberGenerator.new()
    rng.seed=int(world.get("seed",82026))+tile.x*10007+tile.y*19937
    var count: int=11 if biome=="forest" else (4 if biome=="hills" else 6)
    for i in range(count):
        var x: float=rng.randf_range(-WIDTH*0.43,WIDTH*0.43)
        var z: float=rng.randf_range(-DEPTH*0.43,DEPTH*0.43)
        var scale: float=rng.randf_range(2.3,3.6)
        var pose:=Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(
            Vector3.ONE*scale),Vector3(x,height_at(world,tile,x,z),z))
        if biome=="hills" or i%4==0:pine.append(pose)
        else:oak.append(pose)
    for i in range(9 if biome=="hills" else 3):
        var x: float=rng.randf_range(-WIDTH*0.45,WIDTH*0.45)
        var z: float=rng.randf_range(-DEPTH*0.45,DEPTH*0.45)
        var size: float=rng.randf_range(2.2,4.0)
        rock.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(
            Vector3.ONE*size),Vector3(x,height_at(world,tile,x,z),z)))
    WebArt50.add_batch(parent,"oak",oak,"WebOriginalOaks")
    WebArt50.add_batch(parent,"pine",pine,"WebOriginalPines")
    WebArt50.add_batch(parent,"rock",rock,"WebOriginalRocks")
