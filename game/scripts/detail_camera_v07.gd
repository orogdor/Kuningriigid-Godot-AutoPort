extends SubViewportContainer
## 0.19: mouse orbit and scroll; single finger orbit/tap, two fingers pinch/pan.
signal ground_clicked(position: Vector3)
signal ground_hovered(position: Vector3)
signal detail_edge_crossed(delta: Vector2i,local_focus: Vector3)
signal zoom_exit_requested
const Seam=preload("res://scripts/detail_web_navigation_v41.gd")
const MIN_DISTANCE: float=15.0
var max_distance: float=180.0
var min_x: float=-112.5
var max_x: float=112.5
var min_z: float=-97.5
var max_z: float=97.5

var orbit_camera: Camera3D
var yaw: float=-0.65
var pitch: float=-0.8
var distance: float=76.0
var look_at: Vector3=Vector3.ZERO
var dragging: bool=false
var mouse_left_held: bool=false
var click_origin: Vector2=Vector2.ZERO
var move_distance: float=0.0
var active_fingers: Dictionary={}
var multitouch_active: bool=false
var filtered_touch_motion: Vector2=Vector2.ZERO
var wheel_target: float=76.0
var focus_target: Vector3=Vector3.ZERO
var focus_easing: bool=false
var seam_enabled: bool=false
var seam_half: Vector2=Vector2(112.5,97.5)
var transition_pending: bool=false

func _ready() -> void:
    stretch=true
    mouse_filter=Control.MOUSE_FILTER_STOP
    wheel_target=distance

func _process(delta: float) -> void:
    if orbit_camera==null:return
    var changed: bool=false
    if absf(distance-wheel_target)>0.035:
        distance=lerpf(distance,wheel_target,1.0-exp(-maxf(0.0,delta)*13.0))
        changed=true
    elif not is_equal_approx(distance,wheel_target):
        distance=wheel_target
        changed=true
    if focus_easing:
        var old: Vector3=look_at
        look_at=look_at.lerp(focus_target,1.0-exp(-maxf(0.0,delta)*7.0))
        changed=true
        if look_at.distance_to(focus_target)<0.13:
            look_at=focus_target
            focus_easing=false
        elif look_at==old:focus_easing=false
    if changed:update_camera()

func set_city_bounds(bounds: Dictionary) -> void:
    min_x=float(bounds.get("xmin",-112.5))
    max_x=float(bounds.get("xmax",112.5))
    min_z=float(bounds.get("zmin",-97.5))
    max_z=float(bounds.get("zmax",97.5))
    max_distance=180.0 if bounds.is_empty() else maxf(180.0,float(bounds.get("span",180.0))*1.35)
    look_at.x=clampf(look_at.x,min_x,max_x)
    look_at.z=clampf(look_at.z,min_z,max_z)
    distance=clampf(distance,MIN_DISTANCE,max_distance)
    wheel_target=distance
    focus_easing=false
    update_camera()

func enable_web_navigation(half_size: Vector2=Vector2(112.5,97.5)) -> void:
    seam_enabled=true
    seam_half=half_size
    max_distance=Seam.WORLD_ZOOM
    transition_pending=false

func restore_detail_focus(point: Vector3,previous_zoom: float) -> void:
    seam_enabled=true
    transition_pending=false
    look_at=Seam.bounded(point,seam_half)
    focus_easing=false
    distance=clampf(previous_zoom,MIN_DISTANCE,max_distance)
    wheel_target=distance
    update_camera()

func check_detail_boundary() -> void:
    if not seam_enabled or transition_pending:return
    var crossed: Dictionary=Seam.crossing(look_at,seam_half)
    if crossed.is_empty():return
    transition_pending=true
    detail_edge_crossed.emit(crossed["delta"],crossed["focus"])

