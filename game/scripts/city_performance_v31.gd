extends RefCounted
## 0.31: CPU-budget-aware resolution hysteresis and on-device diagnostics.
## Headless tests validate decisions, not physical device FPS/GPU throughput.
const LOW_FPS: float=28.0
const HIGH_FPS: float=55.0
const LOW_SECONDS: int=3
const HIGH_SECONDS: int=5

static func viewport_size(level: int) -> Vector2i:
    if level<=0:return Vector2i(600,375)
    if level==1:return Vector2i(720,450)
    return Vector2i(960,600)

static func next_quality(fps: float,previous: Dictionary) -> Dictionary:
    var level: int=clampi(int(previous.get("level",1)),0,2)
    var low: int=int(previous.get("low",0))
    var high: int=int(previous.get("high",0))
    if fps<=0.0 or not is_finite(fps):
        return {"level":level,"low":0,"high":0}
    if fps<LOW_FPS:
        low+=1
        high=0
    elif fps>HIGH_FPS:
        high+=1
        low=0
    else:
        low=0
        high=0
    if low>=LOW_SECONDS and level>0:
        level-=1
        low=0
    if high>=HIGH_SECONDS and level<2:
        level+=1
        high=0
    return {"level":level,"low":low,"high":high}

static func level_name(level: int) -> String:
    match level:
        0:return "Säästlik"
        1:return "Tasakaalustatud"
        _:return "Kõrge"

static func estimate_draw_reduction(wood: int,stone: int) -> Dictionary:
    # Prior rendering: 2 nodes per tree and 3 rocks per stone deposit.
    # Batched rendering: up to one call for each of trunk, canopy and rock.
    var before: int=maxi(0,wood)*2+maxi(0,stone)*3
    var after: int=(2 if wood>0 else 0)+(1 if stone>0 else 0)
    return {"old_meshes":before,"batched_draws":after,
        "saved_draws":maxi(0,before-after)}
