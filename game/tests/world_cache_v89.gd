extends SceneTree
## V89: 36,300 native terrain cells load from disk instead of being regenerated.
## Preserve coastline, islands, height and PackedInt32 drainage without JSON loss.
const World=preload("res://scripts/world_gen_v06.gd")
const Cache=preload("res://scripts/world_cache_v89.gd")
const TEST_PATH: String="user://autoport_world_cache_v89_regression.bin"

func fail(reason: String) -> void:
    printerr("WORLD_CACHE_V89 FAIL: "+reason)
    _cleanup()
    quit(1)

func _cleanup() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup()
    var world: Dictionary=World.generate(82026,true)
    if not Cache.valid_world(world,82026):
        fail("new 220x165 generated world does not meet cache schema")
        return
    if not Cache.load_world(82026,TEST_PATH).is_empty():
        fail("missing cache was accepted")
        return
    if not Cache.save_world(world,82026,TEST_PATH):
        fail("could not store generated world")
        return
    var restored: Dictionary=Cache.load_world(82026,TEST_PATH)
    if restored.is_empty() or restored!=world:
        fail("serialized world differs from original seed, cells or drainage")
        return
    if not (restored["drainage_down"] is PackedInt32Array) or \
            not (restored["layout"]["centers"][0] is Vector2) or \
            not (restored["layout"]["polygons"][0][0] is Vector2):
        fail("native world geometric types were lost in cache")
        return
    var first: Dictionary=world["starts"][0]
    if World.cell(restored,int(first["c"]),int(first["r"]))!=\
            World.cell(world,int(first["c"]),int(first["r"])):
        fail("reloaded world cell differs from original starting tile")
        return
    if not Cache.load_world(82027,TEST_PATH).is_empty():
        fail("new world seed accepted the old world's cache")
        return
    var wrong: FileAccess=FileAccess.open(TEST_PATH,FileAccess.WRITE)
    wrong.store_var({"schema":-1,"seed":82026,"world":world},false)
    wrong.close()
    if not Cache.load_world(82026,TEST_PATH).is_empty():
        fail("outdated generator schema did not invalidate the cache")
        return
    _cleanup()
    print("WORLD_CACHE_V89 SUCCESS: native 36K terrain cells, river graph, seed/schema invalidation and full parity")
    quit(0)
