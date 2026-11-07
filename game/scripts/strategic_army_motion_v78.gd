extends RefCounted
## V91: persistent strategic soldier visuals. Only actively moving/turning
## actors are updated every rendered frame; idle armies cost no per-frame scan.
## Registry contains WeakRefs so removed army actors are never kept alive.
## Simulation, saved positions, animation players and actual teleports are
## unchanged. Works with separate world-map and detail-map army roots.
const FOLLOW_RATE: float=14.0
static var _active_actors: Dictionary={}

static func tracked_count_v91() -> int:
    # Diagnostic helper for deterministic headless performance regressions.
    for actor_id in _active_actors.keys():
        var ref: WeakRef=_active_actors[actor_id] as WeakRef
        if ref==null or ref.get_ref()==null:
            _active_actors.erase(actor_id)
    return _active_actors.size()

static func retarget(actor: Node3D,point: Vector3,heading: float,
        snap_distance: float) -> void:
    if actor==null:return
    # V90: compare consecutive authoritative simulation goals, NOT the
    # lagging rendered position, to distinguish valid travel from teleport.
    var previous_goal: Vector3=actor.get_meta("motion_goal_v78",point)
    var discontinuity: bool=previous_goal.distance_squared_to(point)>\
        snap_distance*snap_distance
    if not actor.has_meta("motion_goal_v78") or discontinuity:
        actor.position=point
        actor.rotation.y=heading
    actor.set_meta("motion_goal_v78",point)
    actor.set_meta("heading_goal_v78",heading)
    var active: bool=actor.position.distance_squared_to(point)>0.000004 or \
        absf(wrapf(actor.rotation.y-heading,-PI,PI))>=0.002
    actor.set_meta("motion_active_v85",active)
    var actor_id: int=actor.get_instance_id()
    if active:
        # Re-retargeting an awake unit replaces its entry, never duplicates it.
        _active_actors[actor_id]=weakref(actor)
    else:
        # Idle refresh, new spawn and genuine teleports should not be scanned.
        _active_actors.erase(actor_id)

static func advance(root: Node3D,delta: float) -> void:
    if root==null or _active_actors.is_empty():return
    var blend: float=1.0-exp(-clampf(delta,0.0,0.25)*FOLLOW_RATE)
    # Iterate a stable snapshot because entries are removed on settling.
    # Cost scales with moving units, NOT all idle rigs in either scene.
    for actor_id in _active_actors.keys():
        var ref: WeakRef=_active_actors[actor_id] as WeakRef
        var actor: Node3D=ref.get_ref() as Node3D if ref!=null else null
        if actor==null:
            _active_actors.erase(actor_id)
            continue
        # Original implementation only advanced direct children of root.
        # Keep world/detail update ownership exactly the same.
        if actor.get_parent()!=root:continue
        if not bool(actor.get_meta("motion_active_v85",false)):
            _active_actors.erase(actor_id)
            continue
        var goal: Vector3=actor.get_meta("motion_goal_v78",actor.position)
        actor.position=actor.position.lerp(goal,blend)
        if actor.position.distance_squared_to(goal)<0.000004:
            actor.position=goal
        var yaw: float=float(actor.get_meta("heading_goal_v78",actor.rotation.y))
        actor.rotation.y=lerp_angle(actor.rotation.y,yaw,blend)
        if absf(wrapf(actor.rotation.y-yaw,-PI,PI))<0.002:
            actor.rotation.y=yaw
        var reached_position: bool=actor.position.distance_squared_to(goal)<0.000004
        var reached_heading: bool=absf(wrapf(actor.rotation.y-yaw,-PI,PI))<0.002
        if reached_position and reached_heading:
            actor.position=goal
            actor.rotation.y=yaw
            actor.set_meta("motion_active_v85",false)
            _active_actors.erase(actor_id)
