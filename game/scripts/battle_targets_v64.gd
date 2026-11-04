extends RefCounted
## AutoPort 0.64: transient spatial index for attacks on individual soldiers.
## Uses the same Stone Age V91 per-man hit rules. No indices are written to
## battle saves; each simulation step rebuilds after movement/projectiles.
const Stones58=preload("res://scripts/projectiles_v58.gd")
const CELL_SIZE: float=8.0

static func _point(entry: Dictionary) -> Vector2:
    return Vector2(float(entry.get("x",0.0)),float(entry.get("z",0.0)))

static func _cell(p: Vector2) -> Vector2i:
    return Vector2i(int(floor(p.x/CELL_SIZE)),int(floor(p.y/CELL_SIZE)))

static func build(battle: Dictionary) -> Dictionary:
    var index: Dictionary={}
    var rank: int=0
    # Retain the original fighter/individual insertion order so equidistant
    # enemies are targeted exactly like the legacy linear search.
    for fighter in battle.get("fighters",[]):
        var team: int=int(fighter.get("team",-1))
        if not index.has(team):index[team]={}
        var grid: Dictionary=index[team]
        for man in fighter.get("men",[]):
            if float(man.get("hp",0.0))<=0.0 or bool(man.get("escaped",false)):
                continue
            var cell: Vector2i=_cell(_point(man))
            if not grid.has(cell):grid[cell]=[]
            grid[cell].append({"person":man,"rank":rank})
            rank+=1
    return index

static func nearest(index: Dictionary,attacker: Dictionary,
        own_team: int,reach: float,terrain: Dictionary={},
        metrics: Dictionary={}) -> Dictionary:
    var grid: Dictionary=index.get(1-own_team,{})
    if grid.is_empty() or reach<=0.0:return {}
    var p: Vector2=_point(attacker)
    var base: Vector2i=_cell(p)
    var radius: int=int(ceil(reach/CELL_SIZE))+1
    var distance2: float=reach*reach
    var earliest: int=2147483647
    var nearest_man: Dictionary={}
    for dz in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            var cell: Vector2i=base+Vector2i(dx,dz)
            for entry in grid.get(cell,[]):
                if not metrics.is_empty():
                    metrics["candidate_checks"]=int(metrics.get("candidate_checks",0))+1
                var enemy: Dictionary=entry["person"]
                if float(enemy.get("hp",0.0))<=0.0 or \
                        bool(enemy.get("escaped",false)):continue
                var q: Vector2=_point(enemy)
                var d2: float=p.distance_squared_to(q)
                var rank: int=int(entry["rank"])
                # The old engine tests dist < reach and chooses the first
                # soldier on exact distance ties.
                if nearest_man.is_empty():
                    if d2>=reach*reach:continue
                else:
                    if d2>distance2 or (d2==distance2 and rank>=earliest):
                        continue
                if not terrain.is_empty() and not Stones58.clear_line(p,q,terrain):
                    continue
                nearest_man=enemy
                distance2=d2
                earliest=rank
    return nearest_man
