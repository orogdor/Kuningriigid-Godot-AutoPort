extends Control
## AutoPort 0.7 prototype: world-tile 3D detail scene using Godot primitives.
## World elevation/coastal context follows 0.6 cells; not yet 1:1 Three.js meshes.
signal return_requested
signal build_requested(kind: String)
signal build_at_requested(kind: String, x: float, z: float, rotation: int)
signal bridge_requested(x: float, z: float)
signal priority_requested(index: int, level: String)
signal turns_requested(count: int)
signal research_requested
signal research_ai_requested
signal capital_ai_requested
signal neighbor_requested(c: int, r: int)
signal seamless_neighbor_requested(c: int,r: int,local_focus: Vector3,zoom: float)
signal return_by_zoom_requested
const World = preload("res://scripts/world_gen_v06.gd")
const CityEconomy = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Construction = preload("res://scripts/construction_v11.gd")
const Materials = preload("res://scripts/construction_v12.gd")
const Schedule = preload("res://scripts/construction_scheduler_v13.gd")
const Freight = preload("res://scripts/freight_v14.gd")
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Access = preload("res://scripts/building_access_v22.gd")
const Planner = preload("res://scripts/city_planner_v24.gd")
const Transit = preload("res://scripts/district_transit_v26.gd")
const Continuous = preload("res://scripts/continuous_city_v27.gd")
const Terrain28 = preload("res://scripts/continuous_terrain_v28.gd")
const Visuals30 = preload("res://scripts/district_visuals_v30.gd")
const Batches31 = preload("res://scripts/city_render_batch_v31.gd")
const Perf31 = preload("res://scripts/city_performance_v31.gd")
const LOD32 = preload("res://scripts/city_building_lod_v32.gd")
const Stable33 = preload("res://scripts/city_lod_stability_v33.gd")
const Unlock36 = preload("res://scripts/building_unlocks_v36.gd")
const Nav = preload("res://scripts/terrain_navigation_v29.gd")
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const CityRecipes = preload("res://scripts/generated_rules.gd")
const Controller = preload("res://scripts/detail_camera_v07.gd")
const SeamTerrain42 = preload("res://scripts/detail_neighbor_terrain_v42.gd")
const WebPalette50 = preload("res://scripts/web_biomes_v50.gd")
const WebArt50 = preload("res://scripts/web_graphics_v50.gd")
const Districts44 = preload("res://scripts/world_districts_v25.gd")
const NeighborBuildings45 = preload("res://scripts/detail_neighbor_buildings_v45.gd")
const Hybrid46 = preload("res://scripts/detail_hybrid_v46.gd")
const SecondCity47 = preload("res://scripts/second_city_detail_v47.gd")
const NeighborActivity48 = preload("res://scripts/detail_neighbor_activity_v48.gd")
const PREVIEW_TYPES: Array[String] = ["hall","house","lumber","well","quarry","farm"]
const SURFACE_WIDTH: float = 225.0
const SURFACE_DEPTH: float = 195.0

var world: Dictionary = {}
var selected: Vector2i = Vector2i(-1,-1)
var active_tile: Vector2i=Vector2i(-1,-1)
var combined_city: bool=false
var combined_root: Node3D
var seam_preview_root: Node3D
var capital_preview_state_v47: Dictionary={}
var satellite_preview_state_v47: Dictionary={}
var satellite_preview_tile_v47: Vector2i=Vector2i(-1,-1)
var seam_preview_refresh_clock: float=0.0
var combined_bounds: Dictionary={}
var shown_district_tiles: Array[Vector2i]=[]
var terrain_mesh_builds: int=0
var prop_builds: int=0
var active_building_mesh_builds: int=0
var street_cache_signature: String=""
var performance_label: Label
var performance_timer: float=0.0
var performance_samples: int=0
var performance_fps_sum: float=0.0
var performance_last: Dictionary={}
var performance_enabled: bool=false
var batched_resource_nodes: int=0
var quality_state: Dictionary={"level":1,"low":0,"high":0}
var view_port: SubViewport
var visual_update_count: int=0
var visual_visibility_poll: float=0.0
var visual_visibility_signature: String=""
var proxy_building_batches: int=0
var passive_building_mesh_builds: int=0
var culled_district_count: int=0
var can_build: bool = false
var district_id: String=""
var city_state: Dictionary = {}
var scene_root: Node3D
var construction_root: Node3D
var resource_root: Node3D
var worker_root: Node3D
var freight_root: Node3D
var plot_root: Node3D
var roads_root: Node3D
var bridge_root: Node3D
var previous_worker_positions: Dictionary={}
var pending_build: String = ""
var placement_marker: MeshInstance3D
var placement_ghost: Node3D
var placement_ghost_material: StandardMaterial3D
var placement_rotation: int=0
var placement_cell: Vector2=Vector2(INF,INF)
var placement_label: Label
var controller: SubViewportContainer
var info: Label
var actions: HBoxContainer
var rendered_buildings: int = 0
var shared_materials: Dictionary={}
var shared_boxes: Dictionary={}
var grid_materials: Dictionary={}
var suggested_site: Dictionary={}
var selected_biome: String = ""

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_STOP
    var column:=VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    column.add_theme_constant_override("separation",2)
    add_child(column)
    var top:=HBoxContainer.new()
    column.add_child(top)
    var heading:=Label.new()
    # Always display the packaged project's actual version, even when
    # the source script is unchanged across later manual APK releases.
    var installed_name: String=String(ProjectSettings.get_setting(
        "application/config/name","Kuningriigid Godot AutoPort"))
    heading.text=installed_name+" • 3D KAART"
    heading.add_theme_font_size_override("font_size",16)
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    var stats_button:=Button.new()
    stats_button.text="FPS"
    stats_button.pressed.connect(_toggle_performance)
    top.add_child(stats_button)
    var back:=Button.new()
    back.text="◀ Maailm"
    back.pressed.connect(func(): return_requested.emit())
    top.add_child(back)
    info=Label.new()
    # Never let hundreds of characters of economic diagnostics shrink the
    # Godot SubViewport to zero pixels, especially in landscape on Android.
    info.autowrap_mode=TextServer.AUTOWRAP_OFF
    info.clip_text=true
    info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    info.custom_minimum_size=Vector2(0,21)
    info.tooltip_text="Puuduta teksti, et näha täielikku majandusinfot."
    column.add_child(info)
    performance_label=Label.new()
    performance_label.text="FPS: --  |  Joonistuskutsed: --  |  3D objekte: --"
    # FPS remains available from the header button, but is not permanently
    # taking a second line away from the map on a small phone.
    performance_label.visible=false
    performance_enabled=false
    performance_label.add_theme_font_size_override("font_size",13)
    column.add_child(performance_label)
    placement_label=Label.new()
    placement_label.autowrap_mode=TextServer.AUTOWRAP_OFF
    placement_label.clip_text=true
    placement_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    placement_label.custom_minimum_size=Vector2(0,21)
    placement_label.text="Vali ehitis, et näha lubatud (roheline) ja keelatud (punane) ehitusruute."
    column.add_child(placement_label)
    controller=Controller.new()
    controller.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    controller.size_flags_vertical=Control.SIZE_EXPAND_FILL
    controller.custom_minimum_size=Vector2(0,180)
    column.add_child(controller)
    var viewport:=SubViewport.new()
    view_port=viewport
    quality_state["level"]=1 if OS.has_feature("mobile") else 2
    viewport.size=Perf31.viewport_size(int(quality_state["level"]))
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg=false
    viewport.handle_input_locally=true
    controller.add_child(viewport)
    scene_root=Node3D.new()
    scene_root.name="WorldTile"
    viewport.add_child(scene_root)
    var environment:=WorldEnvironment.new()
    var sky_settings:=Environment.new()
    sky_settings.background_mode=Environment.BG_COLOR
    sky_settings.background_color=Color("#a8ccdf")
    sky_settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    sky_settings.ambient_light_color=Color("#b0c0cc")
    sky_settings.ambient_light_energy=0.8
    environment.environment=sky_settings
    scene_root.add_child(environment)
    var sun:=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-57,-36,0)
    sun.light_energy=1.1
    scene_root.add_child(sun)
    var camera:=Camera3D.new()
    camera.fov=58.0
    camera.current=true
    scene_root.add_child(camera)
    controller.call("attach_camera",camera)
    controller.connect("ground_clicked",_ground_clicked)
    controller.connect("ground_hovered",_hover_ground)
    controller.detail_edge_crossed.connect(_on_web_edge)
    controller.zoom_exit_requested.connect(func(): return_by_zoom_requested.emit())
    construction_root=Node3D.new()
    construction_root.name="PlacedBuildings"
    scene_root.add_child(construction_root)
    resource_root=Node3D.new()
    resource_root.name="PhysicalResources"
    scene_root.add_child(resource_root)
    worker_root=Node3D.new()
    worker_root.name="MovingWorkers"
    scene_root.add_child(worker_root)
    freight_root=Node3D.new()
    freight_root.name="GoodsWagons"
    scene_root.add_child(freight_root)
    plot_root=Node3D.new()
    plot_root.name="BuildGrid"
    scene_root.add_child(plot_root)
    roads_root=Node3D.new()
    roads_root.name="EmergentFootpaths"
    scene_root.add_child(roads_root)
    bridge_root=Node3D.new()
    bridge_root.name="RiverBridges"
    scene_root.add_child(bridge_root)
    combined_root=Node3D.new()
    combined_root.name="ContinuousCity"
    scene_root.add_child(combined_root)
    seam_preview_root=Node3D.new()
    seam_preview_root.name="SurroundingDetailTiles"
    scene_root.add_child(seam_preview_root)
    # Fixed-height, horizontally scrollable toolbar. Priority buttons no
    # longer wrap to 10+ rows or cover the 3D view as the town grows.
    # The enclosing plain Control holds an exact one-row height. The
    # ScrollContainer's minimum would otherwise grow with button content.
    var toolbar_frame:=Control.new()
    toolbar_frame.name="DetailToolbarFrame"
    toolbar_frame.custom_minimum_size=Vector2(0,46)
    toolbar_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    column.add_child(toolbar_frame)
    var action_scroll:=ScrollContainer.new()
    action_scroll.name="DetailActionsScroll"
    toolbar_frame.add_child(action_scroll)
    action_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    action_scroll.clip_contents=true
    action_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    action_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    actions=HBoxContainer.new()
    actions.name="DetailActionButtons"
    actions.add_theme_constant_override("separation",5)
    action_scroll.add_child(actions)
    _refresh_actions()

