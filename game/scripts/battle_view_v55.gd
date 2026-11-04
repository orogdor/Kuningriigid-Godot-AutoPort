extends Control
## First tactical viewport in Godot. 5x5 visible detail tiles (3x3 combat
## plus retreat ring); original Stone Age GLBs reused as miniature markers.
## Inputs are explicit, battle_v55.gd owns the entire simulation and saving.
signal return_requested
signal battle_command_requested(id: int,order: String)
signal battle_tick_requested(seconds: float)
signal battle_move_requested(id: int,x: float,z: float)

const Units=preload("res://scripts/web_units_v53.gd")
const Battlefield=preload("res://scripts/battle_v55.gd")
const Nav57=preload("res://scripts/battle_nav_v57.gd")
var viewport: SubViewport
var battle_camera: Camera3D
var scene_root: Node3D
var actors_root: Node3D
var obstacles_root: Node3D
var projectiles_root: Node3D
var move_markers_root: Node3D
var battle_canvas_container: SubViewportContainer
var move_toggle: Button
var move_mode_enabled: bool=false
var status_label: Label
var order_picker: OptionButton
var id_list: Array[int]=[]
var current_battle: Dictionary={}
var cam_size: float=560.0

func _box(parent: Node3D,name: String,size: Vector3,pos: Vector3,color: Color) -> void:
    var node:=MeshInstance3D.new()
    node.name=name
    var mesh:=BoxMesh.new()
    mesh.size=size
    node.mesh=mesh
    node.position=pos
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=1.0
    node.material_override=mat
    parent.add_child(node)

func _button(title: String,callback: Callable) -> Button:
    var button:=Button.new()
    button.text=title
    button.custom_minimum_size=Vector2(95,43)
    button.pressed.connect(callback)
    return button

func _issue(cmd: String) -> void:
    var index: int=order_picker.selected
    if index>=0 and index<id_list.size():
        battle_command_requested.emit(id_list[index],cmd)

func _toggle_move_mode() -> void:
    if int(current_battle.get("version",0))<59 or id_list.is_empty():
        move_mode_enabled=false
    else:
        move_mode_enabled=not move_mode_enabled
    if move_toggle!=null:
        move_toggle.text="Puuduta sihtpunkti" if move_mode_enabled else "Liigu kaardil"

func _on_battle_canvas_input(event: InputEvent) -> void:
    if not move_mode_enabled or id_list.is_empty() or \
            int(current_battle.get("version",0))<59:return
    var pos: Vector2
    if event is InputEventMouseButton:
        if not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
        pos=event.position
    elif event is InputEventScreenTouch:
        if not event.pressed:return
        pos=event.position
    else:return
    if battle_camera==null or battle_canvas_container==null:return
    if battle_canvas_container.size.x<1.0 or battle_canvas_container.size.y<1.0:
        return
    var screen_point: Vector2=pos*Vector2(
        float(viewport.size.x)/battle_canvas_container.size.x,
        float(viewport.size.y)/battle_canvas_container.size.y)
    var origin: Vector3=battle_camera.project_ray_origin(screen_point)
    var ray: Vector3=battle_camera.project_ray_normal(screen_point)
    if absf(ray.y)<0.00001:return
    var distance: float=-origin.y/ray.y
    if distance<=0.0:return
    var ground: Vector3=origin+ray*distance
    var index: int=order_picker.selected
    if index<0 or index>=id_list.size():return
    battle_move_requested.emit(id_list[index],ground.x,ground.z)
    move_mode_enabled=false
    if move_toggle!=null:move_toggle.text="Liigu kaardil"

