extends Control
## AutoPort 0.5: playable single-city economy sandbox.
## Live source-derived production definitions; one button press = one game minute.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Schedule = preload("res://scripts/construction_scheduler_v13.gd")
const Trade = preload("res://scripts/two_city_trade_v15.gd")
const Rules = preload("res://scripts/generated_rules.gd")
const WorldMap = preload("res://scripts/world_map_v06.gd")
const WorldGen = preload("res://scripts/world_gen_v06.gd")
const Routes = preload("res://scripts/world_trade_routes_v17.gd")
const DetailView = preload("res://scripts/detail_view_v07.gd")
const Districts = preload("res://scripts/world_districts_v25.gd")
const Transit = preload("res://scripts/district_transit_v26.gd")
const Nav = preload("res://scripts/terrain_navigation_v29.gd")
const SAVE_PATH = "user://autoport_city_v05.json"
const SHOW_TYPES: Array[String] = [
    "lumber","saw","quarry","house","well","farm","mill","bakery",
    "market","warehouse","cellar","vegetable_garden"
]
const RESOURCE_LABELS: Dictionary = {
    "wood":"Puit","stone":"Kivi","plank":"Lauad","bread":"Leib",
    "grain":"Vili","flour":"Jahu","water":"Vesi","berries":"Marjad",
    "vegetables":"Köögiviljad","gold":"Kuld","fish":"Kala","meat":"Liha"
}
var city: Dictionary = {}
var city_scroll: ScrollContainer
var world_view: Control
var detail_view: Control
var recipes: Dictionary = {}
var stat_text: Label
var population_bar: ProgressBar
var workshop_rows: VBoxContainer
var construction_rows: VBoxContainer
var info_text: Label
var trade_label: Label
var satellite_label: Label
var detail_town: String="capital"
var auto_button: Button
var timer: Timer
var event_message: String = "Alusta kiviaegse linna rajamist."

func _ready() -> void:
    var bundle: Dictionary = City.definitions()
    recipes = bundle.get("buildings",{})
    if recipes.is_empty():
        var warning := Label.new()
        warning.text = "0.5 majandusandmed puuduvad. Kontrolli GitHubi viimast AutoPorti väljalaset."
        add_child(warning)
        return
    city = _load_city()
    _setup_ui()
    timer = Timer.new()
    timer.wait_time = 1.0
    timer.one_shot = false
    timer.timeout.connect(func(): _advance(1))
    add_child(timer)
    _refresh()
    # World map replaces the previous 0.5 text-only entry view.
    world_view = WorldMap.new()
    add_child(world_view)
    world_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    world_view.open_city_requested.connect(_show_city)
    world_view.open_detail_requested.connect(_show_detail)
    world_view.expand_requested.connect(_expand_district)
    world_view.set_city_districts(city)
    detail_view=DetailView.new()
    add_child(detail_view)
    detail_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_view.return_requested.connect(_show_world)
    detail_view.build_requested.connect(_build)
    detail_view.build_at_requested.connect(_build_at)
    detail_view.bridge_requested.connect(_build_bridge)
    detail_view.priority_requested.connect(_change_priority)
    detail_view.turns_requested.connect(_advance)
    detail_view.hide()
    city_scroll.hide()

func _detail_state() -> Dictionary:
    if detail_town=="outpost" and Trade.has_outpost(city):
        return Trade.ensure_city(city)
    return city

func _satellite_tile() -> Dictionary:
    if not Trade.has_outpost(city) or world_view==null or world_view.world.is_empty():return {}
    var trade: Dictionary=city["trade_v15"]
    var world: Dictionary=world_view.world
    var seed: int=int(world.get("seed",0))
    if trade.has("position") and int(trade["position"].get("seed",-1))==seed:
        var site: Dictionary=trade["position"]
        var route: Dictionary=trade.get("route_v17",{})
        if route.is_empty() or int(route.get("seed",-1))!=seed:
            Routes.configure(city,world,world["starts"][0],site)
        return site
    var home: Dictionary=world["starts"][0]
    var chosen: Dictionary=Routes.choose_site(world,Vector2i(int(home["c"]),int(home["r"])))
    if chosen.is_empty():return {}
    if not Routes.configure(city,world,home,chosen):return {}
    return chosen

