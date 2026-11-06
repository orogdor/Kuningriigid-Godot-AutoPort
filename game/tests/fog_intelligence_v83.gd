extends SceneTree
## V83: UI must not reveal unexplored biome, height or hidden raider HP.
const Game=preload("res://content.tscn")
const Fog=preload("res://scripts/scout_fog_v80.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")
const Auto79=preload("res://scripts/scout_auto_v79.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(message: String) -> void:
    printerr("FOG_INTELLIGENCE_V83 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(800,560)
    var ui: Control=Game.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var map=ui.world_view
    var world: Dictionary=map.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var far:=Vector2i(-1,-1)
    for r in range(10,World.ROWS-10):
        if far.x>=0:break
        for c in range(10,World.COLS-10):
            if Fog.visibility_at_v83(scout,world,c,r)==0:
                far=Vector2i(c,r)
                break
    if far.x<0:
        fail("no unexplored tile")
        return
    var enemy: Dictionary={"id":-100,"seed":int(world["seed"]),
        "team":1,"kind":"spearman","c":far.x,"r":far.y,
        "hp":123.0,"path":[]}
    map.fog_enabled_v80=true
    map._apply_fog_v80()
    map.set_scout(scout)
    map.set_armies_v54([])
    map.set_raider_v56(enemy)
    map.select_world_cell(far.x,far.y)
    if not map.info_label.text.contains("Avastamata") or \
            not map.army_status_v54.text.contains("asukoht teadmata") or \
            map.army_status_v54.text.contains("123"):
        fail("hidden terrain or enemy intelligence leaked")
        return
    var visited: Dictionary=scout.duplicate(true)
    Auto79.visit(visited,far.x,far.y)
    map.set_scout(visited)
    if Fog.visibility_at_v83(visited,world,far.x,far.y)!=1 or \
            map.info_label.text.contains("Avastamata") or \
            not map.army_status_v54.text.contains("asukoht teadmata"):
        fail("visited terrain should reveal without enemy HP")
        return
    visited["c"]=far.x
    visited["r"]=far.y
    map.set_scout(visited)
    if not map.army_status_v54.text.contains("123"):
        fail("visible enemy HP missing")
        return
    map.set_scout(scout)
    map.fog_enabled_v80=false
    map._apply_fog_v80()
    if map.info_label.text.contains("Avastamata") or \
            not map.army_status_v54.text.contains("123"):
        fail("fog-off did not restore legacy UI")
        return
    map.fog_enabled_v80=true
    map._apply_fog_v80()
    if not map.info_label.text.contains("Avastamata") or \
            map.army_status_v54.text.contains("123"):
        fail("fog-on did not re-hide enemy")
        return
    map.regenerate()
    await process_frame
    await process_frame
    if not map.raider_state_v83.is_empty():
        fail("new seed leaked previous raider")
        return
    print("FOG_INTELLIGENCE_V83 SUCCESS: unknown/visited terrain, enemy HP, scout sight, toggles, new seed")
    quit(0)
