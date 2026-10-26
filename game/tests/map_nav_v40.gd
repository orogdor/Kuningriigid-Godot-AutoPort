extends SceneTree
## AutoPort 0.40: 3D world is the default with a real height mesh.
## Detail arrows work on ALL neighboring world cells, including unowned.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const TerrainMap=preload("res://scripts/world_terrain_v40.gd")

func fail(reason: String) -> void:
    printerr("MAP_NAV_V40 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    var map=ui.world_view
    if map.terrain_3d==null or not map.terrain_3d.visible:
        fail("default world map is still a flat 2D canvas")
        return
    if map.map_canvas.visible:
        fail("legacy 2D canvas should only be the optional fallback")
        return
    if map.terrain_3d.terrain_node.mesh==null:
        fail("actual 3D continent relief mesh was not generated")
        return
    var bbox: AABB=map.terrain_3d.terrain_node.mesh.get_aabb()
    if bbox.size.x<World.COLS-2 or bbox.size.z<World.ROWS-2 or bbox.size.y<6.0:
        fail("3D mesh has no real elevation or is smaller than source map")
        return
    var scroll: ScrollContainer=map.find_child("WorldActionsScroll",true,false) as ScrollContainer
    if scroll==null or scroll.size.y>62.0:
        fail("world controls overlap small-screen map instead of scrolling horizontally")
        return
    var home: Vector2i=Districts.origin(map.world)
    map.select_world_cell(home.x,home.y)
    if map.terrain_3d.selected!=home or map.map_canvas.chosen!=home:
        fail("2D and 3D selections are not synchronized")
        return
    map._switch_mode()
    if not map.map_canvas.visible or map.terrain_3d.visible:
        fail("the 2D fallback toggle did not work")
        return
    map._switch_mode()
    if not map.terrain_3d.visible:
        fail("the 3D world was not restored")
        return
    ui._show_detail(home.x,home.y)
    if ui.detail_view.selected!=home:
        fail("capital detail could not be opened")
        return
    var controls: Array=[]
    for child in ui.detail_view.actions.get_children():
        if child is Button and String(child.text).begins_with("Kaart "):
            controls.append(child)
    if controls.size()!=4:
        fail("mobile detail toolbar lacks the four navigation arrows")
        return
    var target: Vector2i=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var adjacent: Vector2i=home+delta
        if not World.cell(map.world,adjacent.x,adjacent.y).is_empty():
            target=adjacent
            break
    if target.x<0:
        fail("no adjacent world tile for test")
        return
    ui.detail_view.neighbor_requested.emit(target.x,target.y)
    if ui.detail_view.selected!=target or map.selected_cell!=target:
        fail("detail arrow did not actually open a neighboring world tile")
        return
    if ui.detail_view.can_build:
        fail("unowned adjacent tile was granted capital building permissions")
        return
    var next: Vector2i=home
    ui.detail_view.neighbor_requested.emit(next.x,next.y)
    if ui.detail_view.selected!=home:
        fail("cannot return to home detail by normal navigation")
        return
    ui._show_world()
    if map.selected_cell!=home or not map.terrain_3d.visible:
        fail("returning from detail did not retain the current selected world cell")
        return
    var ocean_found: bool=false
    for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var neighbor: Vector2i=home+delta
        var cell: Dictionary=World.cell(map.world,neighbor.x,neighbor.y)
        if not cell.is_empty() and not bool(cell.get("land",false)):
            ui._show_detail(neighbor.x,neighbor.y)
            if ui.detail_view.selected!=neighbor or ui.detail_view.can_build:
                fail("water tile cannot be explored as non-buildable 3D view")
                return
            ocean_found=true
            break
    var before: Vector2i=ui.detail_view.selected
    ui.detail_view._navigate_neighbor(Vector2i(-9999,0))
    if ui.detail_view.selected!=before:
        fail("directional navigation did not reject out-of-bounds world cells")
        return
    print("MAP_NAV_V40 SUCCESS: real 3D continents and relief, 2D fallback, arrow traversal, unowned/ocean tiles, mobile toolbar, bounds")
    quit(0)
