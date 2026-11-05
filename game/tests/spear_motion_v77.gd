extends SceneTree
## V77: regression for a rigid, complete V148 spear tip on the V262 rig and
## visually continuous soldiers while a large combat snapshot arrives.
const Scene=preload("res://content.tscn")
const Units=preload("res://scripts/web_units_v53.gd")
const Battle=preload("res://scripts/battle_v55.gd")
const Anims=preload("res://scripts/battle_animation_v65.gd")

func fail(message: String) -> void:
    printerr("SPEAR_MOTION_V77 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var soldier: Node3D=Units.instance("spearman",5.2,false,true)
    if soldier==null or not bool(soldier.get_meta("rigged_trellis_v73",false)):
        fail("Rigged TRELLIS spearman is missing")
        return
    root.add_child(soldier)
    var mesh_nodes: Array=soldier.find_children("*","MeshInstance3D",true,false)
    var intact: bool=false
    for node in mesh_nodes:
        var mesh: MeshInstance3D=node as MeshInstance3D
        if mesh.mesh==null or mesh.mesh.get_surface_count()<2:
            continue
        var spear: Array=mesh.mesh.surface_get_arrays(1)
        var points: PackedVector3Array=spear[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array=spear[Mesh.ARRAY_INDEX]
        if indices.size()<450:
            fail("Spear tip/shaft triangles were lost from the GLB")
            return
        var smallest: float=INF
        var largest: float=-INF
        for p in points:
            smallest=minf(smallest,p.z)
            largest=maxf(largest,p.z)
        if smallest>-.65 or largest<1.25:
            fail("Spear no longer spans butt to tip")
            return
        intact=true
    if not intact:
        fail("No intact spear surface on the current V262 warrior")
        return
    var animator_info: Dictionary={}
    var clips: Dictionary=Anims.available_clips(soldier)
    if not clips.has("attack"):
        fail("Spear lost imported hand attack animation")
        return
    animator_info=soldier.get_meta("source_animator_v65",{})
    var player: AnimationPlayer=animator_info.get("player",null)
    if player==null:
        fail("Spear rig has no animator")
        return
    player.play(String(clips["attack"]))
    player.advance(0.25)
    if not player.is_playing():
        fail("Attack clip no longer advances")
        return
    soldier.queue_free()
    await process_frame

    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_demo_battle()
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    var battle: Dictionary=Battle.current(ui.city,ui.world_view.world).duplicate(true)
    var candidate: Dictionary=battle["fighters"][0]
    var man: Dictionary=candidate["men"][0]
    var key: String="TacticalMan_%d_%d" % [
        int(candidate["id"]),int(man.get("index",0))]
    var actor: Node3D=view.actors_root.get_node_or_null(key) as Node3D
    if actor==null:
        fail("Live battle actor missing")
        return
    var origin: Vector3=actor.position
    # The old V76 code snapped whenever correction exceeded 12 metres.
    man["x"]=float(man["x"])+22.0
    battle["elapsed"]=float(battle["elapsed"])+0.2
    view.set_battle(battle)
    if actor.position.distance_to(origin)>0.0001:
        fail("Attack snapshot snapped visible soldier instantly")
        return
    view._render_soldier_motion_v65(1.0/60.0)
    var step: float=actor.position.distance_to(origin)
    if step>0.41 or step<=0.0:
        fail("Visible soldier did not interpolate with bounded movement: "+str(step))
        return
    print("SPEAR_MOTION_V77 SUCCESS: complete rigid spear tip, active attack, and no >12m combat teleport")
    quit(0)
