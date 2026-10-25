extends SubViewportContainer
## Interactive Godot 4 detail map camera controller.
## Right drag rotates; left click places buildings; wheel zooms.
signal ground_clicked(position: Vector3)
var orbit_camera: Camera3D
var yaw: float = -0.65
var pitch: float = -0.8
var distance: float = 76.0
var look_at: Vector3 = Vector3.ZERO
var dragging: bool = false
var click_origin: Vector2=Vector2.ZERO
var move_distance: float=0.0

func _ready() -> void:
    stretch=true
    mouse_filter=Control.MOUSE_FILTER_STOP

func attach_camera(camera: Camera3D) -> void:
    orbit_camera=camera
    update_camera()

func update_camera() -> void:
    if orbit_camera==null:return
    var horizontal: float=cos(pitch)*distance
    var position_3d:=look_at+Vector3(sin(yaw)*horizontal,-sin(pitch)*distance,cos(yaw)*horizontal)
    orbit_camera.position=position_3d
    orbit_camera.look_at(look_at,Vector3.UP)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton=event
        if mouse_button.button_index==MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            distance=clampf(distance*0.88,15.0,180.0)
            update_camera()
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            distance=clampf(distance*1.12,15.0,180.0)
            update_camera()
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_RIGHT:
            dragging=mouse_button.pressed
            accept_event()
        elif mouse_button.button_index==MOUSE_BUTTON_LEFT:
            if mouse_button.pressed:
                click_origin=mouse_button.position
                move_distance=0.0
            elif move_distance<9.0:
                _click_ground(mouse_button.position)
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        var motion: InputEventMouseMotion=event
        yaw-=motion.relative.x*0.009
        pitch=clampf(pitch+motion.relative.y*0.006,-1.42,-0.15)
        update_camera()
        accept_event()
    elif event is InputEventMouseMotion:
        var motion: InputEventMouseMotion=event
        move_distance+=motion.position.distance_to(click_origin)
        click_origin=motion.position
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch=event
        if touch.pressed:
            click_origin=touch.position
            move_distance=0.0
        elif move_distance<9.0:
            _click_ground(touch.position)
        accept_event()
    elif event is InputEventScreenDrag:
        var finger: InputEventScreenDrag=event
        move_distance+=finger.relative.length()
        yaw-=finger.relative.x*0.009
        pitch=clampf(pitch+finger.relative.y*0.006,-1.42,-0.15)
        update_camera()
        accept_event()

func _click_ground(local_point: Vector2) -> void:
    if orbit_camera==null or size.x<=0.0 or size.y<=0.0:return
    var viewport: Viewport=orbit_camera.get_viewport()
    var point_on_viewport:=Vector2(local_point.x*viewport.size.x/size.x,
        local_point.y*viewport.size.y/size.y)
    var origin: Vector3=orbit_camera.project_ray_origin(point_on_viewport)
    var direction: Vector3=orbit_camera.project_ray_normal(point_on_viewport)
    if absf(direction.y)<0.00001:return
    var distance_on_ray: float=-origin.y/direction.y
    if distance_on_ray<0.0:return
    ground_clicked.emit(origin+direction*distance_on_ray)
