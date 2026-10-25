extends SceneTree
## Compare the whole isolated Godot city economy against real upstream
## economy.js::tickEconomy for 6 x 200 sequential turns.
const City = preload("res://scripts/city_sim_v05.gd")
const Rules = preload("res://scripts/generated_rules.gd")
const PATH = "res://tests/city_v05_fixtures.json"

func equal(expected: Variant, actual: Variant) -> bool:
    if expected is Dictionary:
        if not actual is Dictionary or expected.size() != actual.size():
            return false
        for key in expected.keys():
            if not actual.has(key) or not equal(expected[key], actual[key]):
                return false
        return true
    if expected is Array:
        if not actual is Array or expected.size() != actual.size():
            return false
        for i in range(expected.size()):
            if not equal(expected[i],actual[i]):
                return false
        return true
    if expected is float or expected is int:
        if not (actual is float or actual is int):
            return false
        var a: float = float(expected)
        var b: float = float(actual)
        return is_finite(b) and absf(a - b) <= maxf(0.00001,absf(a) * 0.000000001)
    return expected == actual

func _initialize() -> void:
    var definitions: Dictionary = Rules.read_table("city_buildings")
    if definitions.is_empty() or not FileAccess.file_exists(PATH):
        printerr("City reference fixtures or building definitions missing")
        quit(1)
        return
    var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not fixture is Dictionary:
        printerr("Invalid reference format")
        quit(1)
        return
    var scenarios: Array = fixture.get("scenarios",[])
    if scenarios.size() < 6:
        printerr("Too few city scenarios")
        quit(1)
        return
    var total: int = 0
    var errors: int = 0
    for scenario in scenarios:
        var state: Dictionary = scenario["initial"].duplicate(true)
        var turns: Array = scenario["turns"]
        if turns.size() != 200:
            printerr("Expected 200 turns for " + String(scenario["name"]))
            quit(1)
            return
        for expected in turns:
            City.tick(state,definitions)
            var actual: Dictionary = City.snapshot(state)
            total += 1
            if not equal(expected,actual):
                errors += 1
                if errors <= 8:
                    printerr("V05_MISMATCH ", scenario["name"], " turn=", total,
                        " expected=",JSON.stringify(expected), " actual=",JSON.stringify(actual))
    if errors:
        printerr("CITY_V05_PARITY FAILED: %d of %d 1-minute turns" % [errors,total])
        quit(1)
        return
    print("CITY_V05_PARITY SUCCESS: %d turns / %d scenarios, JS source %s" % [
        total,scenarios.size(),String(fixture.get("source_commit","unknown"))])
    quit(0)
