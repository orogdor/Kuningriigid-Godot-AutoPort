extends SceneTree
## Regression for the exact Android-targeted PCK distributed to v0.51 APKs.
## Run in a fresh Godot process, before any game scene is loaded/cached.
func _fail(message: String) -> void:
    printerr("ANDROID_PACK_V58 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_check_pack")

func _has_version(node: Node,expected: String) -> bool:
    if node is Label and expected in String(node.text):
        return true
    for child in node.get_children():
        if _has_version(child,expected):return true
    return false

func _check_pack() -> void:
    var pack: String=OS.get_environment("ANDROID_CONTENT_PACK")
    if pack.is_empty() or not FileAccess.file_exists(pack):
        _fail("Android-targeted PCK path is missing")
        return
    if not ProjectSettings.load_resource_pack(pack,true):
        _fail("Godot could not mount the release PCK")
        return
    var scene: PackedScene=ResourceLoader.load("res://content.tscn") as PackedScene
    if scene==null:
        _fail("The Android PCK lacks a loadable content scene")
        return
    var ui: Control=scene.instantiate() as Control
    if ui==null:
        _fail("The exported content scene could not be instantiated")
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    var expected: String=OS.get_environment("ANDROID_RELEASE_VERSION")
    if expected.is_empty():
        _fail("Test did not receive the release version")
        return
    var manifest_path: String="res://data/generated/release.json"
    if not FileAccess.file_exists(manifest_path):
        _fail("Android export pack omitted the content version metadata")
        return
    var version_data: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not version_data is Dictionary or String(version_data.get("version",""))!=expected:
        _fail("Mounted PCK reported the wrong content release version")
        return
    if not _has_version(ui,"GODOT "+expected):
        _fail("Game header did not reflect mounted PCK version "+expected)
        return
    print("ANDROID_PACK_V58 SUCCESS: Android PCK mounted; UI displays release "+expected)
    quit(0)
