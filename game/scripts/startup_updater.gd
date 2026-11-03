extends Control
## The stable APK/EXE checks for a newer downloadable Godot content pack every launch.
## Content packs run inside the existing Godot engine; Android does not install APKs silently.
const API_URL := "https://api.github.com/repos/orogdor/Kuningriigid-Godot-AutoPort/releases/latest"
const ASSET_NAME := "Kuningriigid-Content.pck"
const CACHE_PATH := "user://kuningriigid-content.pck"
const NEXT_PATH := "user://kuningriigid-next.pck"
const HASH_PATH := "user://kuningriigid-content.sha256"
const NEXT_HASH_PATH := "user://kuningriigid-next.sha256"
const BACKUP_PATH := "user://kuningriigid-content.previous.pck"
const BACKUP_HASH_PATH := "user://kuningriigid-content.previous.sha256"
const STATUS_PATH := "user://last-update-status.txt"
const SCENE_PATH := "res://content.tscn"
const NETWORK_TIMEOUT := 24.0

var label: Label
var http: HTTPRequest
var pack_url := ""
var expected_sha := ""
var last_reason := ""

func _ready() -> void:
    # Windows is started by the independent native launcher, which has already
    # downloaded game/scripts, data/generated and scenes into a real directory.
    # Keep the embedded PCK updater only for Android.
    if OS.get_name() == "Windows":
        get_tree().call_deferred("change_scene_to_file", SCENE_PATH)
        return
    _recover_interrupted_swap()
    var layout := VBoxContainer.new()
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout.add_theme_constant_override("separation", 14)
    add_child(layout)
    var title := Label.new()
    title.text = "Kuningriigid Godot"
    title.add_theme_font_size_override("font_size", 27)
    layout.add_child(title)
    label = Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 20)
    layout.add_child(label)
    http = HTTPRequest.new()
    http.timeout = NETWORK_TIMEOUT
    http.max_redirects = 8
    add_child(http)
    label.text = "Kontrollin käivitamisel GitHubi uuendusi..."
    http.request_completed.connect(_on_release_response)
    var err := http.request(API_URL, PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: Kuningriigid-AutoPort"]))
    if err != OK:
        _load_best_available("Võrgukontroll pole saadaval.")

func _valid_cached_pack() -> bool:
    if not FileAccess.file_exists(CACHE_PATH) or not FileAccess.file_exists(HASH_PATH):
        return false
    var stored_sha: String = FileAccess.get_file_as_string(HASH_PATH).strip_edges().to_lower()
    if stored_sha.length() != 64:
        return false
    return FileAccess.get_sha256(CACHE_PATH).to_lower() == stored_sha

func _on_release_response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
    http.request_completed.disconnect(_on_release_response)
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        _load_best_available("Värske versiooni kontroll ebaõnnestus (HTTP %d)." % code)
        return
    var release: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if not release is Dictionary:
        _load_best_available("GitHubi vastus ei olnud korrektne.")
        return
    var assets: Variant = release.get("assets", [])
    if not assets is Array:
        _load_best_available("Väljalaske failide loend puudub.")
        return
    for asset in assets:
        if not asset is Dictionary or String(asset.get("name", "")) != ASSET_NAME:
            continue
        pack_url = String(asset.get("browser_download_url", ""))
        var digest: String = String(asset.get("digest", ""))
        if digest.begins_with("sha256:"):
            expected_sha = digest.substr(7).to_lower()
        break
    if not pack_url.begins_with(
            "https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/download/"):
        pack_url = ""
    if pack_url == "" or expected_sha.length() != 64 or not expected_sha.is_valid_hex_number():
        _load_best_available("Uuendus puudub või puudub SHA-256 kontroll.")
        return
    if _valid_cached_pack() and FileAccess.get_file_as_string(HASH_PATH).strip_edges().to_lower() == expected_sha:
        _open_content("Uusim sisu on juba salvestatud.")
        return
    label.text = "Leidsin uuema sisu. Laadin ja kontrollin faili..."
    http.download_file = NEXT_PATH
    http.request_completed.connect(_on_download_response)
    var err := http.request(pack_url, PackedStringArray(["User-Agent: Kuningriigid-AutoPort"]))
    if err != OK:
        _load_best_available("Uue sisu allalaadimine ei käivitunud.")

func _on_download_response(result: int, code: int, _headers: PackedStringArray, _bytes: PackedByteArray) -> void:
    http.request_completed.disconnect(_on_download_response)
    if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(NEXT_PATH):
        _load_best_available("Uuenduse allalaadimine ebaõnnestus.")
        return
    if FileAccess.get_sha256(NEXT_PATH).to_lower() != expected_sha:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(NEXT_PATH))
        _load_best_available("Uuenduse turvakontroll ebaõnnestus.")
        return
    if not _promote_verified_pack():
        _load_best_available("Uuenduse salvestamine ebaõnnestus; eelmine pakett säilitati.")
        return
    _open_content("Sisu uuendatud ja SHA-256 kontrollitud.")

