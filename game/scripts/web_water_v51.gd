extends RefCounted
## Godot 0.51: 3D river graphics from REAL world_gen_v06 drainage, not random
## painted terrain stripes. Based on the Web landscape continuous-water
## visual approach; preserves source river_to, economic rules and saves.
const World=preload("res://scripts/world_gen_v06.gd")
const WebPalette=preload("res://scripts/web_biomes_v50.gd")
const WebArt=preload("res://scripts/web_graphics_v50.gd")
const DetailTerrain=preload("res://scripts/detail_neighbor_terrain_v42.gd")
const CARDINAL: Array[Vector2i]=[
    Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)
]
const BANK_COLOR: Color=Color("#9aab86")

static func downstream(world: Dictionary,c: int,r: int) -> Vector2i:
    var cell: Dictionary=World.cell(world,c,r)
    if cell.is_empty() or not bool(cell.get("river",false)):
        return Vector2i(-1,-1)
    var next_index: int=int(cell.get("river_to",-1))
    if next_index<0 or next_index>=World.COLS*World.ROWS:
        return Vector2i(-1,-1)
    var target:=Vector2i(next_index%World.COLS,int(next_index/World.COLS))
    if absi(target.x-c)+absi(target.y-r)!=1:
        return Vector2i(-1,-1)
    return target

static func water_half_width(flow: int,scale: float=1.0) -> float:
    # Same flow must give the same width on BOTH sides of a detail border.
    return clampf(0.052+sqrt(maxf(1.0,float(flow)))*0.0041,0.06,0.20)*scale

static func _quad(vertices: PackedVector3Array,colors: PackedColorArray,
        a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
    for point in [a,c,b,b,c,d]:
        vertices.append(point)
        colors.append(tint)

static func _segment(water_vertices: PackedVector3Array,water_colors: PackedColorArray,
        bank_vertices: PackedVector3Array,bank_colors: PackedColorArray,
        start: Vector3,finish: Vector3,half_width: float,land_color: Color,
        water_color: Color) -> void:
    var delta:=Vector2(finish.x-start.x,finish.z-start.z)
    if delta.length_squared()<0.0001:return
    var tangent: Vector2=delta.normalized()
    var across:=Vector3(-tangent.y,0.0,tangent.x)
    var bank_width: float=maxf(0.025,half_width*0.48)
    var sa: Vector3=start+across*half_width
    var sb: Vector3=start-across*half_width
    var ea: Vector3=finish+across*half_width
    var eb: Vector3=finish-across*half_width
    _quad(water_vertices,water_colors,sa,sb,ea,eb,water_color)
    var outside: float=half_width+bank_width
    _quad(bank_vertices,bank_colors,
        start+across*outside,sa,finish+across*outside,ea,land_color)
    _quad(bank_vertices,bank_colors,
        sb,start-across*outside,eb,finish-across*outside,land_color)

static func _surface(name: String,vertices: PackedVector3Array,
        colors: PackedColorArray,opacity: float) -> MeshInstance3D:
    var result:=MeshInstance3D.new()
    result.name=name
    if vertices.is_empty():return result
    var arrays: Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_COLOR]=colors
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    result.mesh=mesh
    var material:=StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.roughness=0.36 if opacity<1.0 else 0.96
    if opacity<1.0:
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        material.albedo_color=Color(1.0,1.0,1.0,opacity)
    result.material_override=material
    result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return result

static func _group(label: String,river_vertices: PackedVector3Array,
        river_colors: PackedColorArray,bank_vertices: PackedVector3Array,
        bank_colors: PackedColorArray,count: int) -> Node3D:
    var group:=Node3D.new()
    group.name=label
    group.set_meta("river_segments",count)
    if count>0:
        group.add_child(_surface("WebRiverBanks51",bank_vertices,bank_colors,1.0))
        group.add_child(_surface("WebRiverWater51",river_vertices,river_colors,0.94))
    return group