func _sync_trade_map() -> void:
    if world_view==null or world_view.world.is_empty():return
    world_view.set_city_districts(city)
    Transit.configure(city,world_view.world)
    world_view.map_canvas.set_city_agents(city.get("transport_v26",{}).get("agents",[]),
        Transit.home_key(city))
    if not Trade.has_outpost(city):
        world_view.map_canvas.set_trade_route({},[])
        return
    _satellite_tile()
    var trade: Dictionary=city["trade_v15"]
    world_view.map_canvas.set_trade_route(trade.get("route_v17",{}),trade.get("caravans",[]))

func _open_satellite() -> void:
    if not Trade.has_outpost(city):
        event_message="Asuta kõigepealt teine linn"
        _refresh()
        return
    var location: Dictionary=_satellite_tile()
    if location.is_empty():
        event_message="Teisele linnale ei leitud sobivat maismaaruutu"
        _refresh()
        return
    detail_town="outpost"
    var satellite: Dictionary=Trade.ensure_city(city)
    detail_view.open_tile(world_view.world,int(location["c"]),int(location["r"]),satellite,true)
    _save()
    city_scroll.hide()
    world_view.hide()
    detail_view.show()

func _show_city() -> void:
    detail_town="capital"
    if world_view != null:world_view.hide()
    if detail_view != null:detail_view.hide()
    if city_scroll != null:city_scroll.show()
    _refresh()

func _show_world() -> void:
    _sync_trade_map()
    if city_scroll != null:city_scroll.hide()
    if detail_view != null:detail_view.hide()
    if world_view != null:world_view.show()

func _show_detail(c: int, r: int) -> void:
    if world_view == null or detail_view == null or world_view.world.is_empty():
        return
    var capital: bool=false
    if world_view.world["starts"].size()>0:
        var home: Dictionary=world_view.world["starts"][0]
        capital=(int(home["c"])==c and int(home["r"])==r)
    var satellite: bool=false
    if Trade.has_outpost(city):
        var loc: Dictionary=_satellite_tile()
        satellite=not loc.is_empty() and int(loc["c"])==c and int(loc["r"])==r
    detail_town="outpost" if satellite else "capital"
    var active: Dictionary=Trade.ensure_city(city) if satellite else city
    if not satellite:Transit.configure(city,world_view.world)
    var owned: bool=Districts.owns(city,world_view.world,c,r)
    var district_key: String=""
    if owned and not capital and not satellite:
        district_key=Districts.key(Vector2i(c,r))
    detail_view.open_tile(world_view.world,c,r,active,owned or satellite,district_key)
    if capital or satellite:_save()
    if city_scroll != null:city_scroll.hide()
    if world_view != null:world_view.hide()
    detail_view.show()

func _load_city() -> Dictionary:
    if FileAccess.file_exists(SAVE_PATH):
        var bytes: String = FileAccess.get_file_as_string(SAVE_PATH)
        if bytes.length() <= 180000:
            var doc: Variant = JSON.parse_string(bytes)
            if doc is Dictionary and doc.has("realms") and doc.has("buildings") and doc.has("time"):
                if doc["realms"] is Array and doc["realms"].size() == 1 and doc["buildings"] is Array:
                    return doc
    return City.default_state()

func _save() -> void:
    var file: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(city))
        file.close()

func _heading(text: String, size: int = 22) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",size)
    return label

