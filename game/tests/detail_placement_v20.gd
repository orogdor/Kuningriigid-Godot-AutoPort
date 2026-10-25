extends SceneTree
## V0.20 regression: visible legal/blocked build grid, snapped placement,
## invalid attempt, cancel, resources, and return to an unowned tile.
const Screen=preload("res://content.tscn")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")

func fail(why: String) -> void:
    printerr("DETAIL_PLACEMENT_V20 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var home: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(home["c"]),int(home["r"]))
    await process_frame
    var detail: Control=ui.detail_view
    if not detail.can_build or detail.plot_root==null:
        fail("capital build view missing")
        return
    if detail.placement_label==null or detail.plot_root.get_node_or_null("BuildGridLine")==null:
        fail("neutral construction grid not visible")
        return
    var initial_count: int=ui.city["buildings"].size()
    var initial_stock: float=float(ui.city["realms"][0]["resources"]["wood"])
    detail.select_building("lumber")
    await process_frame
    var free: int=0
    var blocked: int=0
    for tile in detail.plot_root.get_children():
        if tile.name=="BuildPlotOpen":free+=1
        if tile.name=="BuildPlotBlocked":blocked+=1
    if free<5 or blocked<1 or detail.placement_marker==null:
        fail("legal green or forbidden red plots are not shown")
        return
    if not Spatial.can_place(ui.city,Vector2(30,-10)) or Spatial.can_place(ui.city,Vector2.ZERO):
        fail("test preconditions do not match placement rules")
        return
    detail._hover_ground(Vector3(34.6,0,-14.1))
    if detail.placement_cell!=Vector2(30,-10) or not detail.placement_marker.visible:
        fail("hover preview did not snap to 10m grid")
        return
    detail._hover_ground(Vector3.ZERO)
    var color: Color=(detail.placement_marker.material_override as StandardMaterial3D).albedo_color
    if color.r<0.85 or color.g>0.4:
        fail("blocked site was not marked in red")
        return
    detail._ground_clicked(Vector3.ZERO)
    if ui.city["buildings"].size()!=initial_count or not is_equal_approx(float(ui.city["realms"][0]["resources"]["wood"]),initial_stock):
        fail("invalid construction spent materials or created a building")
        return
    if detail.pending_build!="lumber":
        fail("invalid location cancelled placement unexpectedly")
        return
    detail._cancel_placement()
    await process_frame
    if detail.pending_build!="" or detail.placement_marker!=null:
        fail("cancel left a placement marker or an active building")
        return
    if ui.city["buildings"].size()!=initial_count:
        fail("cancel built something")
        return
    detail.select_building("lumber")
    detail._ground_clicked(Vector3(34.6,0,-14.1))
    await process_frame
    if ui.city["buildings"].size()!=initial_count+1:
        fail("legal snapped placement did not create exactly one building")
        return
    var built: Dictionary=ui.city["buildings"][initial_count]
    if not is_equal_approx(float(built["x"]),30.0) or not is_equal_approx(float(built["z"]),-10.0):
        fail("building location was not persisted on its snapped tile")
        return
    if float(ui.city["realms"][0]["resources"]["wood"])>=initial_stock or detail.pending_build!="":
        fail("successful construction did not charge materials or clear pending selection")
        return
    ui._show_detail(0,0)
    await process_frame
    if detail.can_build or detail.pending_build!="" or detail.placement_marker!=null:
        fail("unowned land retained editable construction overlay")
        return
    print("DETAIL_PLACEMENT_V20 SUCCESS: grid colors, preview, snapping, invalid cost, cancel, valid build, unowned tile")
    quit(0)
