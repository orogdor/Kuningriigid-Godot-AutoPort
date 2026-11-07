extends RefCounted
## V85: smooth strategic positions at low FPS without rewriting every settled
## soldier transform on every render frame. Simulation clocks stay independent.
## V78 saved actor identity, target metadata and teleport tolerance are kept.
const FOLLOW_RATE: float=6.0
const SETTLED_DISTANCE_SQUARED: float=0.000004
const SETTLED_ANGLE: float=0.002

static func retarget(actor: Node3D,point: Vector3,heading: float,
        snap_distance: float) -> void:
    if actor==null:return
    # A new rig, a reloaded world or an actual teleport must not spend
    # seconds traversing a discontinuity that never happened in the game.
    if not actor.has_meta("motion_goal_v78") or \
            actor.position.distance_squared_to(point)>snap_distance*snap_distance:
        actor.position=point
        actor.rotation.y=heading
    actor.set_meta("motion_goal_v78",point)
    actor.set_meta("heading_goal_v78",heading)
    # Stable actors need no per-frame Node3D transform writes. Retargeting
    # during a move keeps smoothing active even if the saved goal is unchanged.
    var moving: bool=actor.position.distance_squared_to(point)>=SETTLED_DISTANCE_SQUARED
    var turning: bool=absf(wrapf(actor.rotation.y-heading,-PI,PI))>=SETTLED_ANGLE
    if not moving and actor.position!=point:
        actor.position=point
    if not turning and actor.rotation.y!=heading:
        actor.rotation.y=heading
    actor.set_meta("motion_pending_v85",moving or turning)

static func advance(root: Node3D,delta: float) -> void:
    if root==null or delta<=0.0:return
    var blend: float=1.0-exp(-clampf(delta,0.0,0.25)*FOLLOW_RATE)
    for child in root.get_children():
        var actor: Node3D=child as Node3D
        if actor==null or not actor.has_meta("motion_goal_v78") or \
                not bool(actor.get_meta("motion_pending_v85",true)):
            continue
        var goal: Vector3=actor.get_meta("motion_goal_v78",actor.position)
        var yaw: float=float(actor.get_meta("heading_goal_v78",actor.rotation.y))
        var moving: bool=actor.position.distance_squared_to(goal)>=SETTLED_DISTANCE_SQUARED
        var turning: bool=absf(wrapf(actor.rotation.y-yaw,-PI,PI))>=SETTLED_ANGLE
        if moving:
            var next: Vector3=actor.position.lerp(goal,blend)
            actor.position=goal if next.distance_squared_to(goal)<SETTLED_DISTANCE_SQUARED else next
        elif actor.position!=goal:
            actor.position=goal
        if turning:
            var next_yaw: float=lerp_angle(actor.rotation.y,yaw,blend)
            actor.rotation.y=yaw if absf(wrapf(next_yaw-yaw,-PI,PI))<SETTLED_ANGLE else next_yaw
        elif actor.rotation.y!=yaw:
            actor.rotation.y=yaw
        var settled: bool=actor.position==goal and \
                absf(wrapf(actor.rotation.y-yaw,-PI,PI))<SETTLED_ANGLE
        if settled and actor.rotation.y!=yaw:
            actor.rotation.y=yaw
        if settled:
            actor.set_meta("motion_pending_v85",false)
