extends SceneTree
## Rigged TRELLIS V262 source geometry and live V148 skeletal clips,
## including all 216 actual battle renderers, not substitute cylinders.
const Scene=preload("res://content.tscn")
const Units=preload("res://scripts/web_units_v53.gd")
const Anim=preload("res://scripts/battle_animation_v65.gd")

func fail(reason: String) -> void:
    printerr("TRELLIS_RIG_V73 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path: String="res://assets/web73/manifest.json"
    if not FileAccess.file_exists(path):
        fail("missing V73 rig source and SHA256 manifest")
        return
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or parsed.get("models",{}).size()!=3:
        fail("V73 source manifest lacks one of three warriors")
        return
    for kind in ["axeman","spearman","slinger"]:
        var detail: Dictionary=parsed["models"][kind]
        if int(detail.get("vertices",0))<4000 or int(detail.get("skins",0))!=1 or \
                int(detail.get("weighted_bones",0))<6:
            fail("invalid imported TRELLIS rig: "+kind)
            return
        var actor: Node3D=Units.instance(kind,5.2,false,true)
        if actor==null or not actor.has_meta("rigged_trellis_v73"):
            fail("V73 is not the active battle character "+kind)
            return
        if String(actor.get_meta("source_glb",""))!=\
                "res://assets/web73/"+kind+".glb":
            fail("wrong source model selected: "+kind)
            return
        var skeletons: Array=actor.find_children("*","Skeleton3D",true,false)
        var meshes: Array=actor.find_children("*","MeshInstance3D",true,false)
        var found_mesh: bool=false
        if skeletons.is_empty() or \
                (skeletons[0] as Skeleton3D).get_bone_count()<12:
            fail("source model has no real Skeleton3D: "+kind)
            return
        for node in meshes:
            var m: MeshInstance3D=node as MeshInstance3D
            if m.skin!=null and m.mesh!=null and m.mesh.get_surface_count()>0 and \
                    m.mesh.surface_get_array_len(0)>4000:
                found_mesh=true
        if not found_mesh:
            fail("TRELLIS source mesh is not skinned in Godot: "+kind)
            return
        var clips: Dictionary=Anim.available_clips(actor)
        for action in ["idle","walk","run","attack","hit","death"]:
            if not clips.has(action):
                fail("missing "+action+" animation for "+kind)
                return
        if kind=="spearman" and not clips.has("brace"):
            fail("spear defense clip not preserved")
            return
        var info: Dictionary=actor.get_meta("source_animator_v65",{})
        var animator: AnimationPlayer=info.get("player",null)
        if animator==null:
            fail("no imported AnimationPlayer: "+kind)
            return
        animator.play(String(clips["walk"]))
        animator.advance(0.12)
        if not animator.is_playing() or animator.current_animation_position<0.05:
            fail("skeletal walk clip does not advance: "+kind)
            return
        actor.free()
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_large_demo_battle()
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    if view.actors_root.get_child_count()!=216:
        fail("216 soldiers were not spawned")
        return
    var kinds: Dictionary={}
    for soldier in view.actors_root.get_children():
        if soldier.get_child_count()<1:
            fail("empty battle soldier")
            return
        var model: Node3D=soldier.get_child(0) as Node3D
        if model==null or not bool(model.get_meta("rigged_trellis_v73",false)):
            fail("battle still uses old procedural/legacy models")
            return
        var clip_map: Dictionary=Anim.available_clips(model)
        if not clip_map.has("attack") or not clip_map.has("death"):
            fail("battle unit lost its true skeletal animation")
            return
        var src: String=String(model.get_meta("source_glb",""))
        if not src.begins_with("res://assets/web73/"):
            fail("legacy mesh in active battle")
            return
        kinds[src]=int(kinds.get(src,0))+1
    if kinds.size()!=3:
        fail("not all three V262 character designs appear in the battle")
        return
    print("TRELLIS_RIG_V73 SUCCESS: 3 original textured V262 meshes + Skeleton3D animations, 216 real active battle soldiers")
    quit(0)