func pan_pointer(previous: Vector2,current: Vector2) -> void:
    # Match web's one-finger drag: move map, not orbit camera.
    var before: Variant=_plane_hit(previous)
    var after: Variant=_plane_hit(current)
    if not (before is Vector3 and after is Vector3):return
    look_at+=before-after
    var bx: float=seam_half.x+32.0 if seam_enabled else maxf(absf(min_x),absf(max_x))
    var bz: float=seam_half.y+32.0 if seam_enabled else maxf(absf(min_z),absf(max_z))
    look_at.x=clampf(look_at.x,-bx,bx)
    look_at.z=clampf(look_at.z,-bz,bz)
    focus_easing=false
    update_camera()
    check_detail_boundary()

func zoom_out_step() -> void:
    if seam_enabled and wheel_target*1.12>=Seam.WORLD_ZOOM:
        transition_pending=true
        zoom_exit_requested.emit()
        return
    wheel_target=clampf(wheel_target*1.12,MIN_DISTANCE,max_distance)
    distance=lerpf(distance,wheel_target,0.32)
    update_camera()

func overview(bounds: Dictionary) -> void:
    set_city_bounds(bounds)
    look_at=bounds.get("midpoint",Vector3.ZERO)
    distance=clampf(float(bounds.get("span",160.0))*1.20,76.0,max_distance)
    wheel_target=distance
    focus_easing=false
    update_camera()

func focus(point: Vector3) -> void:
    look_at.x=clampf(point.x,min_x,max_x)
    look_at.z=clampf(point.z,min_z,max_z)
    focus_easing=false
    update_camera()

func focus_smooth(point: Vector3) -> void:
    focus_target=Vector3(clampf(point.x,min_x,max_x),look_at.y,
        clampf(point.z,min_z,max_z))
    focus_easing=true

func attach_camera(camera: Camera3D) -> void:
    orbit_camera=camera
    update_camera()

func update_camera() -> void:
    if orbit_camera==null:return
    var horizontal: float=cos(pitch)*distance
    var position_3d:=look_at+Vector3(sin(yaw)*horizontal,-sin(pitch)*distance,cos(yaw)*horizontal)
    orbit_camera.position=position_3d
    orbit_camera.look_at(look_at,Vector3.UP)

func _plane_hit(local_point: Vector2) -> Variant:
    if orbit_camera==null or size.x<=0.0 or size.y<=0.0:return null
    var viewport: Viewport=orbit_camera.get_viewport()
    if viewport==null or viewport.size.x<=0 or viewport.size.y<=0:return null
    var on_viewport:=Vector2(local_point.x*float(viewport.size.x)/size.x,
        local_point.y*float(viewport.size.y)/size.y)
    var origin: Vector3=orbit_camera.project_ray_origin(on_viewport)
    var direction: Vector3=orbit_camera.project_ray_normal(on_viewport)
    if absf(direction.y)<0.00001:return null
    var ray_length: float=-origin.y/direction.y
    if ray_length<0.0:return null
    return origin+direction*ray_length

func _click_ground(local_point: Vector2) -> void:
    var hit: Variant=_plane_hit(local_point)
    if hit is Vector3:ground_clicked.emit(hit)

