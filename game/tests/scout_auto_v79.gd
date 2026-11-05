extends SceneTree
## V79 integration: real UI, terrain-safe routes, persistent auto mode,
## 60-second ticks, save-size regression and legacy 0.78 migration.
const Game=preload("res://content.tscn")
const Scout=preload("res://scripts/world_scout_v52.gd")
const Auto79=preload("res://scripts/scout_auto_v79.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const World=preload("res://scripts/world_gen_v06.gd")

func fail(why: String) -> void:
    printerr("SCOUT_AUTO_V79 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(760,460)
    var ui: Control=Game.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    if bool(scout.get("auto_explore_v79",true)) or \
            int(scout.get("visited_count_v79",0))!=1:
        fail("fresh game must start with one visited capital and manual mode")
        return
    var initial:=Vector2i(int(scout["c"]),int(scout["r"]))
    var first: Array=Auto79.route(world,scout)
    if first.size()!=1 or not Routes.passable(world,int(first[0]["c"]),int(first[0]["r"])):
        fail("nearest scout frontier is not an adjacent, passable land tile")
        return
    var button: Button=ui.world_view.find_child("ScoutAutoV79",true,false) as Button
    if button==null:
        fail("real world-map scout autopilot button missing")
        return
    button.pressed.emit()
    if not bool(scout.get("auto_explore_v79",false)) or scout["path"].is_empty() or \
            not button.text.contains("sees"):
        fail("autopilot button did not issue a saved route")
        return
    var start_count: int=int(scout["visited_count_v79"])
    ui._advance(8)
    if int(scout["visited_count_v79"])<=start_count:
        fail("eight actual economy turns explored no world cells")
        return
    if not Routes.passable(world,int(scout["c"]),int(scout["r"])):
        fail("autopilot moved through an impassable tile")
        return
    var bits: PackedByteArray=Marshalls.base64_to_raw(
        String(scout.get("explored_bits_v79","")))
    var expected_bytes: int=int(ceili(float(World.COLS*World.ROWS)/8.0))
    if bits.size()!=expected_bytes:
        fail("visited positions are not stored as a bounded bitmap")
        return
    var saved: String=JSON.stringify(ui.city)
    if saved.length()>180000:
        fail("legacy city saves exceed the 180KB loader cap")
        return
    var restored: Dictionary=JSON.parse_string(saved)
    var restored_scout: Dictionary=Scout.ensure(restored,world)
    if int(restored_scout["visited_count_v79"])!=int(scout["visited_count_v79"]) or \
            not bool(restored_scout["auto_explore_v79"]):
        fail("JSON save/load lost visited tiles or auto mode")
        return
    button.pressed.emit()
    if bool(scout["auto_explore_v79"]) or not button.text.contains("väljas"):
        fail("scout autopilot toggle off did not persist")
        return
    # Stop scheduling future routes but finish the currently moving segment
    # instead of snapping the player back to the beginning of the tile.
    Scout.tick(ui.city,world,300.0)
    if not scout["path"].is_empty():
        fail("disabling autopilot still scheduled fresh routes")
        return
    var current:=Vector2i(int(scout["c"]),int(scout["r"]))
    var dest:=Vector2i(-1,-1)
    for direction in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        if Routes.passable(world,current.x+direction.x,current.y+direction.y):
            dest=current+direction
            break
    if dest.x<0 or Scout.order(ui.city,world,dest)!="":
        fail("manual movement is broken after autonomous exploration")
        return
    if bool(scout["auto_explore_v79"]):
        fail("manual destination did not override auto mode")
        return
    var legacy: Dictionary=ui.city.duplicate(true)
    legacy["world_scout_v52"]={"seed":int(world["seed"]),
        "kind":"scout","c":initial.x,"r":initial.y,"speed":4.3,
        "path":[],"travelClock":0.0,"travelDuration":0.0}
    var migrated: Dictionary=Scout.ensure(legacy,world)
    if bool(migrated.get("auto_explore_v79",true)) or \
            int(migrated.get("visited_count_v79",0))!=1:
        fail("0.78 save migration must default to manual scouting")
        return
    print("SCOUT_AUTO_V79 SUCCESS: real map UI, nearest passable frontier, eight turns, compact save, toggle, manual override and old save migration")
    quit(0)