func _ready() -> void:
    var column:=VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(column)
    var bar:=HFlowContainer.new()
    column.add_child(bar)
    bar.add_child(_button("Tagasi linna",func():return_requested.emit()))
    bar.add_child(_button("+1 s",func():battle_tick_requested.emit(1.0)))
    bar.add_child(_button("+10 s",func():battle_tick_requested.emit(10.0)))
    bar.add_child(_button("+30 s",func():battle_tick_requested.emit(30.0)))
    bar.add_child(_button("Suumi +",func():_zoom(0.75)))
    bar.add_child(_button("Suumi −",func():_zoom(1.33)))
    var tactical:=HFlowContainer.new()
    column.add_child(tactical)
    order_picker=OptionButton.new()
    order_picker.custom_minimum_size=Vector2(160,44)
    tactical.add_child(order_picker)
    move_toggle=_button("Liigu kaardil",_toggle_move_mode)
    tactical.add_child(move_toggle)
    for option in [
        ["Ründa","attack"],["Hoia positsiooni","hold"],
        ["Odade vastuvõtt","spear_wall"],["Hajurivi","loose"],
        ["Lase ja eemaldu","skirmish"],["Tavarivi","line"],
        ["Tagane üle piiri","retreat"]
    ]:
        tactical.add_child(_button(option[0],_issue.bind(option[1])))
    status_label=Label.new()
    status_label.name="BattleStatusV55"
    status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size",13)
    column.add_child(status_label)
    var container:=SubViewportContainer.new()
    battle_canvas_container=container
    container.gui_input.connect(_on_battle_canvas_input)
    container.stretch=true
    container.size_flags_vertical=Control.SIZE_EXPAND_FILL
    column.add_child(container)
    viewport=SubViewport.new()
    viewport.name="TacticalViewV55"
    viewport.own_world_3d=true
    viewport.size=Vector2i(800,600)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    container.add_child(viewport)
    scene_root=Node3D.new()
    scene_root.name="BattlefieldV55"
    viewport.add_child(scene_root)
    var environment:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color("#8da4ae")
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color("#c6c7b6")
    env.ambient_light_energy=1.0
    environment.environment=env
    scene_root.add_child(environment)
    var sun:=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-48,-40,0)
    sun.light_energy=1.3
    scene_root.add_child(sun)
    battle_camera=Camera3D.new()
    battle_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    battle_camera.size=cam_size
    battle_camera.position=Vector3(0,670,520)
    battle_camera.current=true
    scene_root.add_child(battle_camera)
    battle_camera.look_at(Vector3.ZERO,Vector3.UP)
    # x=-2..2, z=-2..2: the outer 16 tiles are the retreat ring.
    for r in range(-2,3):
        for c in range(-2,3):
            var retreat: bool=absi(c)==2 or absi(r)==2
            var color:=Color("#a48967") if retreat else Color("#6a8561")
            _box(scene_root,"Tile_%d_%d" % [c,r],
                Vector3(224.5,1.0,194.5),Vector3(c*225.0,-1.0,r*195.0),color)
    var red:=Color("#bd3734")
    for x in [-Battlefield.HALF_X,Battlefield.HALF_X]:
        _box(scene_root,"RetreatLineX_"+str(x),
            Vector3(1.8,0.5,585.0),Vector3(x,0,0),red)
    for z in [-Battlefield.HALF_Z,Battlefield.HALF_Z]:
        _box(scene_root,"RetreatLineZ_"+str(z),
            Vector3(675.0,0.5,1.8),Vector3(0,0,z),red)
    obstacles_root=Node3D.new()
    obstacles_root.name="BattleObstaclesV57"
    scene_root.add_child(obstacles_root)
    actors_root=Node3D.new()
    actors_root.name="TacticalActorsV55"
    scene_root.add_child(actors_root)
    projectiles_root=Node3D.new()
    projectiles_root.name="StoneFlightsV58"
    scene_root.add_child(projectiles_root)
    move_markers_root=Node3D.new()
    move_markers_root.name="MoveDestinationsV59"
    scene_root.add_child(move_markers_root)

