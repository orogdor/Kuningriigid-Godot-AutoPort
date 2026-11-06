extends SceneTree
## V82 integration: same enemy visibility in both world renderers and detail.
const Game=preload("res://content.tscn")
const Fog=preload("res://scripts/scout_fog_v80.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(reason: String) -> void:
    printerr("ARMY_FOG_PARITY_V82 FAIL: "+reason)
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
    # Integration tests must not inherit fog settings saved by earlier scenes.
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    var map=ui.world_view
    var world: Dictionary=map.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var far:=Vector2i(-1,-1)
    for r in range(10,World.ROWS-10):
        if far.x>=0:break
        for c in range(10,World.COLS-10):
            if bool(World.cell(world,c,r).get("land",false)) and \
                    not Fog.visible_at(scout,world,c,r):
                far=Vector2i(c,r)
                break
    if far.x<0:
        fail("could not find distant land tile")
        return
    var enemy: Dictionary={"id":82001,"team":1,"kind":"spearman","c":far.x,
        "r":far.y,"seed":int(world["seed"]),"path":[],
        "travelClock":0.0,"travelDuration":0.0}
    var friend: Dictionary=enemy.duplicate(true)
    friend["id"]=82002
    friend["team"]=0
    map.map_canvas.set_armies_v54([enemy,friend])
    map.terrain_3d.set_armies_v54([enemy,friend])
    var actor: Node3D=map.terrain_3d.army_root_v54.get_node_or_null("ArmyActorV54_82001") as Node3D
    var own: Node3D=map.terrain_3d.army_root_v54.get_node_or_null("ArmyActorV54_82002") as Node3D
    if actor==null or own==null or actor.visible or not own.visible or \
            map.map_canvas.army_visible_v82(enemy) or not map.map_canvas.army_visible_v82(friend):
        fail("enemy leaked through 2D/3D fog or friendly rig disappeared")
        return
    var original_id: int=actor.get_instance_id()
    var discovered: Dictionary=scout.duplicate(true)
    discovered["c"]=far.x
    discovered["r"]=far.y
    map.set_scout(discovered)
    if not actor.visible or not map.map_canvas.army_visible_v82(enemy) or \
            actor.get_instance_id()!=original_id:
        fail("scout reveal replaced GLB or failed to update both atlas renderers")
        return
    map.set_scout(scout)
    if actor.visible or map.map_canvas.army_visible_v82(enemy):
        fail("hostile actor remained visible outside scout sight")
        return
    map.fog_enabled_v80=false
    map._apply_fog_v80()
    if not actor.visible or not map.map_canvas.army_visible_v82(enemy):
        fail("fog-off did not restore the enemy actor")
        return
    map.fog_enabled_v80=true
    map._apply_fog_v80()
    if actor.visible or map.map_canvas.army_visible_v82(enemy):
        fail("fog-on did not hide the enemy actor")
        return
    ui._show_detail(far.x,far.y)
    var detail=ui.detail_view
    detail.set_world_armies_v54([enemy,friend])
    if detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_82001")!=null or \
            detail.army_detail_root_v54.get_node_or_null("DetailArmyV54_82002")==null:
        fail("detail and atlas disagree about enemy/friendly actors")
        return
    if int(enemy["c"])!=far.x or int(friend["c"])!=far.x or \
            not enemy["path"].is_empty() or not friend["path"].is_empty():
        fail("fog altered military game state")
        return
    print("ARMY_FOG_PARITY_V82 SUCCESS: 2D/3D/detail sight, friendly rigs, no restart, toggles, no simulated army changes")
    quit(0)
