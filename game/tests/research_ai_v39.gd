extends SceneTree
## 0.39 graph-dependent research automation: real costs, manual respect,
## Bronze payment waiting, national sync, persistent settings, both UIs.
const City=preload("res://scripts/city_sim_v05.gd")
const Research=preload("res://scripts/research_v35.gd")
const AI=preload("res://scripts/research_auto_v39.gd")
const Capital=preload("res://scripts/capital_auto_v38.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Screen=preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("RESEARCH_AI_V39 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var old: Dictionary=City.default_state()
    if AI.enabled(old) or AI.step(old)!="" or old.has("research_v35"):
        fail("legacy 0.5 parity state unexpectedly started research")
        return
    var manual: Dictionary=City.default_state()
    Research.ensure(manual)
    if AI.step(manual)!="" or String(manual["research_v35"]["active"])!="":
        fail("manual mode started a science project")
        return
    AI.set_enabled(manual,true)
    if AI.next_discovery(manual)!="stone_tools":
        fail("first technology is not stone_tools")
        return
    if Research.start(manual,"hunting")!="":
        fail("manual research fixture could not start hunting")
        return
    if AI.step(manual)!="" or String(manual["research_v35"]["active"])!="hunting":
        fail("autopilot overwrote the player's active research")
        return
    AI.set_enabled(manual,false)
    if AI.step(manual)!="":
        fail("off switch did not prevent research selection")
        return
    var state: Dictionary=City.default_state()
    var stock: Dictionary=state["realms"][0]["resources"]
    for key in ["wood","stone","bread","water"]:
        stock[key]=1000.0
    Research.ensure(state)
    AI.set_enabled(state,true)
    var learned: Array[String]=[]
    var selection_count: int=0
    var saw_bronze: bool=false
    for minute in range(450):
        var chosen: String=AI.step(state)
        if chosen!="":
            selection_count+=1
            if selection_count==1 and chosen!="stone_tools":
                fail("autopilot skipped Stone Tools prerequisite")
                return
        state["time"]=float(minute)*60.0
        var completed: Array[String]=Research.tick(state)
        learned.append_array(completed)
        if completed.has("bronze"):
            saw_bronze=true
            break
    if not saw_bronze or int(state.get("age",0))!=1:
        fail("AI could not traverse actual Stone-to-Bronze tech dependencies")
        return
    for required in ["stone_tools","water","agriculture","hunting",
            "antler_picks","stone_wedges","copper_tin","fire_use",
            "pottery","copper_smelting","woodworking","stone_crafts","bronze"]:
        if not learned.has(required):
            fail("missing prerequisite discovery: "+required)
            return
    if absf(float(stock["wood"])-965.0)>0.0001 or absf(float(stock["stone"])-975.0)>0.0001:
        fail("Bronze transition charged or refunded wrong amount")
        return
    if selection_count!=learned.size():
        fail("AI started duplicate unfinished technologies")
        return
    var post: String=AI.step(state)
    if post!="":
        if String(state["research_v35"]["active"])!=post or Research.block(state,post)!="":
            fail("AI tried invalid post-Bronze discovery")
            return
    var restored: Variant=JSON.parse_string(JSON.stringify(state))
    if not restored is Dictionary or not AI.enabled(restored):
        fail("science AI switch lost through JSON save")
        return
    if restored["research_ai_v39"]["history"].size()!=selection_count+(1 if post!="" else 0):
        fail("science plan history not saved")
        return

    # Science cannot bypass the atomic Bronze price. Research holds at 100%.
    var waiting: Dictionary=City.default_state()
    var s: Dictionary=waiting["realms"][0]["resources"]
    s["wood"]=0.0
    s["stone"]=100.0
    s["bread"]=100.0
    s["water"]=100.0
    var w: Dictionary=Research.ensure(waiting)
    for known_id in ["stone_tools","hunting","antler_picks","stone_wedges",
            "copper_tin","fire_use","pottery","copper_smelting","woodworking","stone_crafts"]:
        w["known"].append(known_id)
    AI.set_enabled(waiting,true)
    if AI.step(waiting)!="water":
        fail("strategic water supply research priority changed")
        return
    w["known"].append("water")
    w["active"]=""
    w["known"].append("agriculture")
    if AI.next_discovery(waiting)!="bronze":
        fail("AI did not choose available Bronze transition")
        return
    if AI.step(waiting)!="bronze":
        fail("AI could not begin Bronze despite completed technology")
        return
    for i in range(35):
        Research.tick(waiting)
        if AI.step(waiting)!="":
            fail("AI replaced completed Bronze research awaiting wood")
            return
    if int(waiting["age"])!=0 or String(w["active"])!="bronze" or String(w["age_wait"])=="":
        fail("resource-starved Bronze research bypassed material requirement")
        return
    s["wood"]=100.0
    if not Research.tick(waiting).has("bronze") or int(waiting["age"])!=1:
        fail("Bronze did not finish when real wood was supplied")
        return
    if absf(float(s["wood"])-65.0)>0.0001:
        fail("Bronze wood was not charged exactly once")
        return

    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    if AI.enabled(ui.city) or ui.research_ai_button==null:
        fail("fresh game has no independent manual science mode")
        return
    ui._toggle_capital_ai()
    if not Capital.enabled(ui.city) or not AI.enabled(ui.city):
        fail("enabling capital autopilot did not enable linked science AI")
        return
    ui._toggle_research_ai()
    if AI.enabled(ui.city) or not Capital.enabled(ui.city):
        fail("science control accidentally disabled capital construction")
        return
    var home: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(home.x,home.y)
    var found: bool=false
    for button in ui.detail_view.actions.get_children():
        if button is Button and String(button.text).begins_with("Teaduse AI:"):
            found=true
    if not found:
        fail("mobile toolbar has no horizontally scrolling science switch")
        return
    ui.detail_view.research_ai_requested.emit()
    if not AI.enabled(ui.city):
        fail("mobile science switch failed to enable autopilot")
        return
    ui._advance(1)
    if String(ui.city["research_v35"]["active"])!="stone_tools":
        fail("actual gameplay turn did not automatically start Stone Tools")
        return
    print("RESEARCH_AI_V39 SUCCESS: AND/oneOf tech graph, Stone-to-Bronze, manual priority, material wait, saved state, mobile UI")
    quit(0)
