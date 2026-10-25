extends SceneTree
## Fail a release if the actual scene cannot open and run the new 0.5 controls.
const View = preload("res://content.tscn")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var scene: Control = View.instantiate()
    root.add_child(scene)
    await process_frame
    if scene.city.is_empty() or scene.recipes.is_empty():
        printerr("CITY_V05_UI: scene failed to load economy definitions")
        quit(1)
        return
    if int(scene.city["time"]) != 0 and not FileAccess.file_exists("user://autoport_city_v05.json"):
        printerr("CITY_V05_UI: unexpected starting clock")
        quit(1)
        return
    scene._reset()
    var old_stock: float = float(scene.city["realms"][0]["resources"]["wood"])
    scene._build("lumber")
    if scene.city["buildings"].size() != 2 or float(scene.city["realms"][0]["resources"]["wood"]) >= old_stock:
        printerr("CITY_V05_UI: building controls did not debit materials")
        quit(1)
        return
    scene._advance(10)
    if int(scene.city["time"]) != 600 or not bool(scene.city["buildings"][1].get("ready",false)):
        printerr("CITY_V05_UI: ten-turn build operation failed")
        quit(1)
        return
    scene._save()
    if not FileAccess.file_exists("user://autoport_city_v05.json"):
        printerr("CITY_V05_UI: saving failed")
        quit(1)
        return
    print("CITY_V05_UI SUCCESS: scene, build, turn controls and save")
    quit(0)