func _pinch_drag(finger: InputEventScreenDrag) -> void:
    var ids: Array=active_fingers.keys()
    if ids.size()!=2:return
    var previous_a: Vector2=active_fingers[ids[0]]
    var previous_b: Vector2=active_fingers[ids[1]]
    var old_middle: Vector2=(previous_a+previous_b)*0.5
    var old_span: float=previous_a.distance_to(previous_b)
    var before: Variant=_plane_hit(old_middle)
    active_fingers[finger.index]=finger.position
    var next_a: Vector2=active_fingers[ids[0]]
    var next_b: Vector2=active_fingers[ids[1]]
    var next_middle: Vector2=(next_a+next_b)*0.5
    var next_span: float=next_a.distance_to(next_b)
    # Moving fingers apart brings the camera closer; never invert at zero span.
    if old_span>8.0 and next_span>8.0:
        var target_distance: float=distance*pow(old_span/next_span,0.85)
        if seam_enabled and target_distance>=Seam.WORLD_ZOOM:
            transition_pending=true
            zoom_exit_requested.emit()
            return
        distance=clampf(target_distance,MIN_DISTANCE,max_distance)
        wheel_target=distance
    update_camera()
    # Keep the ground point previously beneath the midpoint beneath the
    # NEW midpoint. This simultaneously pans and provides anchored zoom.
    var after: Variant=_plane_hit(next_middle)
    if before is Vector3 and after is Vector3:
        look_at+=before-after
        var bx: float=seam_half.x+32.0 if seam_enabled else maxf(absf(min_x),absf(max_x))
        var bz: float=seam_half.y+32.0 if seam_enabled else maxf(absf(min_z),absf(max_z))
        look_at.x=clampf(look_at.x,-bx,bx)
        look_at.z=clampf(look_at.z,-bz,bz)
        update_camera()
        check_detail_boundary()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton=event
        if mouse_button.button_index==MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            wheel_target=clampf(wheel_target*0.88,MIN_DISTANCE,max_distance)
            distance=lerpf(distance,wheel_target,0.32)
            update_camera()
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            zoom_out_step()
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_RIGHT:
            dragging=mouse_button.pressed
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_LEFT:
            # A mouse-up with no matching mouse-down must never place a building.
            if mouse_button.pressed:
                mouse_left_held=active_fingers.is_empty()
                click_origin=mouse_button.position
                move_distance=0.0
            else:
                if mouse_left_held and active_fingers.is_empty() and move_distance<9.0:
                    _click_ground(mouse_button.position)
                mouse_left_held=false
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        var motion: InputEventMouseMotion=event
        yaw-=motion.relative.x*0.006
        pitch=clampf(pitch+motion.relative.y*0.004,-1.42,-0.15)
        update_camera()
        accept_event()
    elif event is InputEventMouseMotion and mouse_left_held:
        var motion: InputEventMouseMotion=event
        move_distance+=motion.position.distance_to(click_origin)
        if move_distance>=7.0:pan_pointer(click_origin,motion.position)
        click_origin=motion.position
        accept_event()
    elif event is InputEventMouseMotion and not dragging and not mouse_left_held and active_fingers.is_empty():
        var hovered: Variant=_plane_hit(event.position)
        if hovered is Vector3:ground_hovered.emit(hovered)
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch=event
        if touch.pressed:
            active_fingers[touch.index]=touch.position
            mouse_left_held=false
            if active_fingers.size()==1:
                filtered_touch_motion=Vector2.ZERO
                click_origin=touch.position
                move_distance=0.0
                multitouch_active=false
            else:
                move_distance=999.0
                multitouch_active=true
        else:
            if active_fingers.has(touch.index):
                if active_fingers.size()==1 and not multitouch_active and move_distance<9.0:
                    _click_ground(touch.position)
                active_fingers.erase(touch.index)
            if active_fingers.is_empty():
                multitouch_active=false
                filtered_touch_motion=Vector2.ZERO
            else:
                # The remaining finger may orbit, but release cannot build.
                move_distance=999.0
                multitouch_active=true
        accept_event()
    elif event is InputEventScreenDrag:
        var finger: InputEventScreenDrag=event
        if not active_fingers.has(finger.index):return
        if active_fingers.size()==1:
            var old_position: Vector2=active_fingers[finger.index]
            active_fingers[finger.index]=finger.position
            var delta: Vector2=finger.position-old_position
            move_distance+=delta.length()
            # Single-finger drag pans; right mouse button still orbits.
            if move_distance>=7.0:pan_pointer(old_position,finger.position)
        elif active_fingers.size()==2:
            move_distance=999.0
            multitouch_active=true
            _pinch_drag(finger)
        else:
            active_fingers[finger.index]=finger.position
            move_distance=999.0
            multitouch_active=true
        accept_event()