func _toggle_performance() -> void:
    performance_enabled=not performance_enabled
    if performance_label!=null:performance_label.visible=performance_enabled

func _process(delta: float) -> void:
    if not visible or view_port==null:return
    if not combined_city and controller!=null:
        seam_preview_refresh_clock+=delta
        if seam_preview_refresh_clock>=0.25:
            seam_preview_refresh_clock=0.0
            _refresh_seam_neighbor_buildings()
    if combined_city and controller!=null and not shown_district_tiles.is_empty():
        visual_visibility_poll+=delta
        if visual_visibility_poll>=0.30:
            visual_visibility_poll=0.0
            var states: Array[Dictionary]=[]
            for tile in shown_district_tiles:
                var pos: Vector3=Continuous.offset(tile,selected)
                var distance_to_focus: float=Vector2(
                    controller.look_at.x-pos.x,controller.look_at.z-pos.z).length()
                var label: String="DistrictTile_Capital" if tile==selected else "DistrictTile_"+Continuous.district_key(tile,world).replace(":","_")
                var node: Node3D=combined_root.get_node_or_null(label) as Node3D
                var previous_level: int=int(node.get_meta("lod_level",-1)) if node!=null else -1
                var previous_visible: Variant=node.get_meta("lod_visible") if node!=null and node.has_meta("lod_visible") else null
                states.append(Stable33.state(distance_to_focus,controller.distance,
                    tile==active_tile,previous_level,previous_visible))
            var signature: String=Stable33.view_signature(shown_district_tiles,states)
            if signature!=visual_visibility_signature:
                visual_visibility_signature=signature
                _render_neighbors()
    performance_timer+=delta
    if performance_timer<1.0:return
    var interval: float=performance_timer
    performance_timer=0.0
    var fps: float=float(Engine.get_frames_per_second())
    # Captures hardware-side frame statistics on supported live renderers.
    # A headless editor can report 0 draw calls: do not fabricate data.
    var calls: int=RenderingServer.viewport_get_render_info(view_port.get_viewport_rid(),
        RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
        RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
    var geometry: int=RenderingServer.viewport_get_render_info(view_port.get_viewport_rid(),
        RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
        RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
    var nodes: int=Batches31.node_count(scene_root)
    performance_last={"fps":fps,"draw_calls":calls,"visible_meshes":geometry,
        "scene_nodes":nodes,"quality":int(quality_state["level"]),"sample_interval":interval,
        "lod_batches":proxy_building_batches,"culled_districts":culled_district_count}
    if OS.has_feature("mobile"):
        var next: Dictionary=Perf31.next_quality(fps,quality_state)
        if int(next["level"])!=int(quality_state["level"]):
            view_port.size=Perf31.viewport_size(int(next["level"]))
        quality_state=next
    if performance_label!=null and performance_enabled:
        performance_label.text="FPS %.0f | Draw %d | Mesh %d | Sõlmi %d | LOD %d | Peidus %d | %s" % [
            fps,calls,geometry,nodes,proxy_building_batches,culled_district_count,
            Perf31.level_name(int(quality_state["level"]))]

func _material(color: Color, roughness: float=0.95) -> StandardMaterial3D:
    var key: String=color.to_html(true)+"_"+str(snappedf(roughness,0.01))
    if shared_materials.has(key):return shared_materials[key]
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=roughness
    shared_materials[key]=m
    return m

func _mesh(parent: Node3D, primitive: Mesh, pos: Vector3, color: Color, label: String) -> MeshInstance3D:
    var result:=MeshInstance3D.new()
    result.name=label
    result.mesh=primitive
    result.position=pos
    result.material_override=_material(color)
    parent.add_child(result)
    return result

func _box(parent: Node3D, pos: Vector3, scale: Vector3, color: Color, label: String) -> MeshInstance3D:
    var key: String=str(snappedf(scale.x,0.001))+":"+str(snappedf(scale.y,0.001))+":"+str(snappedf(scale.z,0.001))
    var mesh: BoxMesh
    if shared_boxes.has(key):
        mesh=shared_boxes[key]
    else:
        mesh=BoxMesh.new()
        mesh.size=scale
        shared_boxes[key]=mesh
    return _mesh(parent,mesh,pos,color,label)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, label: String) -> MeshInstance3D:
    var mesh:=CylinderMesh.new()
    mesh.top_radius=radius
    mesh.bottom_radius=radius
    mesh.height=height
    return _mesh(parent,mesh,pos,color,label)

func _roof(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh:=PrismMesh.new()
    mesh.size=size
    return _mesh(parent,mesh,pos,color,"PitchedRoof")

func _tree(parent: Node3D, place: Vector3, scale_factor: float=1.0) -> void:
    _cylinder(parent,place+Vector3(0,2.2*scale_factor,0),0.47*scale_factor,4.4*scale_factor,Color("#6d4a2b"),"Trunk")
    var foliage:=SphereMesh.new()
    foliage.radius=2.4*scale_factor
    foliage.height=4.8*scale_factor
    _mesh(parent,foliage,place+Vector3(0,5.5*scale_factor,0),Color("#315e37"),"Foliage")

func _rock(parent: Node3D, pos: Vector3, factor: float) -> void:
    var stone:=SphereMesh.new()
    stone.radius=1.6*factor
    stone.height=1.6*factor
    var m:=_mesh(parent,stone,pos+Vector3(0,0.35*factor,0),Color("#787b76"),"Rock")
    m.rotation_degrees=Vector3(0,37,18)

func _elevation(x: float, z: float, base: float, plain: bool) -> float:
    if plain and city_state.has("detail_sim"):
        # Preserve original roads/buildings/river physics in the town core.
        # Match the surrounding world terrain exactly on every outer border.
        return SeamTerrain42.city_height_at(world,selected,city_state["detail_sim"],x,z)
    if plain:return SeamTerrain42.height_at(world,selected,x,z)
    # Same world-coordinate relief as surrounding tiles: no step at borders.
    return SeamTerrain42.height_at(world,selected,x,z)

func _surface(cell: Dictionary) -> void:
    selected_biome=String(cell.get("biome","sea"))
    if combined_city:
        scene_root.add_child(Terrain28.surface(world,selected,"DetailTerrain"))
        terrain_mesh_builds+=1
        for water in Terrain28.water(world,selected):
            scene_root.add_child(water)
        return
    var sea: bool=selected_biome=="sea"
    var heights: float=clampf(float(cell.get("h",0))*0.02,-1.0,1.7)
    var smooth_centre: bool=can_build
    var width: float=Continuous.TILE_SPAN if combined_city else SURFACE_WIDTH
    var depth: float=Continuous.TILE_SPAN if combined_city else SURFACE_DEPTH
    var material:=StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.roughness=0.98
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tiles_x: int=30
    var tiles_z: int=26
    for r in range(tiles_z):
        for c in range(tiles_x):
            var x0: float=(-0.5+float(c)/tiles_x)*width
            var x1: float=(-0.5+float(c+1)/tiles_x)*width
            var z0: float=(-0.5+float(r)/tiles_z)*depth
            var z1: float=(-0.5+float(r+1)/tiles_z)*depth
            var a:=Vector3(x0,(0.0 if combined_city else _elevation(x0,z0,heights,smooth_centre)),z0)
            var b:=Vector3(x1,(0.0 if combined_city else _elevation(x1,z0,heights,smooth_centre)),z0)
            var d:=Vector3(x0,(0.0 if combined_city else _elevation(x0,z1,heights,smooth_centre)),z1)
            var e:=Vector3(x1,(0.0 if combined_city else _elevation(x1,z1,heights,smooth_centre)),z1)
            var col: Color=WebPalette50.detail(world,selected,
                (x0+x1)*0.5,(z0+z1)*0.5)
            if can_build and not sea:col=col.lerp(Color("#bdba8c"),0.12)
            # Correct Godot front-facing winding: generated normals point upward.
            for v in [a,b,d,b,e,d]:
                tool.set_color(col)
                tool.add_vertex(v)
    tool.generate_normals()
    var ground:=MeshInstance3D.new()
    ground.name="DetailTerrain"
    ground.mesh=tool.commit()
    ground.material_override=material
    scene_root.add_child(ground)
    if sea or _is_coastal(cell):
        _box(scene_root,Vector3(0,-1.2,0),Vector3(width,0.25,depth),
            Color("#3b86a8"),"SeaLevel")
    var rng:=RandomNumberGenerator.new()
    rng.seed=int(world.get("seed",82026))+selected.x*10007+selected.y*19937
    if not sea and not can_build:
        var oaks: Array=[]
        var pines: Array=[]
        var rocks: Array=[]
        var trees: int=50 if selected_biome=="forest" else (6 if selected_biome=="hills" else 16)
        for i in range(trees):
            var x: float=rng.randf_range(-108,108)
            var z: float=rng.randf_range(-92,92)
            var factor: float=rng.randf_range(2.4,4.0)
            var transform:=Transform3D(
                Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*factor),
                Vector3(x,_elevation(x,z,heights,smooth_centre),z))
            if selected_biome=="hills" or i%4==0:pines.append(transform)
            else:oaks.append(transform)
        for i in range(25 if selected_biome=="hills" else 8):
            var x: float=rng.randf_range(-109,109)
            var z: float=rng.randf_range(-89,89)
            rocks.append(Transform3D(
                Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(
                    Vector3.ONE*rng.randf_range(2.0,4.0)),
                Vector3(x,_elevation(x,z,heights,smooth_centre),z)))
        WebArt50.add_batch(scene_root,"oak",oaks,"WebActiveOaks")
        WebArt50.add_batch(scene_root,"pine",pines,"WebActivePines")
        WebArt50.add_batch(scene_root,"rock",rocks,"WebActiveRocks")
    if bool(cell.get("river",false)):
        _box(scene_root,Vector3(0,-0.26,25),Vector3(width,0.13,14),
            Color("#419abb"),"RiverWater")
        for bank_z in [17.0,33.0]:
            _box(scene_root,Vector3(0,0.06,bank_z),Vector3(width,0.25,1.7),
                Color("#978766"),"RiverBank")

func _selected_offset() -> Vector3:
    return Continuous.offset(active_tile,selected) if combined_city else Vector3.ZERO

func _position_local_groups() -> void:
    var delta: Vector3=_selected_offset()
    for root_node in [construction_root,resource_root,worker_root,freight_root,plot_root,roads_root,bridge_root]:
        if root_node!=null:root_node.position=delta

func _render_neighbors() -> void:
    if combined_root==null or not combined_city:return
    var buildings: Array=city_state.get("buildings",[])
    var agents: Array=city_state.get("transport_v26",{}).get("agents",[])
    var local_home: String=Transit.home_key(city_state)
    culled_district_count=0
    proxy_building_batches=0
    # Retain each permanent terrain tile across ticks. A turn only adjusts
    # changed houses, living resource props and moving transport actors.
    for tile in shown_district_tiles:
        var district: String=Continuous.district_key(tile,world)
        var label: String="DistrictTile_Capital" if tile==selected else "DistrictTile_"+district.replace(":","_")
        var part: Node3D=combined_root.get_node_or_null(label) as Node3D
        if part==null:
            part=Node3D.new()
            part.name=label
            part.position=Continuous.offset(tile,selected)
            combined_root.add_child(part)
            if tile!=selected:
                part.add_child(Terrain28.surface(world,tile,"DistrictTerrain"))
                terrain_mesh_builds+=1
                for water in Terrain28.water(world,tile):
                    part.add_child(water)
            var resources:=Node3D.new()
            resources.name="DistrictResources"
            part.add_child(resources)
        var district_offset: Vector3=Continuous.offset(tile,selected)
        var camera_distance: float=controller.distance
        var distance_from_focus: float=Vector2(
            controller.look_at.x-district_offset.x,
            controller.look_at.z-district_offset.z).length()
        var previous_level: int=int(part.get_meta("lod_level",-1))
        var previous_visible: Variant=part.get_meta("lod_visible") if part.has_meta("lod_visible") else null
        var decision: Dictionary=Stable33.state(distance_from_focus,camera_distance,
            tile==active_tile,previous_level,previous_visible)
        var draw_tile: bool=bool(decision["visible"])
        var building_lod: int=int(decision["level"])
        part.set_meta("lod_visible",draw_tile)
        part.set_meta("lod_level",building_lod)
        part.visible=draw_tile
        if not draw_tile:
            culled_district_count+=1
            continue
        var props: Node3D=part.get_node("DistrictResources") as Node3D
        props.visible=tile!=active_tile
        if tile!=active_tile:
            var sim: Dictionary=Transit._local_state(city_state,
                local_home if district=="" else district).get("detail_sim",{})
            var offset: Vector3=Continuous.offset(tile,selected)
            var level: int=Visuals30.detail_level(controller.look_at,offset)
            var limit: int=Visuals30.resource_limit(level)
            var sig: String=Batches31.signature(sim.get("sites",[]),limit)
            if int(props.get_meta("visual_lod",-1))!=level or String(props.get_meta("resource_key",""))!=sig:
                for old in props.get_children():old.free()
                props.set_meta("visual_lod",level)
                props.set_meta("resource_key",sig)
                prop_builds+=Batches31.populate(props,sim.get("sites",[]),limit,world,tile,true)
                batched_resource_nodes+=props.get_child_count()
        # Close buildings keep their complete primitive models. Distant
        # non-active districts use GPU-instanced silhouettes grouped by type.
        var proxies: Node3D=part.get_node_or_null("BuildingLODs") as Node3D
        if proxies==null:
            proxies=Node3D.new()
            proxies.name="BuildingLODs"
            part.add_child(proxies)
        var use_proxies: bool=tile!=active_tile and building_lod<2
        proxies.visible=use_proxies
        if use_proxies:
            var proxy_sig: String=LOD32.signature(buildings,district,building_lod)
            if String(proxies.get_meta("signature",""))!=proxy_sig:
                for old in proxies.get_children():old.free()
                LOD32.populate(proxies,buildings,district,building_lod)
                proxies.set_meta("signature",proxy_sig)
            proxy_building_batches+=proxies.get_child_count()
        var current_buildings: Dictionary={}
        if tile!=active_tile and not use_proxies:
            for i in range(buildings.size()):
                var building: Dictionary=buildings[i]
                if String(building.get("district",""))!=district:continue
                var label_b: String=String(building.get("type","building"))+"_"+str(i)
                current_buildings[label_b]=true
                var ready: bool=bool(building.get("ready",false))
                var stage: int=3 if ready else Construction.stage(building,
                    CityRecipes.read_table("city_buildings").get("buildings",{}).get(String(building.get("type","")),{})
                )
                var sig: String=str(stage)+":"+str(ready)+":"+str(int(building.get("rotation",0)))
                var holder: Node3D=part.get_node_or_null(label_b) as Node3D
                if holder!=null and String(holder.get_meta("visual_sig",""))!=sig:
                    holder.free()
                    holder=null
                if holder==null:
                    holder=Node3D.new()
                    holder.name=label_b
                    holder.set_meta("visual_sig",sig)
                    holder.set_meta("is_building",true)
                    part.add_child(holder)
                    passive_building_mesh_builds+=1
                    _box(holder,Vector3(0.0,0.15,8.0),Vector3(3.0,0.27,4.3),
                        Color("#b7a381"),"FrontDoorStep")
                    if ready:
                        _building(holder,String(building.get("type","house")),Vector3.ZERO,true)
                    else:
                        _construction_site(holder,String(building.get("type","house")),Vector3.ZERO,building)
                holder.position=Vector3(float(building.get("x",0)),0.0,float(building.get("z",0)))
                holder.rotation_degrees.y=float(building.get("rotation",0))
        for child in part.get_children():
            if not bool(child.get_meta("is_building",false)):continue
            if use_proxies:
                if Stable33.low_detail_policy(building_lod)=="release":
                    child.free()
                else:
                    # Reuse full meshes if camera crosses the 195m threshold
                    # repeatedly. The next full pass validates their stage.
                    child.visible=false
            elif current_buildings.has(child.name):
                child.visible=true
            else:
                child.free()
        var live_agents: Dictionary={}
        if tile!=active_tile and building_lod>=1:
            for agent in agents:
                if String(agent.get("district",""))!=(local_home if district=="" else district):continue
                var label_a: String="DistrictAgent_"+str(agent.get("id",0))
                live_agents[label_a]=true
                var actor: Node3D=part.get_node_or_null(label_a) as Node3D
                var loaded: bool=float(agent.get("load",0.0))>0.0
                var is_wagon: bool=String(agent.get("role","")) in ["wagon","input_wagon","material"]
                if actor==null:
                    actor=Node3D.new()
                    actor.name=label_a
                    actor.set_meta("is_agent",true)
                    actor.set_meta("loaded",loaded)
                    part.add_child(actor)
                    if is_wagon:
                        _box(actor,Vector3(0,1.1,0),Vector3(3.7,1.2,5.0),
                            Color("#896442"),"CargoWagon")
                        if loaded:_box(actor,Vector3(0,2.0,0),Vector3(3.0,1.1,3.2),
                            Color("#c5a36d"),"VisibleGoodsCargo")
                    else:
                        _cylinder(actor,Vector3(0,1.25,0),0.55,2.2,Color("#7a927b"),"WorkerBody")
                elif is_wagon and bool(actor.get_meta("loaded",false))!=loaded:
                    var cargo: Node=actor.get_node_or_null("VisibleGoodsCargo")
                    if cargo!=null:cargo.free()
                    if loaded:_box(actor,Vector3(0,2.0,0),Vector3(3.0,1.1,3.2),
                        Color("#c5a36d"),"VisibleGoodsCargo")
                    actor.set_meta("loaded",loaded)
                actor.position=Vector3(float(agent.get("x",0)),0.0,float(agent.get("z",0)))
        for child in part.get_children():
            if bool(child.get_meta("is_agent",false)) and not live_agents.has(child.name):
                child.free()
    # Shared roads use the *same* safe gate chosen by 0.26 A* transport,
    # including a noncentral alternative when the center is blocked.
    # No street may appear at an impassable world-tile boundary.
    var current_signature: String=Visuals30.static_signature(city_state,world)
    if current_signature!=street_cache_signature:
        for old in combined_root.get_children():
            if String(old.name).begins_with("ContinuousStreet_"):old.free()
        var links: Array=Visuals30.connections(city_state,world,selected,shown_district_tiles)
        var i: int=0
        for link in links:
            i+=1
            var midpoint: Vector3=link["middle"]
            var along_x: bool=bool(link["east_west"])
            var length: float=float(link["length"])+0.7
            var shape:=Vector3(length,0.13,5.5) if along_x else Vector3(5.5,0.13,length)
            _box(combined_root,midpoint,shape,Color("#c3a371"),
                "ContinuousStreet_"+str(i))
        street_cache_signature=current_signature

func _render_seam_previews() -> void:
    if seam_preview_root==null:return
    for old in seam_preview_root.get_children():old.free()
    for dr in range(-1,2):
        for dc in range(-1,2):
            if dc==0 and dr==0:continue
            var tile: Vector2i=selected+Vector2i(dc,dr)
            var neighbor: Dictionary=World.cell(world,tile.x,tile.y)
            if neighbor.is_empty():continue
            # Existing owned 160m city districts already contain real streets,
            # buildings and workers. Do not cover them with passive terrain.
            if combined_city and shown_district_tiles.has(tile):continue
            var part:=Node3D.new()
            part.name="DetailNeighbor_%d_%d" % [dc,dr]
            var width: float=Continuous.TILE_SPAN if combined_city else SURFACE_WIDTH
            var depth: float=Continuous.TILE_SPAN if combined_city else SURFACE_DEPTH
            part.position=Vector3(float(dc)*width,0,float(dr)*depth)
            seam_preview_root.add_child(part)
            if combined_city:
                # Same 160m continuous-terrain renderer as neighboring
                # developed districts, but without inventing buildings or roads.
                part.add_child(Terrain28.surface(world,tile,"DistrictTerrain"))
                for river in Terrain28.water(world,tile):part.add_child(river)
            else:
                part.add_child(SeamTerrain42.surface(world,tile))
                SeamTerrain42.decorate(part,world,tile)
            # Runtime representation will switch between actual building
            # geometry and GPU-instanced silhouettes as camera approaches.
            part.set_meta("world_tile",tile)
            # A lightweight sea/river indication keeps all eight previews
            # readable before the user crosses into a different biome.
            if combined_city:continue
            if String(neighbor.get("biome","sea"))=="sea":
                _box(part,Vector3(0,-1.4,0),
                    Vector3(SURFACE_WIDTH,0.12,SURFACE_DEPTH),
                    Color("#3b86a8"),"NeighborSea")
            elif bool(neighbor.get("river",false)):
                _box(part,Vector3(0,-0.25,25.0),
                    Vector3(SURFACE_WIDTH,0.12,14.0),
                    Color("#419abb"),"NeighborRiver")

    _refresh_seam_neighbor_buildings()

func configure_town_sources_v47(capital: Dictionary,satellite: Dictionary,
        satellite_tile: Vector2i) -> void:
    capital_preview_state_v47=capital
    satellite_preview_state_v47=satellite
    satellite_preview_tile_v47=satellite_tile

func _refresh_seam_neighbor_buildings() -> void:
    # Draw real owners of nearby tiles, never dummy cities or free stock.
    # The full geometry is reused from the *same* _building() /
    # _construction_site() functions as the active 3D city.
    if seam_preview_root==null or combined_city or controller==null:return
    var definitions: Dictionary=CityRecipes.read_table("city_buildings").get("buildings",{})
    var capital: Dictionary=capital_preview_state_v47 if not capital_preview_state_v47.is_empty() else city_state
    for part in seam_preview_root.get_children():
        if not part is Node3D or not part.has_meta("world_tile"):continue
        var tile: Vector2i=part.get_meta("world_tile")
        var ownership: Dictionary=SecondCity47.source(world,tile,capital,
            satellite_preview_state_v47,satellite_preview_tile_v47)
        if ownership.is_empty():continue
        var town: Dictionary=ownership["town"]
        var district: String=String(ownership["district"])
        var eligible: Array=LOD32.eligible(town.get("buildings",[]),district)
        # Preview activity independently of buildings: workers move while
        # houses stay unchanged, and traffic is saved by actual walking.
        _refresh_neighbor_activity_v48(part,town,district,tile)
        var previous: Node3D=part.get_node_or_null("ActualNeighborBuildings") as Node3D
        if eligible.is_empty():
            if previous!=null:previous.free()
            continue
        var distance_to_center: float=Vector2(
            controller.look_at.x-part.position.x,
            controller.look_at.z-part.position.z).length()
        var full: bool=NeighborBuildings45.detailed(
            distance_to_center,controller.distance,eligible.size())
        var hybrid: bool=Hybrid46.active(
            distance_to_center,controller.distance,eligible.size())
        var mode: String="full" if full else ("hybrid" if hybrid else "lod")
        var signature: String=NeighborBuildings45.signature(
            eligible,district,full or hybrid,definitions)+":"+mode
        if previous!=null and String(previous.get_meta("render_key",""))==signature:
            continue
        if previous!=null:previous.free()
        var container:=Node3D.new()
        container.name="ActualNeighborBuildings"
        container.set_meta("render_key",signature)
        container.set_meta("full_3d",full)
        container.set_meta("mode",mode)
        part.add_child(container)
        var detailed: Array=[]
        var background: Array=eligible
        if full:
            for index in range(eligible.size()):
                detailed.append({"index":index,"data":eligible[index]})
            background=[]
        elif hybrid:
            var planned: Dictionary=Hybrid46.split(
                eligible,selected-tile,Hybrid46.model_budget(OS.has_feature("mobile")))
            detailed=planned["models"]
            background=planned["lod"]
        for entry in detailed:
            var b: Dictionary=entry["data"]
            var kind: String=String(b.get("type","house"))
            var holder:=Node3D.new()
            holder.name=kind+"_"+str(int(entry["index"]))
            holder.position=Vector3(float(b.get("x",0.0)),0.0,
                float(b.get("z",0.0)))
            holder.rotation_degrees.y=float(b.get("rotation",0))
            container.add_child(holder)
            if bool(b.get("ready",false)):
                _building(holder,kind,Vector3.ZERO,true)
            else:
                _construction_site(holder,kind,Vector3.ZERO,b)
        if not background.is_empty():
            LOD32.populate(container,background,district,1)

func _refresh_neighbor_activity_v48(part: Node3D,town: Dictionary,
        district: String,tile: Vector2i) -> void:
    var data: Dictionary=NeighborActivity48.snapshot(town,district)
    var key: String=NeighborActivity48.signature(data)
    var previous: Node3D=part.get_node_or_null("ActualNeighborActivity") as Node3D
    if previous!=null and String(previous.get_meta("render_key",""))==key:return
    if previous!=null:previous.free()
    if data.get("roads",[]).is_empty() and data.get("workers",[]).is_empty():return
    var group:=Node3D.new()
    group.name="ActualNeighborActivity"
    group.set_meta("render_key",key)
    part.add_child(group)
    NeighborActivity48.populate(group,data,world,tile,town)

func _activate_district(tile: Vector2i) -> void:
    if not combined_city or not shown_district_tiles.has(tile):return
    active_tile=tile
    district_id=Continuous.district_key(tile,world)
    selected_biome=Continuous.tile_biome(world,tile)
    pending_build=""
    placement_rotation=0
    placement_cell=Vector2(INF,INF)
    suggested_site={}
    _position_local_groups()
    refresh_buildings()
    _refresh_info()
    if placement_label!=null:
        placement_label.text="Linnaosa %d, %d valitud. Ehita siin või puuduta järgmist linnaosa." % [tile.x,tile.y]

func _overview_city() -> void:
    if not combined_city:return
    controller.call("overview",combined_bounds)

func _next_city_tile() -> void:
    if not combined_city or shown_district_tiles.is_empty():return
    var idx: int=shown_district_tiles.find(active_tile)
    var next: Vector2i=shown_district_tiles[(idx+1)%shown_district_tiles.size()]
    _activate_district(next)
    controller.call("focus_smooth",Continuous.offset(next,selected))

func _is_coastal(cell: Dictionary) -> bool:
    var c: int=int(cell.get("c",-1))
    var r: int=int(cell.get("r",-1))
    for delta in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
        var neighbor: Dictionary=World.cell(world,c+delta.x,r+delta.y)
        if not neighbor.is_empty() and not bool(neighbor.get("land",false)):return true
    return false

func _building(parent: Node3D, kind: String, place: Vector3, completed: bool) -> void:
    var timber:=Color("#805c3e") if completed else Color("#555e61")
    var thatch:=Color("#b49b61") if completed else Color("#6a7272")
    match kind:
        "hall":
            if int(city_state.get("age",0))>=1:
                _box(parent,place+Vector3(0,0.65,0),Vector3(19,1.3,14),Color("#99938a"),"BronzeHallFoundation")
            _box(parent,place+Vector3(0,4.1,0),Vector3(18,8,13),timber,"HallWalls")
            _roof(parent,place+Vector3(0,10.4,0),Vector3(21,7,16),thatch)
            _box(parent,place+Vector3(0,3,6.7),Vector3(3.1,6,0.5),Color("#473629"),"HallDoor")
        "house":
            WebArt50.place(parent,"timber_house",place,3.15,"WebTimberHouse")
        "lumber":
            for i in range(4):
                _cylinder(parent,place+Vector3(-4+i*2.6,0.6,0),0.8,9,Color("#816046"),"FelledLog")
            _roof(parent,place+Vector3(0,6,0),Vector3(13,5,9),Color("#846f52"))
        "well":
            _cylinder(parent,place+Vector3(0,1.4,0),3.3,2.8,Color("#828b8a"),"StoneWell")
            _cylinder(parent,place+Vector3(-3.2,4.5,0),0.35,6,Color("#815c3b"),"SupportA")
            _cylinder(parent,place+Vector3(3.2,4.5,0),0.35,6,Color("#815c3b"),"SupportB")
            _roof(parent,place+Vector3(0,8,0),Vector3(9,4,8),thatch)
        "quarry":
            for i in range(7):
                var x: float=(i%3-1)*3.9
                var z: float=(i/3-1)*3.4
                _box(parent,place+Vector3(x,1.1,z),Vector3(3.3,2.2,3.0),Color("#91928a"),"QuarryStone")
        "farm":
            for i in range(6):
                _box(parent,place+Vector3(-8+i*3.2,0.11,0),Vector3(1.5,0.22,18),
                    Color("#8a7249"),"PlowedRow")
                for j in range(5):
                    var foliage:=SphereMesh.new()
                    foliage.radius=0.65
                    foliage.height=1.3
                    _mesh(parent,foliage,place+Vector3(-8+i*3.2,0.8,-7+j*3.4),Color("#5e8d35"),"Crops")
        "saw":
            _box(parent,place+Vector3(0,2.9,-1),Vector3(13,5.8,10),timber,"SawmillWalls")
            _roof(parent,place+Vector3(0,7,-1),Vector3(15,5,12),Color("#936943"))
            _box(parent,place+Vector3(2,2,6),Vector3(10,2,3.5),Color("#967457"),"SawBench")
            for i in range(4):
                _cylinder(parent,place+Vector3(-3.0+i*2.0,1.4,7),0.6,5.0,Color("#b18a55"),"SawLogs")
        "market":
            WebArt50.place(parent,"market",place,3.5,"WebMarketStalls")
        "mill":
            WebArt50.place(parent,"windmill",place,3.4,"WebWindmill")
        "warehouse":
            _box(parent,place+Vector3(0,3.2,0),Vector3(17,6.4,12),timber,"WarehouseWalls")
            _box(parent,place+Vector3(0,0.65,0),Vector3(18,1.2,13),Color("#88867e"),"WarehouseBase")
            _roof(parent,place+Vector3(0,8.4,0),Vector3(20,6,15),Color("#776b54"))
            _box(parent,place+Vector3(0,3.0,6.2),Vector3(5.5,5.8,0.5),
                Color("#493b2a"),"WarehouseDoor")
            for i in range(3):
                _box(parent,place+Vector3(-5+float(i)*5,0.8,10),Vector3(3.5,1.6,3.5),
                    Color("#b78f5d"),"WarehouseCrates")
        "cellar":
            _box(parent,place+Vector3(0,1.7,0),Vector3(14,3.4,11),
                Color("#99988d"),"CellarStoneWalls")
            _roof(parent,place+Vector3(0,5.4,0),Vector3(16,4,13),Color("#a08a62"))
            _box(parent,place+Vector3(0,1.8,5.7),Vector3(3.4,3.6,0.5),
                Color("#5e4735"),"CellarDoor")
            for i in range(4):
                _cylinder(parent,place+Vector3(-5.0+float(i)*3.0,1.5,-6.5),
                    1.0,2.5,Color("#976e47"),"CellarBarrels")
        "vegetable_garden":
            for i in range(5):
                var x: float=-7.5+float(i)*3.8
                _box(parent,place+Vector3(x,0.23,0),Vector3(2.5,0.45,16),
                    Color("#674d30"),"GardenBed")
                for j in range(4):
                    var vegetable:=SphereMesh.new()
                    vegetable.radius=0.85
                    vegetable.height=1.4
                    _mesh(parent,vegetable,place+Vector3(x,0.95,-6.0+float(j)*3.8),
                        Color("#478144"),"Vegetables")
            for z in [-9.5,9.5]:
                _box(parent,place+Vector3(0,0.9,z),Vector3(22,1.8,0.5),
                    Color("#8d6a46"),"GardenFence")
        _:
            _box(parent,place+Vector3(0,2.5,0),Vector3(7,5,7),timber,"WorkshopWalls")
            _roof(parent,place+Vector3(0,6,0),Vector3(9,4,9),thatch)

func _construction_site(parent: Node3D, kind: String, place: Vector3, building: Dictionary) -> void:
    var spec: Dictionary=CityRecipes.read_table("city_buildings").get("buildings",{}).get(kind,{})
    var current_stage: int=Construction.stage(building,spec)
    # Foundations -> raised framing -> roof scaffold -> completed building.
    _box(parent,place+Vector3(0,0.22,0),Vector3(13,0.45,12),
        Color("#a09278"),"Stage0Foundation")
    if current_stage>=1:
        for x in [-5.3,5.3]:
            for z in [-4.8,4.8]:
                _cylinder(parent,place+Vector3(x,2.9,z),0.35,5.6,
                    Color("#90643e"),"Stage1TimberFrame")
    if current_stage>=2:
        _box(parent,place+Vector3(0,3,0),Vector3(10,4.5,9),
            Color("#967b5e"),"Stage2Walls")
        for x in [-6.0,6.0]:
            _box(parent,place+Vector3(x,6.5,0),Vector3(0.7,0.6,12.0),
                Color("#785539"),"Stage2RoofBeam")
    # Display ONLY materials that have actually reached this construction site.
    var delivered_stock: Dictionary=building.get("supply_delivered",{})
    var amount: float=0.0
    for key in delivered_stock.keys():amount+=float(delivered_stock[key])
    if amount>0:
        _box(parent,place+Vector3(8,0.65,5),Vector3(3.0,1.3,2.8),
            Color("#8b6540"),"BuildingMaterialPile")
        var bundles: int=mini(5,int(ceil(amount/8.0)))
        for i in range(bundles):
            _box(parent,place+Vector3(7.2+i*0.45,1.5,4.7),Vector3(0.4,0.5,1.5),
                Color("#b89564"),"DeliveredWoodOrStone")

func _clear_buildings() -> void:
    for child in construction_root.get_children():
        child.free()

func refresh_buildings() -> void:
    if construction_root==null:return
    rendered_buildings=0
    if can_build:
        var buildings: Array=city_state.get("buildings",[])
        var required: Dictionary={}
        var definitions: Dictionary=CityRecipes.read_table("city_buildings").get("buildings",{})
        for i in range(buildings.size()):
            var building: Dictionary=buildings[i]
            if String(building.get("district",""))!=district_id:continue
            var kind: String=String(building.get("type","building"))
            var label: String=kind+"_"+str(i)
            required[label]=true
            var complete: bool=bool(building.get("ready",false))
            var stage: int=3 if complete else Construction.stage(building,definitions.get(kind,{}))
            var sig: String=str(stage)+":"+str(complete)+":"+str(int(building.get("rotation",0)))
            var holder: Node3D=construction_root.get_node_or_null(label) as Node3D
            if holder!=null and String(holder.get_meta("visual_sig",""))!=sig:
                holder.free()
                holder=null
            if holder==null:
                holder=Node3D.new()
                holder.name=label
                holder.set_meta("visual_sig",sig)
                construction_root.add_child(holder)
                _box(holder,Vector3(0.0,0.15,8.0),Vector3(3.0,0.27,4.3),
                    Color("#b7a381"),"FrontDoorStep")
                if complete:
                    _building(holder,kind,Vector3.ZERO,true)
                else:
                    _construction_site(holder,kind,Vector3.ZERO,building)
                active_building_mesh_builds+=1
            var fallback:=Vector2(float((i%5-2)*26),float((i/5-2)*27))
            holder.position=Vector3(float(building.get("x",fallback.x)),0.0,float(building.get("z",fallback.y)))
            holder.rotation_degrees.y=float(building.get("rotation",0))
            rendered_buildings+=1
        for old in construction_root.get_children():
            if not required.has(String(old.name)):old.free()
        _refresh_resource_meshes()
        _refresh_worker_meshes()
        _refresh_freight_meshes()
        _refresh_district_transport_meshes()
        _refresh_grid()
        _refresh_roads()
        _refresh_bridges()
        _render_neighbors()
    else:
        _clear_buildings()
        # Changing from the capital to an unowned tile must not leave
        # the old town's 3D workers, paths or resources on screen.
        for group in [resource_root,worker_root,freight_root,plot_root,roads_root,bridge_root]:
            if group!=null:
                for child in group.get_children():
                    child.queue_free()
        previous_worker_positions.clear()
    _refresh_actions()
    _refresh_info()

func _refresh_resource_meshes() -> void:
    if resource_root==null:return
    var sim: Dictionary=city_state.get("detail_sim",{})
    if district_id!="":
        sim=city_state.get("transport_v26",{}).get("surfaces",{}).get(district_id,{})
    var signature: String=district_id+":"+Batches31.signature(sim.get("sites",[]),1024)
    if String(resource_root.get_meta("resource_key",""))==signature:return
    for old in resource_root.get_children():old.free()
    resource_root.set_meta("resource_key",signature)
    var local_tile: Vector2i=active_tile
    batched_resource_nodes+=Batches31.populate(resource_root,sim.get("sites",[]),1024,
        world,local_tile,combined_city)


func _refresh_worker_meshes() -> void:
    if worker_root==null:return
    for old in worker_root.get_children():old.queue_free()
    var sim: Dictionary=city_state.get("detail_sim",{}) if district_id=="" else {}
    for i in range(sim.get("workers",[]).size()):
        var person: Dictionary=sim["workers"][i]
        var p:=Vector3(float(person["x"]),0.0,float(person["z"]))
        var previous: Vector3=previous_worker_positions.get(i,p)
        var body:=Node3D.new()
        body.name="Worker_"+str(i)
        worker_root.add_child(body)
        body.position=previous
        _cylinder(body,Vector3(0,1.3,0),0.55,2.2,Color("#9c6f4a"),"WorkerBody")
        var head:=SphereMesh.new()
        head.radius=0.6
        head.height=1.2
        _mesh(body,head,Vector3(0,2.95,0),Color("#dfba94"),"WorkerHead")
        if float(person.get("carry",0))>0:
            _box(body,Vector3(0.8,1.9,0),Vector3(1.3,1.4,1.1),
                Color("#74563b") if person["kind"]=="wood" else Color("#8f9798"),"Cargo")
        if not previous.is_equal_approx(p):
            body.create_tween().tween_property(body,"position",p,0.68).set_trans(Tween.TRANS_SINE)
        previous_worker_positions[i]=p
    # Independent builders stand by real construction sites, not at the town hall.
    for builder in sim.get("builders",[]):
        var builder_id: String="builder_"+str(builder.get("id",0))
        var position3:=Vector3(float(builder.get("x",0)),0.0,float(builder.get("z",0)))
        var previous_builder: Vector3=previous_worker_positions.get(builder_id,position3)
        var actor:=Node3D.new()
        actor.name="Builder_"+str(builder.get("id",0))
        actor.position=previous_builder
        worker_root.add_child(actor)
        _cylinder(actor,Vector3(0,1.28,0),0.55,2.1,Color("#536d96"),"BuilderBody")
        var head:=SphereMesh.new()
        head.radius=0.55
        head.height=1.1
        _mesh(actor,head,Vector3(0,2.8,0),Color("#d6b08b"),"BuilderHead")
        _box(actor,Vector3(0,3.52,0),Vector3(1.6,0.45,1.5),
            Color("#987443"),"BuildersHat")
        if String(builder.get("phase",""))=="working":
            _box(actor,Vector3(1.1,1.8,0),Vector3(0.45,0.25,1.2),
                Color("#99918b"),"BuilderHammer")
        if float(builder.get("cargo_amount",0))>0:
            _box(actor,Vector3(1.0,1.6,0),Vector3(1.2,1.4,1.1),
                Color("#82633e") if String(builder.get("cargo_kind",""))=="wood" else Color("#969b9c"),
                "ConstructionCargo")
        if not previous_builder.is_equal_approx(position3):
            actor.create_tween().tween_property(actor,"position",position3,0.68).set_trans(Tween.TRANS_SINE)
        previous_worker_positions[builder_id]=position3

func _refresh_freight_meshes() -> void:
    if freight_root==null:return
    for old in freight_root.get_children():old.queue_free()
    var sim: Dictionary=city_state.get("detail_sim",{}) if district_id=="" else {}
    for hauler in sim.get("haulers",[]):
        var id_key: String="hauler_"+str(hauler.get("id",0))
        var position3:=Vector3(float(hauler.get("x",0)),0.0,float(hauler.get("z",0)))
        var previous: Vector3=previous_worker_positions.get(id_key,position3)
        var wagon:=Node3D.new()
        wagon.name="GoodsWagon_"+str(hauler.get("id",0))
        wagon.position=previous
        freight_root.add_child(wagon)
        _box(wagon,Vector3(0,1.1,0),Vector3(3.6,0.8,5.1),Color("#795332"),"WagonBody")
        for side in [-1.9,1.9]:
            for axle in [-1.5,1.5]:
                var wheel:=CylinderMesh.new()
                wheel.top_radius=0.9
                wheel.bottom_radius=0.9
                wheel.height=0.35
                var m:=_mesh(wagon,wheel,Vector3(side,0.85,axle),
                    Color("#39322b"),"WoodenWheel")
                m.rotation_degrees=Vector3(0,0,90)
        _cylinder(wagon,Vector3(0,2.3,-1.4),0.5,2.0,Color("#566f59"),"WagonDriver")
        if float(hauler.get("load",0))>0.0:
            _box(wagon,Vector3(0,2.0,0.65),Vector3(3.0,1.6,3.0),
                Color("#b99865"),"VisibleGoodsCargo")
        if not previous.is_equal_approx(position3):
            wagon.create_tween().tween_property(wagon,"position",position3,0.68).set_trans(Tween.TRANS_SINE)
        previous_worker_positions[id_key]=position3

func _refresh_district_transport_meshes() -> void:
    var network: Dictionary=city_state.get("transport_v26",{})
    if network.is_empty():return
    var local_id: String=district_id if district_id!="" else Transit.home_key(city_state)
    for agent in network.get("agents",[]):
        if String(agent.get("district",""))!=local_id:continue
        var role: String=String(agent.get("role",""))
        var wagon: bool=role in ["wagon","input_wagon","material"]
        var root_node: Node3D=freight_root if wagon else worker_root
        var actor:=Node3D.new()
        actor.name=("DistrictWagon_" if wagon else "DistrictWorker_")+str(agent.get("id",0))
        actor.position=Vector3(float(agent.get("x",0)),0.0,float(agent.get("z",0)))
        root_node.add_child(actor)
        if wagon:
            _box(actor,Vector3(0,1.0,0),Vector3(3.3,0.8,4.6),Color("#84603c"),"WagonBody")
            for side in [-1.8,1.8]:
                for axle in [-1.3,1.3]:
                    var wheel:=CylinderMesh.new()
                    wheel.top_radius=0.85
                    wheel.bottom_radius=0.85
                    wheel.height=0.30
                    var mesh:=_mesh(actor,wheel,Vector3(side,0.77,axle),
                        Color("#383027"),"CartWheel")
                    mesh.rotation_degrees.z=90.0
            if float(agent.get("load",0))>0.0:
                _box(actor,Vector3(0,1.9,0),Vector3(2.8,1.3,2.7),
                    Color("#c5a36d"),"VisibleGoodsCargo")
        else:
            _cylinder(actor,Vector3(0,1.25,0),0.55,2.1,
                Color("#758c68") if role=="gatherer" else Color("#526e9b"),"WorkerBody")
            if role=="gatherer" and float(agent.get("load",0))>0.0:
                _box(actor,Vector3(0.9,1.65,0),Vector3(1.2,1.2,1.0),
                    Color("#91754f"),"WorkerCargo")

func _refresh_roads() -> void:
    if roads_root==null:return
    for old in roads_root.get_children():old.queue_free()
    var local: Dictionary=Transit._local_state(city_state,
        Transit.home_key(city_state) if district_id=="" else district_id) if city_state.has("transport_v26") else city_state
    var sim: Dictionary=local.get("detail_sim",{})
    for tile in Paths.road_tiles(sim):
        if Terrain.river_lane(sim,float(tile["x"]),float(tile["z"])) and Terrain.crossing_kind(sim,int(roundf(float(tile["x"])/Terrain.CELL)))=="":
            continue
        var amount: float=float(tile["strength"])
        var shade:=Color("#927451") if amount<8.0 else Color("#ab9165")
        _box(roads_root,Vector3(float(tile["x"]),Nav.elevation(sim,float(tile["x"]),float(tile["z"]))+0.11,float(tile["z"])),
            Vector3(7.5+minf(1.0,amount*0.07),0.06,7.5+minf(1.0,amount*0.07)),
            shade,"Footpath")
    # Connect adjacent high-traffic tiles into continuous, narrower streets.
    # Links are generated by A* traversability checks (no wall/river shortcuts).
    var street_number: int=0
    for link in Paths.road_links(local):
        var a: Vector2=link["a"]
        var b: Vector2=link["b"]
        var delta: Vector2=b-a
        var middle: Vector2=(a+b)*0.5
        var amount: float=float(link["strength"])
        var width: float=5.0+minf(1.3,amount*0.09)
        var road_color:=Color("#947b57") if amount<8.0 else Color("#bba077")
        var segment:=_box(roads_root,
            Vector3(middle.x,Nav.elevation(sim,middle.x,middle.y)+0.14,middle.y),
            Vector3(width,0.08,delta.length()+1.2),road_color,"TrafficStreetLink_"+str(street_number))
        segment.rotation.y=atan2(delta.x,delta.y)
        street_number+=1
    # Draw a short connector to the reachable access of each building.
    # Actual worn footpaths still arise ONLY from A* traffic.
    var buildings: Array=city_state.get("buildings",[])
    var connected: Dictionary={}
    if district_id=="" and not buildings.is_empty():
        connected=Paths.connected_cells(local,Access.entrance(buildings[0]),0)
    for i in range(buildings.size()):
        var building: Dictionary=buildings[i]
        if String(building.get("district",""))!=district_id:continue
        if float(building.get("hp",1.0))<=0.0:continue
        var centre: Vector2=Access.center(building)
        var entry: Vector2=Access.reachable_from_map(city_state,i,connected,0)
        if district_id!="":
            # In 0.25 an annex is a separate 3D tile. Its cross-tile
            # logistics are not yet a single 3D pathfinding graph.
            entry=Access.entrance(building)
        if entry.x>1000.0:continue
        var side: Vector2=(entry-centre).normalized()
        var mid: Vector2=centre+side*13.5
        var east_west: bool=absf(side.x)>0.5
        var segment_size:=Vector3(14.0,0.09,2.9) if east_west else Vector3(2.9,0.09,14.0)
        _box(roads_root,Vector3(mid.x,Nav.elevation(sim,mid.x,mid.y)+0.19,mid.y),
            segment_size,Color("#ae966e"),"DoorAccessPath_"+str(i))
        _box(roads_root,Vector3(entry.x,Nav.elevation(sim,entry.x,entry.y)+0.17,entry.y),
            Vector3(3.4,0.10,3.4),Color("#d6b77d"),"DoorAccessPoint_"+str(i))

    # Each adjoining owned world square has a local gate at ±70 m.
    # The partner tile's matching gate is separated by a 20m travel link.
    var current: String=district_id if district_id!="" else Transit.home_key(city_state)
    if current!="":
        var current_pair: PackedStringArray=current.split(":")
        if current_pair.size()==2:
            var cx: int=int(current_pair[0])
            var cy: int=int(current_pair[1])
            for owned_key in Transit.all_keys(city_state):
                if owned_key==current:continue
                var parts: PackedStringArray=owned_key.split(":")
                if parts.size()!=2:continue
                var dx: int=int(parts[0])-cx
                var dy: int=int(parts[1])-cy
                if absi(dx)+absi(dy)!=1:continue
                var gate:=Vector2(float(dx)*70.0,float(dy)*70.0)
                var midpoint:=gate-Vector2(float(dx)*8.0,float(dy)*8.0)
                var extents:=Vector3(19.0,0.12,4.0) if dx!=0 else Vector3(4.0,0.12,19.0)
                _box(roads_root,Vector3(midpoint.x,0.24,midpoint.y),
                    extents,Color("#bda375"),"DistrictGateRoad_"+owned_key)

func _refresh_bridges() -> void:
    if bridge_root==null:return
    for old in bridge_root.get_children():old.queue_free()
    var local: Dictionary=Transit._local_state(city_state,
        Transit.home_key(city_state) if district_id=="" else district_id) if city_state.has("transport_v26") else city_state
    var sim: Dictionary=local.get("detail_sim",{})
    if Nav.enabled(sim):
        # The same crossing descriptors are used by A* to permit river edges.
        for crossing in Nav.crossings(sim):
            var bridge: bool=String(crossing["kind"])=="bridge"
            var along_x: bool=String(crossing["axis"])=="x"
            var x: float=float(crossing["x"])
            var z: float=float(crossing["z"])
            var shape:=Vector3(8.5,0.36,18.0) if along_x else Vector3(18.0,0.36,8.5)
            var waterbed: float=Nav.ground(sim,x,z)
            var y: float=maxf(0.58,waterbed+0.57) if bridge else waterbed+0.28
            _box(bridge_root,Vector3(x,y,z),shape,
                Color("#89643f") if bridge else Color("#aaa18a"),
                ("TimberBridge_" if bridge else "StoneFord_")+str(bridge_root.get_child_count()))
            if bridge:
                for side in [-4.0,4.0]:
                    var rail_x: float=x+side if along_x else x
                    var rail_z: float=z if along_x else z+side
                    var rail_size:=Vector3(0.45,0.6,18.0) if along_x else Vector3(18.0,0.6,0.45)
                    _box(bridge_root,Vector3(rail_x,y+1.25,rail_z),rail_size,
                        Color("#735238"),"BridgeRail")
        return
    if not Terrain.river_at(sim,0.0,0.0):return
    for x_cell in Terrain.FORDS:
        var xf: float=float(x_cell)*Terrain.CELL
        _box(bridge_root,Vector3(xf,-0.06,25),Vector3(8.2,0.20,18),
            Color("#a49b82"),"StoneFord")
    for bridge in sim.get("bridges",[]):
        var x: float=float(bridge["x"])*Terrain.CELL
        _box(bridge_root,Vector3(x,0.62,25),Vector3(8.5,0.45,22),
            Color("#856648"),"TimberBridge")
        for side in [-4.0,4.0]:
            _box(bridge_root,Vector3(x+side,2.1,25),Vector3(0.45,0.6,22),
                Color("#775333"),"BridgeRail")
            for end_z in [15.0,35.0]:
                _box(bridge_root,Vector3(x+side,1.35,end_z),Vector3(0.7,2.8,0.7),
                    Color("#735238"),"BridgePost")

func _placement_tile(point: Vector2, color: Color, label: String, width: float=8.5) -> MeshInstance3D:
    var square:=BoxMesh.new()
    square.size=Vector3(width,0.055,width)
    var instance:=MeshInstance3D.new()
    instance.name=label+"_"+str(plot_root.get_child_count())
    instance.mesh=square
    instance.position=Vector3(point.x,0.21,point.y)
    var material: StandardMaterial3D
    # Highlight material changes while hovering, so never share the preview.
    if label=="BuildPlacementPreview":
        material=StandardMaterial3D.new()
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color=color
    else:
        var key: String=label+":"+color.to_html(true)
        if grid_materials.has(key):
            material=grid_materials[key]
        else:
            material=StandardMaterial3D.new()
            material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
            material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
            material.albedo_color=color
            grid_materials[key]=material
    instance.material_override=material
    plot_root.add_child(instance)
    return instance

func _refresh_grid() -> void:
    if plot_root==null:return
    if pending_build=="" and bool(plot_root.get_meta("idle_grid",false)):return
    plot_root.set_meta("idle_grid",pending_build=="")
    for old in plot_root.get_children():old.free()
    placement_marker=null
    placement_ghost=null
    placement_ghost_material=null
    if not can_build:return
    # Neutral fine lines stay visible outside build mode; status fills only
    # appear while a building is selected to avoid covering the 3D terrain.
    var line_color:=Color(0.93,0.89,0.72,0.17)
    for n in range(-8,9):
        var grid_coordinate: float=float(n)*Spatial.STEP-5.0
        var horizontal:=BoxMesh.new()
        horizontal.size=Vector3(160.0,0.02,0.12)
        var h:=_placement_tile(Vector2(0.0,grid_coordinate),line_color,"BuildGridLine",0.12)
        h.mesh=horizontal
        var vertical:=BoxMesh.new()
        vertical.size=Vector3(0.12,0.02,160.0)
        var v:=_placement_tile(Vector2(grid_coordinate,0.0),line_color,"BuildGridLine",0.12)
        v.mesh=vertical
    if pending_build=="":
        return
    if pending_build!="bridge":
        for z in range(-7,8):
            for x in range(-7,8):
                var point:=Vector2(float(x)*Spatial.STEP,float(z)*Spatial.STEP)
                var allowed: bool=Spatial.can_place(city_state,point,district_id)
                var shade:=Color(0.19,0.89,0.52,0.31) if allowed else Color(0.91,0.24,0.22,0.25)
                _placement_tile(point,shade,"BuildPlotOpen" if allowed else "BuildPlotBlocked")
    placement_marker=_placement_tile(Vector2.ZERO,Color(1.0,0.83,0.27,0.72),"BuildPlacementPreview",9.4)
    placement_marker.hide()
    if pending_build!="bridge":
        placement_ghost=Node3D.new()
        placement_ghost.name="BuildModelPreview"
        plot_root.add_child(placement_ghost)
        # Exact same primitive geometry as the completed building, rendered
        # with a transparent single-color material (no collision, no cost).
        _building(placement_ghost,pending_build,Vector3.ZERO,true)
        placement_ghost_material=StandardMaterial3D.new()
        placement_ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        placement_ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        placement_ghost_material.albedo_color=Color(0.28,0.98,0.69,0.48)
        for part in placement_ghost.get_children():
            if part is MeshInstance3D:
                var preview_part: MeshInstance3D=part as MeshInstance3D
                preview_part.material_override=placement_ghost_material
                preview_part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        placement_ghost.rotation_degrees.y=float(placement_rotation)
        placement_ghost.hide()
    if is_finite(placement_cell.x):
        _set_placement_marker(placement_cell)

func _set_placement_marker(cell: Vector2) -> void:
    placement_cell=cell
    if placement_marker==null:return
    var valid: bool=can_build and Spatial.can_place(city_state,cell,district_id)
    var material: StandardMaterial3D=placement_marker.material_override as StandardMaterial3D
    material.albedo_color=Color(0.99,0.82,0.23,0.78) if valid else Color(1.0,0.14,0.19,0.83)
    placement_marker.position=Vector3(cell.x,0.32,cell.y)
    placement_marker.show()
    if placement_ghost!=null:
        placement_ghost.position=Vector3(cell.x,0.24,cell.y)
        placement_ghost.rotation_degrees.y=float(placement_rotation)
        if placement_ghost_material!=null:
            placement_ghost_material.albedo_color=Color(0.27,0.98,0.66,0.45) if valid else Color(0.99,0.25,0.26,0.47)
        placement_ghost.show()
    if placement_label!=null and pending_build!="":
        placement_label.text=("Sobiv ehituskoht" if valid else "Keelatud ehituskoht")+" (%d, %d m), suund %d°. " % [int(cell.x),int(cell.y),placement_rotation]+("Puuduta kinnitamiseks." if valid else "Vali roheline ruut.")

func _hover_ground(pos: Vector3) -> void:
    if not can_build or pending_build=="" or pending_build=="bridge":return
    if combined_city:
        if Continuous.at_position(world,city_state,selected,pos)!=active_tile:return
        pos=Continuous.local_position(active_tile,selected,pos)
    _set_placement_marker(Spatial.snap(Vector2(pos.x,pos.z)))

func _rotate_placement(degrees: int) -> void:
    if pending_build=="" or pending_build=="bridge":return
    placement_rotation=posmod(placement_rotation+degrees,360)
    if is_finite(placement_cell.x):
        _set_placement_marker(placement_cell)
    elif placement_label!=null:
        placement_label.text="Ehitis: "+pending_build+" | Suund: %d° | Vali roheline ruut." % placement_rotation
    if placement_ghost!=null:
        placement_ghost.rotation_degrees.y=float(placement_rotation)

func _cancel_placement() -> void:
    pending_build=""
    placement_rotation=0
    placement_cell=Vector2(INF,INF)
    if placement_label!=null:placement_label.text="Ehituskoha valik tühistatud."
    _refresh_grid()
    _refresh_actions()

func _ground_clicked(pos: Vector3) -> void:
    if combined_city:
        var clicked: Vector2i=Continuous.at_position(world,city_state,selected,pos)
        if clicked.x<0:return
        if clicked!=active_tile:
            _activate_district(clicked)
            return
        pos=Continuous.local_position(active_tile,selected,pos)
    if not can_build or pending_build=="":return
    if pending_build=="bridge":
        var local: Dictionary=Transit._local_state(city_state,
            Transit.home_key(city_state) if district_id=="" else district_id) if city_state.has("transport_v26") else city_state
        var sim: Dictionary=local.get("detail_sim",{})
        if Nav.enabled(sim):
            var valid: bool=false
            for axis in ["x","z"]:
                var index: int=int(roundf((pos.x if axis=="x" else pos.z)/Terrain.CELL))
                var crossing: Vector2=Nav.bridge_position(sim,axis,index)
                if Nav.can_bridge(sim,axis,index) and crossing.distance_to(Vector2(pos.x,pos.z))<=10.0:
                    valid=true
                    break
            if not valid:
                if info!=null:info.text="Sild peab olema jõel asuvas läbitavas sillaehituskohas."
                return
        else:
            var x_cell: int=int(roundf(pos.x/Terrain.CELL))
            if not Terrain.can_place_bridge(sim,x_cell) or pos.z<Terrain.RIVER_NEAR or pos.z>Terrain.RIVER_FAR:
                if info!=null:info.text="Sild tuleb ehitada jõe kohal: Z 18–32 m, X -30 või +30 m"
                return
        pending_build=""
        bridge_requested.emit(pos.x,pos.z)
        return
    var snapped: Vector2=Spatial.snap(Vector2(pos.x,pos.z))
    _set_placement_marker(snapped)
    if not Spatial.can_place(city_state,snapped,district_id):
        if info!=null:info.text="Ehituskoht on hõivatud või väljaspool linna: "+str(snapped)
        return
    var kind: String=pending_build
    var rotation: int=placement_rotation
    pending_build=""
    placement_rotation=0
    placement_cell=Vector2(INF,INF)
    build_at_requested.emit(kind,snapped.x,snapped.y,rotation)

func select_building(kind: String) -> void:
    if not can_build or not _can_build(kind):return
    pending_build=kind
    placement_rotation=0
    # Preserve the original 0-degree starting orientation for all legacy
    # interactions. The separate planning button applies a street-aligned
    # facing only when the player explicitly requests it.
    suggested_site=Planner.plan(city_state,kind,district_id)
    placement_cell=suggested_site.get("position",Spatial.next_free(city_state))
    if district_id!="" and suggested_site.is_empty():
        placement_cell=Vector2(INF,INF)
    if placement_label!=null:
        placement_label.text="EHITUS: "+kind+" — plaanitud krunt on kollane. Pööra või vali muu roheline ruut."
    _refresh_grid()
    _refresh_actions()

func _recommend_placement() -> void:
    if pending_build=="" or pending_build=="bridge" or not can_build:return
    suggested_site=Planner.plan(city_state,pending_build,district_id)
    if suggested_site.is_empty():
        if placement_label!=null:placement_label.text="Vaba ligipääsetavat krunti ei leitud."
        return
    placement_cell=suggested_site["position"]
    placement_rotation=int(suggested_site.get("rotation",0))
    _set_placement_marker(placement_cell)
    if placement_label!=null:
        placement_label.text="Planeeritud krunt %d, %d m • suund %d° • %d võimalikku kohta. Puuduta ehitamiseks." % [
            int(placement_cell.x),int(placement_cell.y),placement_rotation,
            int(suggested_site.get("plots",0))]


func _refresh_info() -> void:
    if info==null:return
    var shown: Vector2i=active_tile if combined_city else selected
    var terrain_size: String="160 × 160 m / ruut" if combined_city else "225 × 195 m"
    var text_line: String="%s • Detailruut %d × %d • %s • %s" % [
        String(city_state.get("city_name","Pealinn")),shown.x,shown.y,selected_biome,terrain_size]
    if combined_city:text_line+=" • Ühine 3D linn (%d linnaosa)" % shown_district_tiles.size()
    if district_id!="":text_line+=" • Linna laiendus (ühine ladu)"
    if can_build and city_state.has("realms"):
        var realm: Dictionary=city_state["realms"][0]
        var resources: Dictionary=realm["resources"]
        text_line+=" | Elanikke %d | Puit %.0f | Kivi %.0f | Vesi %.0f | Käik %d" % [
            int(realm.get("pop",3)),float(resources.get("wood",0)),
            float(resources.get("stone",0)),float(resources.get("water",0)),
            int(float(city_state.get("time",0))/60.0)]
        var sim: Dictionary=city_state.get("detail_sim",{})
        text_line+=" | Metsas %.0f puitu | Maardlates %.0f kivi | Töölisi %d" % [
            Spatial.count_remaining(city_state,"wood"),Spatial.count_remaining(city_state,"stone"),
            sim.get("workers",[]).size()]
        if Terrain.river_at(sim,0,0):
            text_line+=" | Sildu %d" % sim.get("bridges",[]).size()
        var streets: Dictionary=Paths.roads_summary(sim)
        text_line+=" | Sissekäidud teeruutusid %d" % int(streets["tiles"])
        var work: Dictionary=Materials.report(city_state)
        var priority: Dictionary=Schedule.report(city_state)
        text_line+=" | Ehitajaid %d | Ehitusel %d | Vedamas %d | Kohaletoimetatud %.0f | Kõrge prioriteediga %d" % [
            int(work["builders"]),int(work["sites"]),int(work["in_transit"]),float(work["delivered"]),int(priority["high"])]
        var transport: Dictionary=Freight.summary(city_state)
        text_line+=" | Kaubavankreid %d | Veotöölisi %d | Ootel %.0f | Koormas %.0f | Kohaletoimetamisi %d" % [
            int(transport["haulers"]),int(transport["workers"]),float(transport["waiting"]),
            float(transport["in_transit"]),int(transport["trips"])]
    else:
        text_line+=" | Maastikuvaade (ehitamine ainult oma pealinna ruudul)"
    info.text=text_line
    info.tooltip_text=text_line

func _on_web_edge(delta: Vector2i,local_focus: Vector3) -> void:
    var next: Vector2i=selected+delta
    if World.cell(world,next.x,next.y).is_empty():
        controller.restore_detail_focus(
            Vector3(clampf(controller.look_at.x,-controller.seam_half.x+0.6,controller.seam_half.x-0.6),
                controller.look_at.y,clampf(controller.look_at.z,-controller.seam_half.y+0.6,controller.seam_half.y-0.6)),
            controller.distance)
        return
    seamless_neighbor_requested.emit(next.x,next.y,local_focus,controller.distance)

func _navigate_neighbor(delta: Vector2i) -> void:
    # All four directions work in any detail view, not only owned districts.
    var next: Vector2i=selected+delta
    if World.cell(world,next.x,next.y).is_empty():return
    neighbor_requested.emit(next.x,next.y)

func _refresh_actions() -> void:
    if actions==null:return
    for child in actions.get_children():
        child.queue_free()
    # Navigation must be available even on unowned tiles and on water.
    for direction in [
            {"title":"Kaart ↑","move":Vector2i(0,-1)},
            {"title":"Kaart ↓","move":Vector2i(0,1)},
            {"title":"Kaart ←","move":Vector2i(-1,0)},
            {"title":"Kaart →","move":Vector2i(1,0)}]:
        var next: Vector2i=selected+direction["move"]
        var arrow:=Button.new()
        arrow.text=String(direction["title"])
        arrow.disabled=World.cell(world,next.x,next.y).is_empty()
        arrow.pressed.connect(_navigate_neighbor.bind(direction["move"]))
        actions.add_child(arrow)
    if not can_build:
        return
    if combined_city:
        var whole:=Button.new()
        whole.text="Vaata kogu linna"
        whole.pressed.connect(_overview_city)
        actions.add_child(whole)
        var next_district:=Button.new()
        next_district.text="Järgmine linnaosa"
        next_district.pressed.connect(_next_city_tile)
        actions.add_child(next_district)
    if pending_build!="":
        if pending_build!="bridge":
            var planned:=Button.new()
            planned.text="Soovita linna krunti"
            planned.pressed.connect(_recommend_placement)
            actions.add_child(planned)
            var rotate_left:=Button.new()
            rotate_left.text="Pööra ↶ 90°"
            rotate_left.pressed.connect(_rotate_placement.bind(-90))
            actions.add_child(rotate_left)
            var rotate_right:=Button.new()
            rotate_right.text="Pööra ↷ 90°"
            rotate_right.pressed.connect(_rotate_placement.bind(90))
            actions.add_child(rotate_right)
        var cancel:=Button.new()
        cancel.text="Tühista ehitise paigutamine"
        cancel.pressed.connect(_cancel_placement)
        actions.add_child(cancel)
    var turn:=Button.new()
    turn.text="+10 käiku"
    turn.pressed.connect(func(): turns_requested.emit(10))
    actions.add_child(turn)
    var study:=Button.new()
    study.text="Teadus"
    study.tooltip_text="Ava linna uurimismenüü"
    study.pressed.connect(func(): research_requested.emit())
    actions.add_child(study)
    var science_auto:=Button.new()
    science_auto.text="Teaduse AI: "+("sees" if bool(city_state.get("research_ai_v39",{}).get("enabled",false)) else "väljas")
    science_auto.tooltip_text="Automaatne teaduste valik, käsitsi uuringut katkestamata"
    science_auto.pressed.connect(func(): research_ai_requested.emit())
    actions.add_child(science_auto)
    var capital_auto:=Button.new()
    var is_second: bool=bool(city_state.get("satellite_town",false))
    var ai_on: bool=bool(city_state.get("auto_build_v47",false)) if is_second else \
        bool(city_state.get("capital_ai_v38",{}).get("enabled",false))
    capital_auto.text=("Teise linna AI: " if is_second else "Linna AI: ")+\
        ("sees" if ai_on else "väljas")
    capital_auto.tooltip_text="Lülita teise linna ehitus-AI sisse või välja" if is_second else \
        "Lülita pealinna ehitus-AI sisse või välja"
    capital_auto.pressed.connect(func(): capital_ai_requested.emit())
    actions.add_child(capital_auto)
    var bridge_state: Dictionary=Transit._local_state(city_state,
        Transit.home_key(city_state) if district_id=="" else district_id) if city_state.has("transport_v26") else city_state
    var bridge_sim: Dictionary=bridge_state.get("detail_sim",{})
    if (Nav.enabled(bridge_sim) and not bridge_sim.get("terrain_v29",{}).get("segments",[]).is_empty()) or (not Nav.enabled(bridge_sim) and Terrain.river_at(bridge_sim,0.0,0.0)):
        var bridge_button:=Button.new()
        bridge_button.text="Ehita sild (28 puitu, 18 kivi)"
        bridge_button.pressed.connect(func():
            pending_build="bridge"
            info.text="SILD: vali vee kohal sobiv sillaehituskoht, ±30 m mööda jõelõiku.")
        actions.add_child(bridge_button)
    for kind in ["house","lumber","well","quarry","farm",
            "saw","warehouse","market","vegetable_garden","cellar"]:
        var button:=Button.new()
        button.text="Ehita "+kind
        button.disabled=not _can_build(kind)
        var reason: String=Unlock36.block(city_state,kind)
        if reason!="":button.tooltip_text=reason
        button.pressed.connect(select_building.bind(kind))
        actions.add_child(button)
    # No wrapping informational label in the one-row toolbar: on phones
    # it grows to multiple lines and can hide the 3D terrain.
    for i in range(1,city_state.get("buildings",[]).size()):
        var b: Dictionary=city_state["buildings"][i]
        if bool(b.get("ready",false)):continue
        var current: String=Schedule.normalize(String(b.get("priority","normal")))
        var choices: Array[String]=["low","normal","high"]
        var next_priority: String=choices[(choices.find(current)+1)%choices.size()]
        var btn:=Button.new()
        btn.text="%s #%d: %s (muuda)" % [String(b.get("type","hoone")),i,current]
        btn.pressed.connect(_priority_click.bind(i,next_priority))
        actions.add_child(btn)

func _priority_click(index: int, level: String) -> void:
    priority_requested.emit(index,level)

func _can_build(kind: String) -> bool:
    if not city_state.has("realms"):return false
    var defs: Dictionary=CityRecipes.read_table("city_buildings").get("buildings",{})
    if not defs.has(kind):return false
    var d: Dictionary=defs[kind]
    if int(d.get("age",0))>int(city_state.get("age",0)):return false
    if not Unlock36.allowed(city_state,kind):return false
    for req in d.get("requires",[]):
        var exists: bool=false
        for b in city_state["buildings"]:
            if String(b.get("type",""))==String(req) and bool(b.get("ready",false)):
                exists=true
                break
        if not exists:return false
    return CityEconomy.can_afford(city_state["realms"][0]["resources"],d.get("cost",{}))

func open_tile(next_world: Dictionary, c: int, r: int, city: Dictionary, capital: bool, district: String="") -> void:
    world=next_world
    selected=Vector2i(c,r)
    active_tile=selected
    city_state=city
    can_build=capital
    district_id=district
    combined_city=can_build and Continuous.active(world,city_state,selected)
    shown_district_tiles.clear()
    if combined_city:shown_district_tiles=Continuous.visible(world,city_state,selected)
    combined_bounds=Continuous.bounds(shown_district_tiles,selected) if combined_city else {}
    if controller!=null:
        controller.call("set_city_bounds",combined_bounds)
        # Same detail boundary crossing as Three.js V123 (225 x 195).
        # Merged 160m cities retain their existing local tile spacing.
        controller.enable_web_navigation(Vector2(Continuous.HALF_TILE,Continuous.HALF_TILE)
            if combined_city else Vector2(SURFACE_WIDTH*0.5,SURFACE_DEPTH*0.5))
    pending_build=""
    placement_rotation=0
    placement_cell=Vector2(INF,INF)
    suggested_site={}
    if placement_label!=null:placement_label.text="Vali ehitis. Roheline tähistab lubatud, punane keelatud ehituskohta."
    previous_worker_positions.clear()
    if can_build:
        Spatial.initialize(city_state)
        Freight.initialize(city_state)
        # Annexed tiles have their own surface; do not overwrite the
        # capital's stored local terrain/river routing when opening one.
        if district_id=="":
            var terrain_sim: Dictionary=city_state["detail_sim"]
            var current_tile: Dictionary=World.cell(world,c,r)
            terrain_sim["terrain"]=String(current_tile.get("biome","plains"))
            terrain_sim["river"]=bool(current_tile.get("river",false))
    if scene_root==null:return
    _position_local_groups()
    # A newly opened 3D world needs fresh permanent tiles, whereas gameplay
    # refreshes must retain terrain resources and static neighboring houses.
    if combined_root!=null:
        for previous in combined_root.get_children():previous.free()
    terrain_mesh_builds=0
    prop_builds=0
    batched_resource_nodes=0
    resource_root.set_meta("resource_key","")
    active_building_mesh_builds=0
    passive_building_mesh_builds=0
    street_cache_signature=""
    visual_visibility_signature=""
    visual_visibility_poll=0.0
    culled_district_count=0
    proxy_building_batches=0
    plot_root.set_meta("idle_grid",false)
    _clear_buildings()
    # Keep lighting and camera, discard old procedural terrain and natural props.
    for child in scene_root.get_children():
        if child==construction_root or child==resource_root or child==worker_root or child==freight_root or child==plot_root or child==roads_root or child==bridge_root or child==combined_root or child==seam_preview_root or child is WorldEnvironment or child is DirectionalLight3D or child is Camera3D:
            continue
        # A queued mesh still has the DetailTerrain name this frame.
        # Replace it now so the terrain and color cannot be shadowed by
        # an old overlapping surface on a reopened detail view.
        child.free()
    var tile: Dictionary=World.cell(world,c,r)
    if tile.is_empty():return
    _surface(tile)
    seam_preview_refresh_clock=0.0
    _render_seam_previews()
    refresh_buildings()
