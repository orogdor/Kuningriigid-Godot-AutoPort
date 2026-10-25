extends SceneTree
## Check actual world + existing 0.5 city screen in headless Godot.
const Scene = preload("res://content.tscn")
const World = preload("res://scripts/world_gen_v06.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var screen: Control=Scene.instantiate()
    root.add_child(screen)
    await process_frame
    await process_frame
    var map: Control=screen.world_view
    if map==null or map.world.is_empty():
        printerr("WORLD_V06_UI failed to generate world")
        quit(1)
        return
    var grid: Dictionary=map.world
    if grid["cells"].size()!=World.COLS*World.ROWS or grid["starts"].size()!=4:
        printerr("WORLD_V06_UI wrong world size or missing starting nations")
        quit(1)
        return
    if int(grid["land_count"])<1500 or int(grid["river_count"])<5:
        printerr("WORLD_V06_UI missing usable land or rivers")
        quit(1)
        return
    for site in grid["starts"]:
        var cell: Dictionary=World.cell(grid,int(site["c"]),int(site["r"]))
        if not bool(cell.get("land",false)) or bool(cell.get("mountain",false)):
            printerr("WORLD_V06_UI spawn on impassable terrain")
            quit(1)
            return
    var checked: int=0
    for cell in grid["cells"]:
        if bool(cell.get("river",false)):
            if not World.river_reaches_sea(grid,int(cell["c"]),int(cell["r"])):
                printerr("WORLD_V06_UI disconnected watercourse: ",cell["c"],",",cell["r"])
                quit(1)
                return
            checked+=1
            if checked>=20:break
    map.map_canvas.select_cell(30,30)
    if map.selected_cell!=Vector2i(30,30):
        printerr("WORLD_V06_UI selection failed")
        quit(1)
        return
    screen._show_city()
    if not screen.city_scroll.visible or screen.world_view.visible:
        printerr("WORLD_V06_UI cannot open 0.5 city view")
        quit(1)
        return
    screen._show_world()
    if screen.city_scroll.visible or not screen.world_view.visible:
        printerr("WORLD_V06_UI cannot return to world view")
        quit(1)
        return
    print("WORLD_V06_UI SUCCESS: 220x165, four starts, selected tile, rivers and city screen")
    quit(0)