func _button(text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(112,42)
    b.pressed.connect(callback)
    return b

func _setup_ui() -> void:
    var scroll := ScrollContainer.new()
    city_scroll=scroll
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left",20)
    margin.add_theme_constant_override("margin_top",16)
    margin.add_theme_constant_override("margin_right",20)
    margin.add_theme_constant_override("margin_bottom",24)
    scroll.add_child(margin)
    var body := VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation",13)
    margin.add_child(body)
    body.add_child(_heading("KUNINGRIIGID   •   GODOT 0.32",26))
    body.add_child(_heading("Linnamajandus — esimene mängitav simulatsioon",16))
    var sub := Label.new()
    var manifest: Dictionary = Rules.read_table("manifest")
    sub.text = "Veebimängu reeglite lähtecommit: %s • 1 minut = 1 käik" % String(manifest.get("source_commit","teadmata")).substr(0,12)
    sub.add_theme_color_override("font_color",Color(0.62,0.77,0.86))
    body.add_child(sub)

    var controls := HFlowContainer.new()
    controls.add_theme_constant_override("h_separation",8)
    controls.add_theme_constant_override("v_separation",8)
    body.add_child(controls)
    controls.add_child(_button("Maailmakaart",_show_world))
    controls.add_child(_button("+1 käik",func(): _advance(1)))
    controls.add_child(_button("+10 käiku",func(): _advance(10)))
    controls.add_child(_button("+200 käiku",func(): _advance(200)))
    auto_button = _button("Auto: väljas",_toggle_auto)
    controls.add_child(auto_button)
    controls.add_child(_button("Alusta uuesti",_reset))
    stat_text = _heading("",17)
    stat_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(stat_text)
    population_bar = ProgressBar.new()
    population_bar.custom_minimum_size = Vector2(0,17)
    population_bar.show_percentage = false
    body.add_child(population_bar)
    info_text = _heading("",16)
    info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(info_text)
    body.add_child(HSeparator.new())
    body.add_child(_heading("Hoone ehitamine",20))
    var hint := Label.new()
    hint.text = "Vali ehitis. Ehitamine nõuab materjale ja aega, töötajad jagunevad töökohtade vahel."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)
    workshop_rows=VBoxContainer.new()
    workshop_rows.add_theme_constant_override("separation",6)
    body.add_child(workshop_rows)
    body.add_child(HSeparator.new())
    body.add_child(_heading("Linna ehitised",20))
    construction_rows=VBoxContainer.new()
    construction_rows.add_theme_constant_override("separation",4)
    body.add_child(construction_rows)
    body.add_child(HSeparator.new())
    body.add_child(_heading("Kahe linna kaubandus (prototüüp)",20))
    trade_label=_heading("",15)
    trade_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_child(trade_label)
    satellite_label=_heading("",15)
    satellite_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_child(satellite_label)
    var trading:=HFlowContainer.new()
    body.add_child(trading)
    trading.add_child(_button("Asuta teine linn",_found_trade_city))
    trading.add_child(_button("Teise linna ehitus-AI sees/väljas",_toggle_satellite_ai))
    trading.add_child(_button("Ava teise linna 3D detailkaart",_open_satellite))
    trading.add_child(_button("Saada 15 puitu teise linna",func(): _trade_send("outpost","wood",15.0)))
    trading.add_child(_button("Saada 5 puitu teise linna",func(): _trade_send("outpost","wood",5.0)))
    trading.add_child(_button("Saada 5 leiba teise linna",func(): _trade_send("outpost","bread",5.0)))
    trading.add_child(_button("Saada 10 vett teise linna",func(): _trade_send("outpost","water",10.0)))
    trading.add_child(_button("Too 5 puitu pealinna",func(): _trade_send("capital","wood",5.0)))
    body.add_child(HSeparator.new())
    var note := Label.new()
    note.text="0.30: läbipääsetavate linnaosade teed ja kiirem 3D suur linn."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_color_override("font_color",Color(0.7,0.8,0.82))
    body.add_child(note)

func _toggle_satellite_ai() -> void:
    if not Trade.has_outpost(city):
        event_message="Asuta enne teine linn."
    else:
        var trade: Dictionary=city["trade_v15"]
        trade["ai_enabled"]=not bool(trade.get("ai_enabled",false))
        event_message="Teise linna ehitus-AI: sees" if bool(trade["ai_enabled"]) else "Teise linna ehitus-AI: väljas"
    _save()
    _refresh()

func _found_trade_city() -> void:
    event_message=Trade.found(city)
    if event_message=="":
        city["trade_v15"]["ai_enabled"]=true
        event_message="Teine linn asutati. Ehitus-AI on sees."
    _sync_trade_map()
    _save()
    _refresh()

func _trade_send(target: String, kind: String, amount: float) -> void:
    event_message=Trade.send(city,target,kind,amount)
    if event_message=="":event_message="Kaubakaravan saadeti: %s %.0f → %s" % [kind,amount,target]
    _sync_trade_map()
    _save()
    _refresh()

