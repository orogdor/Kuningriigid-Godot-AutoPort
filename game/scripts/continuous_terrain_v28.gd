extends RefCounted
## 0.28 seam-safe shared terrain. Every border samples identical global world
## coordinates; river ribbons connect only when BOTH adjoining world cells
## have a river. 3D visuals approximate, not a replacement for 0.26 A* rules.
const World=preload("res://scripts/world_gen_v06.gd")
const SPAN: float=160.0
const HALF: float=80.0
const RIVER_HALF_WIDTH: float=6.0
const RIVER_BANK: float=13.0
const RESOLUTION: int=16

static func global_point(tile: Vector2i,local: Vector2) -> Vector2:
    return Vector2(float(tile.x)*SPAN+local.x,float(tile.y)*SPAN+local.y)

static func segments(world: Dictionary,tile: Vector2i) -> Array:
    var result: Array=[]
    var cell: Dictionary=World.cell(world,tile.x,tile.y)
    if not bool(cell.get("river",false)):return result
    var center:=Vector2(0.0,25.0)
    for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var neighbor: Dictionary=World.cell(world,tile.x+direction.x,tile.y+direction.y)
        if not bool(neighbor.get("river",false)):continue
        var end: Vector2=Vector2(float(direction.x)*HALF,float(direction.y)*HALF)
        if direction.x!=0:end.y=25.0
        result.append({"start":center,"end":end,"direction":direction})
    if result.is_empty():
        result.append({"start":Vector2(-33,25),"end":Vector2(33,25),"direction":Vector2i.ZERO})
    return result

static func _distance_to_segment(point: Vector2,a: Vector2,b: Vector2) -> float:
    var edge: Vector2=b-a
    var length_squared: float=edge.length_squared()
    if length_squared<0.00001:return point.distance_to(a)
    var t: float=clampf((point-a).dot(edge)/length_squared,0.0,1.0)
    return point.distance_to(a+edge*t)

static func height(world: Dictionary,tile: Vector2i,x: float,z: float) -> float:
    return height_from_segments(int(world.get("seed",0)),tile,segments(world,tile),x,z)

static func height_from_segments(seed_value: int,tile: Vector2i,rivers: Array,x: float,z: float) -> float:
    var global: Vector2=global_point(tile,Vector2(x,z))
    var seed: float=float(seed_value)
    var elevation: float=1.20*sin(global.x*0.015+seed*0.00013)*cos(global.y*0.016-seed*0.00017)
    elevation+=0.43*sin(global.x*0.032+global.y*0.021+seed*0.0009)
    # Building cores and actual 0.26 border gates stay comfortably low.
    var interior: float=clampf((maxf(absf(x),absf(z))-27.0)/34.0,0.0,1.0)
    elevation*=interior
    if absf(x)>=58.0 and absf(z)<=8.0:
        elevation*=clampf((absf(z)-2.0)/6.0,0.0,1.0)
    if absf(z)>=58.0 and absf(x)<=8.0:
        elevation*=clampf((absf(x)-2.0)/6.0,0.0,1.0)
    var river_distance: float=INF
    for segment in rivers:
        river_distance=minf(river_distance,_distance_to_segment(Vector2(x,z),segment["start"],segment["end"]))
    if river_distance<RIVER_BANK:
        var blend: float=1.0-clampf((river_distance-RIVER_HALF_WIDTH)/(RIVER_BANK-RIVER_HALF_WIDTH),0.0,1.0)
        elevation=lerpf(elevation,-0.42,blend)
    return elevation

static func biome_color(world: Dictionary,tile: Vector2i) -> Color:
    match String(World.cell(world,tile.x,tile.y).get("biome","plains")):
        "forest":return Color("#608653")
        "hills":return Color("#999d8f")
        "sea":return Color("#4185a7")
        _:return Color("#9bad6b")

static func surface(world: Dictionary,tile: Vector2i,name: String="DistrictTerrain") -> MeshInstance3D:
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tint: Color=biome_color(world,tile)
    for z in range(RESOLUTION):
        for x in range(RESOLUTION):
            var x0: float=-HALF+SPAN*float(x)/float(RESOLUTION)
            var x1: float=-HALF+SPAN*float(x+1)/float(RESOLUTION)
            var z0: float=-HALF+SPAN*float(z)/float(RESOLUTION)
            var z1: float=-HALF+SPAN*float(z+1)/float(RESOLUTION)
            var a:=Vector3(x0,height(world,tile,x0,z0),z0)
            var b:=Vector3(x1,height(world,tile,x1,z0),z0)
            var c:=Vector3(x0,height(world,tile,x0,z1),z1)
            var d:=Vector3(x1,height(world,tile,x1,z1),z1)
            for v in [a,c,b,b,c,d]:
                tool.set_color(tint)
                tool.add_vertex(v)
    tool.generate_normals()
    var mesh:=MeshInstance3D.new()
    mesh.name=name
    mesh.mesh=tool.commit()
    var material:=StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.roughness=0.95
    mesh.material_override=material
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mesh

static func water(world: Dictionary,tile: Vector2i) -> Array:
    var result: Array=[]
    var count: int=0
    for segment in segments(world,tile):
        var a: Vector2=segment["start"]
        var b: Vector2=segment["end"]
        var diff: Vector2=b-a
        var middle: Vector2=(a+b)*0.5
        var ribbon:=MeshInstance3D.new()
        ribbon.name="RiverLink_"+str(count)
        var box:=BoxMesh.new()
        box.size=Vector3(RIVER_HALF_WIDTH*2.0,0.08,diff.length()+0.015)
        ribbon.mesh=box
        ribbon.position=Vector3(middle.x,-0.33,middle.y)
        ribbon.rotation.y=atan2(diff.x,diff.y)
        var material:=StandardMaterial3D.new()
        material.albedo_color=Color("#378fb0")
        material.roughness=0.25
        ribbon.material_override=material
        ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        result.append(ribbon)
        count+=1
    return result

static func distant_props(camera_position: Vector3,tile_position: Vector3) -> bool:
    return Vector2(camera_position.x-tile_position.x,camera_position.z-tile_position.z).length()>250.0
