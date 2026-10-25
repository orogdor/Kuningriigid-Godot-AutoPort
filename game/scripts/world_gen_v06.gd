extends RefCounted
## AutoPort 0.6: deterministic 220x165 world layout.
## Polygon layout + separated continental starting sites are translated from
## Kuningriigid/continent-map.js. Elevation/drainage are an initial Godot
## approximation, not yet JS height/drainage parity.
const COLS: int = 220
const ROWS: int = 165
const TILE: float = 50.0
const ORIGIN_X: float = -650.0
const ORIGIN_Z: float = -550.0
const WORLD_WIDTH: float = COLS * TILE
const WORLD_DEPTH: float = ROWS * TILE
const MIN_START_DISTANCE: float = 28.0

static func random01(seed_state: Array) -> float:
    seed_state[0] = (int(seed_state[0]) * 1664525 + 1013904223) & 0xffffffff
    return float(seed_state[0]) / 4294967296.0

static func signed_distance(u: float, v: float, poly: Array) -> float:
    var inside: bool = false
    var minimum: float = INF
    for i in range(poly.size()):
        var j: int = (i + poly.size() - 1) % poly.size()
        var a: Vector2 = poly[i]
        var c: Vector2 = poly[j]
        if ((a.y > v) != (c.y > v)) and u < (c.x - a.x) * (v - a.y) / (c.y - a.y) + a.x:
            inside = not inside
        var delta: Vector2 = c - a
        var length_squared: float = delta.length_squared()
        var t: float = clampf((Vector2(u,v) - a).dot(delta) / length_squared,0.0,1.0) if length_squared > 0.0 else 0.0
        minimum = minf(minimum,(Vector2(u,v) - a - delta*t).length())
    return minimum if inside else -minimum

static func separated_starts(polygons: Array, centers: Array) -> Array:
    var candidates: Array = []
    for r in range(5, ROWS - 5, 2):
        for c in range(5, COLS - 5, 2):
            var u: float = (c + 0.5) / float(COLS)
            var v: float = (r + 0.5) / float(ROWS)
            var interior: float = -1.0
            for poly in polygons:
                interior = maxf(interior,signed_distance(u,v,poly))
            if interior > 0.029:
                candidates.append({"c":c,"r":r,"interior":interior})
    if candidates.is_empty():
        return []
    var selected: Array = []
    for target_index in range(4):
        var target: Variant = centers[target_index] if target_index < 2 and target_index < centers.size() else null
        var best: Variant = null
        var score: float = -INF
        for p in candidates:
            var nearest: float = INF
            for q in selected:
                nearest = minf(nearest,Vector2(p["c"]-q["c"],p["r"]-q["r"]).length())
            if nearest < MIN_START_DISTANCE:
                continue
            var u: float = (float(p["c"])+0.5) / COLS
            var v: float = (float(p["r"])+0.5) / ROWS
            var cd: float = Vector2(u,v).distance_to(target) if target is Vector2 else 0.0
            var potential: float
            if target_index == 0:
                potential = -cd*75.0 + float(p["interior"])*20.0
            elif target_index == 1 and target is Vector2:
                potential = -cd*100.0 + float(p["interior"])*25.0
            else:
                potential = nearest + float(p["interior"])*35.0
            if potential > score:
                best=p
                score=potential
        if best == null:
            return selected
        selected.append({"c":int(best["c"]),"r":int(best["r"])})
    return selected

