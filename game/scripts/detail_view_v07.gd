extends Control
## AutoPort 0.7 prototype: world-tile 3D detail scene using Godot primitives.
## World elevation/coastal context follows 0.6 cells; not yet 1:1 Three.js meshes.
signal return_requested
signal build_requested(kind: String)
signal build_at_requested(kind: String, x: float, z: float)
signal bridge_requested(x: float)
signal turns_requested(count: int)
const World = preload("res://scripts/world_gen_v06.gd")
const CityEconomy = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Terrain = preload("res://scripts/detail_terrain_v10.gd")
const CityRecipes = preload("res://scripts/generated_rules.gd")
const Controller = preload("res://scripts/detail_camera_v07.gd")
const PREVIEW_TYPES: Array[String] = ["hall","house","lumber","well","quarry","farm"]
const SURFACE_WIDTH: float = 225.0
const SURFACE_DEPTH: float = 195.0

var world: Dictionary = {}
var selected: Vector2i = Vector2i(-1,-1)
var can_build: bool = false
var city_state: Dictionary = {}
var scene_root: Node3D
var construction_root: Node3D
var resource_root: Node3D
var worker_root: Node3D
var plot_root: Node3D
var roads_root: Node3D
var bridge_root: Node3D
var previous_worker_positions: Dictionary={}
var pending_build: String = ""
var controller: SubViewportContainer
var info: Label
var actions: HFlowContainer
var rendered_buildings: int = 0
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
    heading.text="KUNINGRIIGID • GODOT 0.10 • 3D DETAILKAART"
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
    construction_root=Node3D.new()
    construction_root.name="PlacedBuildings"
    scene_root.add_child(construction_root)
    resource_root=Node3D.new()
    resource_root.name="PhysicalResources"
    scene_root.add_child(resource_root)
    worker_root=Node3D.new()
    worker_root.name="MovingWorkers"
    scene_root.add_child(worker_root)
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
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=roughness
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
    var mesh:=BoxMesh.new()
    mesh.size=scale
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
            var fallback:=Vector2(float((i%5-2)*26),float((i/5-2)*27))
            var pos:=Vector3(float(building.get("x",fallback.x)),0.0,float(building.get("z",fallback.y)))
            var holder:=Node3D.new()
            holder.name=String(building.get("type","building"))+"_"+str(i)
            construction_root.add_child(holder)
            _building(holder,String(building.get("type","house")),pos,bool(building.get("ready",false)))
            rendered_buildings+=1
        _refresh_resource_meshes()
        _refresh_worker_meshes()
        _refresh_grid()
        _refresh_roads()
        _refresh_bridges()
    else:
        # Changing from the capital to an unowned tile must not leave
        # the old town's 3D workers, paths or resources on screen.
        for group in [resource_root,worker_root,plot_root,roads_root,bridge_root]:
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
    var sim: Dictionary=city_state.get("detail_sim",{})
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

func _refresh_roads() -> void:
    if roads_root==null:return
    for old in roads_root.get_children():old.queue_free()
    var sim: Dictionary=city_state.get("detail_sim",{})
    for tile in Paths.road_tiles(sim):
        if Terrain.river_lane(sim,float(tile["x"]),float(tile["z"])) and Terrain.crossing_kind(sim,int(roundf(float(tile["x"])/Terrain.CELL)))=="":
            continue
        var amount: float=float(tile["strength"])
        var shade:=Color("#927451") if amount<8.0 else Color("#ab9165")
        _box(roads_root,Vector3(float(tile["x"]),Terrain.elevation(sim,float(tile["x"]),float(tile["z"]))+0.11,float(tile["z"])),
            Vector3(7.5+minf(1.0,amount*0.07),0.06,7.5+minf(1.0,amount*0.07)),
            shade,"Footpath")

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

func _refresh_grid() -> void:
    if plot_root==null:return
    for old in plot_root.get_children():old.queue_free()
    if not can_build:return
    for z in range(-7,8):
        for x in range(-7,8):
            var point:=Vector2(float(x)*Spatial.STEP,float(z)*Spatial.STEP)
            if not Spatial.can_place(city_state,point):continue
            var square:=BoxMesh.new()
            square.size=Vector3(8,0.035,8)
            _mesh(plot_root,square,Vector3(point.x,0.08,point.y),
                Color(0.2,0.8,0.55,0.16),"BuildPlot")

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
    if not Spatial.can_place(city_state,snapped):
        if info!=null:info.text="Ehituskoht on hõivatud või väljaspool linna: "+str(snapped)
        return
    var kind: String=pending_build
    pending_build=""
    build_at_requested.emit(kind,snapped.x,snapped.y)

func select_building(kind: String) -> void:
    if not can_build or not _can_build(kind):return
    pending_build=kind
    if info!=null:info.text="EHITUS: "+kind+" — klõpsa rohelisel ehitusruudul; parem hiir pöörab kaamerat"

func _refresh_info() -> void:
    if info==null:return
    var text_line: String="Detailruut %d × %d • %s • 225 × 195 m" % [selected.x,selected.y,selected_biome]
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
    else:
        text_line+=" | Maastikuvaade (ehitamine ainult oma pealinna ruudul)"
    info.text=text_line

func _refresh_actions() -> void:
    if actions==null:return
    for child in actions.get_children():
        child.queue_free()
    if not can_build:
        return
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
    note.text="Töölised leiavad tee ümber hoonete; kasutatud käiguradadest tekivad ja hääbuvad teed."
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    actions.add_child(note)

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

func open_tile(next_world: Dictionary, c: int, r: int, city: Dictionary, capital: bool) -> void:
    world=next_world
    selected=Vector2i(c,r)
    city_state=city
    can_build=capital
    pending_build=""
    previous_worker_positions.clear()
    if can_build:
        Spatial.initialize(city_state)
        var terrain_sim: Dictionary=city_state["detail_sim"]
        var current_tile: Dictionary=World.cell(world,c,r)
        terrain_sim["terrain"]=String(current_tile.get("biome","plains"))
        terrain_sim["river"]=bool(current_tile.get("river",false))
    if scene_root==null:return
    # Keep lighting and camera, discard old procedural terrain and natural props.
    for child in scene_root.get_children():
        if child==construction_root or child==resource_root or child==worker_root or child==plot_root or child==roads_root or child==bridge_root or child is WorldEnvironment or child is DirectionalLight3D or child is Camera3D:
            continue
        child.queue_free()
    var tile: Dictionary=World.cell(world,c,r)
    if tile.is_empty():return
    _surface(tile)
    refresh_buildings()
