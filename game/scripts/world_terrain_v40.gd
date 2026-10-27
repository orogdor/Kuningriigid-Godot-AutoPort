extends SubViewportContainer
## AutoPort v0.40: actual height-mesh world map for 220x165 source tiles.
## Default 3D view, pointer/touch picking, drag and pinch. The old 2D map
## remains available on demand for accessibility and device compatibility.
signal cell_selected(c: int,r: int)
signal cell_activated(c: int,r: int)
const World=preload("res://scripts/world_gen_v06.gd")
const Trade3D=preload("res://scripts/world_trade_3d_v49.gd")
const WebPalette50=preload("res://scripts/web_biomes_v50.gd")
const ZOOM_MIN: float=38.0
const ZOOM_MAX: float=340.0
var world: Dictionary={}
var viewport: SubViewport
var scene_root: Node3D
var terrain_node: MeshInstance3D
var trade_road_root: Node3D
var trade_caravans_root: Node3D
var trade_route_key: String=""
var marker: MeshInstance3D
var camera: Camera3D
var camera_target: Vector2=Vector2(110,82.5)
var zoom: float=235.0
var selected: Vector2i=Vector2i(-1,-1)
var touch_points: Dictionary={}
var dragging: bool=false
var start_pointer: Vector2=Vector2.ZERO
var last_pointer: Vector2=Vector2.ZERO
var moved: float=0.0
var pinch_gesture: bool=false
var last_tap_ms: int=-10000
var last_tap_cell: Vector2i=Vector2i(-1,-1)

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    stretch=true
    size_flags_horizontal=Control.SIZE_EXPAND_FILL
    size_flags_vertical=Control.SIZE_EXPAND_FILL
    custom_minimum_size=Vector2(200,150)
    viewport=SubViewport.new()
    viewport.name="World3DViewport"
    viewport.size=Vector2i(900,550)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally=true
    add_child(viewport)
    scene_root=Node3D.new()
    scene_root.name="ReliefWorld"
    viewport.add_child(scene_root)
    var environment:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color("#264665")
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color("#d1deeb")
    env.ambient_light_energy=0.9
    environment.environment=env
    scene_root.add_child(environment)
    var sun:=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-58,-45,0)
    sun.light_energy=0.8
    scene_root.add_child(sun)
    camera=Camera3D.new()
    camera.name="World3DCamera"
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.current=true
    camera.far=1000.0
    scene_root.add_child(camera)
    terrain_node=MeshInstance3D.new()
    terrain_node.name="WorldReliefMesh"
    scene_root.add_child(terrain_node)
    trade_road_root=Node3D.new()
    trade_road_root.name="TradeRoute3D"
    scene_root.add_child(trade_road_root)
    trade_caravans_root=Node3D.new()
    trade_caravans_root.name="TradeCaravans3D"
    scene_root.add_child(trade_caravans_root)
    marker=MeshInstance3D.new()
    marker.name="SelectedWorldTile"
    var selection:=BoxMesh.new()
    selection.size=Vector3(1.18,0.5,1.18)
    marker.mesh=selection
    var yellow:=StandardMaterial3D.new()
    yellow.albedo_color=Color("#ffd45f")
    yellow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override=yellow
    marker.visible=false
    scene_root.add_child(marker)
    _update_camera()

static func terrain_height(cell: Dictionary) -> float:
    # 3D relief is exaggerated but terrain remains the same world data.
    return maxf(-4.0,float(cell.get("h",0.0))*0.33)

static func _shade(cell: Dictionary) -> Color:
    var biome: String=String(cell.get("biome","sea"))
    var col:=Color("#235f88")
    if biome=="plains":col=Color("#9bbf71")
    elif biome=="forest":col=Color("#377d52")
    elif biome=="hills":col=Color("#b0aca3")
    elif float(cell.get("h",-20)) < -12.0:col=Color("#173e65")
    if bool(cell.get("river",false)) and bool(cell.get("land",false)):
        col=col.lerp(Color("#428ab1"),0.33)
    return col

