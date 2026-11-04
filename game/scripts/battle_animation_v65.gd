extends RefCounted
## Godot AutoPort 0.65: frame-driven, source-GLB-safe tactical actions.
## The original source soldiers carry REAL Skeleton3D + glTF animations:
## idle, walk, run, attack, hit, death (+ spearman brace). Prefer the imported
## AnimationPlayer and its original clips; keep a non-destructive procedural
## whole-model fallback only for genuinely unanimated future GLBs.
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

static func _imported_animator(model: Node3D) -> Dictionary:
    if model.has_meta("source_animator_v65"):
        return model.get_meta("source_animator_v65")
    var result: Dictionary={}
    for candidate in model.find_children("*","AnimationPlayer",true,false):
        var player: AnimationPlayer=candidate as AnimationPlayer
        if player==null:continue
        var names: Dictionary={}
        for item in player.get_animation_list():
            var imported_name: String=String(item)
            var simple: String=imported_name.get_file().to_lower()
            # glTF animation exporters often name clips as e.g.
            # Armature|Walk, Take 001 - Run, Walk_Armature or mixamo.com.
            # Recognize descriptive names without changing source GLBs.
            simple=simple.replace("|","_").replace("-","_").replace(" ","_")
            for action in ["idle","walk","run","attack","hit","death","brace"]:
                if simple==action or simple.begins_with(action+"_") or \
                        simple.ends_with("_"+action) or \
                        simple.contains("_"+action+"_"):
                    if not names.has(action):names[action]=imported_name
                    break
        if names.has("walk") or names.has("run") or names.has("idle"):
            result={"player":player,"clips":names}
            break
    model.set_meta("source_animator_v65",result)
    return result

static func available_clips(model: Node3D) -> Dictionary:
    return _imported_animator(model).get("clips",{})

static func _play_original_animation(model: Node3D,
        state: Dictionary) -> bool:
    var info: Dictionary=_imported_animator(model)
    if info.is_empty():return false
    var player: AnimationPlayer=info["player"]
    if not is_instance_valid(player):return false
    var clips: Dictionary=info["clips"]
    var target: String="walk" if bool(state["walking"]) else "idle"
    if target=="walk" and not clips.has("walk") and clips.has("run"):
        target="run"
    if target=="idle" and not clips.has("idle") and clips.has("walk"):
        target="walk"
    if bool(state["hit"]) and clips.has("hit"):
        target="hit"
    elif bool(state["attacking"]) and clips.has("attack"):
        target="attack"
    if not clips.has(target):return false
    var clip: String=String(clips[target])
    var changed: bool=player.current_animation!=clip
    if changed or (not player.is_playing() and \
            ["walk","idle"].has(target)):
        var animation: Animation=player.get_animation(clip)
        if animation!=null and ["walk","idle","run"].has(target):
            animation.loop_mode=Animation.LOOP_LINEAR
        # Crossfade is modest: play the real skeletal clip from the
        # imported GLB instead of posing the whole model as one stiff block.
        player.play(clip,0.10,1.0)
    return true

## V69: play the actual glTF death clip once on the original Skeleton3D.
## This is purely visual; simulation casualties already happened upstream.
static func play_death(model: Node3D) -> bool:
    if model==null:return false
    var info: Dictionary=_imported_animator(model)
    if info.is_empty():return false
    var clips: Dictionary=info.get("clips",{})
    if not clips.has("death"):return false
    var player: AnimationPlayer=info.get("player",null)
    if player==null or not is_instance_valid(player):return false
    var clip: String=String(clips["death"])
    var animation: Animation=player.get_animation(clip)
    if animation==null:return false
    animation.loop_mode=Animation.LOOP_NONE
    player.play(clip,0.08,1.0)
    return true

