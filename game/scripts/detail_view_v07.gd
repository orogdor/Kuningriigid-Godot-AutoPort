extends Control
## AutoPort 0.7 prototype: world-tile 3D detail scene using Godot primitives.
## World elevation/coastal context follows 0.6 cells; not yet 1:1 Three.js meshes.
signal return_requested
signal build_requested(kind: String)
signal build_at_requested(kind: String, x: float, z: float, rotation: int)
signal bridge_requested(x: float)
signal priority_requested(index: int, level: String)
signal turns_requested(count: int)
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
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const CityRecipes = preload("res://scripts/generated_rules.gd")
const Controller = preload("res://scripts/detail_camera_v07.gd")
const PREVIEW_TYPES: Array[String] = ["hall","house","lumber","well","quarry","farm"]
const SURFACE_WIDTH: float = 225.0
const SURFACE_DEPTH: float = 195.0

var world: Dictionary = {}
var selected: Vector2i = Vector2i(-1,-1)
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
var actions: HFlowContainer
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
    column.add_theme_constant_override("separation",8)
    add_child(column)
    var top:=HBoxContainer.new()
    column.add_child(top)
    var heading:=Label.new()
    heading.text="KUNINGRIIGID • GODOT 0.26 • 3D DETAILKAART"
    heading.add_theme_font_size_override("font_size",20)
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    var back:=Button.new()
    back.text="Tagasi maailmakaardile"
    back.pressed.connect(func(): return_requested.emit())
    top.add_child(back)
    info=Label.new()
    info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(info)
    placement_label=Label.new()
    placement_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    placement_label.text="Vali ehitis, et näha lubatud (roheline) ja keelatud (punane) ehitusruute."
    column.add_child(placement_label)
    controller=Controller.new()
    controller.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    controller.size_flags_vertical=Control.SIZE_EXPAND_FILL
    controller.custom_minimum_size=Vector2(300,180)
    column.add_child(controller)
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(960,600)
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
    actions=HFlowContainer.new()
    actions.add_theme_constant_override("h_separation",6)
    actions.add_theme_constant_override("v_separation",6)
    column.add_child(actions)
    _refresh_actions()

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
        return Terrain.elevation(city_state["detail_sim"],x,z)
    if plain:return 0.0
    # Mild relief. Full web-game detail-sample parity belongs to a future port.
    var wave: float=sin(x*0.046+selected.x*0.2)*cos(z*0.064+selected.y*0.1)
    return base+wave*1.7

