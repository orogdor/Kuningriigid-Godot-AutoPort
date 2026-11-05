extends RefCounted
## V80: one strategic-coordinate -> detail-3D projection for scouts/armies.
## Standalone wilderness uses 225 x 195 m (Three.js V123), while connected
## 0.27 city districts render exactly 160 x 160 m tiles. The simulation,
## world atlas, routes and saved coordinates are unaffected.
const WORLD_WIDTH: float=225.0
const WORLD_DEPTH: float=195.0
const CITY_SPAN: float=160.0

static func owner(pose: Dictionary) -> Vector2i:
    # Atlas tiles are centred on integer c/r; make the shared half-tile edge
    # belong to exactly one tile (the positive neighbour), never both.
    return Vector2i(int(floor(float(pose.get("c",-999))+0.5)),
        int(floor(float(pose.get("r",-999))+0.5)))

static func span(combined_city: bool) -> Vector2:
    return Vector2(CITY_SPAN,CITY_SPAN) if combined_city else \
        Vector2(WORLD_WIDTH,WORLD_DEPTH)

static func local(pose: Dictionary,anchor: Vector2i,
        combined_city: bool) -> Vector2:
    var step: Vector2=span(combined_city)
    return Vector2((float(pose.get("c",-999))-float(anchor.x))*step.x,
        (float(pose.get("r",-999))-float(anchor.y))*step.y)

static func visible(pose: Dictionary,anchor: Vector2i,
        combined_city: bool,displayed: Array[Vector2i]) -> bool:
    var tile: Vector2i=owner(pose)
    if not combined_city:return tile==anchor
    # Multi-district terrain lives in ONE shared viewport. World actors may
    # move across all displayed districts, not just the selected anchor tile.
    return displayed.has(tile)

static func in_owner_local(pose: Dictionary,anchor: Vector2i,
        combined_city: bool,draw_point: Vector2) -> Vector2:
    var tile: Vector2i=owner(pose)
    var step: Vector2=span(combined_city)
    return draw_point-Vector2(float(tile.x-anchor.x)*step.x,
        float(tile.y-anchor.y)*step.y)

static func sector(pose: Dictionary) -> Vector2i:
    # The scout uses the same 8x8 sub-cell indices at either camera scale.
    var c: float=float(pose.get("c",0.0))
    var r: float=float(pose.get("r",0.0))
    return Vector2i(clampi(int(floor(fposmod(c+0.5,1.0)*8.0)),0,7),
        clampi(int(floor(fposmod(r+0.5,1.0)*8.0)),0,7))
