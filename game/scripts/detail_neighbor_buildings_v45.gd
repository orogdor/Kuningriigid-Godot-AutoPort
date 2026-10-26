extends RefCounted
## AutoPort 0.45: automatically choose the exact existing Godot building
## meshes for a nearby city preview, otherwise batch into instanced LOD.
## Draw-only decisions. Do not mutate city, simulation or resource stock.
const FULL_DISTANCE: float=195.0
const FULL_CAMERA_ZOOM: float=205.0
const MAX_DETAILED_BUILDINGS: int=18

static func detailed(distance_to_center: float,zoom: float,number: int) -> bool:
    return number>0 and number<=MAX_DETAILED_BUILDINGS \
        and distance_to_center<=FULL_DISTANCE and zoom<=FULL_CAMERA_ZOOM

static func signature(buildings: Array,kind: String,
        detailed_view: bool,definitions: Dictionary) -> String:
    var result: Array=["real" if detailed_view else "lod"]
    for building in buildings:
        var b: Dictionary=building
        if String(b.get("district",""))!=kind or float(b.get("hp",1.0))<=0.0:
            continue
        var type_name: String=String(b.get("type","house"))
        var props: Array=[type_name,float(b.get("x",0)),float(b.get("z",0)),
            int(b.get("rotation",0)),bool(b.get("ready",false))]
        if detailed_view and not bool(b.get("ready",false)):
            # Building materials and stage are visual data, unlike timer
            # progress that may change on every individual simulation tick.
            props.append(float(b.get("progress",0.0)))
            props.append(b.get("supply_delivered",{}))
        result.append(props)
    return JSON.stringify(result)