static func atlas(world: Dictionary) -> Node3D:
    # One batched river and one batched bank mesh for the whole atlas.
    # Each segment ends at the exact center where the next begins.
    var water_vertices:=PackedVector3Array()
    var water_colors:=PackedColorArray()
    var bank_vertices:=PackedVector3Array()
    var bank_colors:=PackedColorArray()
    var count: int=0
    if world.is_empty():
        return _group("WebWorldRiverNetwork51",water_vertices,water_colors,
            bank_vertices,bank_colors,count)
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var to: Vector2i=downstream(world,c,r)
            if to.x<0:continue
            var cell: Dictionary=World.cell(world,c,r)
            var other: Dictionary=World.cell(world,to.x,to.y)
            var w: float=water_half_width(int(cell.get("river_flow",40)))
            var start:=Vector3(float(c)+0.5,WebArt.atlas_y(world,c,r)+0.18,float(r)+0.5)
            var finish:=Vector3(float(to.x)+0.5,
                WebArt.atlas_y(world,to.x,to.y)+0.18,float(to.y)+0.5)
            var water_tint: Color=WebPalette.RIVER.lerp(WebPalette.SHALLOW,
                0.55 if not bool(other.get("land",true)) else 0.12)
            _segment(water_vertices,water_colors,bank_vertices,bank_colors,
                start,finish,w,BANK_COLOR,water_tint)
            count+=1
    return _group("WebWorldRiverNetwork51",water_vertices,water_colors,
        bank_vertices,bank_colors,count)

static func border_height(world: Dictionary,tile: Vector2i,
        x: float,z: float) -> float:
    return DetailTerrain.height_at(world,tile,x,z)

static func detail(world: Dictionary,tile: Vector2i,
        width: float=DetailTerrain.WIDTH,depth: float=DetailTerrain.DEPTH) -> Node3D:
    var water_vertices:=PackedVector3Array()
    var water_colors:=PackedColorArray()
    var bank_vertices:=PackedVector3Array()
    var bank_colors:=PackedColorArray()
    var count: int=0
    var cell: Dictionary=World.cell(world,tile.x,tile.y)
    var label: String="WebDetailRiverNetwork51"
    if cell.is_empty() or world.is_empty():
        return _group(label,water_vertices,water_colors,bank_vertices,bank_colors,count)
    var tile_index: int=tile.y*World.COLS+tile.x
    var strips: Array=[]
    var target: Vector2i=downstream(world,tile.x,tile.y)
    if target.x>=0:
        var heading: Vector2i=target-tile
        strips.append({"from":Vector2.ZERO,
            "to":Vector2(float(heading.x)*width*0.5,
                float(heading.y)*depth*0.5),
            "flow":int(cell.get("river_flow",40)),
            "mouth":not bool(World.cell(world,target.x,target.y).get("land",true))})
    for direction in CARDINAL:
        var from_tile: Vector2i=tile+direction
        var source_cell: Dictionary=World.cell(world,from_tile.x,from_tile.y)
        if source_cell.is_empty():continue
        if int(source_cell.get("river_to",-1))!=tile_index or \
                not bool(source_cell.get("river",false)):continue
        strips.append({"from":Vector2(float(direction.x)*width*0.5,
                float(direction.y)*depth*0.5),"to":Vector2.ZERO,
                "flow":int(source_cell.get("river_flow",40)),
                "mouth":not bool(cell.get("land",true))})
    for entry in strips:
        var a: Vector2=entry["from"]
        var b: Vector2=entry["to"]
        var start:=Vector3(a.x,border_height(world,tile,a.x,a.y)+0.18,a.y)
        var finish:=Vector3(b.x,border_height(world,tile,b.x,b.y)+0.18,b.y)
        var half: float=water_half_width(int(entry["flow"]),
            minf(width,depth))
        var tint: Color=WebPalette.RIVER.lerp(WebPalette.SHALLOW,
            0.6 if bool(entry["mouth"]) else 0.13)
        _segment(water_vertices,water_colors,bank_vertices,bank_colors,
            start,finish,half,BANK_COLOR,tint)
        count+=1
    return _group(label,water_vertices,water_colors,bank_vertices,bank_colors,count)