static func _corner(world_data: Dictionary,c: int,r: int) -> float:
    var sum: float=0.0
    var total: int=0
    for dz in [-1,0]:
        for dx in [-1,0]:
            var cell: Dictionary=World.cell(world_data,c+dx,r+dz)
            if cell.is_empty():continue
            sum+=terrain_height(cell)
            total+=1
    return sum/float(maxi(total,1))

func set_world(data: Dictionary) -> void:
    world=data
    # New seed invalidates roads and wagons from the previous world.
    trade_route_key=""
    if trade_road_root!=null:
        for child in trade_road_root.get_children():child.free()
    if trade_caravans_root!=null:
        for child in trade_caravans_root.get_children():child.free()
    if terrain_node==null or world.is_empty():return
    var vertices:=PackedVector3Array()
    var normals:=PackedVector3Array()
    var colors:=PackedColorArray()
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var cell: Dictionary=World.cell(world,c,r)
            var x: float=float(c)
            var z: float=float(r)
            var a:=Vector3(x,_corner(world,c,r),z)
            var b:=Vector3(x+1,_corner(world,c+1,r),z)
            var d:=Vector3(x,_corner(world,c,r+1),z+1)
            var e:=Vector3(x+1,_corner(world,c+1,r+1),z+1)
            var face_color: Color=WebPalette50.color(world,c,r)
            # Two triangles with upwards normals, continuous height at edges.
            for v in [a,d,b,b,d,e]:
                vertices.append(v)
                normals.append(Vector3.UP)
                colors.append(face_color)
    var arrays: Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_NORMAL]=normals
    arrays[Mesh.ARRAY_COLOR]=colors
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    terrain_node.mesh=mesh
    var material:=StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.roughness=1.0
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    terrain_node.material_override=material
    camera_target=Vector2(World.COLS*0.5,World.ROWS*0.5)
    zoom=235.0
    _update_camera()
    _move_marker()

func set_trade_route(route: Dictionary,caravans: Array) -> void:
    if trade_road_root==null or trade_caravans_root==null:return
    var points: Array[Vector3]=Trade3D.route_points(world,route)
    var identity: String=JSON.stringify(route) if points.size()>=2 else ""
    if identity!=trade_route_key:
        for old in trade_road_root.get_children():old.free()
        if points.size()>=2:Trade3D.populate_road(trade_road_root,points)
        trade_route_key=identity
    # A trade tick updates lightweight wagons, not the fixed road mesh.
    for old in trade_caravans_root.get_children():old.free()
    if points.size()>=2:
        Trade3D.populate_caravans(trade_caravans_root,
            Trade3D.caravan_positions(points,caravans))

func _update_camera() -> void:
    if camera==null:return
    camera.size=zoom
    camera.position=Vector3(camera_target.x,240.0,camera_target.y+135.0)
    camera.look_at(Vector3(camera_target.x,0,camera_target.y),Vector3.UP)

func fit_to_view() -> void:
    camera_target=Vector2(World.COLS*0.5,World.ROWS*0.5)
    zoom=235.0
    _update_camera()

func select_cell(c: int,r: int,emit_signal: bool=true) -> void:
    if World.cell(world,c,r).is_empty():return
    selected=Vector2i(c,r)
    _move_marker()
    if emit_signal:cell_selected.emit(c,r)

func _move_marker() -> void:
    if marker==null:return
    var cell: Dictionary=World.cell(world,selected.x,selected.y)
    marker.visible=not cell.is_empty()
    if marker.visible:
        marker.position=Vector3(float(selected.x)+0.5,terrain_height(cell)+1.2,
            float(selected.y)+0.5)

