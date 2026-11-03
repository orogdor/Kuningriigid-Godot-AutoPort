extends SceneTree
## The installed APK may still be 0.51: the game must show the exact
## version of the newly mounted PCK rather than the bootstrap package.
const UI=preload("res://content.tscn")
const Version=preload("res://scripts/build_info_v58.gd")
const PATH: String="res://data/generated/release.json"

func _fail(why: String) -> void:
    printerr("CONTENT_VERSION_V58 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var exists: bool=FileAccess.file_exists(PATH)
    var before: String=FileAccess.get_file_as_string(PATH) if exists else ""
    var file:=FileAccess.open(PATH,FileAccess.WRITE)
    if file==null:
        _fail("Cannot create release identity fixture")
        return
    file.store_string('{"version":"0.56.987","tag":"v0.56.987","run_number":987}')
    file.close()
    if Version.release_version()!="0.56.987":
        _fail("Version reader ignores mounted release metadata")
        return
    root.size=Vector2i(780,550)
    var ui: Control=UI.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    var title: Label=ui.find_child("ContentVersionV58",true,false) as Label
    if title==null or not "GODOT 0.56.987" in title.text:
        _fail("In-game header still uses a hardcoded version")
        return
    if exists:
        var restore:=FileAccess.open(PATH,FileAccess.WRITE)
        if restore==null:
            _fail("Cannot restore fixture file")
            return
        restore.store_string(before)
        restore.close()
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    print("CONTENT_VERSION_V58 SUCCESS: in-game title uses exact PCK release version")
    quit(0)
