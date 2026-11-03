extends SceneTree
## Fast-fail loader: catches dependency parse errors before the slow v39 test.
func _initialize() -> void:
    for file in ["res://scripts/world_scout_v52.gd",
            "res://scripts/world_canvas_v06.gd",
            "res://scripts/world_terrain_v40.gd",
            "res://scripts/world_map_v06.gd",
            "res://scripts/content.gd"]:
        var script: Variant=load(file)
        if not script is GDScript or not script.can_instantiate():
            printerr("WORLD_SCOUT_PARSE_V52 FAIL: "+file)
            quit(1)
            return
        print("WORLD_SCOUT_PARSE_V52 OK: "+file)
    quit(0)
