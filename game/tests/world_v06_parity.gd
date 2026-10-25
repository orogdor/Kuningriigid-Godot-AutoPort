extends SceneTree
## Enforce parity with the seeded world shape and separated site generation
## in the real upstream continent-map.js. Terrain height is still approximate.
const World = preload("res://scripts/world_gen_v06.gd")
const PATH = "res://tests/world_v06_fixtures.json"

func close(a: float,b: float) -> bool:
    return absf(a-b) <= 0.000001

func same_points(got: Array, expected: Array) -> bool:
    if got.size()!=expected.size():return false
    for i in range(got.size()):
        var actual: Vector2=got[i]
        var point: Variant=expected[i]
        var x: float=float(point[0]) if point is Array else float(point["x"])
        var y: float=float(point[1]) if point is Array else float(point["y"])
        if not close(actual.x,x) or not close(actual.y,y):return false
    return true

func _initialize() -> void:
    if not FileAccess.file_exists(PATH):
        printerr("Missing world reference fixtures")
        quit(1)
        return
    var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not doc is Dictionary or doc.get("cases",[]).size()!=6:
        printerr("Invalid world parity document")
        quit(1)
        return
    var passed: int=0
    for expected in doc["cases"]:
        var result: Dictionary=World.layout(int(expected["seed"]),bool(expected["islands"]))
        if int(result["count"])!=int(expected["count"]) or int(result["bridges"])!=int(expected["bridges"]):
            printerr("WORLD_V06_PARITY count/bridge mismatch seed=",expected["seed"])
            quit(1)
            return
        if not same_points(result["centers"],expected["centers"]) or not same_points(result["islands"],expected["islandCenters"]):
            printerr("WORLD_V06_PARITY centers mismatch seed=",expected["seed"])
            quit(1)
            return
        if result["polygons"].size()!=expected["polygons"].size():
            printerr("WORLD_V06_PARITY polygon count mismatch seed=",expected["seed"])
            quit(1)
            return
        for k in range(result["polygons"].size()):
            if not same_points(result["polygons"][k],expected["polygons"][k]):
                printerr("WORLD_V06_PARITY polygon mismatch seed=",expected["seed"]," polygon=",k)
                quit(1)
                return
        if result["starts"].size()!=expected["starts"].size():
            printerr("WORLD_V06_PARITY start count mismatch")
            quit(1)
            return
        for k in range(result["starts"].size()):
            if result["starts"][k] != expected["starts"][k]:
                printerr("WORLD_V06_PARITY site mismatch seed=",expected["seed"]," i=",k,
                    " godot=",result["starts"][k]," js=",expected["starts"][k])
                quit(1)
                return
        passed+=1
    print("WORLD_V06_PARITY SUCCESS: %d original continent/island layouts" % passed)
    quit(0)
