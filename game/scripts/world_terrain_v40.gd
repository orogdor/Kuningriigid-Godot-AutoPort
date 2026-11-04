extends SubViewportContainer
## AutoPort v0.40: actual height-mesh world map for 220x165 source tiles.
## Default 3D view, pointer/touch picking, drag and pinch. The old 2D map
## remains available on demand for accessibility and device compatibility.
signal cell_selected(c: int,r: int)
signal cell_activated(c: int,r: int)
const World=preload("res://scripts/world_gen_v06.gd")
const Trade3D=preload("res://scripts/world_trade_3d_v49.gd")
const WebPalette50=preload("res://scripts/web_biomes_v50.gd")
const WebArt50=preload("res://scripts/web_graphics_v50.gd")
const WebWater51=preload("res://scripts/web_water_v51.gd")
const Scout52=preload("res://scripts/world_scout_v52.gd")
const WebUnits53=preload("res://scripts/web_units_v53.gd")
const ZOOM_MIN: float=38.0
const ZOOM_MAX: float=340.0
var world: Dictionary={}
var viewport: SubViewport
var scene_root: Node3D
var terrain_node: MeshInstance3D
var web_props_root: Node3D
var river_root: Node3D
var trade_road_root: Node3D
var trade_caravans_root: Node3D
var trade_route_key: String=""
var scout_actor: Node3D
var army_root_v54: Node3D
var hostile_actor_v56: Node3D
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
    # Atlas and detail are separate SubViewports. Without an independent World3D,
    # the atlas relief stays rendered behind (and through) detail terrain.
    viewport.own_world_3d=true
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
    web_props_root=Node3D.new()
    web_props_root.name="OriginalWebAtlasObjects"
    scene_root.add_child(web_props_root)
    river_root=Node3D.new()
    river_root.name="OriginalWebRiverLayers51"
    scene_root.add_child(river_root)
    trade_road_root=Node3D.new()
    trade_road_root.name="TradeRoute3D"
    scene_root.add_child(trade_road_root)
    trade_caravans_root=Node3D.new()
    trade_caravans_root.name="TradeCaravans3D"
    scene_root.add_child(trade_caravans_root)
    scout_actor=Node3D.new()
    scout_actor.name="WorldScoutV52"
    scene_root.add_child(scout_actor)
    # Temporary native Godot actor; replaces a mere pin, ready for a GLB later.
    var coat:=StandardMaterial3D.new()
    coat.albedo_color=Color("#dcc08c")
    var head_mat:=StandardMaterial3D.new()
    head_mat.albedo_color=Color("#c49166")
    var wood_mat:=StandardMaterial3D.new()
    wood_mat.albedo_color=Color("#69452d")
    var body:=MeshInstance3D.new()
    body.name="ScoutBody"
    var body_mesh:=CapsuleMesh.new()
    body_mesh.radius=0.30
    body_mesh.height=1.35
    body.mesh=body_mesh
    body.position=Vector3(0,0.85,0)
    body.material_override=coat
    scout_actor.add_child(body)
    var head:=MeshInstance3D.new()
    head.name="ScoutHead"
    var head_mesh:=SphereMesh.new()
    head_mesh.radius=0.23
    head_mesh.height=0.46
    head.mesh=head_mesh
    head.position=Vector3(0,1.73,0)
    head.material_override=head_mat
    scout_actor.add_child(head)
    var spear:=MeshInstance3D.new()
    spear.name="ScoutSpear"
    var spear_mesh:=CylinderMesh.new()
    spear_mesh.top_radius=0.035
    spear_mesh.bottom_radius=0.035
    spear_mesh.height=2.2
    spear.mesh=spear_mesh
    spear.position=Vector3(0.42,1.15,0.1)
    spear.material_override=wood_mat
    scout_actor.add_child(spear)
    # Use the original Three.js GLB, including its authored materials, when
    # the exact source models have been imported by GitHub Actions.
    var original_scout: Node3D=WebUnits53.instance("scout",2.7)
    if original_scout!=null:
        original_scout.name="OriginalWebScoutV53"
        scout_actor.add_child(original_scout)
        body.visible=false
        head.visible=false
        spear.visible=false
    scout_actor.visible=false
    army_root_v54=Node3D.new()
    army_root_v54.name="StoneAgeArmiesV54"
    scene_root.add_child(army_root_v54)
    hostile_actor_v56=Node3D.new()
    hostile_actor_v56.name="HostileRaiderV56"
    scene_root.add_child(hostile_actor_v56)
    var enemy_model: Node3D=WebUnits53.instance("spearman",2.9,false,true)
    if enemy_model!=null:
        hostile_actor_v56.add_child(enemy_model)
        WebUnits53.animate_world(enemy_model,false)
    var hostile_marker:=MeshInstance3D.new()
    hostile_marker.name="HostileMarker"
    var marker_mesh:=CylinderMesh.new()
    marker_mesh.top_radius=0.55
    marker_mesh.bottom_radius=0.55
    marker_mesh.height=0.12
    hostile_marker.mesh=marker_mesh
    hostile_marker.position.y=0.03
    var red:=StandardMaterial3D.new()
    red.albedo_color=Color("#d83c31")
    hostile_marker.material_override=red
    hostile_actor_v56.add_child(hostile_marker)
    hostile_actor_v56.visible=false
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

