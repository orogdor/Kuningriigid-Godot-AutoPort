extends Control
## Minimal Godot 4 preview: loads the same JSON used in source parity checks.
## This is a rules validation scene, not the full Kuningriigid game.
const GeneratedRules = preload("res://scripts/generated_rules.gd")

func _ready() -> void:
    var column := VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    column.add_theme_constant_override("separation", 18)
    add_child(column)
    var heading := Label.new()
    heading.text = "Kuningriigid • Godot AutoPort"
    heading.add_theme_font_size_override("font_size", 27)
    column.add_child(heading)
    var report := Label.new()
    report.name = "GeneratedRulesStatus"
    report.add_theme_font_size_override("font_size", 20)
    report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(report)
    var manifest: Dictionary = GeneratedRules.read_table("manifest")
    if manifest.is_empty():
        report.text = "Mängureegleid pole veel eksporditud. Käivita npm run port."
        return
    var tree: Dictionary = GeneratedRules.read_table("tech_tree")
    var goods: Dictionary = GeneratedRules.read_table("goods")
    var costs: Dictionary = GeneratedRules.read_table("era_costs")
    report.text = "Lähtekoodi commit: %s\nTehnoloogiaid: %d\nKaupu: %d\nAjastute hinnakirju: %d\n\nSee on automaatse pordi andmekontroll, mitte veel mäng." % [
        String(manifest.get("source_commit","unknown")),tree.size(),goods.size(),costs.size()]
