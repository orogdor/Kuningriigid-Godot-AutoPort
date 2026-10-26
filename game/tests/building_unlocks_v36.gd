extends SceneTree
## 0.36 regressions: no free locked buildings, shared tech, both UIs and saves.
const City=preload("res://scripts/city_sim_v05.gd")
const Unlock=preload("res://scripts/building_unlocks_v36.gd")
const Research=preload("res://scripts/research_v35.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Screen=preload("res://content.tscn")

func fail(why: String) -> void:
    printerr("BUILDING_UNLOCKS_V36 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var legacy: Dictionary=City.default_state()
    if not Unlock.allowed(legacy,"quarry"):
        fail("legacy parity simulation now requires research")
        return
    var city: Dictionary=City.default_state()
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=300.0
    stock["stone"]=300.0
    stock["bread"]=300.0
    var science: Dictionary=Research.ensure(city)
    var initial_wood: float=float(stock["wood"])
    var initial_count: int=city["buildings"].size()
    if City.build(city,"quarry")=="" or city["buildings"].size()!=initial_count or float(stock["wood"])!=initial_wood:
        fail("locked quarry was built or consumed resources")
        return
    if not Unlock.allowed(city,"house") or not Unlock.allowed(city,"lumber"):
        fail("starting houses or lumber are unexpectedly locked")
        return
    if Unlock.allowed(city,"well") or Unlock.allowed(city,"farm"):
        fail("water/agriculture research not required")
        return
    var original: Dictionary={"type":"quarry","ready":true,"hp":350}
    city["buildings"].append(original)
    science["known"].append("stone_tools")
    city["buildings"].append({"type":"lumber","ready":true,"hp":350})
    if City.build(city,"quarry")!="":
        fail("researched stone tools did not unlock quarry")
        return
    if absf(float(stock["wood"])-(initial_wood-20.0))>0.001:
        fail("quarry charged wrong amount of wood")
        return
    if City.build(city,"well")=="" or City.build(city,"farm")=="":
        fail("well/farm bypassed missing research")
        return
    science["known"].append("water")
    if City.build(city,"well")!="":
        fail("water technology did not unlock well")
        return
    science["known"].append("agriculture")
    if City.build(city,"farm")!="":
        fail("agriculture did not unlock farm")
        return
    if Unlock.allowed(city,"saw") or Unlock.allowed(city,"market"):
        fail("bronze workshops unlocked without tech")
        return
    if not city["buildings"].has(original):
        fail("migration removed a pre-existing building")
        return
    var restored: Variant=JSON.parse_string(JSON.stringify(city))
    if not restored is Dictionary or not Unlock.allowed(restored,"well") or Unlock.allowed(restored,"market"):
        fail("save changed research unlocks")
        return
    var nation: Dictionary=City.default_state()
    nation["realms"][0]["resources"]["wood"]=300.0
    nation["realms"][0]["resources"]["stone"]=300.0
    Research.ensure(nation)
    if Trade.found(nation)!="":
        fail("second town setup failed")
        return
    Research.ensure(nation)
    var satellite: Dictionary=Trade.ensure_city(nation)
    if Unlock.allowed(satellite,"quarry"):
        fail("satellite construction ignored national lock")
        return
    Research.ensure(nation)["known"].append("stone_tools")
    if not Unlock.allowed(satellite,"quarry"):
        fail("satellite did not inherit national discovery")
        return
    nation["age"]=1
    Research.ensure(nation)
    if int(satellite.get("age",0))!=1:
        fail("satellite age did not follow capital")
        return
    var reloaded: Variant=JSON.parse_string(JSON.stringify(nation))
    if not reloaded is Dictionary:
        fail("serialized national state is invalid")
        return
    Research.ensure(reloaded)
    var other: Dictionary=Trade.ensure_city(reloaded)
    Research.ensure(reloaded)["known"].append("agriculture")
    if not Unlock.allowed(other,"farm"):
        fail("national tech not rebound after JSON reload")
        return
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._show_city()
    var button: Button=ui.workshop_rows.get_child(2).get_child(1) as Button
    if button==null or not button.disabled:
        fail("city menu quarry is enabled before research")
        return
    ui.city["realms"][0]["resources"]["wood"]=300.0
    ui.city["buildings"].append({"type":"lumber","ready":true,"hp":350})
    Research.ensure(ui.city)["known"].append("stone_tools")
    ui._refresh()
    await process_frame
    button=ui.workshop_rows.get_child(2).get_child(1) as Button
    if button.disabled:
        fail("city menu quarry still disabled after research")
        return
    var origin: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(origin.x,origin.y)
    if ui.detail_view._can_build("farm") or not ui.detail_view._can_build("quarry"):
        fail("3D toolbar science checks differ from city menu")
        return
    ui.detail_view.research_requested.emit()
    if not ui.city_scroll.visible or ui.detail_view.visible:
        fail("3D toolbar science button does not open city research screen")
        return
    print("BUILDING_UNLOCKS_V36 SUCCESS: technology lock, costs, legacy parity, second town, save and mobile UI")
    quit(0)
