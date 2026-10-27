extends SceneTree
## Consistent biome palette across atlas and 3D detail maps.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Palette=preload("res://scripts/web_biomes_v50.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
func fail(why: String) -> void:
    printerr("WEB_BIOMES_V50 FAIL: "+why)
    quit(1)
func _initialize() -> void:
    call_deferred("_test")
func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    var data: Dictionary=ui.world_view.world
    var ocean: Vector2i=Vector2i(-1,-1)
    var shore: Vector2i=Vector2i(-1,-1)
    var forest: Vector2i=Vector2i(-1,-1)
    for row in range(World.ROWS):
        if ocean.x>=0 and shore.x>=0 and forest.x>=0:break
        for col in range(World.COLS):
            var cell: Dictionary=World.cell(data,col,row)
            if not bool(cell.get("land",false)) and not Palette.coastline(data,col,row):
                ocean=Vector2i(col,row)
            if bool(cell.get("land",false)) and Palette.coastline(data,col,row) and shore.x<0:
                shore=Vector2i(col,row)
            if String(cell.get("biome",""))=="forest" and forest.x<0:
                forest=Vector2i(col,row)
            if ocean.x>=0 and shore.x>=0 and forest.x>=0:break
    if ocean.x<0 or shore.x<0 or forest.x<0:
        fail("missing actual ocean, shore or forest in generated world")
        return
    var dark: Color=Palette.color(data,ocean.x,ocean.y)
    if dark.r>0.30:
        fail("deep ocean did not use darker web water palette")
        return
    var beach: Color=Palette.color(data,shore.x,shore.y)
    if beach.r<0.44:
        fail("real coastal beach doesn't have light sand palette")
        return
    var first: Color=Palette.detail(data,forest,0,0)
    var second: Color=Palette.detail(data,forest,40,40)
    if first==second or Palette.detail(data,forest,0,0)!=first:
        fail("detail noise did not vary or wasn't deterministic")
        return
    var home: Vector2i=Districts.origin(data)
    ui._show_detail(home.x,home.y)
    await process_frame
    if ui.detail_view.controller.size.y<180:
        fail("mobile 3D detail viewport shrank")
        return
    if ui.world_view.terrain_3d.terrain_node.mesh==null:
        fail("world relief failed to render using shared palette")
        return
    print("WEB_BIOMES_V50 SUCCESS: matching atlas/detail palette, colored coastline, deep ocean, varied forest soil, mobile viewport")
    quit(0)
