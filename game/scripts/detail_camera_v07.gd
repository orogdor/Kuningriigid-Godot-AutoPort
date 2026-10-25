extends SubViewportContainer
## Interactive Godot 4 detail map camera controller.
## Right/left drag or touch to orbit; mouse wheel zooms.
var orbit_camera: Camera3D
var yaw: float = -0.65
var pitch: float = -0.8
var distance: float = 76.0
var look_at: Vector3 = Vector3.ZERO
var dragging: bool = false

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
        elif mouse_button.button_index==MOUSE_BUTTON_LEFT or mouse_button.button_index==MOUSE_BUTTON_RIGHT:
            dragging=mouse_button.pressed
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        var motion: InputEventMouseMotion=event
        yaw-=motion.relative.x*0.009
        pitch=clampf(pitch+motion.relative.y*0.006,-1.42,-0.15)
        update_camera()
        accept_event()
    elif event is InputEventScreenDrag:
        var finger: InputEventScreenDrag=event
        yaw-=finger.relative.x*0.009
        pitch=clampf(pitch+finger.relative.y*0.006,-1.42,-0.15)
        update_camera()
        accept_event()