func _refresh_obstacles() -> void:
    for node in obstacles_root.get_children():
        obstacles_root.remove_child(node)
        node.free()
    var terrain: Dictionary=current_battle.get("terrain_v57",{})
    if terrain.is_empty():return
    for i in range(terrain.get("obstacles",[]).size()):
        var rock: Dictionary=terrain["obstacles"][i]
        var holder:=Node3D.new()
        holder.name="StoneBoulder_%d" % i
        holder.position=Vector3(float(rock["x"]),0,float(rock["z"]))
        obstacles_root.add_child(holder)
        var stone:=MeshInstance3D.new()
        stone.name="BoulderMesh"
        var mesh:=SphereMesh.new()
        mesh.radius=float(rock["r"])
        mesh.height=float(rock.get("height",2.0))
        mesh.radial_segments=10
        mesh.rings=5
        stone.mesh=mesh
        stone.position.y=float(rock.get("height",2.0))*0.4
        stone.rotation_degrees.y=float(posmod(i*71,180))
        var stone_material:=StandardMaterial3D.new()
        stone_material.albedo_color=Color("#5b5b55").lightened(float(i)*0.035)
        stone_material.roughness=1.0
        stone.material_override=stone_material
        holder.add_child(stone)

func _refresh_projectiles() -> void:
    # Reuse marker meshes between updates; one saved projectile is one 3D stone.
    var active: Dictionary={}
    for stone in current_battle.get("projectiles_v58",[]):
        var label: String="Stone_%d" % int(stone.get("id",0))
        active[label]=true
        var marker: MeshInstance3D=projectiles_root.get_node_or_null(label) as MeshInstance3D
        if marker==null:
            marker=MeshInstance3D.new()
            marker.name=label
            var mesh:=SphereMesh.new()
            mesh.radius=0.18
            mesh.height=0.36
            mesh.radial_segments=8
            mesh.rings=4
            marker.mesh=mesh
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=Color("#68645b")
            mat.roughness=0.95
            marker.material_override=mat
            projectiles_root.add_child(marker)
        marker.position=Vector3(float(stone["x"]),
            float(stone.get("height",1.1)),float(stone["z"]))
    for node in projectiles_root.get_children():
        if active.has(String(node.name)):continue
        projectiles_root.remove_child(node)
        node.free()

func _refresh_move_markers() -> void:
    var needed: Dictionary={}
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("team",-1))!=0 or \
                String(fighter.get("mode",""))!="move":continue
        var target: Variant=fighter.get("move_target_v59",null)
        if not target is Dictionary or target.is_empty():continue
        var key: String="Waypoint_%d" % int(fighter["id"])
        needed[key]=true
        var marker: MeshInstance3D=move_markers_root.get_node_or_null(key) as MeshInstance3D
        if marker==null:
            marker=MeshInstance3D.new()
            marker.name=key
            var mesh:=CylinderMesh.new()
            mesh.top_radius=1.5
            mesh.bottom_radius=1.5
            mesh.height=0.12
            marker.mesh=mesh
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=Color("#f1d24d")
            mat.roughness=1.0
            marker.material_override=mat
            move_markers_root.add_child(marker)
        marker.position=Vector3(float(target["x"]),0.12,float(target["z"]))
    for node in move_markers_root.get_children():
        if needed.has(String(node.name)):continue
        move_markers_root.remove_child(node)
        node.free()

func _zoom(factor: float) -> void:
    cam_size=clampf(cam_size*factor,120.0,1050.0)
    if battle_camera!=null:battle_camera.size=cam_size

