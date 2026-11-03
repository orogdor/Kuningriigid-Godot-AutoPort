extends SceneTree
## v0.52: first playable strategic scout, V258 travel time, save migration,
## traversable route, 2D/3D shared position and turn progression.
const Scene=preload("res://content.tscn")
const Scout=preload("res://scripts/world_scout_v52.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(reason: String) -> void:
    printerr("WORLD_SCOUT_V52 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if absf(Scout.segment_seconds({"c":20,"r":20},{"c":21,"r":20},3.0)-75.0)>0.00001 or \
            absf(Scout.segment_seconds({"c":20,"r":20},{"c":20,"r":21},3.0)-65.0)>0.00001:
        fail("V258 east/south duration differs from original JavaScript")
        return
    if absf(Scout.segment_seconds({"c":20,"r":20},{"c":21,"r":20},3.0,1.5)-50.0)>0.00001:
        fail("V258 road speed multiplier does not match upstream")
        return
    var migrated: Dictionary={"travelDuration":2.0,"travelClock":1.0}
    Scout.rescale_travel(migrated,75.0)
    if absf(float(migrated["travelClock"])-37.5)>0.00001:
        fail("a saved in-flight position jumped when duration changed")
        return
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var map=ui.world_view
    var world: Dictionary=map.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    if scout.is_empty() or not scout["path"].is_empty() or \
            int(scout["seed"])!=int(world["seed"]):
        fail("starting scout was not initialized for the current saved world")
        return
    if map.map_canvas.scout_state.is_empty() or map.terrain_3d.scout_actor==null or \
            not map.terrain_3d.scout_actor.visible:
        fail("new game has no persistent scout on both atlas renderers")
        return
    var start:=Vector2i(int(scout["c"]),int(scout["r"]))
    var target:=Vector2i(-1,-1)
    for dir in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
        var next: Vector2i=start+dir
        if Routes.passable(world,next.x,next.y):
            target=next
            break
    if target.x<0:
        fail("no passable neighbouring tile for scout regression")
        return
    if Scout.order(ui.city,world,Vector2i(-1,-1))=="" or \
            not scout["path"].is_empty():
        fail("sea/out-of-bounds order should fail without changing path")
        return
    map.scout_destination_requested.emit(target.x,target.y)
    if scout["path"].size()!=1 or int(scout["path"][0]["c"])!=target.x or \
            int(scout["path"][0]["r"])!=target.y:
        fail("world-map move command did not update the actual saved path")
        return
    var seconds: float=Scout.segment_seconds(scout,scout["path"][0])
    var saved_state: Dictionary=JSON.parse_string(JSON.stringify(ui.city))
    var stock_before: String=JSON.stringify(saved_state["realms"][0]["resources"])
    var saved_scout: Dictionary=Scout.ensure(saved_state,world)
    if saved_scout["path"].size()!=scout["path"].size():
        fail("active order did not survive JSON save/load")
        return
    Scout.tick(saved_state,world,seconds*0.5)
    var half: Dictionary=Scout.sample(saved_scout)
    if not bool(half["moving"]) or absf(float(half["fraction"])-0.5)>0.000001 or \
            absf(float(half["c"])-lerpf(float(start.x),float(target.x),0.5))>0.00001:
        fail("interpolated scout position differs from V258 travel progress")
        return
    Scout.tick(saved_state,world,seconds*0.5)
    if int(saved_scout["c"])!=target.x or int(saved_scout["r"])!=target.y or \
            not saved_scout["path"].is_empty():
        fail("scout did not reach the ordered tile and stop")
        return
    if JSON.stringify(saved_state["realms"][0]["resources"])!=stock_before:
        fail("scout movement unexpectedly created or consumed resources")
        return
    ui._advance(1)
    if int(scout["c"])!=target.x or int(scout["r"])!=target.y or \
            int(scout.get("worldArrivalV258",{}).get("c",-1))!=target.x:
        fail("one game minute did not advance the V258 scout")
        return
    var expected: Vector3=map.terrain_3d.scout_point_for(scout)
    if map.terrain_3d.scout_actor.position.distance_to(expected)>0.00001:
        fail("3D scout does not match 2D logical position and terrain height")
        return
    var selected: Vector2i=map.selected_cell
    map._switch_mode()
    if map.map_3d_enabled or map.map_canvas.scout_state.is_empty() or \
            map.selected_cell!=selected:
        fail("2D fallback lost the scout or world selection")
        return
    map._switch_mode()
    var old_seed: int=int(world["seed"])
    map.regenerate()
    await process_frame
    await process_frame
    var next_scout: Dictionary=Scout.ensure(ui.city,map.world)
    if int(map.world["seed"])==old_seed or int(next_scout["seed"])!=int(map.world["seed"]) or \
            not next_scout["path"].is_empty():
        fail("a new world reused a scout order from the old seed")
        return
    print("WORLD_SCOUT_V52 SUCCESS: V258 physical speed, land routing, 2D/3D, save, world reset, no free resources")
    quit(0)
