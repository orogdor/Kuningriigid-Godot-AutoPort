extends SceneTree
## Offline Android content-updater regression. Never contacts GitHub.
## GitHub Actions has an isolated user:// directory; no player data touched.
const Updater=preload("res://scripts/startup_updater.gd")

func fail(message: String) -> void:
    printerr("UPDATER_V57 FAIL: "+message)
    quit(1)

func _write(path: String,contents: String) -> bool:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:return false
    file.store_string(contents)
    file.close()
    return true

func _remove(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var updater=Updater.new()
    # Always start from clean temporary CI state.
    for path in [Updater.CACHE_PATH,Updater.HASH_PATH,Updater.NEXT_PATH,
            Updater.NEXT_HASH_PATH,Updater.BACKUP_PATH,Updater.BACKUP_HASH_PATH]:
        _remove(path)
    if not _write(Updater.CACHE_PATH,"old-verified-content"):
        fail("cannot write old cache fixture")
        return
    var old_hash: String=FileAccess.get_sha256(Updater.CACHE_PATH)
    _write(Updater.HASH_PATH,old_hash)
    if not updater._valid_cached_pack():
        fail("previous cached checksum should be valid")
        return
    _write(Updater.NEXT_PATH,"new-verified-content")
    updater.expected_sha=FileAccess.get_sha256(Updater.NEXT_PATH)
    if not updater._promote_verified_pack():
        fail("verified new content was not installed")
        return
    if not updater._valid_cached_pack() or \
            FileAccess.get_file_as_string(Updater.CACHE_PATH)!="new-verified-content":
        fail("new content or checksum was not installed intact")
        return
    var installed_hash: String=FileAccess.get_sha256(Updater.CACHE_PATH)
    _write(Updater.NEXT_PATH,"damaged-download")
    updater.expected_sha="f".repeat(64)
    if updater._promote_verified_pack():
        fail("corrupt download passed verification")
        return
    if FileAccess.get_sha256(Updater.CACHE_PATH)!=installed_hash:
        fail("corrupt download destroyed previously working cache")
        return
    # Crash immediately after moving both old files to the backup names.
    _remove(Updater.NEXT_PATH)
    if not updater._move(Updater.CACHE_PATH,Updater.BACKUP_PATH) or \
            not updater._move(Updater.HASH_PATH,Updater.BACKUP_HASH_PATH):
        fail("cannot construct interrupted update")
        return
    updater._recover_interrupted_swap()
    if not updater._valid_cached_pack() or \
            FileAccess.get_file_as_string(Updater.CACHE_PATH)!="new-verified-content":
        fail("crash recovery did not restore previous verified content")
        return
    for path in [Updater.CACHE_PATH,Updater.HASH_PATH,Updater.NEXT_PATH,
            Updater.NEXT_HASH_PATH,Updater.BACKUP_PATH,Updater.BACKUP_HASH_PATH]:
        _remove(path)
    updater.free()
    print("UPDATER_V57 SUCCESS: staged PCK+hash, corrupt download rejection, preserved previous pack and interrupted update recovery")
    quit(0)
