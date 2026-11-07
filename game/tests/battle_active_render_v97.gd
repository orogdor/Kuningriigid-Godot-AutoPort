extends SceneTree
## V97 deterministic render-worker regression. Sleeping 216 actors must
## consume zero per-frame traversal; only moving/attacking actors wake.
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_ACTIVE_RENDER_V97 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=View.new()
    var actors:=Node3D.new()
    view.actors_root=actors
    view.add_child(actors)
    var original_person: Dictionary={"moving":false,"anim_phase":0.0,
        "attack_anim":0.0,"hit_anim_v61":0.0,
        "strike_seq_v70":0,"hit_seq_v70":0}
    var saved: String=JSON.stringify(original_person)
    var army: Array[Node3D]=[]
    for i in range(216):
        var node:=Node3D.new()
        node.name="V97Soldier_"+str(i)
        node.position=Vector3(float(i),0,0)
        actors.add_child(node)
        node.add_child(Node3D.new())
        node.set_meta("interpolation_v63",{
            "origin":node.position,"target":node.position,
            "to_heading":0.0,"fraction":1.0,"duration":0.4,
            "move_active":false,"phase":0.0,
            "attack_clock":0.0,"hit_clock":0.0,
            "person":original_person.duplicate(true),"kind":"spearman"})
        view._wake_battle_actor_v97(node)
        army.append(node)
    if view.active_battle_render_count_v97()!=216:
        fail("216 freshly loaded soldiers did not register for first pose")
        return
    view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0:
        fail("216 idle models remain on the per-frame work list")
        return
    var cached: Array[float]=[]
    for node in army:
        var state: Dictionary=node.get_meta("interpolation_v63")
        if not bool(state.get("idle_pose_ready_v92",false)):
            fail("sleeping actor never applied its idle pose")
            return
        cached.append(float(state["phase"]))
    for frame in range(240):
        view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0:
        fail("empty render frames woke idle actors")
        return
    for i in range(216):
        var s: Dictionary=army[i].get_meta("interpolation_v63")
        if absf(float(s["phase"])-cached[i])>0.000001:
            fail("sleeping actor's animation state changed during empty frames")
            return

    var walker: Node3D=army[0]
    var walk: Dictionary=walker.get_meta("interpolation_v63")
    walk["origin"]=walker.position
    walk["target"]=walker.position+Vector3(2,0,0)
    walk["fraction"]=0.0
    walk["move_active"]=true
    walk["idle_pose_ready_v92"]=false
    walker.set_meta("interpolation_v63",walk)
    view._wake_battle_actor_v97(walker)
    view._wake_battle_actor_v97(walker)
    if view.active_battle_render_count_v97()!=1:
        fail("retargeting one soldier generated duplicate active entries")
        return
    var last_x: float=walker.position.x
    for frame in range(15):
        view._render_soldier_motion_v65(1.0/60.0)
        if walker.position.x<=last_x:
            fail("active soldier stopped between visual frames")
            return
        last_x=walker.position.x
    if view.active_battle_render_count_v97()!=1 or last_x>=2.0:
        fail("walking soldier slept or teleported before reaching target")
        return

    # A new stationary snapshot must settle and drop the render entry.
    var settled: Dictionary=walker.get_meta("interpolation_v63")
    settled["origin"]=walker.position
    settled["target"]=walker.position
    settled["fraction"]=1.0
    settled["move_active"]=false
    settled["idle_pose_ready_v92"]=false
    walker.set_meta("interpolation_v63",settled)
    view._wake_battle_actor_v97(walker)
    view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0:
        fail("new idle snapshot failed to sleep a soldier")
        return

    # Hit and attack timers wake an otherwise settled person.
    var defender: Node3D=army[1]
    var hit: Dictionary=defender.get_meta("interpolation_v63")
    hit["hit_clock"]=0.36
    hit["idle_pose_ready_v92"]=false
    defender.set_meta("interpolation_v63",hit)
    view._wake_battle_actor_v97(defender)
    view._render_soldier_motion_v65(1.0/60.0)
    var after_hit: Dictionary=defender.get_meta("interpolation_v63")
    if view.active_battle_render_count_v97()!=1 or \
            float(after_hit["hit_clock"])>=0.36 or \
            (defender.get_child(0) as Node3D).rotation.x<=0.0:
        fail("new hit event was not animated on the next frame")
        return

    # Death animation is owned by the separate V93 fallen registry.
    view._start_fallen_v69(defender)
    if view.active_battle_render_count_v97()!=0 or \
            not defender.has_meta("fallen_since_v69"):
        fail("fallen soldier remains in active movement work set")
        return

    # Freed or transferred nodes must never be kept alive by render cache.
    var retired: Node3D=army[2]
    var active: Dictionary=retired.get_meta("interpolation_v63")
    active["move_active"]=true
    active["idle_pose_ready_v92"]=false
    retired.set_meta("interpolation_v63",active)
    view._wake_battle_actor_v97(retired)
    retired.free()
    view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0 or \
            JSON.stringify(original_person)!=saved:
        fail("freed render actor remained tracked or mutated saved state")
        return

    # Scene transfers must also relinquish render ownership without
    # deleting the soldier node from the receiving scene.
    var transferred: Node3D=army[3]
    var refreshed: Dictionary=transferred.get_meta("interpolation_v63")
    refreshed["idle_pose_ready_v92"]=false
    refreshed["move_active"]=true
    transferred.set_meta("interpolation_v63",refreshed)
    view._wake_battle_actor_v97(transferred)
    var elsewhere:=Node3D.new()
    view.add_child(elsewhere)
    actors.remove_child(transferred)
    elsewhere.add_child(transferred)
    view._render_soldier_motion_v65(1.0/60.0)
    if view.active_battle_render_count_v97()!=0 or \
            not is_instance_valid(transferred) or \
            transferred.get_parent()!=elsewhere:
        fail("scene-transferred soldier retained render work ownership")
        return

    print("BATTLE_ACTIVE_RENDER_V97 SUCCESS: 216 sleep, zero idle scans, new walk/hit/death, freed/transferred node cleanup, unchanged saves")
    quit(0)
