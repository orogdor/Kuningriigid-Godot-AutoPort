extends RefCounted
## Mirrors the V123 web map: a detail tile is 225 x 195 local units.
const HALF_X: float=112.5
const HALF_Z: float=97.5
const WORLD_ZOOM: float=450.0

static func crossing(focus: Vector3,half: Vector2=Vector2(HALF_X,HALF_Z)) -> Dictionary:
    var offset:=Vector2i.ZERO
    if focus.x>half.x:offset.x=1
    elif focus.x< -half.x:offset.x=-1
    if focus.z>half.y:offset.y=1
    elif focus.z< -half.y:offset.y=-1
    if offset==Vector2i.ZERO:return {}
    return {"delta":offset,"focus":Vector3(
        focus.x-float(offset.x)*half.x*2.0,
        focus.y,focus.z-float(offset.y)*half.y*2.0)}

static func bounded(focus: Vector3,half: Vector2=Vector2(HALF_X,HALF_Z)) -> Vector3:
    return Vector3(clampf(focus.x,-half.x+0.6,half.x-0.6),focus.y,
        clampf(focus.z,-half.y+0.6,half.y-0.6))
