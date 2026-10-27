extends RefCounted
## Shared web-inspired visual palette for Godot atlas and detail terrain.
## Source: atlas-biomes-v47.js, landscape-material-v85.js,
## continuous-landscape-visual.js. Does not change economic/map data.
const World=preload("res://scripts/world_gen_v06.gd")
const DEEP: Color=Color("#1d4a57")
const SHALLOW: Color=Color("#62a6a3")
const GRASS: Color=Color("#9bad6b")
const FOREST: Color=Color("#557c51")
const ROCK: Color=Color("#92968d")
const SAND: Color=Color("#c5b487")
const RIVER: Color=Color("#2d7584")

static func noise(seed: int,x: int,z: int) -> float:
    var h: int=((seed*374761393) ^ (x*668265263) ^ (z*1274126177)) & 0x7fffffff
    h=(h ^ (h >> 13))*274763641 & 0x7fffffff
    return float(h)/2147483647.0

static func coastline(world: Dictionary,c: int,r: int) -> bool:
    var tile: Dictionary=World.cell(world,c,r)
    if tile.is_empty():return false
    var land: bool=bool(tile.get("land",false))
    for shift in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
        var next: Dictionary=World.cell(world,c+shift.x,r+shift.y)
        if not next.is_empty() and bool(next.get("land",false))!=land:
            return true
    return false

static func color(world: Dictionary,c: int,r: int) -> Color:
    var tile: Dictionary=World.cell(world,c,r)
    if tile.is_empty():return DEEP
    var land: bool=bool(tile.get("land",false))
    var biome: String=String(tile.get("biome","sea"))
    var value: Color=GRASS
    var coastal: bool=coastline(world,c,r)
    if not land:
        value=SHALLOW.lerp(DEEP,0.20) if coastal else DEEP.lerp(SHALLOW,0.17)
        if float(tile.get("h",0.0))< -15.0:value=value.lerp(DEEP,0.35)
    elif biome=="forest":
        value=FOREST
    elif biome=="hills":
        value=ROCK.lerp(Color("#b0aba0"),
            clampf((float(tile.get("h",0))-26.0)/40.0,0.0,0.5))
    if land and coastal:
        value=value.lerp(SAND,0.64 if biome!="hills" else 0.2)
    if land and bool(tile.get("river",false)):
        value=value.lerp(Color("#6e6a4c"),0.24)
    var variation: float=(noise(int(world.get("seed",82026)),c,r)-0.5)*0.15
    return value.lerp(Color.WHITE,variation) if variation>0.0 else value.lerp(Color.BLACK,-variation)

static func detail(world: Dictionary,tile: Vector2i,x: float,z: float) -> Color:
    var result: Color=color(world,tile.x,tile.y)
    var grain: float=noise(int(world.get("seed",82026)),
        tile.x*2048+int(floor(x*0.11)),
        tile.y*2048+int(floor(z*0.11)))
    var tint: float=(grain-0.5)*0.15+sin(x*0.1)*cos(z*0.07)*0.045
    return result.lerp(Color("#e8d4a0"),tint) if tint>0.0 else result.lerp(Color("#40503c"),-tint)