func _toggle_auto() -> void:
    if timer.is_stopped():
        timer.start()
        auto_button.text="Auto: sees"
    else:
        timer.stop()
        auto_button.text="Auto: väljas"

func _reset() -> void:
    if timer != null:
        timer.stop()
        auto_button.text="Auto: väljas"
    city = City.default_state()
    _sync_trade_map()
    event_message="Uus kiviaegne linn on rajatud."
    _save()
    _refresh()

func _advance(n: int) -> void:
    var before: int = int(city["realms"][0]["pop"])
    if world_view!=null and not world_view.world.is_empty():
        Transit.configure(city,world_view.world)
    for i in range(n):
        City.tick(city)
    var after: int = int(city["realms"][0]["pop"])
    event_message="%d käiku möödus. Elanikkond: %d → %d." % [n,before,after]
    if bool(city["realms"][0].get("housingShortage",false)):
        event_message += " Toidu või vee puudus!"
    _sync_trade_map()
    _save()
    _refresh()
    if detail_view != null and detail_view.visible:
        detail_view.refresh_buildings()

func _build(kind: String) -> void:
    var result: String = City.build(_detail_state(),kind)
    event_message = result if result != "" else "Alustati ehitamist: " + String(recipes[kind].get("name",kind))
    _save()
    _refresh()
    if detail_view != null and detail_view.visible:
        detail_view.refresh_buildings()

func _build_at(kind: String, x: float, z: float, rotation: int=0) -> void:
    var active: Dictionary=_detail_state()
    var pending: Dictionary={"x":x,"z":z,"rotation":rotation}
    if detail_view!=null and detail_view.visible and String(detail_view.district_id)!="":
        pending["district"]=String(detail_view.district_id)
    active["pending_site"]=pending
    _build(kind)
    active.erase("pending_site")
    _save()

func _expand_district(c: int,r: int) -> void:
    if world_view==null or world_view.world.is_empty():return
    var result: String=Districts.expand(city,world_view.world,c,r)
    event_message=result if result!="" else "Linn laienes ruudule %d, %d. Kasutati 20 puitu ja 10 kivi." % [c,r]
    Transit.configure(city,world_view.world)
    _save()
    _sync_trade_map()
    _refresh()
    world_view._on_selected(c,r)

func _change_priority(index: int, level: String) -> void:
    if Schedule.change_priority(_detail_state(),index,level):
        event_message="Ehitus #%d on nüüd %s prioriteediga." % [index,level]
        _save()
        _refresh()
        if detail_view!=null and detail_view.visible:detail_view.refresh_buildings()

func _build_bridge(x: float,z: float=25.0) -> void:
    var outcome: String=""
    var state: Dictionary=_detail_state()
    var combined: bool=detail_view!=null and detail_view.visible and bool(detail_view.combined_city)
    if combined:
        var district: String=String(detail_view.district_id)
        var local: Dictionary=Transit._local_state(state,
            Transit.home_key(state) if district=="" else district)
        var sim: Dictionary=local.get("detail_sim",{})
        outcome="Silda ei saa sinna jõele ehitada."
        for axis in ["x","z"]:
            var cell: int=int(roundf((x if axis=="x" else z)/10.0))
            var place: Vector2=Nav.bridge_position(sim,axis,cell)
            if Nav.can_bridge(sim,axis,cell) and place.distance_to(Vector2(x,z))<=10.0:
                outcome=Nav.build_bridge(state,sim,axis,cell)
                break
    else:
        outcome=Spatial.build_bridge(state,x)
    event_message="Sild valmis jõe kohal %.0f, %.0f m" % [x,z] if outcome=="" else outcome
    _save()
    _refresh()
    if detail_view!=null and detail_view.visible:
        detail_view.refresh_buildings()

func _affordable(kind: String) -> bool:
    var d: Dictionary = recipes[kind]
    if int(d.get("age",0)) > int(city.get("age",0)):
        return false
    var buildings: Array = city["buildings"]
    for required in d.get("requires",[]):
        var found: bool = false
        for b in buildings:
            if String(b.get("type","")) == String(required) and bool(b.get("ready",false)):
                found=true
        if not found:
            return false
    return City.can_afford(city["realms"][0]["resources"],d.get("cost",{}))

