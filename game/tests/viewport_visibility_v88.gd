extends SceneTree
## V88: a hidden atlas or detail scene never consumes a continuously updating
## off-screen Godot SubViewport. Restoring the view resumes GPU rendering.
const Scene=preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("VIEWPORT_VISIBILITY_V88 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _mode(viewport: SubViewport) -> int:
    return int(viewport.render_target_update_mode)

func _run() -> void:
    root.size=Vector2i(800,560)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var map=ui.world_view
    var world_3d=map.terrain_3d
    var detail=ui.detail_view
    var world_viewport: SubViewport=world_3d.viewport
    var detail_viewport: SubViewport=detail.view_port
    if world_viewport==null or detail_viewport==null:
        fail("3D viewports not initialized")
        return
    var atlas_id: int=world_viewport.get_instance_id()
    var detail_id: int=detail_viewport.get_instance_id()
    ui._show_world()
    if _mode(world_viewport)!=SubViewport.UPDATE_ALWAYS or \
            _mode(detail_viewport)!=SubViewport.UPDATE_DISABLED:
        fail("3D atlas must render; hidden detail must sleep")
        return
    map._switch_mode()
    if _mode(world_viewport)!=SubViewport.UPDATE_DISABLED:
        fail("2D fallback left 3D atlas rendering in background")
        return
    map._switch_mode()
    if _mode(world_viewport)!=SubViewport.UPDATE_ALWAYS:
        fail("switching back to 3D did not restart atlas renderer")
        return
    var home: Dictionary=map.world["starts"][0]
    ui._show_detail(int(home["c"]),int(home["r"]))
    if _mode(world_viewport)!=SubViewport.UPDATE_DISABLED or \
            _mode(detail_viewport)!=SubViewport.UPDATE_ALWAYS:
        fail("opening detail did not hand rendering from atlas to detail")
        return
    ui._show_city()
    if _mode(world_viewport)!=SubViewport.UPDATE_DISABLED or \
            _mode(detail_viewport)!=SubViewport.UPDATE_DISABLED:
        fail("city economy still rendered an offscreen 3D viewport")
        return
    ui._show_world()
    if _mode(world_viewport)!=SubViewport.UPDATE_ALWAYS or \
            _mode(detail_viewport)!=SubViewport.UPDATE_DISABLED:
        fail("returning to atlas did not restore the expected viewport")
        return
    if world_viewport.get_instance_id()!=atlas_id or \
            detail_viewport.get_instance_id()!=detail_id:
        fail("view switching unnecessarily recreated 3D resources")
        return
    print("VIEWPORT_VISIBILITY_V88 SUCCESS: world, 2D, detail, city, resume, stable viewports")
    quit(0)
