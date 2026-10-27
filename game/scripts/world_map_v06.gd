extends Control
## AutoPort 0.6 atlas screen: click a tile, zoom, pan, and return to 0.5 city.
signal open_city_requested
signal open_detail_requested(c: int, r: int)
signal expand_requested(c: int, r: int)
const World = preload("res://scripts/world_gen_v06.gd")
const Canvas = preload("res://scripts/world_canvas_v06.gd")
const Terrain3D = preload("res://scripts/world_terrain_v40.gd")
const Districts = preload("res://scripts/world_districts_v25.gd")
const SAVE_PATH: String = "user://autoport_world_v06.json"
var world: Dictionary = {}
var district_city: Dictionary={}
var map_canvas: Control
var terrain_3d: SubViewportContainer
var map_mode_button: Button
var map_3d_enabled: bool=true
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
    var bar_frame:=Control.new()
    bar_frame.custom_minimum_size=Vector2(0,48)
    top.add_child(bar_frame)
    var bar_scroll:=ScrollContainer.new()
    bar_scroll.name="WorldActionsScroll"
    bar_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bar_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    bar_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    bar_frame.add_child(bar_scroll)
    var bar:=HBoxContainer.new()
    bar.add_theme_constant_override("separation",10)
    bar_scroll.add_child(bar)
    var title:=Label.new()
    title.text=String(ProjectSettings.get_setting(
        "application/config/name","Kuningriigid Godot AutoPort"))
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
    var annex:=Button.new()
    annex.text="Liida linna ruut"
    annex.pressed.connect(func():
        if selected_cell.x>=0:expand_requested.emit(selected_cell.x,selected_cell.y))
    bar.add_child(annex)
    map_mode_button=Button.new()
    map_mode_button.text="2D vaade"
    map_mode_button.pressed.connect(_switch_mode)
    bar.add_child(map_mode_button)
    var new_world:=Button.new()
    new_world.text="Uus maailm"
    new_world.pressed.connect(regenerate)
    bar.add_child(new_world)
    var focus:=Button.new()
    focus.text="Näita kogu kaarti"
    focus.pressed.connect(func():
        map_canvas.fit_to_view()
        terrain_3d.fit_to_view())
    bar.add_child(focus)
    status_label=Label.new()
    status_label.text="Kaardi genereerimine..."
    status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    top.add_child(status_label)
    var map_frame:=Control.new()
    map_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    map_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
    map_frame.custom_minimum_size=Vector2(200,155)
    top.add_child(map_frame)
    map_canvas=Canvas.new()
    map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    map_canvas.cell_selected.connect(_on_selected)
    map_frame.add_child(map_canvas)
    terrain_3d=Terrain3D.new()
    terrain_3d.name="WorldTerrain3D"
    terrain_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    terrain_3d.cell_selected.connect(_on_selected)
    terrain_3d.cell_activated.connect(func(c:int,r:int): open_detail_requested.emit(c,r))
    map_frame.add_child(terrain_3d)
    _apply_map_mode()
    var legend:=Label.new()
    legend.text="3D maailm: päris kaubateed ja liikuvad karavanid. Topeltpuudutus avab detailkaardi. Lohista / suumi kahe sõrmega."
    legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    top.add_child(legend)
    info_label=Label.new()
    info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    info_label.custom_minimum_size=Vector2(0,23)
    info_label.clip_text=true
    top.add_child(info_label)
    _load_settings()
    call_deferred("_generate")

func _apply_map_mode() -> void:
    if map_canvas!=null:map_canvas.visible=not map_3d_enabled
    if terrain_3d!=null:terrain_3d.visible=map_3d_enabled
    if map_mode_button!=null:
        map_mode_button.text="2D vaade" if map_3d_enabled else "3D vaade"

func _switch_mode() -> void:
    map_3d_enabled=not map_3d_enabled
    _apply_map_mode()

