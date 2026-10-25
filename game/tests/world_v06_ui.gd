extends SceneTree
## Check actual world + existing 0.5 city screen in headless Godot.
const Scene = preload("res://content.tscn")
const World = preload("res://scripts/world_gen_v06.gd")

func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
    var event:=InputEventScreenTouch.new()
    event.index=index
    event.position=position
    event.pressed=pressed
    return event

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
    # Synthetic Android touch events: pinch should zoom at the midpoint
    # without selecting a map tile, then the next single tap still works.
    var canvas: Control=map.map_canvas
    canvas.size=Vector2(900,640)
    canvas.fit_to_view()
    var selected_before: Vector2i=map.selected_cell
    var initial_zoom: float=canvas.zoom
    canvas._gui_input(_touch(0,Vector2(350,300),true))
    canvas._gui_input(_touch(1,Vector2(450,300),true))
    var outward:=InputEventScreenDrag.new()
    outward.index=1
    outward.position=Vector2(520,300)
    canvas._gui_input(outward)
    if canvas.zoom<=initial_zoom or canvas.zoom>28.0:
        printerr("WORLD_V06_UI pinch did not zoom in")
        quit(1)
        return
    canvas._gui_input(_touch(1,Vector2(520,300),false))
    canvas._gui_input(_touch(0,Vector2(350,300),false))
    if map.selected_cell!=selected_before or not canvas.touch_points.is_empty():
        printerr("WORLD_V06_UI pinch selected a tile or left fingers active")
        quit(1)
        return
    var tap_location: Vector2=canvas.point(30.5,30.5)
    canvas._gui_input(_touch(0,tap_location,true))
    canvas._gui_input(_touch(0,tap_location,false))
    if map.selected_cell!=Vector2i(30,30):
        printerr("WORLD_V06_UI ordinary tap failed after pinch")
        quit(1)
        return
    var old_pan: Vector2=canvas.pan
    canvas._gui_input(_touch(0,Vector2(300,300),true))
    var move:=InputEventScreenDrag.new()
    move.index=0
    move.position=Vector2(325,315)
    canvas._gui_input(move)
    canvas._gui_input(_touch(0,Vector2(325,315),false))
    if canvas.pan.distance_to(old_pan)<20.0 or map.selected_cell!=Vector2i(30,30):
        printerr("WORLD_V06_UI pan failed or triggered a tile tap")
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
    print("WORLD_V06_UI SUCCESS: 220x165, four starts, selected tile, pinch zoom, touch pan, rivers and city screen")
    quit(0)