func _render_cost(cost: Dictionary) -> String:
    var elements: Array[String] = []
    for key in cost.keys():
        elements.append("%s %.0f" % [RESOURCE_LABELS.get(key,String(key)),float(cost[key])])
    return ", ".join(elements)

func _refresh() -> void:
    var realm: Dictionary = city["realms"][0]
    var stock: Dictionary = realm["resources"]
    var pop: float = float(realm.get("pop",3))
    var cap: float = City.housing_capacity(city["buildings"])
    stat_text.text = "Käik: %d   |   Elanikke: %d / %.1f   |   Tööl: %.1f   |   Teadus: %.0f p/min\n" % [
        int(round(float(city["time"]) / 60.0)),int(pop),cap,float(realm.get("employed",0.0)),pop]
    var shown: Array[String] = []
    for kind in ["wood","plank","stone","bread","grain","flour","berries","water","gold"]:
        shown.append("%s: %.1f" % [RESOURCE_LABELS[kind],float(stock.get(kind,0))])
    stat_text.text += "     ".join(shown)
    if trade_label!=null:
        trade_label.text=Trade.overview(city)
        if Trade.has_outpost(city):
            var route: Dictionary=city["trade_v15"].get("route_v17",{})
            if not route.is_empty():
                trade_label.text+=" | Maismaatee %d ruutu | Karavan %d käiku" % [int(route["distance_tiles"]),int(route["duration"])]
    if satellite_label!=null:
        if Trade.has_outpost(city):
            var satellite: Dictionary=Trade.ensure_city(city)
            var sr: Dictionary=satellite["realms"][0]
            var ss: Dictionary=sr["resources"]
            satellite_label.text="Teise linna elanikud %d / %.0f | Ehitised %d | Puit %.0f | Vesi %.0f | Leib %.0f | Käik %d" % [
                int(sr["pop"]),City.housing_capacity(satellite["buildings"]),satellite["buildings"].size(),
                float(ss.get("wood",0)),float(ss.get("water",0)),float(ss.get("bread",0)),int(float(satellite["time"])/60)]
            satellite_label.text+=" | Ehitus-AI %s" % ("sees" if bool(city["trade_v15"].get("ai_enabled",false)) else "väljas")
            var history: Array=satellite.get("ai_log",[])
            if not history.is_empty():
                satellite_label.text+=" | Viimati: "+String(history[history.size()-1]["type"])
        else:satellite_label.text="Teise linna iseseisev majandus avaneb pärast asutamist."
    population_bar.max_value=maxf(1.0,cap)
    population_bar.value=pop
    var next_growth: float = float(realm.get("growthNeed",2.3+pop*0.28))
    info_text.text="%s\nKasv: %.2f / %.2f  |  Toitu minutis: %.2f  |  Vett minutis: %.2f" % [
        event_message,float(realm.get("growthProgress",0)),next_growth,
        pop*0.60,pop*0.45]
    for child in workshop_rows.get_children():
        child.queue_free()
    for kind in SHOW_TYPES:
        if not recipes.has(kind):
            continue
        var d: Dictionary = recipes[kind]
        var row := HBoxContainer.new()
        workshop_rows.add_child(row)
        var name_label := Label.new()
        name_label.text = "%s  —  %s  •  töötajaid %d" % [
            String(d.get("name",kind)),_render_cost(d.get("cost",{})),int(d.get("workers",0))]
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(name_label)
        var b := Button.new()
        b.text="Ehita"
        b.custom_minimum_size=Vector2(92,36)
        b.disabled=not _affordable(kind)
        b.pressed.connect(_build.bind(kind))
        row.add_child(b)
    for child in construction_rows.get_children():
        child.queue_free()
    for b in city["buildings"]:
        var label := Label.new()
        var d: Dictionary = recipes.get(b.get("type",""),{})
        var status: String="Valmis" if bool(b.get("ready",false)) else "Ehitamisel %.0f / %.0f" % [
            float(b.get("progress",0)),float(d.get("time",0))]
        label.text = "• %s   —   %s   •   töötajaid %.1f" % [
            String(d.get("name",b.get("type","hall"))),status,float(b.get("assigned",0))]
        construction_rows.add_child(label)
