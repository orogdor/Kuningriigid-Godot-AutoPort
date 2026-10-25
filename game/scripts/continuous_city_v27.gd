extends RefCounted
## 0.27 composite 3D city: owned world tiles are 160m adjacent squares.
## The 0.26 physical gate path is 70m+20m+70m, exactly one 160m span.
const Districts=preload("res://scripts/world_districts_v25.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const TILE_SPAN: float=160.0
const HALF_TILE: float=80.0

static func active(world: Dictionary,city: Dictionary,anchor: Vector2i) -> bool:
    return Districts.owns(city,world,anchor.x,anchor.y) and Districts.cells(city,world).size()>1

static func offset(tile: Vector2i,anchor: Vector2i) -> Vector3:
    return Vector3(float(tile.x-anchor.x)*TILE_SPAN,0.0,float(tile.y-anchor.y)*TILE_SPAN)

static func district_key(tile: Vector2i,world: Dictionary) -> String:
    return "" if tile==Districts.origin(world) else Districts.key(tile)

static func visible(world: Dictionary,city: Dictionary,anchor: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i]=[]
    var allowed: Array[Vector2i]=Districts.cells(city,world)
    for p in allowed:
        if abs(p.x-anchor.x)<=4 and abs(p.y-anchor.y)<=4:
            result.append(p)
    return result

static func at_position(world: Dictionary,city: Dictionary,anchor: Vector2i,point: Vector3) -> Vector2i:
    var dx: int=int(floor((point.x+HALF_TILE)/TILE_SPAN))
    var dy: int=int(floor((point.z+HALF_TILE)/TILE_SPAN))
    var tile:=Vector2i(anchor.x+dx,anchor.y+dy)
    return tile if Districts.owns(city,world,tile.x,tile.y) else Vector2i(-1,-1)

static func local_position(tile: Vector2i,anchor: Vector2i,point: Vector3) -> Vector3:
    return point-offset(tile,anchor)

static func bounds(tiles: Array[Vector2i],anchor: Vector2i) -> Dictionary:
    var xmin: float=-HALF_TILE
    var xmax: float=HALF_TILE
    var zmin: float=-HALF_TILE
    var zmax: float=HALF_TILE
    for p in tiles:
        var o: Vector3=offset(p,anchor)
        xmin=minf(xmin,o.x-HALF_TILE)
        xmax=maxf(xmax,o.x+HALF_TILE)
        zmin=minf(zmin,o.z-HALF_TILE)
        zmax=maxf(zmax,o.z+HALF_TILE)
    return {"xmin":xmin,"xmax":xmax,"zmin":zmin,"zmax":zmax,
        "midpoint":Vector3((xmin+xmax)*0.5,0.0,(zmin+zmax)*0.5),
        "span":maxf(xmax-xmin,zmax-zmin)}

static func tile_biome(world: Dictionary,tile: Vector2i) -> String:
    return String(World.cell(world,tile.x,tile.y).get("biome","plains"))
