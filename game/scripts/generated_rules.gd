extends RefCounted
## The exported JSON serves both Godot runtime and parity validation.
const ALLOWED: Array[String] = [
    "manifest", "tech_tree", "tech_reforms", "production_reforms", "goods", "good_buildings",
    "food_needs", "era_costs", "era_techs", "bronze_min_turns", "bronze_fortify_pop",
    "bronze_full_wall_pop", "science_per_resident", "science_per_city", "science_per_turn", "eureka_fraction"]

static func read_table(table: String) -> Variant:
    if not ALLOWED.has(table):
        push_warning("AutoPort: unknown table " + table)
        return {}
    var path: String = "res://data/generated/" + table + ".json"
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path,FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed == null:
        push_warning("AutoPort: invalid JSON in " + table)
        return {}
    return parsed
