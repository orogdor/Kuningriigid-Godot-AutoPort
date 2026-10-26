extends SceneTree
## 0.38 opt-in construction AI and no regressions to roads/mobile UI.
const City=preload("res://scripts/city_sim_v05.gd")
const Research=preload("res://scripts/research_v35.gd")
const AI=preload("res://scripts/capital_auto_v38.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Screen=preload("res://content.tscn")

func fail(why: String) -> void:
    printerr("CAPITAL_AI_V38 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var legacy: Dictionary=City.default_state()
    if AI.enabled(legacy) or AI.step(legacy)!="" or legacy.has("detail_sim"):
        fail("manual and economy parity mode changed")
        return
    var city: Dictionary=City.default_state()
    city["age"]=1
    var stock: Dictionary=city["realms"][0]["resources"]
    for key in ["wood","stone","plank","bread","water"]:
        stock[key]=1000.0
    city["realms"][0]["pop"]=7
    var discoveries: Dictionary=Research.ensure(city)
    for id in ["bronze","stone_tools","water","agriculture","woodworking",
            "storage","commerce","cellaring","milling"]:
        discoveries["known"].append(id)
    AI.set_enabled(city,true)
    if not city.has("detail_sim") or not AI.enabled(city):
        fail("enabling automation failed to initialize physical city")
        return
    for i in range(4):Paths.touch(city["detail_sim"],Vector2i(2,0))
    var prior: Dictionary=city["detail_sim"]["roads"]["2:0"].duplicate(true)
    if Paths.road_tiles(city["detail_sim"]).is_empty():
        fail("emergent road fixture was not created")
        return
    var required: Array[String]=["lumber","well","house","quarry","farm","saw"]
    for i in range(required.size()):
        city["time"]=float(180*i)
        var before: int=city["buildings"].size()
        var kind: String=AI.step(city)
        if kind!=required[i] or city["buildings"].size()!=before+1:
            fail("planning step %d expected %s, got %s" % [i,required[i],kind])
            return
        var site: Dictionary=city["buildings"][before]
        var spot:=Vector2(float(site["x"]),float(site["z"]))
        if spot.length()>75.0 or absf(spot.x)>75.0 or absf(spot.y)>75.0:
            fail("AI built outside central compact city")
            return
        if int(site.get("rotation",-1))%90!=0:
            fail("building facing is not aligned to quarter turns")
            return
        for j in range(before):
            var previous: Dictionary=city["buildings"][j]
            var prev:=Vector2(float(previous.get("x",0)),float(previous.get("z",0)))
            if spot.distance_to(prev)<15.5:
                fail("AI placed building over existing building")
                return
        if AI.step(city)!="":
            fail("AI ordered multiple builds in same turn")
            return
        site["ready"]=true
        site["progress"]=10000.0
    if city["detail_sim"]["roads"].get("2:0",{})!=prior:
        fail("original emergent traffic road was overwritten")
        return
    if city["capital_ai_v38"]["history"].size()!=required.size():
        fail("build history is incomplete")
        return
    var saved: Variant=JSON.parse_string(JSON.stringify(city))
    if not saved is Dictionary or not AI.enabled(saved):
        fail("save lost AI preference")
        return
    if saved["detail_sim"]["roads"].get("2:0",{})!=prior:
        fail("save lost roads")
        return
    AI.set_enabled(city,false)
    var stopped: int=city["buildings"].size()
    city["time"]+=600.0
    if AI.step(city)!="" or city["buildings"].size()!=stopped:
        fail("disabled AI built another house")
        return
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    if AI.enabled(ui.city) or ui.capital_ai_button==null:
        fail("fresh UI is not in manual construction mode")
        return
    ui._toggle_capital_ai()
    if not AI.enabled(ui.city) or not ui.capital_ai_button.text.contains("sees"):
        fail("UI setting failed to enable AI")
        return
    var home: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(home.x,home.y)
    var has_button: bool=false
    for item in ui.detail_view.actions.get_children():
        if item is Button and String(item.text).begins_with("Linna AI:"):
            has_button=true
    if not has_button:
        fail("mobile detail toolbar lacks AI toggle")
        return
    ui.detail_view.capital_ai_requested.emit()
    if AI.enabled(ui.city):
        fail("mobile detail toggle cannot disable AI")
        return
    if Paths.ROAD_THRESHOLD!=3 or Paths.ROAD_FADE_TURNS!=35:
        fail("natural roads and fading constants changed")
        return
    print("CAPITAL_AI_V38 SUCCESS: opt-in, dense accessible construction, real cost, unchanged roads, save, mobile UI")
    quit(0)