func set_battle(b: Dictionary) -> void:
    current_battle=b.duplicate(true)
    if status_label==null:return
    _refresh_obstacles()
    _refresh_projectiles()
    _refresh_move_markers()
    var existing_id: int=-1
    if order_picker.selected>=0 and order_picker.selected<id_list.size():
        existing_id=id_list[order_picker.selected]
    id_list.clear()
    order_picker.clear()
    var selected_index: int=0
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("team",-1))!=0:continue
        var id: int=int(fighter.get("id",-1))
        if id<0:continue
        id_list.append(id)
        order_picker.add_item("#%d %s • %.0f HP" % [
            id,String(fighter["kind"]),float(fighter["hp"])])
        if id==existing_id:selected_index=id_list.size()-1
    if not id_list.is_empty():order_picker.select(selected_index)
    var label: String="Kampaanialahing • iga sõdur liigub ja võitleb eraldi." if \
        bool(current_battle.get("campaign_v56",false)) else \
        "Kiviaja proovilahing • 24 individuaalset sõdurit väesalgas, päris kaotused."
    var lines: Array[String]=[label]
    lines.append("Lahinguaeg %.1f s • tulemus: %s" % [
        float(current_battle.get("elapsed",0)),
        "käimas" if current_battle.get("result","")=="" else String(current_battle["result"])])
    for fighter in current_battle.get("fighters",[]):
        lines.append("%s %s %.0f/%.0f HP • %s (%d sõdurit)" % [
            "Sinu" if int(fighter["team"])==0 else "Vastane",
            String(fighter["kind"]),float(fighter["hp"]),float(fighter["max_hp"]),
            String(fighter.get("mode","")),int(fighter.get("menAlive",0))])
    status_label.text=" | ".join(lines)
    var used: Dictionary={}
    var total: int=0
    for fighter in current_battle.get("fighters",[]):
        if float(fighter.get("hp",0))<=0 or fighter.get("mode","")=="retreated":
            continue
        var kind: String=String(fighter.get("kind",""))
        var men: Array=fighter.get("men",[])
        if men.is_empty():
            men=[{"index":0,"x":fighter["x"],"z":fighter["z"],
                "hp":fighter["hp"],"escaped":false,"heading":0.0}]
        for man in men:
            if float(man.get("hp",0))<=0 or bool(man.get("escaped",false)):
                continue
            if total>=192:break
            var key: String="TacticalMan_%d_%d" % [
                int(fighter["id"]),int(man.get("index",0))]
            var holder: Node3D=actors_root.get_node_or_null(key) as Node3D
            if holder==null:
                var model: Node3D=Units.instance(kind,5.2)
                if model==null:continue
                holder=Node3D.new()
                holder.name=key
                holder.set_meta("source_id",int(fighter["source_id"]))
                actors_root.add_child(holder)
                holder.add_child(model)
                var foot:=CylinderMesh.new()
                foot.top_radius=0.39
                foot.bottom_radius=0.39
                foot.height=0.10
                var marker:=MeshInstance3D.new()
                marker.name="TeamMarker"
                marker.mesh=foot
                marker.position.y=0.04
                var mat:=StandardMaterial3D.new()
                mat.albedo_color=Color("#65caff") if int(fighter["team"])==0 else Color("#ed6b56")
                marker.material_override=mat
                holder.add_child(marker)
            holder.position=Vector3(float(man["x"]),0.0,float(man["z"]))
            holder.rotation.y=float(man.get("heading",
                PI*0.5 if int(fighter["team"])==0 else -PI*0.5))
            # Small source-GLB-safe locomotion and attack poses; no extra
            # geometry objects, no new rig and no per-frame reimport.
            var model_node: Node3D=holder.get_child(0) as Node3D
            if model_node!=null:
                var phase: float=float(man.get("anim_phase",0.0))
                var walking: bool=bool(man.get("moving",false))
                var attacking: float=float(man.get("attack_anim",0.0))
                model_node.position.y=absf(sin(phase))*0.12 if walking else 0.0
                model_node.rotation.x=-0.27*sin(attacking/0.36*PI) if attacking>0.0 else 0.0
                model_node.rotation.z=0.065*sin(phase) if walking else 0.0
            used[key]=true
            total+=1
    for node in actors_root.get_children():
        if used.has(String(node.name)):continue
        actors_root.remove_child(node)
        node.free()
