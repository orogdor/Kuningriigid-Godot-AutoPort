extends SceneTree
## V74: exact rigged TRELLIS mesh + walk/idle glTF clips used on both
## world and detail maps, without changing saved army positions.
const Scene=preload("res://content.tscn")
const Units=preload("res://scripts/web_units_v53.gd")

func fail(reason: String) -> void:
    printerr("TRELLIS_WORLD_V74 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _assert_world_actor(actor: Node3D, moving: bool) -> bool:
    if actor==null or actor.get_child_count()==0:
        return false
    var model: Node3D=actor.get_child(0) as Node3D
    if model==null or not bool(model.get_meta("rigged_trellis_v73",false)):
        return false
    var clips: Dictionary=Units.BattleAnims.available_clips(model)
    var animator: Dictionary=model.get_meta("source_animator_v65",{})
    var player: AnimationPlayer=animator.get("player",null)
    var intended: String="walk" if moving else "idle"
    return clips.has(intended) and player!=null and \
        player.is_playing() and \
        player.current_animation==String(clips[intended]) and \
        String(model.get_meta("source_glb","")).find("web73")>=0

func _run() -> void:
    for kind in ["axeman","spearman","slinger"]:
        var model: Node3D=Units.instance(kind,3.1,false,true)
        if model==null or not bool(model.get_meta("rigged_trellis_v73",false)):
            fail("V262 rigged source missing for "+kind)
            return
        root.add_child(model)
        if not Units.animate_world(model,true):
            fail("cannot start walking "+kind)
            return
        var clips: Dictionary=Units.BattleAnims.available_clips(model)
        var animator: Dictionary=model.get_meta("source_animator_v65",{})
        var player: AnimationPlayer=animator.get("player",null)
        if player==null or player.current_animation!=String(clips.get("walk","")):
            fail("walk clip did not play "+kind)
            return
        player.advance(0.10)
        if player.current_animation_position<0.04:
            fail("animation position did not progress "+kind)
            return
        if not Units.animate_world(model,false) or \
                player.current_animation!=String(clips.get("idle","")):
            fail("idle clip did not play "+kind)
            return
        model.free()

    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var atlas=ui.world_view.terrain_3d
    var starts: Array=atlas.world.get("starts",[])
    if starts.is_empty():
        fail("no world starting tile")
        return
    var start: Dictionary=starts[0]
    var army: Dictionary={
        "id":74001,"c":int(start["c"]),"r":int(start["r"]),
        "kind":"axeman","path":[]}
    atlas.set_armies_v54([army])
    var world_actor: Node3D=atlas.army_root_v54.get_node_or_null(
        "ArmyActorV54_74001")
    if not _assert_world_actor(world_actor,false):
        fail("atlas does not display idle rigged TRELLIS")
        return
    ui._show_detail(int(start["c"]),int(start["r"]))
    var detail=ui.detail_view
    detail.set_world_armies_v54([army])
    var detail_actor: Node3D=detail.army_detail_root_v54.get_node_or_null(
        "DetailArmyV54_74001")
    if not _assert_world_actor(detail_actor,false):
        fail("detail does not display idle rigged TRELLIS")
        return
    if absf(world_actor.position.x-atlas.scout_point_for(army).x)>0.001:
        fail("visual upgrade changed atlas army position")
        return
    print("TRELLIS_WORLD_V74 SUCCESS: 3 rigged TRELLIS warriors, glTF walk and idle clips, live atlas and detail actors")
    quit(0)
