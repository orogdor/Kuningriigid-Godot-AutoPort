extends RefCounted
## AutoPort 0.47: only actual owned cities supply neighboring 3D models.
## This is read-only; capital and satellite never share inventories or workers.
const Districts=preload("res://scripts/world_districts_v25.gd")

static func satellite_position(site: Dictionary,world: Dictionary) -> Vector2i:
    if site.is_empty() or int(site.get("seed",-1))!=int(world.get("seed",-2)):
        return Vector2i(-1,-1)
    return Vector2i(int(site.get("c",-1)),int(site.get("r",-1)))

static func source(world: Dictionary,tile: Vector2i,capital: Dictionary,
        satellite: Dictionary,satellite_tile: Vector2i) -> Dictionary:
    if tile==satellite_tile and satellite_tile.x>=0 and not satellite.is_empty():
        return {"town":satellite,"district":""}
    if not capital.is_empty() and Districts.owns(capital,world,tile.x,tile.y):
        return {"town":capital,"district":"" if tile==Districts.origin(world) else Districts.key(tile)}
    return {}
