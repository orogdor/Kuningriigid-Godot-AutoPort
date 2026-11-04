extends RefCounted
## Godot AutoPort 0.65: frame-driven, source-GLB-safe tactical actions.
## True arm/leg articulation is used when a model contains Skeleton3D bones.
## Unrigged original GLBs retain their exact geometry and textures and get a
## visible whole-body locomotion, attack and recoil animation instead.
const STRIKE_SECONDS: float=0.36
const HIT_SECONDS: float=0.36
const WALK_PHASE_SPEED: float=7.5

static func pose(man: Dictionary,kind: String) -> Dictionary:
    var phase: float=float(man.get("anim_phase",0.0))
    var walking: bool=bool(man.get("moving",false))
    var attack: float=clampf(float(man.get("attack_anim",0.0)),0.0,STRIKE_SECONDS)
    var hit: float=clampf(float(man.get("hit_anim_v61",0.0)),0.0,HIT_SECONDS)
    var gait: float=sin(phase) if walking else 0.0
    var footfall: float=absf(sin(phase)) if walking else 0.0
    var strike: float=sin((1.0-attack/STRIKE_SECONDS)*PI) if attack>0.0 else 0.0
    var recoil: float=hit/HIT_SECONDS
    # The model is 5.2m high in the tactical scene. Previous V61
    # whole-model motion was only 0.12m and nearly invisible from above.
    var bob: float=0.32*footfall+0.18*recoil
    var forward: float=0.23*gait if walking else 0.0
    var roll: float=0.14*gait+0.12*recoil
    var pitch: float=-0.13 if walking else 0.0
    var yaw: float=0.055*gait
    var arms: float=0.64*gait if walking else 0.0
    var legs: float=0.52*gait if walking else 0.0
    var action: String="walk" if walking else "idle"
    if kind=="spearman":
        pitch-=0.60*strike
        forward+=0.48*strike
        arms+=0.70*strike
        if strike>0.05:action="thrust"
    elif kind=="axeman":
        roll+=0.52*strike
        yaw+=0.35*strike
        arms+=0.90*strike
        if strike>0.05:action="swing"
    elif kind=="slinger":
        yaw+=0.80*strike
        roll-=0.30*strike
        arms+=1.05*strike
        if strike>0.05:action="sling"
    pitch+=0.33*recoil
    if recoil>0.1:action="hit"
    return {"offset":Vector3(0.0,bob,forward),
        "rotation":Vector3(pitch,yaw,roll),
        "legs":legs,"arms":arms,"action":action,
        "walking":walking,"attacking":strike>0.05,
        "hit":hit>0.0}

static func _rig_bones(model: Node3D) -> Array:
    if model.has_meta("rig_bones_v65"):
        return model.get_meta("rig_bones_v65")
    var matches: Array=[]
    for candidate in model.find_children("*","Skeleton3D",true,false):
        var skeleton: Skeleton3D=candidate as Skeleton3D
        if skeleton==null:continue
        for i in range(skeleton.get_bone_count()):
            var name: String=String(skeleton.get_bone_name(i)).to_lower()
            var side: int=0
            if name.contains("left") or name.begins_with("l_") or \
                    name.begins_with("l."):side=-1
            elif name.contains("right") or name.begins_with("r_") or \
                    name.begins_with("r."):side=1
            if side==0:continue
            var leg: bool=name.contains("upleg") or name.contains("thigh") or \
                name.contains("upperleg") or name.contains("upper_leg")
            var arm: bool=name.contains("upperarm") or name.contains("upper_arm") or \
                name.contains("shoulder") or name.ends_with(" arm")
            if leg or arm:
                matches.append({"skeleton":skeleton,"bone":i,"side":side,
                    "leg":leg})
    model.set_meta("rig_bones_v65",matches)
    return matches

static func apply(model: Node3D,man: Dictionary,kind: String) -> void:
    if model==null:return
    var state: Dictionary=pose(man,kind)
    model.position=state["offset"]
    model.rotation=state["rotation"]
    # Existing GLBs are used as-is. Only rotate actual bones if present;
    # never attach fake limbs or replace textured source meshes with cubes.
    var bones: Array=_rig_bones(model)
    for item in bones:
        var skeleton: Skeleton3D=item["skeleton"]
        if not is_instance_valid(skeleton):continue
        var index: int=int(item["bone"])
        var side: int=int(item["side"])
        var angle: float=float(state["legs"]) if bool(item["leg"]) else \
            -float(state["arms"])
        angle*=float(side)
        skeleton.set_bone_pose_rotation(index,
            Quaternion(Vector3.RIGHT,angle))