func _exists(path: String) -> bool:
    return FileAccess.file_exists(path)

func _remove(path: String) -> void:
    if _exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _move(source: String, destination: String) -> bool:
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(source),
        ProjectSettings.globalize_path(destination)) == OK

func _recover_interrupted_swap() -> void:
    # An interrupted installation must leave either a fully verified new
    # content pack or the previous pack, never a half-written replacement.
    if _valid_cached_pack():
        _remove(BACKUP_PATH)
        _remove(BACKUP_HASH_PATH)
        return
    if _exists(BACKUP_PATH) and _exists(BACKUP_HASH_PATH):
        var old_hash: String=FileAccess.get_file_as_string(
            BACKUP_HASH_PATH).strip_edges().to_lower()
        if old_hash.length()==64 and FileAccess.get_sha256(BACKUP_PATH).to_lower()==old_hash:
            _remove(CACHE_PATH)
            _remove(HASH_PATH)
            _move(BACKUP_PATH,CACHE_PATH)
            _move(BACKUP_HASH_PATH,HASH_PATH)

func _promote_verified_pack() -> bool:
    # Do not delete the only working pack before verifying and staging the new
    # pack plus its checksum. On any rename error, roll both files back.
    if expected_sha.length()!=64 or not expected_sha.is_valid_hex_number():
        return false
    if not _exists(NEXT_PATH) or FileAccess.get_sha256(NEXT_PATH).to_lower()!=expected_sha:
        return false
    _remove(NEXT_HASH_PATH)
    var tmp_hash:=FileAccess.open(NEXT_HASH_PATH,FileAccess.WRITE)
    if tmp_hash==null:return false
    tmp_hash.store_string(expected_sha)
    tmp_hash.close()

    _remove(BACKUP_PATH)
    _remove(BACKUP_HASH_PATH)
    var had_pack: bool=_exists(CACHE_PATH)
    var had_hash: bool=_exists(HASH_PATH)
    if had_pack and not _move(CACHE_PATH,BACKUP_PATH):return false
    if had_hash and not _move(HASH_PATH,BACKUP_HASH_PATH):
        if had_pack:_move(BACKUP_PATH,CACHE_PATH)
        return false

    if not _move(NEXT_PATH,CACHE_PATH):
        if had_pack:_move(BACKUP_PATH,CACHE_PATH)
        if had_hash:_move(BACKUP_HASH_PATH,HASH_PATH)
        return false
    if not _move(NEXT_HASH_PATH,HASH_PATH):
        _remove(CACHE_PATH)
        if had_pack:_move(BACKUP_PATH,CACHE_PATH)
        if had_hash:_move(BACKUP_HASH_PATH,HASH_PATH)
        return false
    if not _valid_cached_pack():
        _remove(CACHE_PATH)
        _remove(HASH_PATH)
        if had_pack:_move(BACKUP_PATH,CACHE_PATH)
        if had_hash:_move(BACKUP_HASH_PATH,HASH_PATH)
        return false
    _remove(BACKUP_PATH)
    _remove(BACKUP_HASH_PATH)
    return true

func _load_best_available(reason: String) -> void:
    _open_content(reason + " Käivitan olemasoleva versiooni.")

func _open_content(reason: String) -> void:
    last_reason = reason
    label.text = reason
    var status_file:=FileAccess.open(STATUS_PATH,FileAccess.WRITE)
    if status_file!=null:
        status_file.store_string(reason)
        status_file.close()
    if _valid_cached_pack():
        var fullpath: String = ProjectSettings.globalize_path(CACHE_PATH)
        if not ProjectSettings.load_resource_pack(fullpath, true):
            push_warning("Cached content pack failed to mount; falling back to built-in preview")
    get_tree().call_deferred("change_scene_to_file", SCENE_PATH)
