extends SceneTree
## AutoPort 0.41: web V123 detail navigation parity regression.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Seam=preload("res://scripts/detail_web_navigation_v41.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")

func fail(reason: String) -> void:
    printerr("DETAIL_WEB_V41 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var crossing: Dictionary=Seam.crossing(Vector3(114.0,0,5.0))
    if crossing.get("delta",Vector2i.ZERO)!=Vector2i(1,0) or absf(crossing["focus"].x+111.0)>0.01:
        fail("east tile offset is not the original web 225m")
        return
    var diagonal: Dictionary=Seam.crossing(Vector3(-115.0,0,-102.0))
    if diagonal.get("delta",Vector2i.ZERO)!=Vector2i(-1,-1) or absf(diagonal["focus"].z-93.0)>0.01:
        fail("diagonal offset is not web's 225x195m")
        return
    if not Seam.crossing(Vector3.ZERO).is_empty():
        fail("center triggered spurious cross-tile movement")
        return
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var home: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(home.x,home.y)
    await process_frame
    if not ui.detail_view.combined_city and ui.detail_view.seam_preview_root.get_child_count()<3:
        fail("web-style 3x3 nearby terrain previews are missing")
        return
    var ctrl=ui.detail_view.controller
    if not ctrl.seam_enabled or ctrl.max_distance<450.0:
        fail("web-style edge and zoom navigation are not enabled")
        return
    # A single-finger or left-button pan translates the camera, not orbits.
    var look_before: Vector3=ctrl.look_at
    var yaw_before: float=ctrl.yaw
    ctrl.pan_pointer(Vector2(280,200),Vector2(260,200))
    if ctrl.look_at.distance_to(look_before)<0.005 or absf(ctrl.yaw-yaw_before)>0.001:
        fail("web-style pointer drag did not pan without orbiting")
        return
    var target:=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var candidate: Vector2i=home+delta
        if not World.cell(ui.world_view.world,candidate.x,candidate.y).is_empty():
            target=candidate
            break
    if target.x<0:
        fail("capital has no neighboring map square")
        return
    var step: Vector2i=target-home
    var bounds: Vector2=ctrl.seam_half
    var position:=Vector3(float(step.x)*(bounds.x+1.5),0.0,float(step.y)*(bounds.y+1.2))
    var expected: Vector3=Seam.crossing(position,bounds)["focus"]
    ctrl.distance=93.0
    ctrl.wheel_target=93.0
    ctrl.look_at=position
    ctrl.check_detail_boundary()
    await process_frame
    if ui.detail_view.selected!=target or ui.world_view.selected_cell!=target:
        fail("panning across the boundary did not open the adjacent tile")
        return
    if ctrl.look_at.distance_to(expected)>0.5 or absf(ctrl.distance-93.0)>0.2:
        fail("crossing reset the local camera focal point or zoom")
        return
    if ui.world_view.visible:
        fail("crossing detail boundary jumped out to world")
        return
    ctrl.distance=Seam.WORLD_ZOOM-1.0
    ctrl.wheel_target=ctrl.distance
    ctrl.zoom_out_step()
    await process_frame
    if not ui.world_view.visible or ui.detail_view.visible:
        fail("maximum outward zoom did not return to world map")
        return
    if not ui.world_view.terrain_3d.visible or ui.world_view.selected_cell!=target:
        fail("world map opened with wrong world tile or in 2D")
        return
    var focus: Vector2=ui.world_view.terrain_3d.camera_target
    if focus.distance_to(Vector2(float(target.x)+0.5,float(target.y)+0.5))>0.01:
        fail("world camera did not focus the tile just exited")
        return
    print("DETAIL_WEB_V41 SUCCESS: V123 edge/diagonal offsets, drag pan, zoom continuity, zoom-out to focused 3D world")
    quit(0)
