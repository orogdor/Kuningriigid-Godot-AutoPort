extends RefCounted
## AutoPort 0.22: deterministic rotated door-to-path interface.
## Entrances are 20 m from each building center on the 10 m path grid.
## Nothing is persisted or deducted: rotation belongs to v0.21 building data.
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const DOOR_OFFSET: float=20.0
const FAILED: Vector2=Vector2(99999.0,99999.0)

static func front(building: Dictionary) -> Vector2:
    var degrees: int=posmod(int(building.get("rotation",0)),360)
    match posmod(int(round(float(degrees)/90.0)),4):
        0:return Vector2(0.0,1.0)
        1:return Vector2(1.0,0.0)
        2:return Vector2(0.0,-1.0)
        _:return Vector2(-1.0,0.0)

static func center(building: Dictionary) -> Vector2:
    return Vector2(float(building.get("x",0.0)),float(building.get("z",0.0)))

static func entrance(building: Dictionary) -> Vector2:
    return center(building)+front(building)*DOOR_OFFSET

static func candidates(building: Dictionary) -> Array[Vector2]:
    # Prefer the true front door, then emergency/servicing approaches if
    # another building or steep riverbank prevents access to the main door.
    var main: Vector2=front(building)
    var right: Vector2=Vector2(main.y,-main.x)
    var c: Vector2=center(building)
    return [c+main*DOOR_OFFSET,c+right*DOOR_OFFSET,
        c-right*DOOR_OFFSET,c-main*DOOR_OFFSET]

static func reachable(state: Dictionary, index: int, start: Vector2, home_index: int=0) -> Vector2:
    var buildings: Array=state.get("buildings",[])
    if index<0 or index>=buildings.size():return FAILED
    for p in candidates(buildings[index]):
        if absf(p.x)>float(Paths.EXTENT)*Paths.STEP or absf(p.y)>float(Paths.EXTENT)*Paths.STEP:continue
        if Paths.blocked(state,Paths.grid(p),home_index):continue
        if Paths.find_path(state,start,p,home_index).is_empty():continue
        return p
    return FAILED
