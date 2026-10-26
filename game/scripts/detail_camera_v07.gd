extends SubViewportContainer
## 0.19: mouse orbit and scroll; single finger orbit/tap, two fingers pinch/pan.
signal ground_clicked(position: Vector3)
signal ground_hovered(position: Vector3)
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

func _ready() -> void:
    stretch=true
    mouse_filter=Control.MOUSE_FILTER_STOP

func set_city_bounds(bounds: Dictionary) -> void:
    min_x=float(bounds.get("xmin",-112.5))
    max_x=float(bounds.get("xmax",112.5))
    min_z=float(bounds.get("zmin",-97.5))
    max_z=float(bounds.get("zmax",97.5))
    max_distance=180.0 if bounds.is_empty() else maxf(180.0,float(bounds.get("span",180.0))*1.35)
    look_at.x=clampf(look_at.x,min_x,max_x)
    look_at.z=clampf(look_at.z,min_z,max_z)
    distance=clampf(distance,MIN_DISTANCE,max_distance)
    update_camera()

func overview(bounds: Dictionary) -> void:
    set_city_bounds(bounds)
    look_at=bounds.get("midpoint",Vector3.ZERO)
    distance=clampf(float(bounds.get("span",160.0))*1.20,76.0,max_distance)
    update_camera()

func focus(point: Vector3) -> void:
    look_at.x=clampf(point.x,min_x,max_x)
    look_at.z=clampf(point.z,min_z,max_z)
    update_camera()

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
        distance=clampf(distance*pow(old_span/next_span,0.85),MIN_DISTANCE,max_distance)
    update_camera()
    # Keep the ground point previously beneath the midpoint beneath the
    # NEW midpoint. This simultaneously pans and provides anchored zoom.
    var after: Variant=_plane_hit(next_middle)
    if before is Vector3 and after is Vector3:
        look_at+=before-after
        look_at.x=clampf(look_at.x,min_x,max_x)
        look_at.z=clampf(look_at.z,min_z,max_z)
        update_camera()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton=event
        if mouse_button.button_index==MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            distance=clampf(distance*0.88,MIN_DISTANCE,max_distance)
            update_camera()
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            distance=clampf(distance*1.12,MIN_DISTANCE,max_distance)
            update_camera()
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
        click_origin=motion.position
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
            # Blend jittery touch deltas but retain exact tap cancellation.
            # Clamp OS gesture bursts, not the accumulated camera movement.
            delta.x=clampf(delta.x,-72.0,72.0)
            delta.y=clampf(delta.y,-72.0,72.0)
            filtered_touch_motion=filtered_touch_motion.lerp(delta,0.6)
            yaw-=filtered_touch_motion.x*0.006
            pitch=clampf(pitch+filtered_touch_motion.y*0.004,-1.42,-0.15)
            update_camera()
        elif active_fingers.size()==2:
            move_distance=999.0
            multitouch_active=true
            _pinch_drag(finger)
        else:
            active_fingers[finger.index]=finger.position
            move_distance=999.0
            multitouch_active=true
        accept_event()
