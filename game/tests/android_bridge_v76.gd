extends SceneTree
## Reproduce an actual 0.51 Android bootstrap -> tiny bridge -> 0.76 PCK.
## This test runs from a clean project and never contacts GitHub.
func fail(message: String) -> void:
    printerr("ANDROID_BRIDGE_V76 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var old: String=OS.get_environment("LEGACY_ANDROID_PCK")
    var bridge_path: String=OS.get_environment("BRIDGE_ANDROID_PCK")
    var full_path: String=OS.get_environment("FULL_ANDROID_PCK")
    var expected: String=OS.get_environment("ANDROID_RELEASE_VERSION")
    if old.is_empty() or bridge_path.is_empty() or full_path.is_empty() \
            or expected.is_empty():
        fail("Missing PCK paths or release version")
        return
    if not ProjectSettings.load_resource_pack(old,true):
        fail("Could not mount original v0.51.738 content")
        return
    var old_boot: Resource=ResourceLoader.load("res://main.tscn")
    if not old_boot is PackedScene:
        fail("Original APK boot scene missing")
        return
    if not ProjectSettings.load_resource_pack(bridge_path,true):
        fail("Small bridge PCK failed to mount")
        return
    var bridge_scene: Resource=ResourceLoader.load("res://content.tscn",
        "PackedScene",ResourceLoader.CACHE_MODE_REPLACE_DEEP)
    if not bridge_scene is PackedScene:
        fail("Original entrypoint did not resolve to bridge")
        return
    root.size=Vector2i(720,480)
    var bridge: Node=(bridge_scene as PackedScene).instantiate()
    if bridge==null or not bridge.has_method("_mount_full_from_path"):
        fail("Bootstrap still opens original 0.51 content")
        return
    root.add_child(bridge)
    current_scene=bridge
    await process_frame
    if not bool(bridge.call("_mount_full_from_path",full_path)):
        fail("Bridge cannot mount full Android game")
        return
    await process_frame
    await process_frame
    await process_frame
    var game: Node=current_scene
    if game==null or game==bridge:
        fail("Still running old APK or bootstrap")
        return
    var title: Label=game.find_child("ContentVersionV58",true,false) as Label
    if title==null or not ("GODOT "+expected) in title.text:
        fail("Wrong version header in newly mounted full game: "+\
            (title.text if title!=null else "<missing>"))
        return
    print("ANDROID_BRIDGE_V76 SUCCESS: original 0.51 APK -> small PCK bridge -> real game "+expected)
    quit(0)
