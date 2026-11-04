extends RefCounted
## V61 lightweight model-safe tactical animation. Uses the real imported
## Three.js soldier GLB instances, without replacing them with proxy cubes.
## These procedural poses do not pretend to be skeletal/rigged animations.
const STRIKE_SECONDS: float=0.36
const HIT_SECONDS: float=0.36

static func pose(man: Dictionary,kind: String) -> Dictionary:
    var phase: float=float(man.get("anim_phase",0.0))
    var moving: bool=bool(man.get("moving",false))
    var attack: float=clampf(float(man.get("attack_anim",0.0)),0.0,STRIKE_SECONDS)
    var hit: float=clampf(float(man.get("hit_anim_v61",0.0)),0.0,HIT_SECONDS)
    var gait: float=sin(phase) if moving else 0.0
    var strike: float=sin((1.0-attack/STRIKE_SECONDS)*PI) if attack>0.0 else 0.0
    var recoil: float=hit/HIT_SECONDS
    var bob: float=0.12*absf(gait) if moving else 0.0
    # Weapon classes differ visually even without a skeleton: spearmen
    # lean forward in a thrust, axemen swing diagonally, slingers twist.
    var pitch: float=-0.10 if moving else 0.0
    var roll: float=0.06*gait
    var twist: float=0.0
    var advance: float=0.0
    if kind=="spearman":
        pitch-=0.38*strike
        advance=0.45*strike
    elif kind=="axeman":
        pitch-=0.19*strike
        roll+=0.30*strike
        twist=0.20*strike
        advance=0.18*strike
    elif kind=="slinger":
        twist=0.55*strike
        roll-=0.16*strike
    pitch+=0.25*recoil
    roll+=0.11*recoil
    bob+=0.10*recoil
    return {"offset":Vector3(0.0,bob,-advance),
        "rotation":Vector3(pitch,twist,roll),
        "hit":hit>0.0,"attacking":attack>0.0}

static func apply(model: Node3D,man: Dictionary,kind: String) -> void:
    if model==null:return
    var state: Dictionary=pose(man,kind)
    model.position=state["offset"]
    model.rotation=state["rotation"]
