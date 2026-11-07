extends SceneTree
## V85: settled rigs must not receive redundant per-frame transforms.
const Motion=preload("res://scripts/strategic_army_motion_v78.gd")

func fail(message: String) -> void:
    printerr("ARMY_MOTION_SLEEP_V85 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root3:=Node3D.new()
    root.add_child(root3)
    var actor:=Node3D.new()
    root3.add_child(actor)
    var origin:=Vector3(4,0,6)
    Motion.retarget(actor,origin,0.0,2.5)
    if bool(actor.get_meta("motion_active_v85",true)):
        fail("new actor should snap and sleep")
        return
    for i in range(90):Motion.advance(root3,1.0/60.0)
    if actor.position!=origin:
        fail("idle actor drifted")
        return
    var target:=origin+Vector3(1,0,0)
    Motion.retarget(actor,target,PI/2.0,2.5)
    if not bool(actor.get_meta("motion_active_v85",false)):
        fail("moving actor did not wake")
        return
    Motion.advance(root3,1.0/60.0)
    if actor.position.x<=origin.x or actor.position.x>=target.x:
        fail("movement did not interpolate")
        return
    for i in range(150):Motion.advance(root3,1.0/60.0)
    if actor.position!=target or \
            not is_equal_approx(actor.rotation.y,PI/2.0) or \
            bool(actor.get_meta("motion_active_v85",true)):
        fail("actor failed to settle and sleep")
        return
    Motion.retarget(actor,target,PI/2.0,2.5)
    if bool(actor.get_meta("motion_active_v85",true)):
        fail("identical economy refresh woke settled rig")
        return
    Motion.retarget(actor,target,PI,2.5)
    if not bool(actor.get_meta("motion_active_v85",false)):
        fail("rotation-only change failed to wake rig")
        return
    for i in range(150):Motion.advance(root3,1.0/60.0)
    if bool(actor.get_meta("motion_active_v85",true)):
        fail("rotation-only change failed to settle")
        return
    var teleport:=Vector3(100,0,100)
    Motion.retarget(actor,teleport,0.0,2.5)
    if actor.position!=teleport or bool(actor.get_meta("motion_active_v85",true)):
        fail("large jump did not snap without interpolating")
        return
    print("ARMY_MOTION_SLEEP_V85 SUCCESS: idle, interpolation, settled state, rotation, teleport")
    quit(0)
