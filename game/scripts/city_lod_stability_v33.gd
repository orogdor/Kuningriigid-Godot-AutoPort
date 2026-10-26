extends RefCounted
## 0.33 Camera-stable LOD for multi-district towns. A 20m hysteresis
## avoids regenerating high-detail buildings each time camera position
## drifts across 195m/335m thresholds. Visibility has a 35m hysteresis.
## All decisions are render-only; simulation state is never changed.
const LOD=preload("res://scripts/city_building_lod_v32.gd")
const NEAR: float=195.0
const FAR: float=335.0
const BAND: float=20.0
const VIS_BAND: float=35.0

static func detail(distance: float,zoom: float,previous: int=-1) -> int:
    if previous<0:return LOD.level_for_distance(distance,zoom)
    var level: int=clampi(previous,0,2)
    # A wide overview never generates full nearby building geometry.
    if zoom>=420.0:return mini(level,1)
    if level==2:
        if distance>FAR+BAND or zoom>=720.0:level=0
        elif distance>NEAR+BAND or zoom>=400.0:level=1
    elif level==1:
        if distance<NEAR-BAND and zoom<380.0:level=2
        elif distance>FAR+BAND or zoom>=720.0:level=0
    else:
        if distance<NEAR-BAND and zoom<380.0:level=2
        elif distance<FAR-BAND and zoom<680.0:level=1
    return level

static func displayed(distance: float,zoom: float,active: bool,previous: Variant=null) -> bool:
    if active:return true
    if previous==null:return LOD.visible_at(distance,zoom,false)
    var edge: float=maxf(515.0,zoom*1.6+195.0)
    if bool(previous):return distance<=edge+VIS_BAND
    return distance<edge-VIS_BAND

static func state(distance: float,zoom: float,active: bool,
        prev_level: int=-1,prev_visible: Variant=null) -> Dictionary:
    return {"level":detail(distance,zoom,prev_level),
        "visible":displayed(distance,zoom,active,prev_visible)}

static func low_detail_policy(level: int) -> String:
    # Medium LOD retains hidden detailed models for an immediate return to
    # the center. Distant LOD frees them to cap memory in multi-tile cities.
    if level<=0:return "release"
    if level==1:return "retain_hidden"
    return "full"

static func view_signature(tiles: Array,states: Array) -> String:
    var pieces: Array[String]=[]
    for i in range(mini(tiles.size(),states.size())):
        var entry: Dictionary=states[i]
        pieces.append(str(tiles[i])+":"+str(entry.get("visible",false))+":"+str(entry.get("level",0)))
    return "|".join(pieces)
