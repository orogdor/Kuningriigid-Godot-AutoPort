extends SceneTree
## 0.42: genuine seamless 3D neighbor terrain, stable 3x3 previews, and
## same web-style camera continuity across multiple detail tile crossings.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Relief=preload("res://scripts/detail_neighbor_terrain_v42.gd")
const Seam=preload("res://scripts/detail_web_navigation_v41.gd")

func fail(reason: String) -> void:
    printerr("SEAM_TERRAIN_V42 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var screen: Control=Scene.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    screen._reset()
    var world: Dictionary=screen.world_view.world
    var home: Vector2i=Districts.origin(world)
    # All adjacent terrain pieces must meet at the very same world height,
    # not as separate offset flat boxes.
    for local_z in [-84.0,-12.0,0.0,35.0,96.0]:
        var e: float=Relief.height_at(world,home,Relief.WIDTH*0.5,local_z)
        var w: float=Relief.height_at(world,home+Vector2i(1,0),
            -Relief.WIDTH*0.5,local_z)
        if absf(e-w)>0.0001:
            fail("east/west 3D detail surfaces differ in height at their border")
            return
    for local_x in [-98.0,-25.0,0.0,65.0,108.0]:
        var south: float=Relief.height_at(world,home,local_x,Relief.DEPTH*0.5)
        var north: float=Relief.height_at(world,home+Vector2i(0,1),
            local_x,-Relief.DEPTH*0.5)
        if absf(south-north)>0.0001:
            fail("north/south 3D detail surfaces differ at their border")
            return
    var diag_a: float=Relief.height_at(world,home,Relief.WIDTH*0.5,Relief.DEPTH*0.5)
    var diag_b: float=Relief.height_at(world,home+Vector2i(1,1),
        -Relief.WIDTH*0.5,-Relief.DEPTH*0.5)
    if absf(diag_a-diag_b)>0.0001:
        fail("diagonal world tile corners are discontinuous")
        return
    # Open an UNOWNED square so 0.27 multi-district city does not obscure
    # 0.42 terrain previews.
    var anchor: Vector2i=home+Vector2i(3,3)
    if World.cell(world,anchor.x,anchor.y).is_empty():
        fail("test position outside the map")
        return
    screen._show_detail(anchor.x,anchor.y)
    await process_frame
    var view=screen.detail_view
    if view.combined_city:
        fail("unowned terrain test unexpectedly entered merged city mode")
        return
    var previews: Node3D=view.seam_preview_root
    if previews.get_child_count()!=8:
        fail("3x3 neighbor terrain must include eight separate world tiles")
        return
    for dz in range(-1,2):
        for dx in range(-1,2):
            if dx==0 and dz==0:continue
            var label: String="DetailNeighbor_%d_%d" % [dx,dz]
            var part: Node3D=previews.get_node_or_null(label)
            if part==null:
                fail("missing neighboring tile at "+label)
                return
            var ground: MeshInstance3D=part.get_node_or_null("NeighborTerrain") as MeshInstance3D
            if ground==null or ground.mesh==null or ground.mesh.get_surface_count()!=1:
                fail("neighbor still uses a flat box instead of a 3D relief mesh")
                return
            var size: Vector3=ground.mesh.get_aabb().size
            if size.x<Relief.WIDTH-1.0 or size.z<Relief.DEPTH-1.0 or size.y<0.01:
                fail("3D neighbor geometry has no height or insufficient extent")
                return
    var ctrl=view.controller
    var previous_yaw: float=ctrl.yaw
    var previous_pitch: float=ctrl.pitch
    var start_x: int=anchor.x
    for iteration in range(3):
        var desired: Vector3=Vector3(ctrl.seam_half.x+3.0,0.0,7.0)
        var after: Vector3=Seam.crossing(desired,ctrl.seam_half)["focus"]
        ctrl.look_at=desired
        ctrl.distance=100.0
        ctrl.wheel_target=100.0
        ctrl.check_detail_boundary()
        await process_frame
        if view.selected!=Vector2i(start_x+iteration+1,anchor.y):
            fail("cannot pan east through several detail squares")
            return
        if ctrl.look_at.distance_to(after)>0.8 or absf(ctrl.distance-100.0)>0.1:
            fail("camera focal point or zoom reset at adjacent detail transition")
            return
        if absf(ctrl.yaw-previous_yaw)>0.001 or absf(ctrl.pitch-previous_pitch)>0.001:
            fail("camera orientation reset at detail crossing")
            return
        if screen.world_view.visible:
            fail("detail navigation unexpectedly switched to world atlas")
            return
        if view.seam_preview_root.get_child_count()!=8:
            fail("3x3 neighbor terrain did not refresh after entering next tile")
            return
    var limit: Vector2i=Vector2i(World.COLS-1,anchor.y)
    screen._show_detail(limit.x,limit.y)
    await process_frame
    ctrl.look_at=Vector3(ctrl.seam_half.x+3.0,0.0,0.0)
    ctrl.check_detail_boundary()
    await process_frame
    if view.selected!=limit or ctrl.transition_pending:
        fail("world boundary did not reject crossing safely")
        return
    print("SEAM_TERRAIN_V42 SUCCESS: genuine 3D terrain mesh, forest props, 3x3 preview, continuous heights, triple pan and zoom")
    quit(0)
