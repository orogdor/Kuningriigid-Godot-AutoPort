extends RefCounted
## AutoPort 0.46: deterministic and render-only dense city LOD partition.
const V45=preload("res://scripts/detail_neighbor_buildings_v45.gd")
const MAX_MOBILE: int=8
const MAX_DESKTOP: int=12

static func model_budget(is_mobile: bool) -> int:
    return MAX_MOBILE if is_mobile else MAX_DESKTOP

static func active(distance: float,zoom: float,count: int) -> bool:
    return count>V45.MAX_DETAILED_BUILDINGS and distance<=V45.FULL_DISTANCE \
        and zoom<=V45.FULL_CAMERA_ZOOM

static func split(buildings: Array,direction: Vector2i,count: int) -> Dictionary:
    var ranked: Array=[]
    for i in range(buildings.size()):
        var b: Dictionary=buildings[i]
        var score: float=float(b.get("x",0.0))*float(direction.x)+\
            float(b.get("z",0.0))*float(direction.y)
        if String(b.get("type",""))=="hall":score+=100000.0
        ranked.append({"i":i,"score":score})
    ranked.sort_custom(func(a,b):
        if is_equal_approx(float(a["score"]),float(b["score"])):
            return int(a["i"])<int(b["i"])
        return float(a["score"])>float(b["score"]))
    var selected: Dictionary={}
    for i in range(mini(ranked.size(),clampi(count,0,32))):
        selected[int(ranked[i]["i"])]=true
    var models: Array=[]
    var lod: Array=[]
    for i in range(buildings.size()):
        if selected.has(i):
            models.append({"index":i,"data":buildings[i]})
        else:
            lod.append(buildings[i])
    return {"models":models,"lod":lod}
