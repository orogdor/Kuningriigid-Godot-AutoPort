extends SceneTree
## V78 end-to-end: strategic armies retain the same skinned render actor,
## animation player and travel target across multiple economy refreshes.
const Game=preload("res://content.tscn")
const Motion=preload("res://scripts/strategic_army_motion_v78.gd")

func fail(why: String) -> void:
    printerr("STRATEGIC_ARMY_V78 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(800,560)
    var ui: Control=Game.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var atlas=ui.world_view.terrain_3d
    var start: Dictionary=atlas.world["starts"][0]
    var c: int=int(start["c"])
    var r: int=int(start["r"])
    var army: Dictionary={"id":78001,"c":c,"r":r,"kind":"spearman",
        "path":[],"travelClock":0.0,"travelDuration":0.0}
    atlas.set_armies_v54([army])
    var first: Node3D=atlas.army_root_v54.get_node_or_null(
        "ArmyActorV54_78001") as Node3D
    if first==null or first.get_child_count()<2:
        fail("world army missing original mesh/footprint")
        return
    var initial_id: int=first.get_instance_id()
    var original_model: Node3D=first.get_child(0) as Node3D
    atlas.set_armies_v54([army])
    var reused: Node3D=atlas.army_root_v54.get_node_or_null(
        "ArmyActorV54_78001") as Node3D
    if reused==null or reused.get_instance_id()!=initial_id or \
            reused.get_child(0)!=original_model:
        fail("world map rebuilds mesh on unchanged army tick")
        return
    var move: Vector3=first.position+Vector3(0.35,0.0,0.25)
    Motion.retarget(first,move,0.7,2.5)
    if first.position.distance_to(move)<0.1:
        fail("movement teleported without visual blending")
        return
    Motion.advance(atlas.army_root_v54,0.1)
    if first.position.distance_to(move)>=0.43 or \
            first.position.distance_to(move)<0.001:
        fail("world movement did not interpolate")
        return
    for i in range(60):Motion.advance(atlas.army_root_v54,0.1)
    if first.position.distance_to(move)>0.003:
        fail("world movement failed to converge")
        return
    # Regression: simulation advances in small steps while rendering is late.
    # Retarget must not snap just because the visual actor trails its goal.
    var lag_start: Vector3=first.position
    for step in range(12):
        var lag_goal: Vector3=lag_start+Vector3(float(step+1)*0.4,0.0,0.0)
        Motion.retarget(first,lag_goal,0.7,2.5)
    if first.position.distance_to(lag_start)>0.01:
        fail("lagging render actor teleported during incremental retarget")
        return
    Motion.advance(atlas.army_root_v54,0.1)
    if first.position.distance_to(lag_start)<0.1 or \
            first.position.distance_to(lag_goal)<0.1:
        fail("lagging render actor did not resume smooth interpolation")
        return
    atlas.set_armies_v54([])
    if atlas.army_root_v54.get_child_count()!=0:
        fail("disbanded world army remains visible")
        return
    # Actual detail scene with same stable army ID. Refresh twice, assert
    # no new scene, no new rig, and no animation restart.
    ui._show_detail(c,r)
    var detail=ui.detail_view
    detail.set_world_armies_v54([army])
    var first_detail: Node3D=detail.army_detail_root_v54.get_node_or_null(
        "DetailArmyV54_78001") as Node3D
    if first_detail==null or first_detail.get_child_count()!=1:
        fail("detail map did not create real soldier")
        return
    var detail_id: int=first_detail.get_instance_id()
    var detail_model: Node3D=first_detail.get_child(0) as Node3D
    detail.set_world_armies_v54([army])
    var stable: Node3D=detail.army_detail_root_v54.get_node_or_null(
        "DetailArmyV54_78001") as Node3D
    if stable==null or stable.get_instance_id()!=detail_id or \
            stable.get_child(0)!=detail_model:
        fail("detail refresh restarts skeleton and creates new GLB")
        return
    var detail_goal: Vector3=first_detail.position+Vector3(12.0,0.0,8.0)
    Motion.retarget(first_detail,detail_goal,0.8,90.0)
    var old: Vector3=first_detail.position
    Motion.advance(detail.army_detail_root_v54,0.03)
    if old.distance_to(first_detail.position)<0.005 or \
            first_detail.position.distance_to(detail_goal)<0.005:
        fail("detail army does not blend intermediate frames")
        return
    for i in range(120):Motion.advance(detail.army_detail_root_v54,0.08)
    if first_detail.position.distance_to(detail_goal)>0.003:
        fail("detail actor failed to reach last saved target")
        return
    detail.set_world_armies_v54([])
    if detail.army_detail_root_v54.get_child_count()!=0:
        fail("detail map left a disbanded army behind")
        return
    print("STRATEGIC_ARMY_V78 SUCCESS: persistent world/detail rig, smooth position and heading, cleanup")
    quit(0)
