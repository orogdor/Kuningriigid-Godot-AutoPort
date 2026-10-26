extends SceneTree
## Regression for user-reported "oversized detail UI" and "terrain invisible".
## Tests both legacy capital and contiguous 3D annex surface geometry.
const Screen=preload("res://content.tscn")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(message: String) -> void:
    printerr("DETAIL_UI_TERRAIN_V34 FAIL: "+message)
    quit(1)

func _check_ground(detail: Control,combined: bool) -> bool:
    var surface: MeshInstance3D=detail.scene_root.get_node_or_null("DetailTerrain") as MeshInstance3D
    if surface==null or surface.mesh==null:return false
    if surface.mesh.get_surface_count()!=1:return false
    var vertices: PackedVector3Array=surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if vertices.size()<120:return false
    var dims: Vector3=surface.mesh.get_aabb().size
    if dims.x<150.0 or dims.z<150.0:return false
    if not surface.visible or not surface.is_visible_in_tree():return false
    var material: StandardMaterial3D=surface.material_override as StandardMaterial3D
    if material==null:return false
    if material.cull_mode!=BaseMaterial3D.CULL_DISABLED:return false
    if material.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:return false
    if combined:
        if absf(dims.x-160.0)>0.1 or absf(dims.z-160.0)>0.1:return false
    else:
        if absf(dims.x-225.0)>0.1 or absf(dims.z-195.0)>0.1:return false
    return true

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    ui._show_detail(home.x,home.y)
    await process_frame
    await process_frame
    var detail: Control=ui.detail_view
    if not _check_ground(detail,false):
        fail("legacy capital terrain geometry, material or visible render surface is missing")
        return
    var toolbar: ScrollContainer=detail.find_child("DetailActionsScroll",true,false) as ScrollContainer
    if toolbar==null or not detail.actions is HBoxContainer:
        fail("detail actions still wrap onto many rows and cover the terrain")
        return
    if toolbar.custom_minimum_size.y>55.0 or toolbar.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED:
        fail("bottom toolbar consumes excessive 3D screen height")
        return
    if not detail.info.clip_text or detail.info.autowrap_mode!=TextServer.AUTOWRAP_OFF:
        fail("unbounded economic diagnostics can push the 3D canvas off-screen")
        return
    if detail.performance_label.visible:
        fail("permanent FPS overlay is stealing space from the default mobile 3D canvas")
        return
    # A long list of unfinished buildings produces priority buttons.
    # They may scroll horizontally but must never increase toolbar height.
    for i in range(25):
        ui.city["buildings"].append({"type":"house","x":float((i%5)*15-32),
            "z":float((i/5)*14-30),"ready":false,"progress":0,
            "hp":100.0,"priority":"normal"})
    detail._refresh_actions()
    await process_frame
    if toolbar.size.y>70.0:
        fail("many priority buttons made mobile bottom action bar taller")
        return
    if get_viewport().size.y>450 and detail.controller.size.y<float(get_viewport().size.y)*0.45:
        fail("3D detail viewport does not retain enough of landscape screen")
        return
    # Reopening an existing detail tile must never leave old queued terrain
    # behind, masking new terrain or changing DetailTerrain node identity.
    detail.open_tile(world,home.x,home.y,ui.city,true)
    await process_frame
    var terrain_nodes: int=0
    for node in detail.scene_root.get_children():
        if String(node.name).begins_with("DetailTerrain"):terrain_nodes+=1
    if terrain_nodes!=1 or not _check_ground(detail,false):
        fail("reopening a tile created duplicate or invisible terrain")
        return
    var next: Vector2i=home+Vector2i(1,0)
    if next.x>=World.COLS:next=home+Vector2i(-1,0)
    if next.x<0 or next.x>=World.COLS:
        fail("world fixture lacks horizontal adjacent tile")
        return
    var city: Dictionary=ui.city
    world["cells"][next.y*World.COLS+next.x]["land"]=true
    world["cells"][next.y*World.COLS+next.x]["biome"]="plains"
    city["districts_v25"]={"seed":int(world.get("seed",0)),
        "tiles":[{"c":next.x,"r":next.y}]}
    Transit.configure(city,world)
    detail.open_tile(world,home.x,home.y,city,true)
    await process_frame
    if not detail.combined_city or not _check_ground(detail,true):
        fail("expanded city combined 160m terrain was not drawn")
        return
    var neighbor: Node3D=detail.combined_root.get_node_or_null(
        "DistrictTile_"+Districts.key(next).replace(":","_")) as Node3D
    var adjacent: MeshInstance3D=neighbor.get_node_or_null("DistrictTerrain") as MeshInstance3D if neighbor!=null else null
    if adjacent==null or adjacent.mesh==null:
        fail("annexed district ground absent from contiguous city view")
        return
    var mat: StandardMaterial3D=adjacent.material_override as StandardMaterial3D
    if mat==null or mat.cull_mode!=BaseMaterial3D.CULL_DISABLED:
        fail("annexed terrain is still backface-culled on mobile renderers")
        return
    print("DETAIL_UI_TERRAIN_V34 SUCCESS: compact single-row UI, full-height 3D, two-sided 225m/160m ground, no duplicate terrain")
    quit(0)
