extends Control
## AutoPort 0.6 atlas screen: click a tile, zoom, pan, and return to 0.5 city.
signal open_city_requested
signal open_detail_requested(c: int, r: int)
const World = preload("res://scripts/world_gen_v06.gd")
const Canvas = preload("res://scripts/world_canvas_v06.gd")
const SAVE_PATH: String = "user://autoport_world_v06.json"
var world: Dictionary = {}
var map_canvas: Control
var status_label: Label
var info_label: Label
var seed: int = 82026
var selected_cell: Vector2i=Vector2i(-1,-1)

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var top:=VBoxContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(top)
    var bar:=HBoxContainer.new()
    bar.add_theme_constant_override("separation",10)
    top.add_child(bar)
    var title:=Label.new()
    title.text="KUNINGRIIGID • GODOT 0.23"
    title.add_theme_font_size_override("font_size",22)
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    bar.add_child(title)
    var city_button:=Button.new()
    city_button.text="Ava linna majandus"
    city_button.pressed.connect(func(): open_city_requested.emit())
    bar.add_child(city_button)
    var detail_button:=Button.new()
    detail_button.text="Ava 3D detailkaart"
    detail_button.pressed.connect(open_selected_detail)
    bar.add_child(detail_button)
    var new_world:=Button.new()
    new_world.text="Uus maailm"
    new_world.pressed.connect(regenerate)
    bar.add_child(new_world)
    var focus:=Button.new()
    focus.text="Näita kogu kaarti"
    focus.pressed.connect(func(): map_canvas.fit_to_view())
    bar.add_child(focus)
    status_label=Label.new()
    status_label.text="Kaardi genereerimine..."
    status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    top.add_child(status_label)
    map_canvas=Canvas.new()
    map_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    map_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
    map_canvas.custom_minimum_size=Vector2(240,160)
    map_canvas.cell_selected.connect(_on_selected)
    top.add_child(map_canvas)
    var legend:=Label.new()
    legend.text="Meri • mets • tasandikud • mäed • jõed | Hiireratas või kahe sõrme näpistus: suum | Lohista: liigu | Puuduta: vali ruut"
    legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    top.add_child(legend)
    info_label=Label.new()
    info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    info_label.custom_minimum_size=Vector2(0,47)
    top.add_child(info_label)
    _load_settings()
    call_deferred("_generate")

func _load_settings() -> void:
    if not FileAccess.file_exists(SAVE_PATH):return
    var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if doc is Dictionary and int(doc.get("seed",0))>0:
        seed=int(doc["seed"])

func _save_settings() -> void:
    var f:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f==null:return
    f.store_string(JSON.stringify({"seed":seed,"selected":{"c":selected_cell.x,"r":selected_cell.y}}))
    f.close()

func _generate() -> void:
    world=World.generate(seed,true)
    map_canvas.set_world(world)
    if world["starts"].size()>0:
        var first: Dictionary=world["starts"][0]
        selected_cell=Vector2i(int(first["c"]),int(first["r"]))
        map_canvas.select_cell(selected_cell.x,selected_cell.y)
    status_label.text="Seeme %d • %d mandrit • %d saart • maismaad %d ruutu • mäestikku %d ruutu • jõelõike %d" % [
        seed,int(world["layout"]["count"]),world["layout"]["islands"].size(),
        int(world["land_count"]),int(world["mountain_count"]),int(world.get("river_count",0))]
    _save_settings()

func regenerate() -> void:
    seed+=7919
    if seed>=2147483647:seed=82026
    status_label.text="Uue maailma genereerimine..."
    call_deferred("_generate")

func _on_selected(c: int,r: int) -> void:
    selected_cell=Vector2i(c,r)
    var cell: Dictionary=World.cell(world,c,r)
    if cell.is_empty():return
    var biome: String=String(cell.get("biome","sea"))
    var name: String={"sea":"Meri","plains":"Tasandik","forest":"Mets","hills":"Mäestik"}.get(biome,biome)
    var note: String=""
    if bool(cell.get("river",false)):note=" • Jõgi"
    if biome=="sea":note+=" • Laevatamine tuleb hiljem"
    if biome=="hills":note+=" • Läbimatu mäestik"
    var home: String=""
    for i in range(world["starts"].size()):
        var s: Dictionary=world["starts"][i]
        if int(s["c"])==c and int(s["r"])==r:
            home=" • Riigi %d algus" % (i+1)
    info_label.text="Ruut %d × %d • %s • kõrgus %.1f%s%s\nVali ruut ja vajuta Ava 3D detailkaart. Linnamajandus on samuti saadaval." % [
        c,r,name,float(cell.get("h",0)),note,home]
    _save_settings()

func open_selected_detail() -> void:
    if selected_cell.x < 0 or selected_cell.y < 0 or world.is_empty():
        return
    open_detail_requested.emit(selected_cell.x,selected_cell.y)

func reveal_city() -> void:
    open_city_requested.emit()