func _surface(cell: Dictionary) -> void:
    selected_biome=String(cell.get("biome","sea"))
    var sea: bool=selected_biome=="sea"
    var heights: float=clampf(float(cell.get("h",0))*0.02,-1.0,1.7)
    var smooth_centre: bool=can_build
    var material:=StandardMaterial3D.new()
    material.vertex_color_use_as_albedo=true
    material.roughness=0.98
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tiles_x: int=30
    var tiles_z: int=26
    for r in range(tiles_z):
        for c in range(tiles_x):
            var x0: float=(-0.5+float(c)/tiles_x)*SURFACE_WIDTH
            var x1: float=(-0.5+float(c+1)/tiles_x)*SURFACE_WIDTH
            var z0: float=(-0.5+float(r)/tiles_z)*SURFACE_DEPTH
            var z1: float=(-0.5+float(r+1)/tiles_z)*SURFACE_DEPTH
            var a:=Vector3(x0,_elevation(x0,z0,heights,smooth_centre),z0)
            var b:=Vector3(x1,_elevation(x1,z0,heights,smooth_centre),z0)
            var d:=Vector3(x0,_elevation(x0,z1,heights,smooth_centre),z1)
            var e:=Vector3(x1,_elevation(x1,z1,heights,smooth_centre),z1)
            var col:=Color("#b8ac80") if sea else Color("#86a769")
            if selected_biome=="forest":col=Color("#547b4e")
            elif selected_biome=="hills":col=Color("#999b91")
            elif not sea and can_build:col=Color("#a7b779")
            for v in [a,d,b,b,d,e]:
                tool.set_color(col)
                tool.add_vertex(v)
    tool.generate_normals()
    var ground:=MeshInstance3D.new()
    ground.name="DetailTerrain"
    ground.mesh=tool.commit()
    ground.material_override=material
    scene_root.add_child(ground)
    if sea or _is_coastal(cell):
        _box(scene_root,Vector3(0,-1.2,0),Vector3(SURFACE_WIDTH,0.25,SURFACE_DEPTH),
            Color("#3b86a8"),"SeaLevel")
    var rng:=RandomNumberGenerator.new()
    rng.seed=int(world.get("seed",82026))+selected.x*10007+selected.y*19937
    if not sea:
        var tree_count: int=50 if selected_biome=="forest" else (6 if selected_biome=="hills" else 16)
        for i in range(tree_count):
            var x: float=rng.randf_range(-108,108)
            var z: float=rng.randf_range(-92,92)
            if can_build:continue
            _tree(scene_root,Vector3(x,_elevation(x,z,heights,smooth_centre),z),rng.randf_range(0.7,1.35))
        var rocks: int=25 if selected_biome=="hills" else 8
        for i in range(rocks):
            var x: float=rng.randf_range(-109,109)
            var z: float=rng.randf_range(-89,89)
            if can_build:continue
            _rock(scene_root,Vector3(x,_elevation(x,z,heights,smooth_centre),z),rng.randf_range(0.8,1.6))
    if bool(cell.get("river",false)):
        _box(scene_root,Vector3(0,-0.26,25),Vector3(SURFACE_WIDTH,0.13,14),
            Color("#419abb"),"RiverWater")
        for bank_z in [17.0,33.0]:
            _box(scene_root,Vector3(0,0.06,bank_z),Vector3(SURFACE_WIDTH,0.25,1.7),
                Color("#978766"),"RiverBank")

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
            _box(parent,place+Vector3(0,4.1,0),Vector3(18,8,13),timber,"HallWalls")
            _roof(parent,place+Vector3(0,10.4,0),Vector3(21,7,16),thatch)
            _box(parent,place+Vector3(0,3,6.7),Vector3(3.1,6,0.5),Color("#473629"),"HallDoor")
        "house":
            _box(parent,place+Vector3(0,2.8,0),Vector3(9,5.6,8),timber,"HouseWalls")
            _roof(parent,place+Vector3(0,6.8,0),Vector3(11,5,10),thatch)
            _box(parent,place+Vector3(0,1.9,4.1),Vector3(2,3.8,0.3),Color("#4c392a"),"HouseDoor")
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
        child.queue_free()

