extends SceneTree
## V85: interpolated soldier movement + stable idle transforms on atlas/detail.
const Motion=preload("res://scripts/strategic_army_motion_v78.gd")

func fail(reason: String) -> void:
    printerr("STRATEGIC_MOTION_V85 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    var group:=Node3D.new()
    root.add_child(group)
    var actor:=Node3D.new()
    group.add_child(actor)
    Motion.retarget(actor,Vector3(0,0,0),0.0,2.5)
    if bool(actor.get_meta("motion_pending_v85",true)):
        fail("first spawn must settle immediately")
        return
    var position:=Vector3(1.0,0.0,0.5)
    Motion.retarget(actor,position,1.2,2.5)
    if not bool(actor.get_meta("motion_pending_v85",false)):
        fail("small move/turn did not wake interpolation")
        return
    var original: Vector3=actor.position
    Motion.advance(group,0.016)
    if actor.position==original or actor.position==position:
        fail("new visual target jumped instead of interpolating")
        return
    for i in range(130):
        Motion.advance(group,0.016)
    if actor.position.distance_to(position)>0.0001 or \
            absf(wrapf(actor.rotation.y-1.2,-PI,PI))>0.0001 or \
            bool(actor.get_meta("motion_pending_v85",true)):
        fail("interpolation did not converge to a fully idle rig")
        return
    var stable: Transform3D=actor.transform
    for i in range(300):
        Motion.advance(group,0.016)
    if actor.transform!=stable:
        fail("idle soldier transform was written or drifted over 300 frames")
        return
    Motion.retarget(actor,position,1.2,2.5)
    if bool(actor.get_meta("motion_pending_v85",true)):
        fail("unchanged save refresh reactivated idle soldier")
        return
    Motion.retarget(actor,position,-1.0,2.5)
    if not bool(actor.get_meta("motion_pending_v85",false)):
        fail("turning without translation must animate")
        return
    for i in range(130):
        Motion.advance(group,0.016)
    if absf(wrapf(actor.rotation.y+1.0,-PI,PI))>0.0001 or \
            bool(actor.get_meta("motion_pending_v85",true)):
        fail("turn-only soldier never settled")
        return
    Motion.retarget(actor,Vector3(120,0,0),2.8,2.5)
    if actor.position!=Vector3(120,0,0) or \
            bool(actor.get_meta("motion_pending_v85",true)):
        fail("world regeneration/teleport failed to snap immediately")
        return
    # Render smoothing must not modify the strategic game state.
    print("STRATEGIC_MOTION_V85 SUCCESS: easing, idle budget, no wake on identical goals, turning, teleport")
    quit(0)
