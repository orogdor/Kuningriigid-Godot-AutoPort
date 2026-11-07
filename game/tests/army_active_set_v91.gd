extends SceneTree
## V91 performance/regression: hundreds of sleeping actors must not be walked
## by Motion.advance(); only active weak references are processed. Preserve
## independent world/detail roots, retargeting, real jumps and freed rig safety.
const Motion=preload("res://scripts/strategic_army_motion_v78.gd")

func fail(reason: String) -> void:
    printerr("ARMY_ACTIVE_SET_V91 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world:=Node3D.new()
    var detail:=Node3D.new()
    root.add_child(world)
    root.add_child(detail)
    var sleeping: Array[Node3D]=[]
    for i in range(800):
        var soldier:=Node3D.new()
        world.add_child(soldier)
        Motion.retarget(soldier,Vector3(float(i),0.0,4.0),0.0,2.5)
        sleeping.append(soldier)
    if Motion.tracked_count_v91()!=0:
        fail("idle spawn registered active army references")
        return
    for frame in range(10):
        Motion.advance(world,1.0/60.0)
    if sleeping[300].position!=Vector3(300,0,4):
        fail("idle army moved while sleeping")
        return

    var goals: Array[Vector3]=[]
    for i in range(6):
        var unit: Node3D=sleeping[i]
        var goal: Vector3=unit.position+Vector3(1.0,0.0,0.3)
        goals.append(goal)
        Motion.retarget(unit,goal,0.7,2.5)
    if Motion.tracked_count_v91()!=6:
        fail("moving actors were not registered once each")
        return
    Motion.retarget(sleeping[0],goals[0],0.7,2.5)
    if Motion.tracked_count_v91()!=6:
        fail("duplicate target registered multiple times")
        return

    var scout:=Node3D.new()
    detail.add_child(scout)
    Motion.retarget(scout,Vector3(3,0,3),0.0,2.5)
    var scout_target:=Vector3(4,0,3)
    Motion.retarget(scout,scout_target,PI/3.0,2.5)
    if Motion.tracked_count_v91()!=7:
        fail("detail-map soldier was not tracked independently")
        return
    Motion.advance(world,1.0/60.0)
    if scout.position!=Vector3(3,0,3):
        fail("world update advanced a detail-map actor")
        return
    Motion.advance(detail,1.0/60.0)
    if scout.position.x<=3.0 or scout.position.x>=4.0:
        fail("detail update did not interpolate its own actor")
        return
    for frame in range(180):
        Motion.advance(world,1.0/60.0)
        Motion.advance(detail,1.0/60.0)
    for i in range(6):
        if sleeping[i].position.distance_to(goals[i])>0.002:
            fail("world actor did not converge to simulation goal")
            return
    if scout.position.distance_to(scout_target)>0.002 or \
            Motion.tracked_count_v91()!=0:
        fail("converged world/detail actors did not leave active registry")
        return

    # Both heading-only changes and new movement wake the sleeping set.
    Motion.retarget(sleeping[0],goals[0],PI,2.5)
    if Motion.tracked_count_v91()!=1:
        fail("rotation-only change did not wake sleeping actor")
        return
    for frame in range(150):
        Motion.advance(world,1.0/60.0)
    if Motion.tracked_count_v91()!=0:
        fail("turning actor did not settle")
        return

    var deleted:=Node3D.new()
    world.add_child(deleted)
    Motion.retarget(deleted,Vector3(1,0,1),0.0,2.5)
    Motion.retarget(deleted,Vector3(2,0,1),0.0,2.5)
    if Motion.tracked_count_v91()!=1:
        fail("moving temporary actor not registered")
        return
    deleted.free()
    Motion.advance(world,1.0/60.0)
    if Motion.tracked_count_v91()!=0:
        fail("freed actor left a dangling active reference")
        return

    var teleported: Node3D=sleeping[2]
    Motion.retarget(teleported,goals[2]+Vector3(200,0,200),-1.0,2.5)
    if Motion.tracked_count_v91()!=0 or \
            teleported.position!=goals[2]+Vector3(200,0,200):
        fail("real teleport didn't instantly snap and leave registry")
        return

    print("ARMY_ACTIVE_SET_V91 SUCCESS: 800 idle, 7 moving, root isolation, rotation, cleanup, teleport")
    quit(0)