func refresh_buildings() -> void:
    if construction_root==null:return
    _clear_buildings()
    rendered_buildings=0
    if can_build:
        var buildings: Array=city_state.get("buildings",[])
        for i in range(buildings.size()):
            var building: Dictionary=buildings[i]
            if String(building.get("district",""))!=district_id:continue
            var fallback:=Vector2(float((i%5-2)*26),float((i/5-2)*27))
            var pos:=Vector3(float(building.get("x",fallback.x)),0.0,float(building.get("z",fallback.y)))
            var holder:=Node3D.new()
            holder.name=String(building.get("type","building"))+"_"+str(i)
            construction_root.add_child(holder)
            # All building meshes use local coordinates; rotate the entire
            # finished structure or scaffold without moving its footprint.
            holder.position=pos
            holder.rotation_degrees.y=float(building.get("rotation",0))
            # The entrance marker rotates with the house facade. It is a
            # physical visual landmark, not a new obstacle or save field.
            _box(holder,Vector3(0.0,0.15,8.0),Vector3(3.0,0.27,4.3),
                Color("#b7a381"),"FrontDoorStep")
            if bool(building.get("ready",false)):
                _building(holder,String(building.get("type","house")),Vector3.ZERO,true)
            else:
                _construction_site(holder,String(building.get("type","house")),Vector3.ZERO,building)
            rendered_buildings+=1
        _refresh_resource_meshes()
        _refresh_worker_meshes()
        _refresh_freight_meshes()
        _refresh_district_transport_meshes()
        _refresh_grid()
        _refresh_roads()
        _refresh_bridges()
    else:
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
    for old in resource_root.get_children():old.queue_free()
    var sim: Dictionary=city_state.get("detail_sim",{})
    if district_id!="":
        sim=city_state.get("transport_v26",{}).get("surfaces",{}).get(district_id,{})
    for deposit in sim.get("sites",[]):
        var remaining: float=float(deposit.get("remaining",0))
        if remaining<=0.0:continue
        var pos:=Vector3(float(deposit["x"]),0.0,float(deposit["z"]))
        var node:=Node3D.new()
        node.name="Deposit_"+str(deposit["id"])
        resource_root.add_child(node)
        if String(deposit["kind"])=="wood":
            _tree(node,pos,clampf(remaining/35.0,0.3,1.1))
        else:
            for i in range(3):
                _rock(node,pos+Vector3((i-1)*1.9,0,((i%2)*2-1)*1.4),clampf(remaining/45.0,0.4,1.0))

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
        _box(roads_root,Vector3(float(tile["x"]),Terrain.elevation(sim,float(tile["x"]),float(tile["z"]))+0.11,float(tile["z"])),
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
            Vector3(middle.x,Terrain.elevation(sim,middle.x,middle.y)+0.14,middle.y),
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
        _box(roads_root,Vector3(mid.x,Terrain.elevation(sim,mid.x,mid.y)+0.19,mid.y),
            segment_size,Color("#ae966e"),"DoorAccessPath_"+str(i))
        _box(roads_root,Vector3(entry.x,Terrain.elevation(sim,entry.x,entry.y)+0.17,entry.y),
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
    var sim: Dictionary=city_state.get("detail_sim",{})
    if not Terrain.river_at(sim,0.0,0.0):return
    # Shallow stone fords are visible at the same places as A* crossings.
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
    for old in plot_root.get_children():old.queue_free()
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
    if not can_build or pending_build=="":return
    if pending_build=="bridge":
        var x_cell: int=int(roundf(pos.x/Terrain.CELL))
        if not Terrain.can_place_bridge(city_state.get("detail_sim",{}),x_cell) or pos.z<Terrain.RIVER_NEAR or pos.z>Terrain.RIVER_FAR:
            if info!=null:info.text="Sild tuleb ehitada jõe kohal: Z 18–32 m, X -30 või +30 m"
            return
        pending_build=""
        bridge_requested.emit(float(x_cell)*Terrain.CELL)
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
    var text_line: String="%s • Detailruut %d × %d • %s • 225 × 195 m" % [String(city_state.get("city_name","Pealinn")),selected.x,selected.y,selected_biome]
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

func _refresh_actions() -> void:
    if actions==null:return
    for child in actions.get_children():
        child.queue_free()
    if not can_build:
        return
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
    if Terrain.river_at(city_state.get("detail_sim",{}),0.0,0.0):
        var bridge_button:=Button.new()
        bridge_button.text="Ehita sild (28 puitu, 18 kivi)"
        bridge_button.pressed.connect(func():
            pending_build="bridge"
            info.text="SILD: klõpsa jõe kohal X = -30 m või +30 m")
        actions.add_child(bridge_button)
    for kind in ["house","lumber","well","quarry","farm"]:
        var button:=Button.new()
        button.text="Ehita "+kind
        button.disabled=not _can_build(kind)
        button.pressed.connect(select_building.bind(kind))
        actions.add_child(button)
    var note:=Label.new()
    note.text="0.26: füüsilised teekonnad naaberlinnaosade vahel, liikuvad töölised ja kaubavankrid."
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    actions.add_child(note)
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
    city_state=city
    can_build=capital
    district_id=district
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
    # Keep lighting and camera, discard old procedural terrain and natural props.
    for child in scene_root.get_children():
        if child==construction_root or child==resource_root or child==worker_root or child==freight_root or child==plot_root or child==roads_root or child==bridge_root or child is WorldEnvironment or child is DirectionalLight3D or child is Camera3D:
            continue
        child.queue_free()
    var tile: Dictionary=World.cell(world,c,r)
    if tile.is_empty():return
    _surface(tile)
    refresh_buildings()
