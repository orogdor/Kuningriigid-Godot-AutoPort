extends SceneTree
## V56 integration: 24 actual men per squad, source formation slots,
## persistent hostile march, auto encounter, real casualty settlement,
## mobile GLB actor reuse, save/restore, no free resources or army clones.
const Scene=preload("res://content.tscn")
const Mil=preload("res://scripts/military_v54.gd")
const Raider=preload("res://scripts/raider_v56.gd")
const Battle=preload("res://scripts/battle_v55.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Research=preload("res://scripts/research_v35.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")

func fail(message: String) -> void:
    printerr("BATTLE_V56 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if Men.PER_SQUAD!=24 or absf(Men.BODY_RADIUS-0.34)>0.000001:
        fail("V90/V96 soldier count or physical body radius diverged")
        return
    var dummy: Dictionary={"formation":"line"}
    var slot: Vector2=Men.formation_slot(dummy,0,24)
    if absf(slot.x+1.575)>0.00001 or absf(slot.y+2.625)>0.00001:
        fail("V94 basic 4-column source formation slot diverged")
        return
    root.size=Vector2i(980,680)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var m: Dictionary=Mil.ensure(ui.city,world)
    if not Raider.ensure(ui.city,world).is_empty():
        fail("a hostile warband spawned before the player recruited soldiers")
        return
    Research.ensure(ui.city)["known"].append("warfare")
    if Mil.build(ui.city,world)!="":
        fail("cannot build paid Stone Age barracks")
        return
    Mil.tick(ui.city,world,18.0)
    var stock: Dictionary=ui.city["realms"][0]["resources"]
    stock["wood"]=220.0
    stock["stone"]=220.0
    ui.city["realms"][0]["pop"]=20.0
    for kind in ["spearman","axeman","slinger"]:
        if Mil.recruit(ui.city,world,kind)!="":
            fail("source model soldier cannot be recruited: "+kind)
            return
    for i in range(3):Mil.tick(ui.city,world,60.0)
    if m["armies"].size()!=3:
        fail("the three paid test armies did not finish training")
        return
    var enemy: Dictionary=Raider.ensure(ui.city,world)
    if enemy.is_empty() or enemy["path"].is_empty():
        fail("a reachable enemy march path was not created")
        return

    var origin: Dictionary=world["starts"][0]
    var home:=Vector2i(int(origin["c"]),int(origin["r"]))
    var far:=Vector2i(int(enemy["c"]),int(enemy["r"]))
    if far==home or not Routes.passable(world,far.x,far.y):
        fail("warband did not spawn at a different reachable tile")
        return
    var copy: Dictionary=JSON.parse_string(JSON.stringify(ui.city))
    var other: Dictionary=Raider.current(copy,world)
    Raider.tick(copy,world,1800.0)
    if int(other["c"])!=home.x or int(other["r"])!=home.y or \
            not other["path"].is_empty():
        fail("enemy did not physically finish its stored land route")
        return
    if Raider.current(copy,world).get("hp",0)!=enemy["hp"]:
        fail("marching created or destroyed enemy HP")
        return
    # V80 correctly hides distant enemies when fog is enabled. This V56
    # regression checks that actors still render when visibility permits.
    # Turn fog off in memory, without modifying the player's saved settings.
    ui.world_view.fog_enabled_v80=false
    ui.world_view._apply_fog_v80()
    ui._sync_trade_map()
    if ui.world_view.map_canvas.raider_v56.is_empty() or \
            not ui.world_view.terrain_3d.hostile_actor_v56.visible:
        fail("hostile unit missing from 2D or 3D world maps")
        return
    # Same tile contact is the end of the enemy's real march in this fixture.
    # Allow the CITY UI to detect it; do not start the battle directly here.
    enemy["c"]=home.x
    enemy["r"]=home.y
    enemy["path"]=[]
    enemy["travelClock"]=0.0
    enemy["travelDuration"]=0.0
    var time_before: int=int(ui.city["time"])
    ui._advance(10)
    if not Battle.active(ui.city,world) or int(ui.city["time"])!=time_before+60:
        fail("world-tile contact did not interrupt +10 turns (active=%s, time=%d, expected=%d)" % [
            str(Battle.active(ui.city,world)),int(ui.city["time"]),time_before+60])
        return
    var b: Dictionary=Battle.current(ui.city,world)
    var stock_before: String=JSON.stringify(stock)
    var pop_before: float=float(ui.city["realms"][0]["pop"])
    if not bool(b.get("campaign_v56",false)) or int(b.get("individual_version",0))!=56:
        fail("automatic encounter still uses the V55 demo squad engine")
        return
    if b["fighters"].size()!=4 or b["source_ids"].size()!=3:
        fail("encounter lost the three real paid squads")
        return
    var soldiers: int=0
    for fighter in b["fighters"]:
        if fighter["men"].size()!=24 or int(fighter["menAlive"])!=24:
            fail("individual soldiers were not initialized 24 per squad")
            return
        soldiers+=fighter["men"].size()
    if soldiers!=96:
        fail("24x4 individual soldiers missing")
        return
    if ui.battle_view.actors_root.get_child_count()!=96:
        fail("3D tactical scene did not render 96 individual Stone Age GLBs")
        return
    var saved: Dictionary=JSON.parse_string(JSON.stringify(ui.city))
    if not Battle.active(saved,world) or \
            int(Battle.current(saved,world)["fighters"][0]["men"].size())!=24:
        fail("battle and personal HP/positions did not survive JSON")
        return
    ui._advance(1)
    if int(ui.city["time"])!=time_before+60:
        fail("economy advanced during a tactical battle")
        return
    var first_id: int=int(m["armies"][0]["id"])
    if Battle.command(ui.city,world,first_id,"spear_wall")!="":
        fail("source spear-wall formation order failed")
        return
    var first: Dictionary=b["fighters"][0]
    var old_position: float=float(first["men"][0]["x"])
    if Battle.command(ui.city,world,first_id,"attack")!="":
        fail("attack order failed")
        return
    for fighter in b["fighters"]:
        if int(fighter["team"])==0:
            Battle.command(ui.city,world,int(fighter["id"]),"attack")
    Battle.tick(ui.city,world,8.0)
    if absf(float(first["men"][0]["x"])-old_position)<0.02:
        fail("the individual front-line soldier did not march")
        return
    var health_before: Dictionary={}
    for army in m["armies"]:
        health_before[int(army["id"])]=float(army["hp"])
    for i in range(55):
        if not Battle.active(ui.city,world):break
        Battle.tick(ui.city,world,10.0)
    if Battle.active(ui.city,world):
        fail("three real trained squads never finished the finite raider encounter")
        return
    if not bool(b.get("resolved",false)):
        fail("the campaign battle was not settled")
        return
    if bool(enemy.get("engaged",true)) or int(enemy["battle_count"])!=1:
        fail("enemy's original campaign identity was not settled exactly once")
        return
    for army in m["armies"]:
        var id: int=int(army["id"])
        if not health_before.has(id) or float(army["hp"])>float(health_before[id])+0.00001:
            fail("army was created or healed after battle")
            return
    if JSON.stringify(stock)!=stock_before or \
            float(ui.city["realms"][0]["pop"])!=pop_before:
        fail("encounter generated free resources or population")
        return
    var army_snapshot: String=JSON.stringify(m["armies"])
    var enemy_snapshot: String=JSON.stringify(enemy)
    Battle.tick(ui.city,world,100.0)
    if JSON.stringify(m["armies"])!=army_snapshot or JSON.stringify(enemy)!=enemy_snapshot:
        fail("casualties or AI enemy were resolved twice")
        return
    print("BATTLE_V56 SUCCESS: 24 individual soldiers x4, source formations, real raider march, automatic tile contact, GLBs, turn interruption, JSON, permanent wounds, no duplicate/free resources")
    quit(0)
