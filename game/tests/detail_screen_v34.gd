extends SceneTree
## 0.34 regression: actual landscape-sized 3D viewport must retain its
## screen area regardless of economic text or the number of action buttons.
## Both old one-tile and multi-tile terrain must be a visible, colored mesh.
const Screen=preload("res://content.tscn")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(reason: String) -> void:
    printerr("DETAIL_SCREEN_V34 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _assert_ground(view: Control,min_width: float) -> bool:
    var ground: MeshInstance3D=view.scene_root.get_node_or_null("DetailTerrain") as MeshInstance3D
    if ground==null or ground.mesh==null or ground.mesh.get_surface_count()<1:
        fail("3D terrain mesh is missing from the opened detail view")
        return false
    var dimensions: Vector3=ground.mesh.get_aabb().size
    if dimensions.x<min_width or dimensions.z<min_width*0.8:
        fail("terrain surface is too small to display beneath the buildings")
        return false
    var mat: StandardMaterial3D=ground.material_override as StandardMaterial3D
    if mat==null or mat.cull_mode!=BaseMaterial3D.CULL_DISABLED or mat.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:
        fail("generated terrain cannot be rendered reliably on the Android compatibility renderer")
        return false
    var arrays: Array=ground.mesh.surface_get_arrays(0)
    var normal_array: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    if normal_array.is_empty() or normal_array[0].dot(Vector3.UP)<0.6:
        fail("terrain triangles are facing away from the 3D camera")
        return false
    if not ground.is_visible_in_tree():
        fail("terrain is hidden despite an active detail camera")
        return false
    return true

func _test() -> void:
    root.size=Vector2i(720,420)
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
    var view: Control=ui.detail_view
    if view.controller==null or view.controller.size.y<180.0:
        fail("the detail 3D viewport was pushed off a 720x420 landscape screen")
        return
    var scroll: ScrollContainer=view.find_child("DetailActionsScroll",true,false) as ScrollContainer
    if scroll==null or scroll.size.y>60.0:
        fail("action buttons do not stay in one short horizontal scroll strip")
        return
    if view.info.autowrap_mode!=TextServer.AUTOWRAP_OFF or not view.info.clip_text:
        fail("long city economy status still consumes several landscape rows")
        return
    if view.placement_label.autowrap_mode!=TextServer.AUTOWRAP_OFF:
        fail("building instructions wrap over the gameplay area")
        return
    if not _assert_ground(view,190.0):return
    var camera: Camera3D=view.controller.orbit_camera
    if camera==null or camera.is_position_behind(Vector3.ZERO):
        fail("3D ground center is behind the installed detail camera")
        return
    var center: Vector2=camera.unproject_position(Vector3.ZERO)
    if center.x<0.0 or center.y<0.0 or center.x>view.view_port.size.x or center.y>view.view_port.size.y:
        fail("detail camera ground center is outside its render target")
        return
    var first_height: float=view.controller.size.y
    var city: Dictionary=ui.city
    var original_buildings: Array=city["buildings"].duplicate(true)
    for i in range(70):
        city["buildings"].append({"type":"house","ready":false,
            "priority":"normal","hp":100.0,"x":float(i%10),"z":float(i%8)})
    view._refresh_actions()
    await process_frame
    await process_frame
    if view.actions.get_child_count()<65:
        fail("test did not add enough construction controls to stress the toolbar")
        return
    if scroll.size.y>60.0 or view.controller.size.y<first_height-10.0:
        fail("many priority buttons expanded over the 3D terrain")
        return
    city["buildings"]=original_buildings
    var adjacent: Vector2i=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var p: Vector2i=home+delta
        var cell: Dictionary=World.cell(world,p.x,p.y)
        if not cell.is_empty() and bool(cell.get("land",false)):
            adjacent=p
            break
    if adjacent.x>=0:
        city["districts_v25"]={"seed":int(world["seed"]),
            "tiles":[{"c":adjacent.x,"r":adjacent.y}]}
        Transit.configure(city,world)
        ui._show_detail(home.x,home.y)
        await process_frame
        await process_frame
        if not view.combined_city:
            fail("merged city was not rendered after annexing a neighboring tile")
            return
        if not _assert_ground(view,155.0):return
        var district: String=Districts.key(adjacent)
        var part: Node3D=view.combined_root.get_node_or_null("DistrictTile_"+district.replace(":","_")) as Node3D
        if part==null:
            fail("neighboring district land vanished when opening the complete 3D city")
            return
        var next_ground: MeshInstance3D=part.get_node_or_null("DistrictTerrain") as MeshInstance3D
        if next_ground==null or next_ground.mesh==null:
            fail("second 160m district has no terrain mesh")
            return
    print("DETAIL_SCREEN_V34 SUCCESS: 720x420 viewport, single-row priority toolbar, visible camera-facing 3D terrain and adjacent district")
    quit(0)
