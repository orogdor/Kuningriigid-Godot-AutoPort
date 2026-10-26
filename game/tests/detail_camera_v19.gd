extends SceneTree
## 0.19 integration: real 3D Godot viewport, simulated Android multitouch,
## tap-to-build signal safety, one-finger map panning and wheel compatibility.
const Scene=preload("res://content.tscn")

func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
    var e:=InputEventScreenTouch.new()
    e.index=index
    e.position=position
    e.pressed=pressed
    return e

func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
    var e:=InputEventScreenDrag.new()
    e.index=index
    e.position=position
    return e

func _fail(message: String) -> void:
    printerr("DETAIL_CAMERA_V19 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    if ui.world_view==null or ui.world_view.world.is_empty():
        _fail("world did not initialize")
        return
    var home: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(home["c"]),int(home["r"]))
    await process_frame
    var orbit: SubViewportContainer=ui.detail_view.controller
    if orbit==null or orbit.get("orbit_camera")==null:
        _fail("3D orbit camera not attached")
        return
    var clicks: Array=[]
    orbit.connect("ground_clicked",func(location: Vector3): clicks.append(location))
    if orbit.size.x<100.0 or orbit.size.y<100.0:
        _fail("3D viewport has invalid input size")
        return
    var start_distance: float=float(orbit.get("distance"))
    var old_yaw: float=float(orbit.get("yaw"))
    var center: Vector2=orbit.size*0.5
    var left: Vector2=center+Vector2(-50,0)
    var right: Vector2=center+Vector2(50,0)
    orbit.call("_gui_input",_touch(0,left,true))
    orbit.call("_gui_input",_touch(1,right,true))
    # Spreading apart must zoom in, not orbit and not place a building.
    orbit.call("_gui_input",_drag(1,center+Vector2(120,0)))
    var close_distance: float=float(orbit.get("distance"))
    if close_distance>=start_distance or close_distance<15.0:
        _fail("two-finger spread did not zoom towards terrain")
        return
    if absf(float(orbit.get("yaw"))-old_yaw)>0.0001:
        _fail("pinch wrongly rotated the 3D camera")
        return
    # Midpoint moves with both fingers; ground below it must remain anchored.
    var old_mid: Vector2=center+Vector2(35,0)
    var anchored: Variant=orbit.call("_plane_hit",old_mid)
    orbit.call("_gui_input",_drag(0,center+Vector2(-10,25)))
    orbit.call("_gui_input",_drag(1,center+Vector2(160,25)))
    var new_mid: Vector2=center+Vector2(75,25)
    var resulting: Variant=orbit.call("_plane_hit",new_mid)
    if not (anchored is Vector3 and resulting is Vector3):
        _fail("3D midpoint could not intersect terrain")
        return
    if Vector2(anchored.x,anchored.z).distance_to(Vector2(resulting.x,resulting.z))>1.0:
        _fail("two-finger translation lost the world-space anchor")
        return
    orbit.call("_gui_input",_drag(1,center+Vector2(40,25)))
    if float(orbit.get("distance"))<=close_distance:
        _fail("pinch inward did not zoom back out")
        return
    orbit.call("_gui_input",_touch(0,center+Vector2(-10,25),false))
    orbit.call("_gui_input",_touch(1,center+Vector2(40,25),false))
    if clicks.size()!=0 or not orbit.get("active_fingers").is_empty():
        _fail("pinch release placed a building or left stale fingers")
        return
    # Even an unmatched emulated mouse release must not generate a build.
    var release:=InputEventMouseButton.new()
    release.button_index=MOUSE_BUTTON_LEFT
    release.pressed=false
    release.position=center
    orbit.call("_gui_input",release)
    if clicks.size()!=0:
        _fail("orphaned mouse release generated a ground tap")
        return
    # A normal short single-finger tap must still place exactly once.
    orbit.call("_gui_input",_touch(0,center,true))
    orbit.call("_gui_input",_touch(0,center,false))
    if clicks.size()!=1:
        _fail("single-finger ground selection failed after pinch")
        return
    var before_pan: Vector3=orbit.look_at
    orbit.call("_gui_input",_touch(0,center,true))
    orbit.call("_gui_input",_drag(0,center+Vector2(42,17)))
    orbit.call("_gui_input",_touch(0,center+Vector2(42,17),false))
    if clicks.size()!=1 or orbit.look_at.distance_to(before_pan)<0.5:
        _fail("single-finger map panning failed or accidentally built")
        return
    if absf(float(orbit.get("yaw"))-old_yaw)>0.001:
        _fail("one-finger map pan accidentally rotated camera")
        return
    # Camera zoom limits stay intact for mouse users too.
    var scroll:=InputEventMouseButton.new()
    scroll.button_index=MOUSE_BUTTON_WHEEL_DOWN
    scroll.pressed=true
    orbit.call("_gui_input",scroll)
    if float(orbit.get("distance"))>450.0:
        _fail("mouse wheel exceeded web detail zoom boundary")
        return
    print("DETAIL_CAMERA_V19 SUCCESS: anchored pinch, web-style single-finger map pan, single tap, and release safety")
    quit(0)