static func _corner_tint(data: Dictionary,c: int,r: int) -> Color:
    # Blend Web atlas colours at shared vertices; eliminate sharp square
    # biome edges without modifying the actual terrain, river or routes.
    var total:=Color.BLACK
    var n: int=0
    for dr in [-1,0]:
        for dc in [-1,0]:
            var cell: Dictionary=World.cell(data,c+dc,r+dr)
            if cell.is_empty():continue
            total+=WebPalette50.color(data,c+dc,r+dr)
            n+=1
    return total/float(n) if n>0 else WebPalette50.DEEP

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
    if scout_actor!=null:scout_actor.visible=false
    if hostile_actor_v56!=null:hostile_actor_v56.visible=false
    if army_root_v54!=null:
        for child in army_root_v54.get_children():child.free()
    if trade_road_root!=null:
        for child in trade_road_root.get_children():child.free()
    if trade_caravans_root!=null:
        for child in trade_caravans_root.get_children():child.free()
    if terrain_node==null or world.is_empty():return
    var vertices:=PackedVector3Array()
    var normals:=PackedVector3Array()
    var colors:=PackedColorArray()
    var shared_colors:=PackedColorArray()
    for rr in range(World.ROWS+1):
        for cc in range(World.COLS+1):
            shared_colors.append(_corner_tint(world,cc,rr))
    var stride: int=World.COLS+1
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var cell: Dictionary=World.cell(world,c,r)
            var x: float=float(c)
            var z: float=float(r)
            var a:=Vector3(x,_corner(world,c,r),z)
            var b:=Vector3(x+1,_corner(world,c+1,r),z)
            var d:=Vector3(x,_corner(world,c,r+1),z+1)
            var e:=Vector3(x+1,_corner(world,c+1,r+1),z+1)
            # Four shared corners, six original triangle vertices.
            var ca: Color=shared_colors[r*stride+c]
            var cb: Color=shared_colors[r*stride+c+1]
            var cd: Color=shared_colors[(r+1)*stride+c]
            var ce: Color=shared_colors[(r+1)*stride+c+1]
            for v in [a,d,b,b,d,e]:
                vertices.append(v)
                normals.append(Vector3.UP)
            for tint in [ca,cd,cb,cb,cd,ce]:
                colors.append(tint)
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
    if web_props_root!=null:
        for old in web_props_root.get_children():old.free()
        WebArt50.atlas_decor(web_props_root,world)
    if river_root!=null:
        for old in river_root.get_children():old.free()
        river_root.add_child(WebWater51.atlas(world))
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

func scout_point_for(data: Dictionary) -> Vector3:
    if world.is_empty() or data.is_empty():return Vector3.ZERO
    var origin:=Vector2i(int(data.get("c",-1)),int(data.get("r",-1)))
    if World.cell(world,origin.x,origin.y).is_empty():return Vector3.ZERO
    var first: Vector3=Trade3D.tile_point(world,origin.x,origin.y)
    var path: Array=data.get("path",[])
    if path.is_empty():return first
    var next: Dictionary=path[0]
    var end: Vector2i=Vector2i(int(next.get("c",-1)),int(next.get("r",-1)))
    if World.cell(world,end.x,end.y).is_empty():return first
    var sample: Dictionary=Scout52.sample(data)
    return first.lerp(Trade3D.tile_point(world,end.x,end.y),float(sample["fraction"]))

func set_scout(data: Dictionary) -> void:
    if scout_actor==null:return
    var valid: bool=not data.is_empty() and not world.is_empty() and \
        int(data.get("seed",-1))==int(world.get("seed",-2)) and \
        not World.cell(world,int(data.get("c",-1)),int(data.get("r",-1))).is_empty()
    scout_actor.visible=valid
    if not valid:return
    scout_actor.position=scout_point_for(data)
    var route: Array=data.get("path",[])
    if not route.is_empty():
        var next: Dictionary=route[0]
        scout_actor.rotation.y=atan2(float(next["c"])-float(data["c"]),
            float(next["r"])-float(data["r"]))

func set_armies_v54(armies: Array) -> void:
    if army_root_v54==null:return
    # Always derive the drawn position from saved path and duration; the atlas
    # does not simulate a parallel army clock. Cap actors for mobile GPUs.
    for node in army_root_v54.get_children():node.free()
    if world.is_empty():return
    var shown: int=0
    for army in armies:
        if shown>=36:break
        var c: int=int(army.get("c",-1))
        var r: int=int(army.get("r",-1))
        if not bool(World.cell(world,c,r).get("land",false)):continue
        var kind: String=String(army.get("kind",""))
        var model: Node3D=WebUnits53.instance(kind,2.7,false,true)
        if model==null:continue
        var unit:=Node3D.new()
        unit.name="ArmyActorV54_"+str(int(army.get("id",shown)))
        unit.set_meta("army_id",int(army.get("id",shown)))
        army_root_v54.add_child(unit)
        model.name="OriginalStoneAge_"+kind
        unit.add_child(model)
        WebUnits53.animate_world(model,not army.get("path",[]).is_empty())
        unit.position=scout_point_for(army)
        var path: Array=army.get("path",[])
        if not path.is_empty():
            var next: Dictionary=path[0]
            unit.rotation.y=atan2(float(next["c"])-float(c),float(next["r"])-float(r))
        shown+=1

func set_raider_v56(enemy: Dictionary) -> void:
    if hostile_actor_v56==null:return
    var valid: bool=not enemy.is_empty() and not world.is_empty() and \
        not bool(enemy.get("defeated",false)) and \
        int(enemy.get("seed",-1))==int(world.get("seed",-2)) and \
        not World.cell(world,int(enemy.get("c",-1)),int(enemy.get("r",-1))).is_empty()
    hostile_actor_v56.visible=valid
    if not valid:return
    hostile_actor_v56.position=scout_point_for(enemy)
    var path: Array=enemy.get("path",[])
    if not path.is_empty():
        var next: Dictionary=path[0]
        hostile_actor_v56.rotation.y=atan2(float(next["c"])-float(enemy["c"]),
            float(next["r"])-float(enemy["r"]))

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
