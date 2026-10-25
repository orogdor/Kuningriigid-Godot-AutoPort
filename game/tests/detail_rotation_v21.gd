extends SceneTree
## Godot 0.21: actual transparent 3D building ghost, compass rotation,
## successful placement, JSON persistence and 0.20 legacy build calls.
const Screen=preload("res://content.tscn")

func fail(why: String) -> void:
    printerr("DETAIL_ROTATION_V21 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var capital: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(capital["c"]),int(capital["r"]))
    await process_frame
    var detail: Control=ui.detail_view
    if detail.rendered_buildings!=1:
        fail("old town hall was not rendered")
        return
    var legacy_hall: Node3D=detail.construction_root.get_node_or_null("hall_0") as Node3D
    if legacy_hall==null or not is_equal_approx(legacy_hall.rotation_degrees.y,0.0):
        fail("legacy hall without rotation lost its default direction")
        return
    var original: float=float(ui.city["realms"][0]["resources"]["wood"])
    detail.select_building("lumber")
    if detail.placement_ghost==null or not detail.placement_ghost.visible:
        fail("mobile touch preview did not appear before the first tap")
        return
    detail._hover_ground(Vector3(30.0,0.0,-10.0))
    if detail.placement_ghost==null or detail.placement_ghost.get_child_count()<4:
        fail("lumber model was not shown in the ghost preview")
        return
    if detail.placement_ghost_material==null or detail.placement_ghost_material.transparency!=BaseMaterial3D.TRANSPARENCY_ALPHA:
        fail("building ghost was not transparent")
        return
    if not detail.placement_ghost.visible:
        fail("hover did not make building ghost visible")
        return
    if not is_equal_approx(float(ui.city["realms"][0]["resources"]["wood"]),original):
        fail("viewing the preview charged for a building")
        return
    detail._rotate_placement(90)
    if detail.placement_rotation!=90 or not is_equal_approx(detail.placement_ghost.rotation_degrees.y,90.0):
        fail("clockwise 90-degree preview rotation failed")
        return
    detail._rotate_placement(90)
    detail._rotate_placement(90)
    detail._rotate_placement(90)
    if detail.placement_rotation!=0:
        fail("rotation did not wrap at 360 degrees")
        return
    detail._rotate_placement(-90)
    if detail.placement_rotation!=270:
        fail("counterclockwise rotation did not normalize to 270 degrees")
        return
    detail._ground_clicked(Vector3.ZERO)
    if detail.pending_build!="lumber" or ui.city["buildings"].size()!=1 or detail.placement_rotation!=270:
        fail("invalid tile created a building or reset rotation")
        return
    detail._ground_clicked(Vector3(30.0,0.0,-10.0))
    await process_frame
    if ui.city["buildings"].size()!=2:
        fail("legal placement failed")
        return
    var built: Dictionary=ui.city["buildings"][1]
    if int(built.get("rotation",-1))!=270 or not is_equal_approx(float(built["x"]),30.0):
        fail("building did not persist normalized direction and position")
        return
    if float(ui.city["realms"][0]["resources"]["wood"])>=original:
        fail("successful build did not debit resources")
        return
    var holder: Node3D=detail.construction_root.get_node_or_null("lumber_1") as Node3D
    if holder==null or not is_equal_approx(holder.rotation_degrees.y,270.0):
        fail("3D construction scaffold did not rotate")
        return
    var loaded: Dictionary=ui._load_city()
    if int(loaded["buildings"][1].get("rotation",-1))!=270:
        fail("rotation was not saved to persistent JSON")
        return
    detail.select_building("house")
    if detail.placement_ghost==null or detail.placement_ghost.get_node_or_null("HouseDoor")==null:
        fail("house preview reused the wrong 3D model")
        return
    detail._cancel_placement()
    if detail.placement_ghost!=null or detail.pending_build!="" or detail.placement_rotation!=0:
        fail("cancel left model preview or stale rotation")
        return
    # Old 3-argument build integration remains valid with a zero orientation.
    ui._build_at("house",-30.0,-10.0)
    await process_frame
    if ui.city["buildings"].size()!=3 or int(ui.city["buildings"][2].get("rotation",-1))!=0:
        fail("legacy construction call no longer has a default 0-degree orientation")
        return
    # A restored state with no orientation fields displays old homes normally.
    ui.city["buildings"][1].erase("rotation")
    detail.refresh_buildings()
    await process_frame
    var old_holder: Node3D=detail.construction_root.get_node_or_null("lumber_1") as Node3D
    if old_holder==null or not is_equal_approx(old_holder.rotation_degrees.y,0.0):
        fail("legacy loaded building did not fall back to 0 degrees")
        return
    print("DETAIL_ROTATION_V21 SUCCESS: model ghost, quarter turns, blocked tile, 3D model, save, old builds")
    quit(0)
