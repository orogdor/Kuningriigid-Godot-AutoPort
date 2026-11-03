extends SceneTree
## v0.55: source battle dimensions and speed, 3D arena, real paid soldiers,
## explicit orders, battle pause, saved casualties, retreat and group rally.
const Scene=preload("res://content.tscn")
const Mil=preload("res://scripts/military_v54.gd")
const Battle=preload("res://scripts/battle_v55.gd")
const Research=preload("res://scripts/research_v35.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_V55 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if Battle.SCALE!=0.5 or Battle.HALF_X!=337.5 or Battle.HALF_Z!=292.5 or \
            Battle.OUTER_X!=562.5 or Battle.OUTER_Z!=487.5:
        fail("Three.js V88/V93 battlefield geometry or time dilation changed")
        return
    root.size=Vector2i(900,680)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var m: Dictionary=Mil.ensure(ui.city,world)
    Research.ensure(ui.city)["known"].append("warfare")
    if Mil.build(ui.city,world)!="":
        fail("could not build paid camp in fixture")
        return
    Mil.tick(ui.city,world,18.0)
    var stock: Dictionary=ui.city["realms"][0]["resources"]
    stock["wood"]=200.0
    stock["stone"]=200.0
    ui.city["realms"][0]["pop"]=20.0
    for kind in ["spearman","axeman","slinger"]:
        if Mil.recruit(ui.city,world,kind)!="":
            fail("could not queue real paid squad "+kind)
            return
    for step in range(3):Mil.tick(ui.city,world,60.0)
    if m["armies"].size()!=3:
        fail("training fixture did not create three squads")
        return
    var first_id: int=int(m["armies"][0]["id"])
    var health_before: Dictionary={}
    for army in m["armies"]:
        health_before[int(army["id"])]=float(army["hp"])
    var wood_before: float=float(stock["wood"])
    var stone_before: float=float(stock["stone"])
    var pop_before: float=float(ui.city["realms"][0]["pop"])
    if Mil.rally(ui.city,world,first_id)!="":
        fail("co-located formations could not rally")
        return
    for army in m["armies"]:
        if int(army.get("group_id",-1))!=first_id or \
                float(army["hp"])!=float(health_before[int(army["id"])]):
            fail("rally lost army health or original identity")
            return
    var before_time: float=float(ui.city["time"])
    ui._start_skirmish(first_id)
    var b: Dictionary=Battle.current(ui.city,world)
    if b.is_empty() or b["fighters"].size()!=4 or not Battle.active(ui.city,world):
        fail("real city UI could not launch three squads versus one test enemy")
        return
    if ui.battle_view.actors_root.get_child_count()!=4 or \
            ui.battle_view.scene_root.get_node_or_null("Tile_-2_-2")==null or \
            ui.battle_view.scene_root.get_node_or_null("Tile_2_2")==null:
        fail("battle UI missing original GLB units or retreat ring")
        return
    if Battle.start(ui.city,world,[first_id])=="":
        fail("two battles were allowed at the same time")
        return
    if Mil.order(ui.city,world,first_id,Vector2i(int(m["armies"][0]["c"])+1,
            int(m["armies"][0]["r"])))=="":
        fail("campaign marching remained enabled during battle")
        return
    ui._advance(1)
    if float(ui.city["time"])!=before_time:
        fail("battle allowed the city economy to continue ticking")
        return
    if Battle.command(ui.city,world,first_id,"loose")=="" or \
            Battle.command(ui.city,world,first_id,"spear_wall")!="":
        fail("formation restrictions for spear units were not enforced")
        return
    var rock_id: int=int(m["armies"][2]["id"])
    if Battle.command(ui.city,world,rock_id,"loose")!="":
        fail("slinger could not select loose formation")
        return
    var original: Dictionary=JSON.parse_string(JSON.stringify(ui.city))
    if not Battle.active(original,world) or \
            Battle.current(original,world)["source_ids"].size()!=3:
        fail("active battle did not persist in JSON save")
        return
    for army in m["armies"]:
        if Battle.command(ui.city,world,int(army["id"]),"attack")!="":
            fail("unable to order an allied army to attack")
            return
    for step in range(120):
        if not Battle.active(ui.city,world):break
        Battle.tick(ui.city,world,10.0)
    if Battle.active(ui.city,world):
        fail("deterministic test enemy could not be defeated")
        return
    if String(b.get("result",""))!="victory" or not bool(b.get("resolved",false)):
        fail("victory resolution did not complete")
        return
    if m["armies"].size()>3 or m["armies"].size()<1:
        fail("battle duplicated armies or deleted all veterans")
        return
    for army in m["armies"]:
        if not health_before.has(int(army["id"])) or \
                float(army["hp"])>float(health_before[int(army["id"])])+0.000001:
            fail("post-battle health was restored or duplicate troop created")
            return
    if float(stock["wood"])!=wood_before or float(stock["stone"])!=stone_before or \
            float(ui.city["realms"][0]["pop"])!=pop_before:
        fail("battle created resources, food or population")
        return
    var saved_end: String=JSON.stringify(m["armies"])
    Battle.tick(ui.city,world,100.0)
    if JSON.stringify(m["armies"])!=saved_end:
        fail("battle rewards or casualties were resolved twice")
        return
    # Start another real encounter with remaining paid veterans; retreat
    # physically across the red border and preserve any surviving HP.
    var ids: Array=[]
    for army in m["armies"]:ids.append(int(army["id"]))
    if Battle.start(ui.city,world,ids)!="":
        fail("battle restart after victory was blocked")
        return
    var next: Dictionary=Battle.current(ui.city,world)
    for id in ids:
        if Battle.command(ui.city,world,id,"retreat")!="":
            fail("army could not order withdrawal")
            return
    for step in range(120):
        if not Battle.active(ui.city,world):break
        Battle.tick(ui.city,world,10.0)
    if String(next.get("result",""))!="retreat":
        fail("physical red-line crossing did not end in retreat")
        return
    if m["armies"].is_empty() or not bool(next.get("resolved",false)):
        fail("retreated squads were wrongly removed")
        return
    ui._sync_trade_map()
    var unique: Dictionary={}
    for army in m["armies"]:
        var id: int=int(army["id"])
        if unique.has(id):
            fail("duplicate army id after withdrawal")
            return
        unique[id]=true
    print("BATTLE_V55 SUCCESS: real paid squads, regrouped, 3x3+ring, GLBs, orders, formation gate, paused economy, save, victory, losses, retreat, idempotence")
    quit(0)
