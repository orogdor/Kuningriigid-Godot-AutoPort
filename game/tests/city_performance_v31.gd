extends SceneTree
## 0.31: deterministic draw-call reduction, adaptive resolution hysteresis,
## cached static detail UI and actual on-device stats. This HEADLESS test does
## not claim a physical-phone FPS number (GPU profiling is device-specific).
const Screen=preload("res://content.tscn")
const Batch=preload("res://scripts/city_render_batch_v31.gd")
const Perf=preload("res://scripts/city_performance_v31.gd")

func fail(why: String) -> void:
    printerr("CITY_PERFORMANCE_V31 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var sites: Array=[]
    for i in range(60):
        sites.append({"id":i,"kind":"wood" if i%2==0 else "stone",
            "remaining":35.0,"x":float((i%10)*9)-40.0,
            "z":float((i/10)*9)-25.0})
    var tree: Node3D=Node3D.new()
    root.add_child(tree)
    var drawn: int=Batch.populate(tree,sites,60)
    if drawn!=60 or tree.get_child_count()!=3:
        fail("60 resource deposits should use only three render batches")
        return
    var amount: int=0
    var meshes: Dictionary={}
    for group in tree.get_children():
        if not group is MultiMeshInstance3D:
            fail("batch is not backed by Godot MultiMesh")
            return
        var cluster: MultiMeshInstance3D=group
        amount+=cluster.multimesh.instance_count
        meshes[String(cluster.name)]=cluster.multimesh.instance_count
        if cluster.multimesh.mesh==null:
            fail("render batch has no source mesh")
            return
    if meshes.get("BatchTrunks",-1)!=30 or meshes.get("BatchFoliage",-1)!=30 or meshes.get("BatchRocks",-1)!=90:
        fail("tree and triple-rock instance counts are incorrect")
        return
    if amount!=150 or Batch.node_count(tree)!=4:
        fail("batch node counts or actual mesh instances are incorrect")
        return
    var budget: Dictionary=Perf.estimate_draw_reduction(30,30)
    if int(budget["old_meshes"])!=150 or int(budget["batched_draws"])!=3 or int(budget["saved_draws"])!=147:
        fail("draw-call budget assumes a fabricated number of resource meshes")
        return
    var measured: int=Batch.draw_units_for(sites,60)
    if measured!=3 or Batch.draw_units_for(sites,0)!=0:
        fail("real batch material count differs from estimated draw units")
        return
    if Batch.signature(sites,60)==Batch.signature(sites,4):
        fail("distance-based resource detail has no stable signature")
        return
    # Source resource state is immutable. Drawing never mines/consumes it.
    if not is_equal_approx(float(sites[0]["remaining"]),35.0):
        fail("render batching altered the actual finite resources")
        return
    var step: Dictionary={"level":2,"low":0,"high":0}
    for i in range(2):
        step=Perf.next_quality(19.0,step)
    if int(step["level"])!=2:
        fail("render resolution drops before sustained low-FPS threshold")
        return
    step=Perf.next_quality(19.0,step)
    if int(step["level"])!=1:
        fail("low FPS hysteresis did not lower resolution")
        return
    step=Perf.next_quality(40.0,step)
    if int(step["level"])!=1 or int(step["low"])!=0:
        fail("middle FPS did not stop degradation")
        return
    for i in range(5):
        step=Perf.next_quality(60.0,step)
    if int(step["level"])!=2:
        fail("sustained high FPS did not restore detail")
        return
    for i in range(20):
        step=Perf.next_quality(60.0,step)
    if int(step["level"])!=2:
        fail("quality exceeded maximum after sustained high FPS")
        return
    if Perf.viewport_size(0)!=Vector2i(600,375) or Perf.viewport_size(1)!=Vector2i(720,450) or Perf.viewport_size(2)!=Vector2i(960,600):
        fail("quality tiers do not map to expected stable viewport resolutions")
        return
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var home: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(home["c"]),int(home["r"]))
    await process_frame
    var detail: Control=ui.detail_view
    var resource_parent: Node3D=detail.resource_root
    if detail.view_port==null or detail.performance_label==null:
        fail("no live 3D performance telemetry or viewport found")
        return
    var resource_nodes: int=resource_parent.get_child_count()
    if resource_nodes>3:
        fail("active 3D resources still use a node per rock/tree")
        return
    var site_signature: String=String(resource_parent.get_meta("resource_key",""))
    var retained_meshes: Array=resource_parent.get_children().duplicate()
    var base_grid: Node=detail.plot_root.get_child(0)
    var start_builds: int=detail.active_building_mesh_builds
    detail.refresh_buildings()
    detail.refresh_buildings()
    if String(resource_parent.get_meta("resource_key",""))!=site_signature:
        fail("same resource sites unexpectedly changed renderer cache key")
        return
    if detail.active_building_mesh_builds!=start_builds:
        fail("unchanged houses were reconstructed across two economy refreshes")
        return
    if detail.plot_root.get_child(0)!=base_grid:
        fail("idle construction grid was recreated on each economy tick")
        return
    if resource_parent.get_child_count()!=resource_nodes:
        fail("same resource cluster created extra nodes on every tick")
        return
    for instance in retained_meshes:
        if not is_instance_valid(instance):
            fail("stable resource MultiMesh was destroyed between unchanged ticks")
            return
    detail.performance_enabled=true
    detail.performance_label.visible=true
    detail._process(1.2)
    var stats: Dictionary=detail.performance_last
    if not stats.has("draw_calls") or not stats.has("scene_nodes") or not stats.has("fps"):
        fail("on-device FPS and draw-call metrics were not recorded")
        return
    if int(stats["scene_nodes"])<4:
        fail("live 3D scene node counter returned no meaningful nodes")
        return
    if detail.performance_label.text.find("FPS")<0:
        fail("performance overlay failed to show telemetry")
        return
    print("CITY_PERFORMANCE_V31 SUCCESS: 150 instances in 3 draw groups, 147 theoretical calls saved, adaptive 3/5s hysteresis, cached real scene, visible FPS telemetry")
    quit(0)
