extends SceneTree
## V65: visual FPS decoupled from fixed-step combat; source GLB animation
## classes, bounded prediction, close zoom + wheel/pinch/pan regression.
## Headless validates transforms, not physical GPU FPS or a true rig.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Animation65=preload("res://scripts/battle_animation_v65.gd")

func fail(message: String) -> void:
    printerr("BATTLE_MOTION_V65 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_demo_battle()
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    if view.actors_root.get_child_count()!=96 or not view.auto_play_enabled:
        fail("Real 96-person demo did not start")
        return
    # Inspect the actual imported source GLBs. These assets contain real
    # glTF bones and idle/walk/attack/hit/death animations. A fallback
    # whole-body wobble is NOT enough for the user's requested animation.
    var armed: int=0
    var playback: int=0
    for soldier in view.actors_root.get_children():
        var source: Node3D=soldier.get_child(0) as Node3D
        var clips: Dictionary=Animation65.available_clips(source)
        for needed in ["idle","walk","attack","hit","death"]:
            if not clips.has(needed):
                fail("Original soldier GLB did not import "+needed+" animation")
                return
        armed+=1
        var animator: Dictionary=source.get_meta("source_animator_v65",{})
        var player: AnimationPlayer=animator.get("player",null)
        if player!=null and player.is_playing():playback+=1
    if armed!=96 or playback!=96:
        fail("Original 96 skeletal source animations were not started")
        return
    view._refresh_skeletal_status()
    if view.skeletal_status_label==null or \
            view.skeletal_status_label.text!="Animatsioon: 96/96":
        fail("Actual source GLB AnimationPlayer playback diagnostic is wrong")
        return

    # Default full battlefield, mouse wheel, tenfold close zoom and limits.
    view._zoom(0.001)
    if absf(view.cam_size-1.5)>0.001 or \
            absf(view.battle_camera.size-1.5)>0.001:
        fail("Cannot zoom in to 1.5m around the source 5.2m soldier")
        return
    view._zoom(10000.0)
    if absf(view.cam_size-1050.0)>0.001:
        fail("Far zoom bound was lost")
        return
    view._focus_individual()
    if view.cam_size>22.0:
        fail("Focus selected soldier still stops at 120m")
        return
    var wheel:=InputEventMouseButton.new()
    wheel.pressed=true
    wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    var old_zoom: float=view.cam_size
    view._on_battle_canvas_input(wheel)
    if view.cam_size>=old_zoom:
        fail("Mouse wheel does not zoom the 3D battle camera")
        return
    var touch_a:=InputEventScreenTouch.new()
    touch_a.pressed=true
    touch_a.index=0
    touch_a.position=Vector2(100,100)
    view._on_battle_canvas_input(touch_a)
    var touch_b:=InputEventScreenTouch.new()
    touch_b.pressed=true
    touch_b.index=1
    touch_b.position=Vector2(200,100)
    view._on_battle_canvas_input(touch_b)
    var finger:=InputEventScreenDrag.new()
    finger.index=1
    finger.position=Vector2(300,100)
    var before_pinch: float=view.cam_size
    view._on_battle_canvas_input(finger)
    if view.cam_size>=before_pinch:
        fail("Two-finger pinch does not zoom in")
        return
    var release:=InputEventScreenTouch.new()
    release.index=1
    release.pressed=false
    view._on_battle_canvas_input(release)
    release.index=0
    view._on_battle_canvas_input(release)
    if view.pinch_points.size()!=0:
        fail("Pinch state did not clear after fingers released")
        return
    var before_pan: Vector3=view.battle_camera.position
    view._zoom_pan(Vector2(80,35))
    if view.battle_camera.position.distance_to(before_pan)<0.005:
        fail("Cannot pan around a very close 3D battle")
        return
    view._reset_camera()
    if absf(view.cam_size-175.0)>0.001:
        fail("Whole battlefield button failed to restore camera")
        return

    # All weapon types have distinct, visible attack poses; walk steps
    # move the actual imported model wrapper rather than a floating label.
    var kinds: Array=["spearman","axeman","slinger"]
    var poses: Array=[]
    for kind in kinds:
        var man: Dictionary={"moving":true,"anim_phase":1.0,
            "attack_anim":0.18,"hit_anim_v61":0.0}
        var pose: Dictionary=Animation65.pose(man,String(kind))
        if (pose["offset"] as Vector3).y<0.1 or \
                not bool(pose["attacking"]):
            fail("Source GLB walk/attack pose is missing or invisible")
            return
        poses.append(pose)
    if (poses[0]["rotation"] as Vector3).distance_to(
            poses[1]["rotation"] as Vector3)<0.12 or \
            (poses[1]["rotation"] as Vector3).distance_to(
            poses[2]["rotation"] as Vector3)<0.12:
        fail("Spearman, axeman and slinger combat poses are indistinguishable")
        return
    var hit: Dictionary=Animation65.pose({"moving":false,
        "anim_phase":0.0,"attack_anim":0.0,"hit_anim_v61":0.36},"spearman")
    if not bool(hit["hit"]) or \
            (hit["rotation"] as Vector3).x<0.1:
        fail("The soldier has no distinct damage recoil")
        return

    # One 0.2 sim-second snapshot must visually animate on subsequent
    # 50-60 FPS draw frames and continue across a short snapshot gap.
    var battle: Dictionary=Battle.current(ui.city,ui.world_view.world)
    ui._battle_tick(0.5)
    var moved: Node3D=null
    for actor in view.actors_root.get_children():
        var state: Dictionary=actor.get_meta("interpolation_v63",{})
        if state.is_empty():continue
        if (state["target"] as Vector3).distance_to(
            state["origin"] as Vector3)>0.15:
            moved=actor
            break
    if moved==null:
        fail("No source GLB is advancing toward the combat front")
        return
    var state: Dictionary=moved.get_meta("interpolation_v63")
    var target: Vector3=state["target"]
    var base: Vector3=moved.position
    var model: Node3D=moved.get_child(0) as Node3D
    if model==null or not model.has_meta("source_glb"):
        fail("The original source GLB model was replaced")
        return
    var saved_city: String=JSON.stringify(ui.city)
    var last: Vector3=moved.position
    var distinct: int=0
    var pose_distinct: int=0
    var pose_last: Vector3=model.position
    for i in range(20):
        view._process(1.0/56.0)
        if moved.position.distance_to(last)>0.0001:distinct+=1
        if model.position.distance_to(pose_last)>0.0001:pose_distinct+=1
        last=moved.position
        pose_last=model.position
    if distinct<15 or pose_distinct<10:
        fail("Soldiers still move in 1-2 FPS steps or lack moving model poses")
        return
    var live_animator: Dictionary=model.get_meta("source_animator_v65",{})
    var live_player: AnimationPlayer=live_animator.get("player",null)
    if live_player==null or not live_player.is_playing():
        fail("Imported skeletal AnimationPlayer stops during soldier movement")
        return
    view._process(0.22)
    if moved.position.distance_to(target)<0.01 or \
            moved.position.distance_to(target)>base.distance_to(target)*0.55+0.05:
        fail("Movement freezes at the latest snapshot or predicts too far")
        return
    if JSON.stringify(ui.city)!=saved_city:
        fail("Render-frame pose/prediction changed the saved simulation")
        return
    view.set_auto_battle(false)
    view.set_battle(Battle.current(ui.city,ui.world_view.world))
    var display: Dictionary=moved.get_meta("interpolation_v63")
    if moved.position.distance_to(display["target"])>0.001:
        fail("Paused battle refuses to snap back to authoritative positions")
        return
    # V66 camera follows the rendered position of a selected living
    # soldier, while manual pan and full-battle reset cancel tracking.
    view._follow_selected_soldier()
    if view.follow_actor_key=="" or view.follow_button==null:
        fail("Cannot activate selected-soldier follow camera")
        return
    var tracked: Node3D=view.actors_root.get_node_or_null(
        view.follow_actor_key) as Node3D
    if tracked==null:
        fail("Follow camera lost the selected GLB actor")
        return
    var prior_camera: Vector3=view.battle_camera.position
    tracked.position+=Vector3(0.75,0,0.42)
    view._follow_soldier_frame()
    var camera_motion: Vector3=view.battle_camera.position-prior_camera
    if absf(camera_motion.x-0.75)>0.005 or \
            absf(camera_motion.z-0.42)>0.005:
        fail("Follow camera does not track actual visible soldier motion")
        return
    view._zoom_pan(Vector2(60,20))
    if view.follow_actor_key!="":
        fail("Manual pan cannot release follow camera")
        return
    view._follow_selected_soldier()
    view._reset_camera()
    if view.follow_actor_key!="" or absf(view.cam_size-175.0)>0.001:
        fail("Whole-battle reset failed to release tracking and full zoom")
        return
    print("BATTLE_MOTION_V65 SUCCESS: 96 imported skeletal GLB animations, poses and frame animation, zoom to 1.5m, wheel/pinch, soldier follow, manual pan and reset")
    quit(0)
