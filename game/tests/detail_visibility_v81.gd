extends SceneTree
## V81 integration: actual detail scene, fog updates, enemy reveal and saves.
const Scene=preload("res://content.tscn")
const Fog80=preload("res://scripts/scout_fog_v80.gd")
const Auto79=preload("res://scripts/scout_auto_v79.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")

func fail(message: String) -> void:
    printerr("DETAIL_VISIBILITY_V81 FAIL: "+message)
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
    # Integration tests must not inherit fog settings saved by earlier scenes.
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    var world: Dictionary=ui.world_view.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var far:=Vector2i((int(scout["c"])+World.COLS/2)%World.COLS,
        (int(scout["r"])+World.ROWS/2)%World.ROWS)
    if Fog80.visible_at(scout,world,far.x,far.y):
        fail("test target is initially revealed")
        return
    ui._show_detail(far.x,far.y)
    var detail=ui.detail_view
    if not detail.fog_enabled_v81 or detail.fog_last_state_v81!=0 or \
            detail.fog_root_v81.get_child_count()!=1 or \
            not detail.info.text.contains("Avastamata"):
        fail("unknown selected tile revealed its biome or 3D props")
        return
    var concealed: int=0
    for part in detail.seam_preview_root.get_children():
        if bool(part.get_meta("detail_unknown_v81",false)):
            concealed+=1
            if part.get_child_count()!=1 or \
                    part.get_child(0).name!="UnexploredTerrainV81":
                fail("hidden neighbor contains original props or buildings")
                return
    if concealed<3:
        fail("unknown surrounding tiles were exposed")
        return
    var enemy: Dictionary={"id":-100,"seed":int(world["seed"]),
        "team":1,"kind":"spearman","c":far.x,"r":far.y,
        "hp":100.0,"path":[],"travelClock":0.0,"travelDuration":0.0}
    var friend: Dictionary=enemy.duplicate(true)
    friend["id"]=81001
    friend["team"]=0
    detail.set_world_armies_v54([enemy,friend])
    if detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_-100")!=null or \
            detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_81001")==null:
        fail("hidden enemy or friendly model visibility is incorrect")
        return
    # A V79 save knows the terrain, but does not show hostile movement
    # outside today's scout visibility radius.
    var visited: Dictionary=scout.duplicate(true)
    Auto79.visit(visited,far.x,far.y)
    detail.set_visibility_v81(visited,true)
    if detail.fog_last_state_v81!=1 or \
            detail.fog_root_v81.get_child_count()!=0 or \
            detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_-100")!=null:
        fail("historical visits failed to uncover terrain while hiding foes")
        return
    visited["c"]=far.x
    visited["r"]=far.y
    detail.set_visibility_v81(visited,true)
    if detail.fog_last_state_v81!=2 or \
            detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_-100")==null:
        fail("scout vision did not reveal the hidden enemy")
        return
    # No new save fields: disabling fog restores legacy full-detail behavior.
    ui.world_view.fog_enabled_v80=false
    ui._show_detail(far.x,far.y)
    if detail.fog_enabled_v81 or detail.fog_last_state_v81!=2 or \
            detail.fog_root_v81.get_child_count()!=0:
        fail("fog-off main map settings were not propagated to detail")
        return
    var legacy: Dictionary=ui.city.duplicate(true)
    legacy["world_scout_v52"]={"seed":int(world["seed"]),"kind":"scout",
        "c":int(world["starts"][0]["c"]),"r":int(world["starts"][0]["r"]),
        "path":[],"travelClock":0.0,"travelDuration":0.0}
    var migrated: Dictionary=Scout.ensure(legacy,world)
    detail.set_visibility_v81(migrated,true)
    if detail.fog_last_state_v81!=0 or \
            int(migrated.get("visited_count_v79",0))!=1:
        fail("legacy save fog migration broke")
        return
    # Restore the default for following standalone test processes.
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    ui.world_view._save_settings()
    print("DETAIL_VISIBILITY_V81 SUCCESS: unknown detail/neighbor concealment, own soldiers, enemy scouting, visited memory, world toggle, legacy saves")
    quit(0)