func _pick(point: Vector2) -> Vector2i:
    if world.is_empty() or camera==null or size.x<=0.0 or size.y<=0.0:return Vector2i(-1,-1)
    var pixel:=Vector2(point.x/size.x*float(viewport.size.x),
        point.y/size.y*float(viewport.size.y))
    var origin: Vector3=camera.project_ray_origin(pixel)
    var direction: Vector3=camera.project_ray_normal(pixel)
    if absf(direction.y)<0.000001:return Vector2i(-1,-1)
    var t: float=-origin.y/direction.y
    var crossing: Vector3=origin+direction*t
    var cell:=World.cell(world,int(floor(crossing.x)),int(floor(crossing.z)))
    if not cell.is_empty():
        t=(terrain_height(cell)-origin.y)/direction.y
        crossing=origin+direction*t
    var col: int=int(floor(crossing.x))
    var row: int=int(floor(crossing.z))
    if World.cell(world,col,row).is_empty():return Vector2i(-1,-1)
    return Vector2i(col,row)

func _tap(point: Vector2) -> void:
    var pos: Vector2i=_pick(point)
    if pos.x<0:return
    select_cell(pos.x,pos.y)
    var timestamp: int=Time.get_ticks_msec()
    if pos==last_tap_cell and timestamp-last_tap_ms<380:
        cell_activated.emit(pos.x,pos.y)
        last_tap_ms=-10000
    else:
        last_tap_ms=timestamp
        last_tap_cell=pos

func _pan(movement: Vector2) -> void:
    if size.x<=1.0 or size.y<=1.0:return
    var scale: float=zoom/maxf(1.0,size.y)
    camera_target.x=clampf(camera_target.x-movement.x*scale,0,float(World.COLS))
    camera_target.y=clampf(camera_target.y-movement.y*scale,0,float(World.ROWS))
    _update_camera()

func _zoom(multiplier: float) -> void:
    zoom=clampf(zoom*multiplier,ZOOM_MIN,ZOOM_MAX)
    _update_camera()

func _gui_input(event: InputEvent) -> void:
    if world.is_empty():return
    if event is InputEventMouseButton:
        var mouse: InputEventMouseButton=event
        if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            _zoom(0.85 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 1.18)
        elif mouse.button_index==MOUSE_BUTTON_LEFT:
            if mouse.pressed:
                dragging=true
                start_pointer=mouse.position
                last_pointer=mouse.position
                moved=0.0
            else:
                if dragging and moved<9.0:_tap(mouse.position)
                dragging=false
        accept_event()
    elif event is InputEventMouseMotion and dragging:
        var motion: InputEventMouseMotion=event
        moved+=motion.position.distance_to(last_pointer)
        _pan(motion.position-last_pointer)
        last_pointer=motion.position
        accept_event()
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch=event
        if touch.pressed:
            touch_points[touch.index]=touch.position
            if touch_points.size()==1:
                dragging=true
                last_pointer=touch.position
                moved=0.0
                pinch_gesture=false
            else:
                pinch_gesture=true
                dragging=false
        else:
            if touch_points.has(touch.index):
                if touch_points.size()==1 and dragging and not pinch_gesture and moved<9.0:
                    _tap(touch.position)
                touch_points.erase(touch.index)
            if touch_points.is_empty():
                dragging=false
                pinch_gesture=false
            elif touch_points.size()==1:
                last_pointer=touch_points.values()[0]
                dragging=true
        accept_event()
    elif event is InputEventScreenDrag:
        var finger: InputEventScreenDrag=event
        if not touch_points.has(finger.index):return
        if touch_points.size()==1:
            var before: Vector2=touch_points[finger.index]
            touch_points[finger.index]=finger.position
            moved+=finger.position.distance_to(before)
            _pan(finger.position-before)
        else:
            var keys: Array=touch_points.keys()
            var before_dist: float=touch_points[keys[0]].distance_to(touch_points[keys[1]])
            var before_mid: Vector2=(touch_points[keys[0]]+touch_points[keys[1]])*0.5
            touch_points[finger.index]=finger.position
            var next_dist: float=touch_points[keys[0]].distance_to(touch_points[keys[1]])
            var next_mid: Vector2=(touch_points[keys[0]]+touch_points[keys[1]])*0.5
            _pan(next_mid-before_mid)
            if before_dist>8.0:_zoom(before_dist/maxf(8.0,next_dist))
            pinch_gesture=true
            moved=999.0
        accept_event()
