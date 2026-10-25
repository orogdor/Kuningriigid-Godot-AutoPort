extends SceneTree
## Headless parity runner. Expectations are computed from upstream JavaScript,
## NEVER from the manually ported GDScript under test.
const Logic = preload("res://scripts/logic_v02.gd")
const CASES_PATH = "res://tests/logic_parity_cases.json"

func same(expected: Variant, actual: Variant) -> bool:
    if expected is Dictionary:
        if not actual is Dictionary or expected.size() != actual.size():
            return false
        for key in expected.keys():
            if not actual.has(key) or not same(expected[key], actual[key]):
                return false
        return true
    if expected is Array:
        if not actual is Array or expected.size() != actual.size():
            return false
        for i in range(expected.size()):
            if not same(expected[i], actual[i]):
                return false
        return true
    if typeof(expected) == TYPE_INT or typeof(expected) == TYPE_FLOAT:
        if typeof(actual) != TYPE_INT and typeof(actual) != TYPE_FLOAT:
            return false
        var a: float = float(expected)
        var b: float = float(actual)
        return is_finite(b) and absf(a - b) <= maxf(0.000001, absf(a) * 0.000000001)
    return expected == actual

func _initialize() -> void:
    if not FileAccess.file_exists(CASES_PATH):
        push_error("AutoPort parity fixtures absent: " + CASES_PATH)
        quit(1)
        return
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(CASES_PATH))
    if not doc is Dictionary or not doc.has("cases"):
        push_error("AutoPort parity fixtures invalid")
        quit(1)
        return
    var cases: Array = doc["cases"]
    if cases.size() < 500:
        push_error("Too few gameplay parity cases: " + str(cases.size()))
        quit(1)
        return
    var failed: int = 0
    for case_data in cases:
        var actual: Variant = Logic.evaluate(String(case_data["fn"]), case_data["input"])
        if not same(case_data["expected"], actual):
            failed += 1
            if failed <= 8:
                printerr("MISMATCH ", case_data["fn"], " input=", JSON.stringify(case_data["input"]), " expected=", JSON.stringify(case_data["expected"]), " actual=", JSON.stringify(actual))
    if failed > 0:
        push_error("AUTOPORT_LOGIC_PARITY FAILED: %d/%d mismatches" % [failed, cases.size()])
        quit(1)
    else:
        print("AUTOPORT_LOGIC_PARITY SUCCESS: %d/%d cases, source commit %s" % [cases.size(), cases.size(), String(doc.get("source_commit", "unknown"))])
        quit(0)
