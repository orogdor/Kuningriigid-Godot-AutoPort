extends RefCounted
## 0.30 Visual street links use exactly the same physical 0.26 gate
## selection as worker/haul routing. View-only LOD/cache state stays out
## of JSON and does not alter simulated paths or economic tick rules.
const Transit=preload("res://scripts/district_transit_v26.gd")
const Continuous=preload("res://scripts/continuous_city_v27.gd")
const Terrain=preload("res://scripts/continuous_terrain_v28.gd")

static func detail_level(focus: Vector3,center: Vector3) -> int:
    var dist: float=Vector2(focus.x-center.x,focus.z-center.z).length()
    if dist<195.0:return 2
    if dist<335.0:return 1
    return 0

static func resource_limit(level: int) -> int:
    if level>=2:return 14
    if level==1:return 5
    return 0

static func static_signature(state: Dictionary,world: Dictionary) -> String:
    # Do not include worker x/z, foot traffic, resources, population or
    # turn counters. Only durable obstacles and crossings change gate routes.
    var records: Array=[]
    for b in state.get("buildings",[]):
        if float(b.get("hp",1.0))<=0.0:continue
        records.append([String(b.get("district","")),float(b.get("x",0)),
            float(b.get("z",0)),float(b.get("hp",1.0))>0.0])
    var bridges: Array=[]
    bridges.append(state.get("detail_sim",{}).get("bridges",[]))
    var surfaces: Dictionary=state.get("transport_v26",{}).get("surfaces",{})
    var keys: Array=surfaces.keys()
    keys.sort()
    for key in keys:
        bridges.append([key,surfaces[key].get("bridges",[])])
    return JSON.stringify([world.get("seed",0),records,bridges])

static func connections(state: Dictionary,world: Dictionary,
        anchor: Vector2i,tiles: Array[Vector2i]) -> Array:
    var result: Array=[]
    for tile in tiles:
        var from_id: String=Transit.key(tile.x,tile.y)
        for dir in [Vector2i(1,0),Vector2i(0,1)]:
            var other: Vector2i=tile+dir
            if not tiles.has(other):continue
            var to_id: String=Transit.key(other.x,other.y)
            var walker: Dictionary={"district":from_id,"x":0.0,"z":0.0,"route":[]}
            var gate: Dictionary=Transit._choose_gate(state,walker,to_id)
            if gate.is_empty():continue
            var local_a: Vector2=gate["start"]
            var local_b: Vector2=gate["end"]
            var shift_a: Vector3=Continuous.offset(tile,anchor)
            var shift_b: Vector3=Continuous.offset(other,anchor)
            var a:=shift_a+Vector3(local_a.x,0.0,local_a.y)
            var b:=shift_b+Vector3(local_b.x,0.0,local_b.y)
            # The 0.26 A* gate always spans exactly 20 world meters.
            var surface_a: float=Terrain.height(world,tile,local_a.x,local_a.y)
            var surface_b: float=Terrain.height(world,other,local_b.x,local_b.y)
            var y: float=(surface_a+surface_b)*0.5+0.17
            var midpoint: Vector3=(a+b)*0.5
            midpoint.y=y
            result.append({"from":from_id,"to":to_id,"gate_a":local_a,
                "gate_b":local_b,"middle":midpoint,"length":a.distance_to(b),
                "east_west":dir.x!=0})
    return result