static func layout(seed: int, with_islands: bool = true) -> Dictionary:
    var state: Array = [(seed ^ 0x9e3779b9) & 0xffffffff]
    var count: int = 2 + int(floor(random01(state)*3.0))
    var rotation: float = random01(state)*PI*2.0
    var centers: Array = []
    var polygons: Array = []
    for i in range(count):
        var angle: float = rotation + float(i)*TAU/count
        var x: float = 0.5+cos(angle)*(0.25 if count == 2 else 0.28)
        var y: float = 0.5+sin(angle)*0.23
        centers.append(Vector2(x,y))
        var rx: float = 0.18 if count == 2 else 0.145
        var ry: float = 0.24 if count == 2 else 0.175
        var p1: float = random01(state)*6.28
        var p2: float = random01(state)*6.28
        var p3: float = random01(state)*6.28
        var stretch: float = 0.88+random01(state)*0.22
        var poly: Array = []
        for k in range(40):
            var a: float = k*TAU/40.0
            var shape: float = 1.0+0.16*sin(a*3.0+p1)+0.10*cos(a*5.0+p2)+0.06*sin(a*7.0+p3)
            poly.append(Vector2(clampf(x+cos(a)*rx*shape*stretch,0.045,0.955),
                clampf(y+sin(a)*ry*shape/stretch,0.045,0.955)))
        polygons.append(poly)
    var bridges: int = 0
    for i in range(1 if count == 2 else count-1):
        if bridges >= (1 if count == 2 else count-2):
            break
        if random01(state) > 0.45:
            continue
        var start: Vector2 = centers[i]
        var finish: Vector2 = centers[(i+1)%count]
        var displacement: Vector2 = finish-start
        var distance: float = displacement.length()
        var normal: Vector2 = Vector2(-displacement.y,displacement.x)/distance
        var width: float = 0.012+random01(state)*0.008
        var bend: float = (random01(state)-0.5)*0.07
        var middle: Vector2 = (start+finish)*0.5+normal*bend
        polygons.append([start+normal*width,middle+normal*width,finish+normal*width,
            finish-normal*width,middle-normal*width,start-normal*width])
        bridges += 1
    var island_centers: Array = []
    if with_islands:
        for attempt in range(300):
            if island_centers.size() >= 16:
                break
            var x: float = 0.06+random01(state)*0.88
            var y: float = 0.07+random01(state)*0.86
            var valid: bool = true
            for poly in polygons:
                if signed_distance(x,y,poly) > -0.027:
                    valid=false
                    break
            if not valid:
                continue
            for p in island_centers:
                if Vector2(x,y).distance_to(p) < 0.05:
                    valid=false
                    break
            if not valid:
                continue
            var radius: float = 0.009+random01(state)*0.014
            var poly: Array = []
            for k in range(9):
                var a: float = k*TAU/9.0
                var rad: float = radius*(0.8+random01(state)*0.4)
                poly.append(Vector2(x+cos(a)*rad,y+sin(a)*rad))
            polygons.append(poly)
            island_centers.append(Vector2(x,y))
    var starts: Array = separated_starts(polygons.slice(0,count),centers)
    return {"count":count,"centers":centers,"polygons":polygons,"bridges":bridges,
        "starts":starts,"islands":island_centers,"seed":seed}

static func coast_distance(layout_data: Dictionary, u: float, v: float) -> float:
    var d: float = -1.0
    for polygon in layout_data["polygons"]:
        d = maxf(d,signed_distance(u,v,polygon))
    return d

static func terrain(seed: int, with_islands: bool = true) -> Dictionary:
    var landform: Dictionary = layout(seed,with_islands)
    var coast_noise := FastNoiseLite.new()
    coast_noise.seed=seed
    coast_noise.frequency=0.034
    var relief_noise := FastNoiseLite.new()
    relief_noise.seed=seed ^ 1432
    relief_noise.frequency=0.009
    var cells: Array = []
    var land_count: int = 0
    var mountain_count: int = 0
    for r in range(ROWS):
        for c in range(COLS):
            var u: float = (c+0.5)/COLS
            var v: float = (r+0.5)/ROWS
            var coast: float = coast_distance(landform,u,v)
            coast += coast_noise.get_noise_2d(c,r)*0.008
            var land: bool = coast > 0.0
            var height: float = -minf(35.0,absf(coast)*900.0)
            var mountain: bool = false
            var forest: bool = false
            if land:
                land_count += 1
                var rough: float = (relief_noise.get_noise_2d(c,r)+1.0)*0.5
                var ridge: float = (coast_noise.get_noise_2d(c*4.0,r*4.0)+1.0)*0.5
                var arc: float = 0.0
                for i in range(landform["centers"].size()):
                    var point: Vector2 = landform["centers"][i]
                    var du: float = (u-point.x)/0.18
                    var dv: float = (v-point.y)/0.22
                    var along: float = du*0.64+dv*0.77
                    var across: float = du*0.77-dv*0.64
                    if absf(along) > 1.4:
                        continue
                    var bend: float = across+0.24*sin(along*2.9+i*1.3)+0.11*sin(along*6.1+i)
                    arc=maxf(arc,exp(-pow(bend/0.29,2.0))*maxf(0.0,1.0-pow(along/1.42,4)))
                height = minf(24.0,coast*810.0)*(0.55+rough*0.48)
                height += clampf(coast*120.0,0.0,1.0)*arc*(13.0+ridge*23.0)
                mountain=height > 30.0
                forest=not mountain and rough > 0.52
                if mountain: mountain_count += 1
            cells.append({"c":c,"r":r,"h":height,"land":land,"mountain":mountain,
                "biome":"sea" if not land else ("hills" if mountain else ("forest" if forest else "plains")),
                "river":false, "river_to":-1, "river_flow":0})
    return {"seed":seed,"cols":COLS,"rows":ROWS,"layout":landform,"cells":cells,
        "land_count":land_count,"mountain_count":mountain_count}
