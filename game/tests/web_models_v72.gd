extends SceneTree
## Exact V299 model import, geometry, active city visibility and V148
## animation fallback. Do not confuse raw TRELLIS mesh with an animated rig.
const Models=preload("res://scripts/web_models_v72.gd")
const Units=preload("res://scripts/web_units_v53.gd")
const Art=preload("res://scripts/web_graphics_v50.gd")
const Animation=preload("res://scripts/battle_animation_v65.gd")
const Scene=preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("WEB_MODELS_V72 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var file: String="res://assets/web72/manifest.json"
    if not FileAccess.file_exists(file):
        fail("V299 GLB source manifest missing")
        return
    var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
    if not manifest is Dictionary:
        fail("invalid manifest JSON")
        return
    var groups: Dictionary=manifest.get("models",{})
    var expected: Dictionary={"unit":3, "building":18, "world":18, "nature":6}
    for category in expected:
        var models: Dictionary=groups.get(category,{})
        if models.size()!=int(expected[category]):
            fail("missing V299 "+category+" models")
            return
        for name in models:
            var detail: Dictionary=models[name]
            if int(detail.get("triangles",0))<1 or int(detail.get("bytes",0))<1000:
                fail("invalid triangle count: "+category+"/"+name)
                return
            if not Models.packed(category,String(name)) is PackedScene:
                fail("Godot cannot load "+category+"/"+name)
                return
    for kind in ["axeman","spearman","slinger"]:
        var mesh: Node3D=Units.instance(kind,3.1,true)
        if mesh==null or not bool(mesh.get_meta("unrigged_trellis_v262",false)):
            fail("world/detail units did not use V299 "+kind)
            return
        mesh.free()
        var old: Node3D=Units.instance(kind,3.1)
        if old==null or String(old.get_meta("source_glb","")).find("web53")<0:
            fail("animated V148 combat fallback was removed: "+kind)
            return
        if Animation.available_clips(old).is_empty():
            fail("old rigged combat animation unavailable: "+kind)
            return
        old.free()
    var forest: PackedScene=Art.asset("forest_cluster")
    if forest==null or String(forest.resource_path).find("web72/nature/pine.glb")<0:
        fail("atlas is not using the new tree model")
        return
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var preview:=Node3D.new()
    root.add_child(preview)
    for kind in ["hall","house","lumber","well","quarry","farm"]:
        var holder:=Node3D.new()
        holder.name=kind
        preview.add_child(holder)
        ui.detail_view._building(holder,kind,Vector3.ZERO,true)
        var v299: Node3D=holder.get_node_or_null("WebV299Building_"+kind)
        if v299==null or not v299.visible or \
                String(v299.get_meta("source_glb","")).find("web72/building")<0:
            fail("finished "+kind+" still displays old procedural geometry")
            return
    print("WEB_MODELS_V72 SUCCESS: 45 source GLBs, 6 real city models, atlas pine, 3 TRELLIS world units, animated combat fallback")
    quit(0)
