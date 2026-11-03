extends SceneTree
## Godot v0.53: verify actual V148 GLB files, source-size normalization,
## and one saved V258 scout in the atlas and detail, without duplicate ghosts.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const Units=preload("res://scripts/web_units_v53.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")

func fail(reason: String) -> void:
    printerr("WEB_UNITS_V53 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if not FileAccess.file_exists("res://assets/web53/manifest.json"):
        fail("original Three.js model manifest was not imported")
        return
    var data: Variant=JSON.parse_string(
        FileAccess.get_file_as_string("res://assets/web53/manifest.json"))
    if not data is Dictionary or data.get("models",{}).size()!=4:
        fail("GLB manifest is incomplete")
        return
    for kind in ["scout","spearman","axeman","slinger"]:
        var asset: Dictionary=data["models"].get(kind,{})
        if int(asset.get("triangles",0))<=0 or int(asset.get("bytes",0))<=1000:
            fail("invalid source triangle count or file size: "+kind)
            return
        var actor: Node3D=Units.instance(kind,3.1)
        if actor==null:
            fail("Godot could not instantiate original "+kind+" GLB")
            return
        if String(actor.get_meta("source_glb",""))!=String(Units.FILES[kind]):
            fail("imported actor was not made from the source GLB")
            return
        var bounds: Dictionary=Units.bounds_of(actor)
        var height: float=(bounds["max"] as Vector3).y-(bounds["min"] as Vector3).y
        if int(bounds["meshes"])==0 or absf(height-3.1)>0.04:
            fail("original "+kind+" mesh did not normalize to 3.1 m")
            return
        actor.free()
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var scene=ui.world_view.terrain_3d
    if scene.scout_actor.get_node_or_null("OriginalWebScoutV53")==null:
        fail("3D atlas still uses the temporary capsule actor")
        return
    var start:=Vector2i(int(scout["c"]),int(scout["r"]))
    ui._show_detail(start.x,start.y)
    var detail=ui.detail_view
    var actor: Node3D=detail.world_scout_actor_v53
    if actor==null or not actor.visible or \
            actor.get_node_or_null("OriginalWebScoutDetailV53")==null:
        fail("source scout was not visible on its corresponding detail tile")
        return
    if absf(actor.position.x)>0.01 or absf(actor.position.z)>0.01:
        fail("atlas-to-detail transform does not preserve scout tile center")
        return
    var target:=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var candidate: Vector2i=start+delta
        if Routes.passable(world,candidate.x,candidate.y):
            target=candidate
            break
    if target.x<0:
        fail("no passable neighbor to test persistent scout travel")
        return
    ui._scout_order(target.x,target.y)
    ui._advance(1)
    if int(scout["c"])!=target.x or int(scout["r"])!=target.y:
        fail("scout did not advance to adjacent tile in one game minute")
        return
    ui._show_detail(target.x,target.y)
    if not actor.visible or actor.get_child_count()==0:
        fail("real moving scout did not appear on the destination detail tile")
        return
    if scene.scout_actor.position.distance_to(scene.scout_point_for(scout))>0.00001:
        fail("3D atlas and saved model position are out of sync")
        return
    ui._show_detail(start.x,start.y)
    if actor.visible:
        fail("old detail tile contains a duplicate scout after movement")
        return
    print("WEB_UNITS_V53 SUCCESS: 4 original Three.js GLBs; normalized bounds; same saved scout in 2D/3D and detail; no duplicate")
    quit(0)
