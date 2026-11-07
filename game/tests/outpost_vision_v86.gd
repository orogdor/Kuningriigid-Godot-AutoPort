extends SceneTree
## V86: a genuinely founded second city provides permanent friendly vision
## in both atlas renderers and 3D detail without rewriting scout saves.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")
const Fog=preload("res://scripts/scout_fog_v80.gd")
const Town=preload("res://scripts/second_city_detail_v47.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")

func fail(reason: String) -> void:
    printerr("OUTPOST_VISION_V86 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(800,560)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    var map=ui.world_view
    var world: Dictionary=map.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    ui._found_trade_city()
    if not Trade.has_outpost(ui.city):
        fail("could not found the second city")
        return
    var position: Dictionary=ui._satellite_tile()
    var tile: Vector2i=Town.satellite_position(position,world)
    if tile.x<0:
        fail("second city had no world position")
        return
    if Fog.visible_at(scout,world,tile.x,tile.y):
        fail("test outpost unexpectedly within original scout/capital sight")
        return
    var visible_scout: Dictionary=map.scout_state
    if not visible_scout.has("vision_outpost_v85") or \
            Scout.ensure(ui.city,world).has("vision_outpost_v85"):
        fail("derived vision absent or accidentally persisted in save")
        return
    if not Fog.visible_at(visible_scout,world,tile.x,tile.y) or \
            Fog.visibility(visible_scout,world)[tile.y*World.COLS+tile.x]!=2 or \
            Fog.visibility_at_v83(visible_scout,world,tile.x,tile.y)!=2:
        fail("satellite is not revealed in shared fog policy")
        return
    if Fog.atlas_image(visible_scout,world).get_pixel(tile.x,tile.y).a>0.02 or \
            Fog.terrain_image(visible_scout,world).get_pixel(tile.x,tile.y).r<0.99:
        fail("2D or 3D fog texture hides founded outpost")
        return
    if map.map_canvas.fog_key_v80!=Fog.signature(visible_scout,world) or \
            map.terrain_3d.fog_key_v80!=Fog.signature(visible_scout,world)+str(true):
        fail("founded outpost didn't invalidate active GPU fog cache")
        return
    var enemy: Dictionary={"id":-100,"seed":int(world["seed"]),"team":1,
        "c":tile.x,"r":tile.y,"kind":"spearman","hp":234.0,"path":[]}
    if not Fog.unit_visible_v82(visible_scout,world,enemy):
        fail("defenders can't see enemy approaching the outpost")
        return
    map.set_raider_v56(enemy)
    if not map.army_status_v54.text.contains("234"):
        fail("outpost did not expose nearby hostile intelligence")
        return
    # The city centre bypasses fog for buildability; also verify a REAL
    # neighboring wilderness detail tile receives the second city's sight.
    var neighbor:=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(-1,0),
            Vector2i(0,1),Vector2i(0,-1)]:
        var candidate: Vector2i=tile+delta
        if not World.cell(world,candidate.x,candidate.y).is_empty() and \
                not Fog.visible_at(scout,world,candidate.x,candidate.y):
            neighbor=candidate
            break
    if neighbor.x<0:
        fail("no unseen adjacent tile for independent detail vision test")
        return
    ui._show_detail(neighbor.x,neighbor.y)
    if ui.detail_view.can_build or ui.detail_view.fog_last_state_v81!=2 or \
            ui.detail_view.fog_root_v81.get_child_count()!=0:
        fail("outpost did not reveal its adjacent 3D wilderness detail")
        return
    var stale: Dictionary=visible_scout.duplicate(true)
    stale["vision_outpost_v85"]["seed"]=int(world["seed"])+1
    if Fog.visible_at(stale,world,tile.x,tile.y):
        fail("old-world outpost coordinates revealed enemy world")
        return
    ui.city.erase("trade_v15")
    ui._sync_trade_map()
    if Fog.visible_at(map.scout_state,world,tile.x,tile.y) or \
            map.army_status_v54.text.contains("234") or \
            ui.detail_view.fog_last_state_v81!=0 or \
            ui.detail_view.fog_root_v81.get_child_count()!=1:
        fail("removing outpost left permanent sight, detail terrain or enemy intelligence")
        return
    print("OUTPOST_VISION_V86 SUCCESS: founded satellite, 2D/3D/detail vision, cache invalidation, enemy visibility, no save migration")
    quit(0)
