extends SceneTree
## 0.7 integration smoke: actual 3D geometry, map selection, city build,
## saved city resources and return to world map.
const View = preload("res://content.tscn")

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var screen: Control=View.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    if screen.world_view==null or screen.world_view.world.is_empty():
        printerr("DETAIL_V07 failed to load world")
        quit(1)
        return
    screen._reset()
    var home: Dictionary=screen.world_view.world["starts"][0]
    var c: int=int(home["c"])
    var r: int=int(home["r"])
    screen.world_view.map_canvas.select_cell(c,r)
    screen.world_view.open_selected_detail()
    await process_frame
    if screen.detail_view==null or not screen.detail_view.visible:
        printerr("DETAIL_V07 selection did not open detail scene")
        quit(1)
        return
    var detail: Control=screen.detail_view
    if detail.selected!=Vector2i(c,r) or not detail.can_build:
        printerr("DETAIL_V07 capital tile validation failed")
        quit(1)
        return
    if detail.scene_root==null or detail.scene_root.get_node_or_null("DetailTerrain")==null:
        printerr("DETAIL_V07 lacks actual Godot 3D terrain")
        quit(1)
        return
    if detail.rendered_buildings!=1:
        printerr("DETAIL_V07 starting hall not visible")
        quit(1)
        return
    var initial_stock: float=float(screen.city["realms"][0]["resources"]["wood"])
    screen._build("lumber")
    await process_frame
    if screen.city["buildings"].size()!=2 or detail.rendered_buildings!=2:
        printerr("DETAIL_V07 building added to economy but absent from 3D view")
        quit(1)
        return
    if float(screen.city["realms"][0]["resources"]["wood"])>=initial_stock:
        printerr("DETAIL_V07 lumber building failed to spend actual resources")
        quit(1)
        return
    screen._advance(10)
    await process_frame
    if int(screen.city["time"])!=600 or not bool(screen.city["buildings"][1]["ready"]):
        printerr("DETAIL_V07 construction not completed after economy ticks")
        quit(1)
        return
    if not FileAccess.file_exists("user://autoport_city_v05.json"):
        printerr("DETAIL_V07 missing persistent city save")
        quit(1)
        return
    screen._show_world()
    if screen.detail_view.visible or not screen.world_view.visible:
        printerr("DETAIL_V07 return-to-map failed")
        quit(1)
        return
    screen._show_detail(0,0)
    await process_frame
    if detail.can_build:
        printerr("DETAIL_V07 incorrectly allows construction outside own capital")
        quit(1)
        return
    print("DETAIL_V07_UI SUCCESS: 3D terrain, hall, construction, economy, save, camera view and map return")
    quit(0)
