extends SceneTree
## 0.45 web-like detail panning upgrades real saved neighbor buildings to
## exactly the same geometry as the active city, then backs off to LOD.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Models=preload("res://scripts/detail_neighbor_buildings_v45.gd")

func fail(reason: String) -> void:
    printerr("DETAIL_BUILDINGS_V45 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var neighbor: Vector2i=home+Vector2i(1,0)
    if World.cell(world,neighbor.x,neighbor.y).is_empty():
        fail("missing adjacent map tile")
        return
    var saved_buildings: Array=ui.city["buildings"].duplicate(true)
    var saved_stock: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    ui._show_detail(neighbor.x,neighbor.y)
    await process_frame
    var detail=ui.detail_view
    var camera=detail.controller
    var ground: Node3D=detail.seam_preview_root.get_node_or_null(
        "DetailNeighbor_-1_0") as Node3D
    if ground==null:
        fail("adjacent capital terrain preview is missing")
        return
    var cluster: Node3D=ground.get_node_or_null("ActualNeighborBuildings") as Node3D
    if cluster==null or bool(cluster.get_meta("full_3d",true)):
        fail("opening distant neighbor no longer starts in cheap instanced LOD")
        return
    var batches: int=0
    for child in cluster.get_children():
        if child is MultiMeshInstance3D:
            batches+=1
    if batches<1:
        fail("background geometry is not batched")
        return
    var original_yaw: float=camera.yaw
    var original_zoom: float=camera.distance
    # Move toward the home tile without crossing yet: the detailed view
    # should pre-warm actual house meshes on the same side of the seam.
    camera.look_at=Vector3(-90,0,0)
    detail._refresh_seam_neighbor_buildings()
    cluster=ground.get_node_or_null("ActualNeighborBuildings") as Node3D
    if cluster==null or not bool(cluster.get_meta("full_3d",false)):
        fail("nearby home city did not switch to original detailed geometry")
        return
    var hall: Node3D=cluster.get_node_or_null("hall_0") as Node3D
    if hall==null or hall.get_node_or_null("HallWalls")==null:
        fail("neighbor was rendered as a box instead of actual hall walls")
        return
    if absf(hall.position.x-float(ui.city["buildings"][0].get("x",0.0)))>0.01:
        fail("actual detail preview lost saved building coordinates")
        return
    var stable: Node3D=cluster
    detail._refresh_seam_neighbor_buildings()
    if cluster!=ground.get_node_or_null("ActualNeighborBuildings"):
        fail("unchanged building meshes rebuilt on every camera update")
        return
    # A new real construction site must appear as the same stages/scaffold
    # as in capital, not as a finished house silhouette.
    ui.city["buildings"].append({"type":"house","x":30.0,"z":-10.0,
        "rotation":90,"ready":false,"hp":100.0,"progress":0.0})
    detail._refresh_seam_neighbor_buildings()
    cluster=ground.get_node_or_null("ActualNeighborBuildings") as Node3D
    var house: Node3D=cluster.get_node_or_null("house_1") as Node3D
    if house==null or house.get_node_or_null("Stage0Foundation")==null:
        fail("live unfinished building did not show construction foundation")
        return
    var before_snap: String=String(cluster.get_meta("render_key",""))
    ui.city["buildings"].back()["progress"]=0.45
    detail._refresh_seam_neighbor_buildings()
    cluster=ground.get_node_or_null("ActualNeighborBuildings") as Node3D
    if String(cluster.get_meta("render_key",""))==before_snap:
        fail("construction progress failed to refresh real neighboring 3D model")
        return
    # Preserve only registered game state: no free building or economy update
    # is allowed from refreshing visual previews.
    ui.city["buildings"]=saved_buildings
    detail._refresh_seam_neighbor_buildings()
    if ui.city["realms"][0]["resources"]!=saved_stock:
        fail("camera-facing neighbor render altered city resources")
        return
    if not is_equal_approx(camera.yaw,original_yaw) or \
            not is_equal_approx(camera.distance,original_zoom):
        fail("LOD swaps altered web camera orientation or zoom")
        return
    camera.look_at=Vector3.ZERO
    detail._refresh_seam_neighbor_buildings()
    cluster=ground.get_node_or_null("ActualNeighborBuildings") as Node3D
    if cluster==null or bool(cluster.get_meta("full_3d",true)):
        fail("zooming away from near neighbors failed to release detail meshes")
        return
    # Dense towns must keep a bounded number of active meshes on Android.
    if Models.detailed(100,76,Models.MAX_DETAILED_BUILDINGS+1):
        fail("dense-town mobile GPU budget was bypassed")
        return
    print("DETAIL_BUILDINGS_V45 SUCCESS: LOD/full original city meshes switch by camera focus; staged construction; no duplicate or resource grants; mobile GPU budget")
    quit(0)
