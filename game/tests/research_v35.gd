extends SceneTree
## 0.35: prerequisites, real science-per-person, atomic bronze payment,
## save migration and playable UI without changing 0.5 economy parity.
const Research=preload("res://scripts/research_v35.gd")
const City=preload("res://scripts/city_sim_v05.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const Screen=preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("RESEARCH_V35 FAIL: "+reason)
    quit(1)

func _finish(state: Dictionary,id: String) -> bool:
    if Research.start(state,id)!="":return false
    for i in range(80):
        if Research.tick(state).has(id):return true
    return false

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    var stock: Dictionary=state["realms"][0]["resources"]
    for key in ["bread","wood","stone","water"]:
        stock[key]=1000.0
    if Research.ensure(state)["known"].size()!=0:
        fail("migration invented technology on an old save")
        return
    if Research.science_rate(state)!=3.0 or Research.cost("stone_tools")!=20.0:
        fail("source science resident/cost settings do not match")
        return
    if Research.block(state,"bronze")=="" or Research.block(state,"settlement")=="":
        fail("bronze or settlement skipped prerequisites")
        return
    if Research.start(state,"stone_tools")!="":
        fail("could not start first stone technology")
        return
    var earned: float=0.0
    var stone_done: bool=false
    for i in range(12):
        City.tick(state)
        earned+=Research.science_rate(state)
        var result: Array[String]=Research.tick(state)
        if earned+0.000001<20.0 and result.has("stone_tools"):
            fail("stone tools completed before earning 20 science")
            return
        if result.has("stone_tools"):
            stone_done=true
            break
    if not stone_done:
        fail("science did not complete after accumulating 20 points")
        return
    if not Research.ensure(state)["known"].has("stone_tools"):
        fail("completed technology not recorded")
        return
    if Research.block(state,"settlement")=="":
        fail("oneOf prerequisite was ignored")
        return
    if not _finish(state,"hunting") or Research.block(state,"settlement")!="":
        fail("oneOf hunting prerequisite not recognized")
        return
    if not _finish(state,"settlement"):
        fail("settlement unlock failed")
        return
    if Research.block(state,"bronze_crafts")=="":
        fail("bronze age gate skipped")
        return
    for id in ["antler_picks","stone_wedges","copper_tin","fire_use",
            "pottery","copper_smelting","woodworking","stone_crafts"]:
        if not _finish(state,id):
            fail("broken source tech prerequisite chain at "+id)
            return
    if Research.block(state,"bronze")!="":
        fail("bronze prerequisites unexpectedly blocked")
        return
    stock["wood"]=0.0
    if Research.start(state,"bronze")!="":
        fail("bronze research could not start")
        return
    for i in range(30):Research.tick(state)
    var r: Dictionary=Research.ensure(state)
    if int(state["age"])!=0 or not r["known"].has("stone_tools") or r["known"].has("bronze"):
        fail("incomplete bronze payment changed age or research")
        return
    if r["age_wait"]=="" or String(r["active"])!="bronze":
        fail("fully researched bronze did not wait for materials")
        return
    stock["wood"]=100.0
    if not Research.tick(state).has("bronze"):
        fail("atomic material payment did not finish bronze")
        return
    if int(state["age"])!=1 or absf(float(stock["wood"])-65.0)>0.0001 or absf(float(stock["stone"])-975.0)>0.0001:
        fail("bronze age or material deduction was incorrect")
        return
    var wood_after: float=float(stock["wood"])
    for i in range(5):Research.tick(state)
    if float(stock["wood"])!=wood_after:
        fail("bronze cost was deducted twice")
        return
    if Research.block(state,"bronze_crafts")!="":
        fail("bronze-era research remains locked after transition")
        return
    if Research.block(state,"iron")=="":
        fail("unsupported iron research was unlocked early")
        return
    var restored: Variant=JSON.parse_string(JSON.stringify(state))
    if not restored is Dictionary or not Research.ensure(restored)["known"].has("bronze"):
        fail("save round trip lost discovered technology")
        return
    var with_town: Dictionary=City.default_state()
    var trade_stock: Dictionary=with_town["realms"][0]["resources"]
    trade_stock["wood"]=100.0
    trade_stock["stone"]=100.0
    if Trade.found(with_town)!="":
        fail("satellite research fixture could not found the second city")
        return
    if absf(Research.science_rate(with_town)-6.0)>0.001:
        fail("national science did not include both town populations")
        return
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._show_city()
    if ui.research_options==null or ui.research_status==null or ui.research_start==null:
        fail("research controls not exposed on the playable city screen")
        return
    if ui.research_options.item_count<3:
        fail("fresh city does not list the available research branches")
        return
    print("RESEARCH_V35 SUCCESS: population-derived stone tools, AND/OR tech gates, national population science, atomic bronze resources, saves and city UI")
    quit(0)
