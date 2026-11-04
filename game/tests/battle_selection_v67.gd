extends SceneTree
## AutoPort 0.67: use Android finger taps and mouse picking on genuine
## tactical GLB soldiers without snapping predicted movement or giving an
## accidental move order. Headless checks projection and gesture state.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")

func fail(message: String) -> void:
    printerr("BATTLE_SELECTION_V67 FAIL: "+message)
    quit(1)

func _point(view: Control,actor: Node3D) -> Vector2:
    var projected: Vector2=view.battle_camera.unproject_position(
        actor.global_position+Vector3(0.0,2.5,0.0))
    return projected*Vector2(view.battle_canvas_container.size.x/
        maxf(1.0,float(view.viewport.size.x)),
        view.battle_canvas_container.size.y/
        maxf(1.0,float(view.viewport.size.y)))

func _touch(view: Control,index: int,point: Vector2,pressed: bool) -> void:
    var event:=InputEventScreenTouch.new()
    event.index=index
    event.position=point
    event.pressed=pressed
    view._on_battle_canvas_input(event)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_demo_battle()
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    if view.actors_root.get_child_count()!=96:
        fail("Real source GLB soldiers were not instantiated")
        return
    var original: String=JSON.stringify(ui.city)
    var orders: Array=[]
    view.battle_move_requested.connect(func(id: int,x: float,z: float):
        orders.append({"id":id,"x":x,"z":z}))
    var actor: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900002_11") as Node3D
    if actor==null:return fail("Axeman GLB is missing")
    # Prove selection preserves the *rendered* interpolated location,
    # rather than calling set_battle() and snapping to sim coordinates.
    actor.position+=Vector3(0.4,0.0,-0.3)
    var displayed: Vector3=actor.position
    var old_instance: int=actor.get_instance_id()
    var click:=InputEventMouseButton.new()
    click.pressed=true
    click.button_index=MOUSE_BUTTON_LEFT
    click.position=_point(view,actor)
    view._on_battle_canvas_input(click)
    var selected: Dictionary=view._chosen_man()
    if int(selected.get("squad",-1))!=900002 or \
            int(selected.get("index",-1))!=11:
        fail("Mouse left-click did not select the matching 3D GLB soldier")
        return
    if actor.position.distance_to(displayed)>0.0001 or \
            actor.get_instance_id()!=old_instance:
        fail("Mouse selection snapped or recreated a moving soldier")
        return
    var marker: MeshInstance3D=actor.get_node("TeamMarker")
    var mat: StandardMaterial3D=marker.material_override
    if mat==null or mat.albedo_color!=Color("#ffe250"):
        fail("Selected soldier does not have a highlighted team marker")
        return
    var second: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900003_17") as Node3D
    if second==null:return fail("Slinger GLB is missing")
    var finger_position: Vector2=_point(view,second)
    _touch(view,0,finger_position,true)
    _touch(view,0,finger_position,false)
    selected=view._chosen_man()
    if int(selected.get("squad",-1))!=900003 or \
            int(selected.get("index",-1))!=17:
        fail("Android single tap does not select the right soldier/squad")
        return
    if mat.albedo_color==Color("#ffe250"):
        fail("Previously selected soldier remained highlighted")
        return
    var third: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900001_6") as Node3D
    if third==null:return fail("Spearman GLB is missing")
    var from: Vector2=_point(view,third)
    _touch(view,0,from,true)
    var pan:=InputEventScreenDrag.new()
    pan.index=0
    pan.position=from+Vector2(90,25)
    pan.relative=Vector2(90,25)
    view._on_battle_canvas_input(pan)
    _touch(view,0,pan.position,false)
    selected=view._chosen_man()
    if int(selected.get("squad",-1))!=900003 or \
            int(selected.get("index",-1))!=17:
        fail("One-finger camera drag accidentally selected a new soldier")
        return
    # Two fingers modify camera zoom, never the tactical selection.
    _touch(view,0,Vector2(100,100),true)
    _touch(view,1,Vector2(200,100),true)
    _touch(view,1,Vector2(200,100),false)
    _touch(view,0,Vector2(100,100),false)
    selected=view._chosen_man()
    if int(selected.get("squad",-1))!=900003 or \
            int(selected.get("index",-1))!=17:
        fail("Pinch gesture unexpectedly selected a soldier")
        return
    if not orders.is_empty():
        fail("Ordinary picking or pan issued a tactical movement order")
        return
    if JSON.stringify(ui.city)!=original or not Battle.active(
            ui.city,ui.world_view.world):
        fail("Visual selection modified saved battle/campaign state")
        return
    if view.actors_root.get_child_count()!=96:
        fail("Tap selection lost any of the 96 imported GLB soldiers")
        return
    print("BATTLE_SELECTION_V67 SUCCESS: real 3D mouse/touch selection, exact soldier and squad, marker highlight, no positional snap, drag/pinch isolation, 96 GLBs, untouched save")
    quit(0)
