extends Control
## AutoPort 0.5: playable single-city economy sandbox.
## Live source-derived production definitions; one button press = one game minute.
const City = preload("res://scripts/city_sim_v05.gd")
const Rules = preload("res://scripts/generated_rules.gd")
const WorldMap = preload("res://scripts/world_map_v06.gd")
const DetailView = preload("res://scripts/detail_view_v07.gd")
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
    detail_view=DetailView.new()
    add_child(detail_view)
    detail_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_view.return_requested.connect(_show_world)
    detail_view.build_requested.connect(_build)
    detail_view.build_at_requested.connect(_build_at)
    detail_view.turns_requested.connect(_advance)
    detail_view.hide()
    city_scroll.hide()

func _show_city() -> void:
    if world_view != null:world_view.hide()
    if detail_view != null:detail_view.hide()
    if city_scroll != null:city_scroll.show()
    _refresh()

func _show_world() -> void:
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
    detail_view.open_tile(world_view.world,c,r,city,capital)
    if capital:_save()
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
    body.add_child(_heading("KUNINGRIIGID   •   GODOT 0.9",26))
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
    var note := Label.new()
    note.text="0.9: 3D teed tekivad tööliste liikumisest, rajaleidmine väldib maju ja mahajäetud rajad hääbuvad. AI, teed ja sõjad tulevad hiljem."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_color_override("font_color",Color(0.7,0.8,0.82))
    body.add_child(note)

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
    event_message="Uus kiviaegne linn on rajatud."
    _save()
    _refresh()

func _advance(n: int) -> void:
    var before: int = int(city["realms"][0]["pop"])
    for i in range(n):
        City.tick(city)
    var after: int = int(city["realms"][0]["pop"])
    event_message="%d käiku möödus. Elanikkond: %d → %d." % [n,before,after]
    if bool(city["realms"][0].get("housingShortage",false)):
        event_message += " Toidu või vee puudus!"
    _save()
    _refresh()
    if detail_view != null and detail_view.visible:
        detail_view.refresh_buildings()

func _build(kind: String) -> void:
    var result: String = City.build(city,kind)
    event_message = result if result != "" else "Alustati ehitamist: " + String(recipes[kind].get("name",kind))
    _save()
    _refresh()
    if detail_view != null and detail_view.visible:
        detail_view.refresh_buildings()

func _build_at(kind: String, x: float, z: float) -> void:
    city["pending_site"]={"x":x,"z":z}
    _build(kind)
    city.erase("pending_site")
    _save()

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
