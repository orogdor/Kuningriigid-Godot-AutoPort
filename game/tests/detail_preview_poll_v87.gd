extends SceneTree
## V87: preview polling is bounded, construction/traffic recipes are not
## reparsed from JSON on each camera frame, and the city is not changed.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")

func fail(reason: String) -> void:
    printerr("DETAIL_PREVIEW_POLL_V87 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui.world_view.fog_enabled_v80=false
    ui.world_view._apply_fog_v80()
    var home: Vector2i=Districts.origin(ui.world_view.world)
    var neighbor: Vector2i=home+Vector2i(1,0)
    if World.cell(ui.world_view.world,neighbor.x,neighbor.y).is_empty():
        fail("adjacent capital cell missing")
        return
    var stock: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    ui._show_detail(neighbor.x,neighbor.y)
    await process_frame
    var view=ui.detail_view
    if not view.visible or view.combined_city or view.seam_preview_root==null:
        fail("non-combined preview did not initialize")
        return
    if view.seam_preview_definitions_v87.is_empty():
        fail("static city recipe cache not populated")
        return
    view.set_process(false)
    view.seam_preview_refresh_clock=0.0
    view.performance_timer=0.0
    view._process(0.24)
    if absf(view.seam_preview_refresh_clock-0.24)>0.001:
        fail("preview refreshed before 0.5s")
        return
    view._process(0.24)
    if absf(view.seam_preview_refresh_clock-0.48)>0.001:
        fail("preview scanned more than twice per second")
        return
    view._process(0.05)
    if absf(view.seam_preview_refresh_clock)>0.001:
        fail("preview did not refresh at 0.5s")
        return
    view.seam_preview_definitions_v87["__v87_cache_probe"]=true
    view._refresh_seam_neighbor_buildings()
    if not view.seam_preview_definitions_v87.has("__v87_cache_probe"):
        fail("static JSON definitions were reparsed on refresh")
        return
    view.seam_preview_definitions_v87.erase("__v87_cache_probe")
    if ui.city["realms"][0]["resources"]!=stock:
        fail("preview redraw altered real city resources")
        return
    print("DETAIL_PREVIEW_POLL_V87 SUCCESS: 2Hz neighbor scan, cached recipes, preserved city")
    quit(0)