func focus_world_tile(c: int,r: int) -> void:
    if terrain_3d==null or World.cell(world,c,r).is_empty():return
    terrain_3d.camera_target=Vector2(float(c)+0.5,float(r)+0.5)
    # Web returns to the same tile at world zoom, not continent overview.
    terrain_3d.zoom=65.0
    terrain_3d._update_camera()

func select_world_cell(c: int,r: int) -> void:
    if World.cell(world,c,r).is_empty():return
    selected_cell=Vector2i(c,r)
    if map_canvas!=null and map_canvas.chosen!=selected_cell:
        map_canvas.select_cell(c,r)
    if terrain_3d!=null and terrain_3d.selected!=selected_cell:
        terrain_3d.select_cell(c,r,false)
    _on_selected(c,r)

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
    terrain_3d.set_world(world)
    # Discard road overlay when generating a different world seed.
    map_canvas.set_trade_route({},[])
    terrain_3d.set_trade_route({},[])
    _repaint_districts()
    if world["starts"].size()>0:
        var first: Dictionary=world["starts"][0]
        select_world_cell(int(first["c"]),int(first["r"]))
    status_label.text="Seeme %d • %d mandrit • %d saart • maismaad %d ruutu • mäestikku %d ruutu • jõelõike %d" % [
        seed,int(world["layout"]["count"]),world["layout"]["islands"].size(),
        int(world["land_count"]),int(world["mountain_count"]),int(world.get("river_count",0))]
    _save_settings()

func regenerate() -> void:
    seed+=7919
    if seed>=2147483647:seed=82026
    status_label.text="Uue maailma genereerimine..."
    call_deferred("_generate")

func set_trade_route(route: Dictionary,caravans: Array) -> void:
    # The fallback atlas and default 3D map share exactly the same data.
    var fresh: bool=int(route.get("seed",-1))==int(world.get("seed",-2))
    var shown: Dictionary=route if fresh else {}
    var moving: Array=caravans if fresh else []
    if map_canvas!=null:map_canvas.set_trade_route(shown,moving)
    if terrain_3d!=null:terrain_3d.set_trade_route(shown,moving)

func set_city_districts(city: Dictionary) -> void:
    district_city=city
    _repaint_districts()

func _repaint_districts() -> void:
    if map_canvas==null or world.is_empty():return
    var occupied: Array=[]
    for p in Districts.cells(district_city,world):
        occupied.append({"c":p.x,"r":p.y})
    map_canvas.set_city_districts(occupied,Districts.connections(district_city,world))

func _on_selected(c: int,r: int) -> void:
    selected_cell=Vector2i(c,r)
    if map_canvas!=null and map_canvas.chosen!=selected_cell:
        map_canvas.select_cell(c,r)
    if terrain_3d!=null and terrain_3d.selected!=selected_cell:
        terrain_3d.select_cell(c,r,false)
    var cell: Dictionary=World.cell(world,c,r)
    if cell.is_empty():return
    var biome: String=String(cell.get("biome","sea"))
    var name: String={"sea":"Meri","plains":"Tasandik","forest":"Mets","hills":"Mäestik"}.get(biome,biome)
    var note: String=""
    if bool(cell.get("river",false)):note=" • Jõgi"
    if biome=="sea":note+=" • Laevatamine tuleb hiljem"
    if biome=="hills":note+=" • Läbimatu mäestik"
    if Districts.owns(district_city,world,c,r):
        note+=" • Sinu linna territoorium"
    var home: String=""
    for i in range(world["starts"].size()):
        var s: Dictionary=world["starts"][i]
        if int(s["c"])==c and int(s["r"])==r:
            home=" • Riigi %d algus" % (i+1)
    info_label.text="Ruut %d × %d • %s • kõrgus %.1f%s%s\nTopeltpuuduta 3D kaardil või vajuta Ava 3D detailkaart." % [
        c,r,name,float(cell.get("h",0)),note,home]
    _save_settings()

func open_selected_detail() -> void:
    if selected_cell.x < 0 or selected_cell.y < 0 or world.is_empty():
        return
    open_detail_requested.emit(selected_cell.x,selected_cell.y)

func reveal_city() -> void:
    open_city_requested.emit()
