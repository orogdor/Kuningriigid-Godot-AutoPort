extends RefCounted
## V78: real strategic army actors persist across economy/map refreshes.
## AnimationPlayer is never restarted solely because _sync_trade_map ran.
## Save data and travel clocks remain simulation owned; only visuals blend.
const FOLLOW_RATE: float=14.0

static func retarget(actor: Node3D,point: Vector3,heading: float,
        snap_distance: float) -> void:
    if actor==null:return
    # Compare successive simulation targets, not the interpolated actor.
    # A slow render frame must not turn ordinary travel into a teleport.
    # First spawn or a discontinuous simulation jump still snaps instantly.
    var previous_goal: Vector3=actor.get_meta("motion_goal_v78",point)
    if not actor.has_meta("motion_goal_v78") or \
            previous_goal.distance_to(point)>snap_distance:
        actor.position=point
        actor.rotation.y=heading
    actor.set_meta("motion_goal_v78",point)
    actor.set_meta("heading_goal_v78",heading)

static func advance(root: Node3D,delta: float) -> void:
    if root==null:return
    var blend: float=1.0-exp(-clampf(delta,0.0,0.25)*FOLLOW_RATE)
    for child in root.get_children():
        var actor: Node3D=child as Node3D
        if actor==null or not actor.has_meta("motion_goal_v78"):continue
        var goal: Vector3=actor.get_meta("motion_goal_v78",actor.position)
        actor.position=actor.position.lerp(goal,blend)
        if actor.position.distance_squared_to(goal)<0.000004:
            actor.position=goal
        var yaw: float=float(actor.get_meta("heading_goal_v78",actor.rotation.y))
        actor.rotation.y=lerp_angle(actor.rotation.y,yaw,blend)
        if absf(wrapf(actor.rotation.y-yaw,-PI,PI))<0.002:
            actor.rotation.y=yaw
