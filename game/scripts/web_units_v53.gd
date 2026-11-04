extends RefCounted
const WebV299=preload("res://scripts/web_models_v72.gd")
const BattleAnims=preload("res://scripts/battle_animation_v65.gd")
## AutoPort v0.53: original, unmodified Three.js stone-age GLBs.
## Source models-v148/glb/{scout,spearman,axeman,slinger}.glb
## Asset files are generated/reproducibly committed by sync-upstream.yml.
## Normalize actual mesh bounds, never assume generator-specific model scale.
const FILES: Dictionary={
    "scout":"res://assets/web53/scout.glb",
    "spearman":"res://assets/web53/spearman.glb",
    "axeman":"res://assets/web53/axeman.glb",
    "slinger":"res://assets/web53/slinger.glb"
}

static func _measure(node: Node,parent_transform: Transform3D, result: Dictionary) -> void:
    var tx: Transform3D=parent_transform
    if node is Node3D:
        tx=parent_transform*(node as Node3D).transform
    if node is MeshInstance3D:
        var geometry: Mesh=(node as MeshInstance3D).mesh
        if geometry!=null:
            var bounds: AABB=geometry.get_aabb()
            for ix in range(2):
                for iy in range(2):
                    for iz in range(2):
                        var local: Vector3=bounds.position+bounds.size*Vector3(ix,iy,iz)
                        var pt: Vector3=tx*local
                        result["min"]=(result["min"] as Vector3).min(pt)
                        result["max"]=(result["max"] as Vector3).max(pt)
            result["meshes"]=int(result["meshes"])+1
    for child in node.get_children():
        _measure(child,tx,result)

static func bounds_of(node: Node3D) -> Dictionary:
    var data: Dictionary={"min":Vector3(INF,INF,INF),
        "max":Vector3(-INF,-INF,-INF),"meshes":0}
    _measure(node,Transform3D.IDENTITY,data)
    return data

## V75: a missing dynamic GLB must never silently erase an entire army.
## Bright, simple Godot geometry is shown until the exact asset is available.
static func fallback_actor(kind: String,height: float) -> Node3D:
    if not FILES.has(kind):return null
    var root:=Node3D.new()
    root.name="VisibleMissingAsset_"+kind
    root.set_meta("source_glb","native_fallback")
    root.set_meta("model_fallback_v75",true)
    var color:=StandardMaterial3D.new()
    color.albedo_color=Color("#ffd46a")
    color.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var torso:=MeshInstance3D.new()
    var body:=CapsuleMesh.new()
    body.radius=height*0.13
    body.height=height*0.72
    torso.mesh=body
    torso.position.y=height*0.38
    torso.material_override=color
    root.add_child(torso)
    var head:=MeshInstance3D.new()
    var skull:=SphereMesh.new()
    skull.radius=height*0.11
    skull.height=height*0.22
    head.mesh=skull
    head.position.y=height*0.86
    head.material_override=color
    root.add_child(head)
    return root

static func instance(kind: String,height: float=2.7,
        prefer_latest: bool=false, prefer_rigged: bool=false) -> Node3D:
    if prefer_rigged and kind!="scout":
        var rig_path: String="res://assets/web73/"+kind+".glb"
        if ResourceLoader.exists(rig_path):
            var resource: Resource=load(rig_path)
            if resource is PackedScene:
                var model: Node3D=(resource as PackedScene).instantiate() as Node3D
                if model!=null:
                    var bounds: Dictionary=bounds_of(model)
                    if int(bounds["meshes"])>0:
                        var bottom: Vector3=bounds["min"]
                        var top: Vector3=bounds["max"]
                        var h: float=top.y-bottom.y
                        if h>0.0001 and is_finite(h):
                            var factor: float=height/h
                            var group:=Node3D.new()
                            group.name="RiggedTRELLIS_"+kind
                            group.set_meta("source_glb",rig_path)
                            group.set_meta("rigged_trellis_v73",true)
                            group.add_child(model)
                            model.scale=Vector3.ONE*factor
                            model.position=Vector3(
                                -(bottom.x+top.x)*factor*0.5,
                                -bottom.y*factor,
                                -(bottom.z+top.z)*factor*0.5)
                            return group
                    model.free()
    if prefer_latest and kind!="scout":
        var latest: Node3D=WebV299.unit_instance(kind,height)
        if latest!=null:return latest
    var path: String=String(FILES.get(kind,""))
    if path=="" or not ResourceLoader.exists(path):
        return fallback_actor(kind,height)
    var resource: Resource=load(path)
    if not resource is PackedScene:return fallback_actor(kind,height)
    var model: Node3D=(resource as PackedScene).instantiate() as Node3D
    if model==null:return fallback_actor(kind,height)
    var bounds: Dictionary=bounds_of(model)
    if int(bounds["meshes"])==0:
        model.free()
        return fallback_actor(kind,height)
    var bottom: Vector3=bounds["min"]
    var top: Vector3=bounds["max"]
    var raw_height: float=top.y-bottom.y
    if raw_height<=0.0001 or not is_finite(raw_height):
        model.free()
        return fallback_actor(kind,height)
    var factor: float=height/raw_height
    var group:=Node3D.new()
    group.name="OriginalWeb_"+kind
    group.set_meta("source_glb",path)
    group.set_meta("normalization_scale",factor)
    group.add_child(model)
    model.scale=Vector3.ONE*factor
    model.position=Vector3(-(bottom.x+top.x)*factor*0.5,
        -bottom.y*factor,-(bottom.z+top.z)*factor*0.5)
    return group

## V74: play actual imported glTF skeleton clips on the *visible* V262
## world/detail actors. Atlas army units previously used static V262 geometry.
## This affects animation only: route/path/HP/time remain simulation-owned.
static func animate_world(model: Node3D, is_traveling: bool) -> bool:
    if model==null or not bool(model.get_meta("rigged_trellis_v73",false)):
        return false
    var clips: Dictionary=BattleAnims.available_clips(model)
    if clips.is_empty():return false
    var state: Dictionary=model.get_meta("source_animator_v65",{})
    var player: AnimationPlayer=state.get("player",null)
    if player==null or not is_instance_valid(player):return false
    var desired: String="walk" if is_traveling else "idle"
    if not clips.has(desired) and desired=="walk" and clips.has("run"):
        desired="run"
    if not clips.has(desired):return false
    var clip: String=String(clips[desired])
    var animation: Animation=player.get_animation(clip)
    if animation==null:return false
    animation.loop_mode=Animation.LOOP_LINEAR
    if player.current_animation!=clip or not player.is_playing():
        player.play(clip,0.14,1.0)
    model.set_meta("world_animation_v74",desired)
    return true
