extends RefCounted
## V89: save the actual seeded Godot world's generated cells and river graph,
## retaining native Vector2 and PackedInt32Array types via Variant encoding.
## The save is a disposable performance cache, NOT the canonical city save.
## Bump CACHE_SCHEMA when the WorldGen generator output contract changes.
const World=preload("res://scripts/world_gen_v06.gd")
const CACHE_PATH: String="user://autoport_world_v89.cache"
const CACHE_SCHEMA: int=1

static func valid_world(world: Dictionary,seed: int) -> bool:
    if int(world.get("seed",-1))!=seed or \
            int(world.get("cols",-1))!=World.COLS or \
            int(world.get("rows",-1))!=World.ROWS:
        return false
    var cells: Variant=world.get("cells",null)
    var layout: Variant=world.get("layout",null)
    var starts: Variant=world.get("starts",null)
    var drainage: Variant=world.get("drainage_down",null)
    if not (cells is Array) or cells.size()!=World.COLS*World.ROWS or \
            not (layout is Dictionary) or not (starts is Array) or \
            starts.is_empty() or not (drainage is PackedInt32Array) or \
            drainage.size()!=cells.size():
        return false
    if not (cells[0] is Dictionary) or \
            not (cells[cells.size()-1] is Dictionary) or \
            not (layout.get("islands",null) is Array) or \
            not (layout.get("polygons",null) is Array) or \
            not (layout.get("centers",null) is Array):
        return false
    if not world.has("land_count") or not world.has("mountain_count") or \
            not world.has("river_count"):
        return false
    return true

static func load_world(seed: int,path: String=CACHE_PATH) -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var file: FileAccess=FileAccess.open(path,FileAccess.READ)
    if file==null:return {}
    # Never permit object instantiation from a cached file.
    var payload: Variant=file.get_var(false)
    file.close()
    if not (payload is Dictionary) or \
            int(payload.get("schema",-1))!=CACHE_SCHEMA or \
            int(payload.get("seed",-1))!=seed:
        return {}
    var world: Variant=payload.get("world",null)
    if not (world is Dictionary) or not valid_world(world,seed):return {}
    return world

static func save_world(world: Dictionary,seed: int,
        path: String=CACHE_PATH) -> bool:
    if not valid_world(world,seed):return false
    var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
    if file==null:return false
    file.store_var({"schema":CACHE_SCHEMA,"seed":seed,"world":world},false)
    file.flush()
    file.close()
    return true