## V70: real combat generates increasing strike/hit counters at the
## deterministic damage step. Start each imported action clip exactly once,
## on the next render snapshot, on both involved soldiers. The animation
## player is deliberately NOT restarted by each 56-FPS render call.
const ACTION_REAL_SECONDS_V70: float=0.72 # 0.36 sim s at 0.5 battle speed

static func _synced_action_v70(model: Node3D,man: Dictionary) -> bool:
    var info: Dictionary=_imported_animator(model)
    if info.is_empty():return false
    var player: AnimationPlayer=info.get("player",null)
    if player==null or not is_instance_valid(player):return false
    var clips: Dictionary=info.get("clips",{})
    var strike: int=int(man.get("strike_seq_v70",0))
    var hit: int=int(man.get("hit_seq_v70",0))
    var previous: Dictionary=model.get_meta("combat_anim_v70",{})
    if previous.is_empty():
        # A loaded saved battle may already contain hundreds of old
        # events; they must not all replay as a new animation on load.
        model.set_meta("combat_anim_v70",
            {"strike":strike,"hit":hit,"action":""})
        return false
    if strike<int(previous.get("strike",0)) or hit<int(previous.get("hit",0)):
        # New demo/replay reused an old 3D model and reset the counters.
        model.set_meta("combat_anim_v70",
            {"strike":strike,"hit":hit,"action":""})
        return false
    var hit_now: bool=hit>int(previous.get("hit",0))
    var strike_now: bool=strike>int(previous.get("strike",0))
    previous["strike"]=strike
    previous["hit"]=hit
    if hit_now or strike_now:
        # The same person can hit and be hit in one sim step. Hit recoil
        # has priority, while the attack counter is still acknowledged.
        var action: String="hit" if hit_now else "attack"
        if not clips.has(action):
            previous["action"]=""
            model.set_meta("combat_anim_v70",previous)
            return false
        var clip: String=String(clips[action])
        var animation: Animation=player.get_animation(clip)
        if animation==null:return false
        animation.loop_mode=Animation.LOOP_NONE
        var speed: float=clampf(animation.length/
            ACTION_REAL_SECONDS_V70,0.25,5.0)
        player.play(clip,0.06,speed)
        # Godot may resume the same named clip rather than restart it.
        # Explicitly seek to its first frame for a *new* attack event.
        player.seek(0.0,false)
        previous["action"]=action
        model.set_meta("combat_anim_v70",previous)
        return true
    var action: String=String(previous.get("action",""))
    if action!="" and clips.has(action) and player.is_playing() and \
            player.current_animation==String(clips[action]):
        model.set_meta("combat_anim_v70",previous)
        return true
    previous["action"]=""
    model.set_meta("combat_anim_v70",previous)
    return false

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
                    name.begins_with("l.") or name.ends_with("_l") or \
                    name.ends_with(".l"):side=-1
            elif name.contains("right") or name.begins_with("r_") or \
                    name.begins_with("r.") or name.ends_with("_r") or \
                    name.ends_with(".r"):side=1
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
    var synchronized: bool=man.has("strike_seq_v70") and \
        man.has("hit_seq_v70")
    var has_original: bool=false
    if synchronized:
        has_original=_synced_action_v70(model,man)
        if not has_original:
            # A new attack or hit is triggered by an event counter, never
            # by a repeatedly decremented animation timer.
            var locomotion: Dictionary=state.duplicate()
            locomotion["attacking"]=false
            locomotion["hit"]=false
            has_original=_play_original_animation(model,locomotion)
    else:
        has_original=_play_original_animation(model,state)
    # The imported glTF already contains limb animation. Keep a subtle
    # complementary torso displacement, without overriding its keyed bones.
    model.position=(state["offset"] as Vector3)*(0.38 if has_original else 1.0)
    model.rotation=(state["rotation"] as Vector3)*(0.32 if has_original else 1.0)
    if has_original:return
    # Fallback for a future unrigged model; never overwrite actual
    # imported GLB AnimationPlayer poses with procedural bone rotations.
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
