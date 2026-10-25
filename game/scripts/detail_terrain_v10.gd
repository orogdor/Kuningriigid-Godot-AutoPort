extends RefCounted
## AutoPort 0.10: one shared deterministic terrain/river model for
## visible 3D meshes, foot traffic, slopes, crossings and bridge placement.
## It is a scoped approximation; not yet Three.js detail-height parity.
const CELL: float=10.0
const FORDS: Array[int]=[-6,0,6]
const BRIDGE_SLOTS: Array[int]=[-3,3]
const BRIDGE_COST: Dictionary={"wood":28.0,"stone":18.0}
const RIVER_NEAR: float=18.0
const RIVER_FAR: float=32.0
const MAX_STEP: float=4.6

static func height_at(sim: Dictionary, x: float, z: float) -> float:
    var biome: String=String(sim.get("terrain","plains"))
    if biome=="plains" or biome=="river" or biome=="forest" or biome=="coast":
        # Subtle ground undulation but flat building core.
        var core: float=clampf((maxf(absf(x),absf(z))-42.0)/35.0,0.0,1.0)
        return core*(0.9*sin(x*0.031+0.4)*cos(z*0.043))
    if biome=="hills":
        var range_factor: float=clampf((maxf(absf(x),absf(z))-36.0)/30.0,0.0,1.0)
        return range_factor*(7.2*sin(x*0.052)*cos(z*0.044)+2.1*sin((x+z)*0.088))
    return 0.0

static func river_at(sim: Dictionary, x: float, z: float) -> bool:
    return bool(sim.get("river",false)) or String(sim.get("terrain",""))=="river"

static func river_lane(sim: Dictionary, x: float, z: float) -> bool:
    if not river_at(sim,x,z):return false
    return z>=RIVER_NEAR and z<=RIVER_FAR

static func has_bridge(sim: Dictionary, x_cell: int) -> bool:
    for bridge in sim.get("bridges",[]):
        if int(bridge.get("x",-999))==x_cell:return true
    return false

static func crossing_kind(sim: Dictionary, x_cell: int) -> String:
    if x_cell in FORDS:return "ford"
    if has_bridge(sim,x_cell):return "bridge"
    return ""

static func can_place_bridge(sim: Dictionary, x_cell: int) -> bool:
    return river_at(sim,0,0) and x_cell in BRIDGE_SLOTS and not has_bridge(sim,x_cell)

static func blocked_cell(sim: Dictionary, c: Vector2i) -> bool:
    if not river_lane(sim,c.x*CELL,c.y*CELL):return false
    return crossing_kind(sim,c.x)==""

static func too_steep(sim: Dictionary, previous: Vector2i, next: Vector2i) -> bool:
    var a: float=height_at(sim,previous.x*CELL,previous.y*CELL)
    var b: float=height_at(sim,next.x*CELL,next.y*CELL)
    return absf(a-b)>MAX_STEP

static func elevation(sim: Dictionary, x: float, z: float) -> float:
    if river_lane(sim,x,z):
        if crossing_kind(sim,int(roundf(x/CELL)))=="bridge":
            return maxf(0.55,height_at(sim,x,z)+0.55)
        return -0.30
    return height_at(sim,x,z)

static func bridge_slots() -> Array[int]:
    return BRIDGE_SLOTS.duplicate()
