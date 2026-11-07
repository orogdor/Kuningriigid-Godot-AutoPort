extends SceneTree
## V92 tactical render regression: keep imported-style idle pose stable,
## avoid 216x idle GLB pose work and still wake actors for movement/hit/attack.
## Render-only Dictionary changes must not mutate saved battle simulation.
const BattleView=preload("res://scripts/battle_view_v55.gd")

func fail(why: String) -> void:
    printerr("BATTLE_IDLE_POSE_V92 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=BattleView.new()
    var container:=Node3D.new()
    view.actors_root=container
    view.add_child(container)
    var saved_person: Dictionary={"moving":false,"anim_phase":0.0,
        "attack_anim":0.0,"hit_anim_v61":0.0,
        "strike_seq_v70":0,"hit_seq_v70":0}
    var original: String=JSON.stringify(saved_person)
    var army: Array[Node3D]=[]
    for i in range(216):
        var soldier:=Node3D.new()
        soldier.name="V92Man_"+str(i)
        soldier.position=Vector3(float(i),0,0)
        container.add_child(soldier)
        soldier.add_child(Node3D.new())
        soldier.set_meta("interpolation_v63",{
            "origin":soldier.position,"target":soldier.position,
            "to_heading":0.0,"fraction":1.0,"duration":0.4,
            "move_active":false,"phase":0.0,
            "attack_clock":0.0,"hit_clock":0.0,
            "person":saved_person.duplicate(true),"kind":"spearman"})
        view._wake_battle_actor_v97(soldier)
        army.append(soldier)
    # The first frame applies the model's idle pose once.
    view._render_soldier_motion_v65(1.0/60.0)
    var idle_phases: Array[float]=[]
    for actor in army:
        var state: Dictionary=actor.get_meta("interpolation_v63")
        if not bool(state.get("idle_pose_ready_v92",false)):
            fail("settled actor did not cache its idle pose")
            return
        idle_phases.append(float(state["phase"]))
    # No per-frame pose or state changes for the 216 settled source actors.
    for frame in range(180):
        view._render_soldier_motion_v65(1.0/60.0)
    for i in range(216):
        var actor: Node3D=army[i]
        var state: Dictionary=actor.get_meta("interpolation_v63")
        if absf(float(state["phase"])-idle_phases[i])>0.000001 or \
                actor.position!=Vector3(float(i),0,0):
            fail("an idle actor was redundantly updated at frame "+str(i))
            return
    if JSON.stringify(saved_person)!=original:
        fail("render-only updates modified the simulation soldier dictionary")
        return

    # A new authoritative snapshot invalidates the cache. During travel
    # motion interpolation and procedural/GLB walk pose must update each frame.
    var walker: Node3D=army[0]
    var moving: Dictionary=walker.get_meta("interpolation_v63")
    moving["target"]=Vector3(1.0,0.0,0.0)
    moving["origin"]=walker.position
    moving["fraction"]=0.0
    moving["move_active"]=true
    moving["idle_pose_ready_v92"]=false
    walker.set_meta("interpolation_v63",moving)
    view._wake_battle_actor_v97(walker)
    var old_phase: float=float(moving["phase"])
    var prev: Vector3=walker.position
    for frame in range(15):
        view._render_soldier_motion_v65(1.0/60.0)
        if walker.position.x<=prev.x:
            fail("moving actor stopped between render frames "+str(frame))
            return
        prev=walker.position
    var walking_state: Dictionary=walker.get_meta("interpolation_v63")
    if bool(walking_state.get("idle_pose_ready_v92",false)) or \
            float(walking_state["phase"])<=old_phase or \
            walker.position.x>=1.0:
        fail("walking rig was cached prematurely or snapped to target")
        return

    # An attack/impact while standing still must update the pose and clock.
    var defender: Node3D=army[1]
    var hit_state: Dictionary=defender.get_meta("interpolation_v63")
    hit_state["hit_clock"]=0.36
    hit_state["idle_pose_ready_v92"]=false
    defender.set_meta("interpolation_v63",hit_state)
    view._wake_battle_actor_v97(defender)
    view._render_soldier_motion_v65(1.0/60.0)
    var changed: Dictionary=defender.get_meta("interpolation_v63")
    if float(changed["hit_clock"])>=0.36 or \
            bool(changed.get("idle_pose_ready_v92",false)):
        fail("hit animation was wrongly treated as an idle pose")
        return
    var model: Node3D=defender.get_child(0) as Node3D
    if model==null or model.rotation.x<=0.0:
        fail("real hit-recoil fallback pose no longer renders")
        return

    # New saved snapshots can also become idle immediately, then cache
    # only after the new idle pose has actually been applied.
    var retired: Node3D=army[2]
    var refresh: Dictionary=retired.get_meta("interpolation_v63")
    refresh["idle_pose_ready_v92"]=false
    refresh["person"]=saved_person.duplicate(true)
    refresh["phase"]=5.0
    retired.set_meta("interpolation_v63",refresh)
    view._wake_battle_actor_v97(retired)
    view._render_soldier_motion_v65(1.0/60.0)
    var resumed: Dictionary=retired.get_meta("interpolation_v63")
    if not bool(resumed.get("idle_pose_ready_v92",false)) or \
            float(resumed["phase"])<=5.0:
        fail("fresh idle snapshot was skipped rather than applied once")
        return
    print("BATTLE_IDLE_POSE_V92 SUCCESS: 216 cached idle rigs, moving frames, hit, revalidation, saved state")
    quit(0)
