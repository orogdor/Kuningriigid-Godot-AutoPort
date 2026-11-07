extends SceneTree
## V90: low renderer FPS must not teleport a soldier whose authoritative
## travel goals move in small, valid increments. Large real jumps still snap.
const Motion=preload("res://scripts/strategic_army_motion_v78.gd")

func fail(reason: String) -> void:
    printerr("ARMY_RETARGET_LAG_V90 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var group:=Node3D.new()
    root.add_child(group)
    var soldier:=Node3D.new()
    group.add_child(soldier)
    var start:=Vector3(10.0,0.0,5.0)
    Motion.retarget(soldier,start,0.0,2.5)
    if soldier.position!=start or bool(soldier.get_meta("motion_active_v85",true)):
        fail("first spawn did not snap and sleep")
        return
    var target: Vector3=start
    # Simulate 12 economy ticks while rendering is stalled: 12*0.4m
    # cumulative lag is > 2.5m snap threshold but each move is legitimate.
    for i in range(12):
        target=start+Vector3(0.4*float(i+1),0.0,0.0)
        Motion.retarget(soldier,target,0.7,2.5)
        if soldier.position!=start:
            fail("lagging actor teleported after incremental goal "+str(i+1))
            return
    if not bool(soldier.get_meta("motion_active_v85",false)):
        fail("lagging actor wasn't awakened")
        return
    var saved: Vector3=soldier.position
    Motion.advance(group,1.0/60.0)
    if soldier.position.distance_to(saved)<0.01 or \
            soldier.position.distance_to(target)<0.01:
        fail("actor did not interpolate smoothly toward backlog target")
        return
    # Another ordinary simulation tick must not cause a backward or
    # discontinuous snap even when the rendering gap remains substantial.
    var next_goal: Vector3=target+Vector3(0.4,0.0,0.0)
    var previous_position: Vector3=soldier.position
    Motion.retarget(soldier,next_goal,0.9,2.5)
    if soldier.position!=previous_position:
        fail("next valid simulation step snapped the lagging render pose")
        return
    for i in range(160):
        Motion.advance(group,1.0/60.0)
    if soldier.position.distance_to(next_goal)>0.003 or \
            bool(soldier.get_meta("motion_active_v85",true)):
        fail("soldier never converged and slept after lag")
        return
    var jump:=Vector3(150.0,0.0,200.0)
    Motion.retarget(soldier,jump,-1.0,2.5)
    if soldier.position!=jump or \
            not is_equal_approx(soldier.rotation.y,-1.0) or \
            bool(soldier.get_meta("motion_active_v85",true)):
        fail("real teleport did not snap to authoritative coordinates")
        return
    print("ARMY_RETARGET_LAG_V90 SUCCESS: stalled visual, small goals, smooth recovery, true teleport, idle sleep")
    quit(0)
