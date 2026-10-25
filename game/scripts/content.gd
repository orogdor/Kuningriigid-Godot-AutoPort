extends Control
## This scene is part of the independently downloadable PCK.
## It is intentionally distinct from main.tscn, the stable boot/update shell.
const GeneratedRules = preload("res://scripts/generated_rules.gd")
const Logic = preload("res://scripts/logic_v02.gd")

func _ready() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_right", 22)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)
    var title := Label.new()
    title.text = "Kuningriigid • Godot AutoPort 0.3"
    title.add_theme_font_size_override("font_size", 27)
    column.add_child(title)
    var info := Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 18)
    column.add_child(info)
    var manifest: Dictionary = GeneratedRules.read_table("manifest")
    if manifest.is_empty():
        info.text = "Reeglite andmed puuduvad. Automaatne andmete eksport peab esmalt õnnestuma."
        return
    var tree: Dictionary = GeneratedRules.read_table("tech_tree")
    var goods: Dictionary = GeneratedRules.read_table("goods")
    var costs: Dictionary = GeneratedRules.read_table("era_costs")
    var capacity: int = Logic.city_capacity(60.0 * 60.0, 1)
    info.text = "Lähteversioon: %s\nTehnoloogiaid: %d\nKaupu: %d\nAjastute hinnakirju: %d\nLinnade limiit 60 mänguminutil: %d\n\nKuus mänguarvutust on üle kantud.\nTegemist on pordi kontrollrakendusega, mitte veel täismänguga." % [
        String(manifest.get("source_commit", "unknown")), tree.size(), goods.size(), costs.size(), capacity]
