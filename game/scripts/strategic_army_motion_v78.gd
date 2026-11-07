extends RefCounted
## V78: real strategic army actors persist across economy/map refreshes.
## AnimationPlayer is never restarted solely because _sync_trade_map ran.
## Save data and travel clocks remain simulation owned; only visuals blend.
const FOLLOW_RATE: float=14.0

static func retarget(actor: Node3D,point: Vector3,heading: float,
        snap_distance: float) -> void:
    if actor==null:return
    # V90: the visual actor can trail the simulation under low FPS.
    # Compare TWO AUTHORITATIVE GOALS, never the lagging rendered pose:
    # otherwise a sequence of ordinary small moves becomes a teleport.
    var previous_goal: Vector3=actor.get_meta("motion_goal_v78",point)
    var discontinuity: bool=previous_goal.distance_squared_to(point)>\
        snap_distance*snap_distance
    if not actor.has_meta("motion_goal_v78") or discontinuity:
        # First spawn and real world reload/teleport remain instantaneous.
        actor.position=point
        actor.rotation.y=heading
    actor.set_meta("motion_goal_v78",point)
    actor.set_meta("heading_goal_v78",heading)
    actor.set_meta("motion_active_v85",actor.position.distance_squared_to(point)>0.000004 or \
        absf(wrapf(actor.rotation.y-heading,-PI,PI))>=0.002)

static func advance(root: Node3D,delta: float) -> void:
    if root==null:return
    var blend: float=1.0-exp(-clampf(delta,0.0,0.25)*FOLLOW_RATE)
    for child in root.get_children():
        var actor: Node3D=child as Node3D
        if actor==null or not bool(actor.get_meta("motion_active_v85",false)):continue
        var goal: Vector3=actor.get_meta("motion_goal_v78",actor.position)
        actor.position=actor.position.lerp(goal,blend)
        if actor.position.distance_squared_to(goal)<0.000004:
            actor.position=goal
        var yaw: float=float(actor.get_meta("heading_goal_v78",actor.rotation.y))
        actor.rotation.y=lerp_angle(actor.rotation.y,yaw,blend)
        if absf(wrapf(actor.rotation.y-yaw,-PI,PI))<0.002:
            actor.rotation.y=yaw
        # Node3D rotation uses engine precision; literal float equality may
        # never hold even immediately after setting the target heading.
        # Measure settling in the same tolerances used for snapping.
        var reached_position: bool=actor.position.distance_squared_to(goal)<0.000004
        var reached_heading: bool=absf(wrapf(actor.rotation.y-yaw,-PI,PI))<0.002
        if reached_position and reached_heading:
            actor.position=goal
            actor.rotation.y=yaw
            actor.set_meta("motion_active_v85",false)
