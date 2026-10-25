extends Control
## The stable APK/EXE checks for a newer downloadable Godot content pack every launch.
## Content packs run inside the existing Godot engine; Android does not install APKs silently.
const API_URL := "https://api.github.com/repos/orogdor/Kuningriigid-Godot-AutoPort/releases/latest"
const ASSET_NAME := "Kuningriigid-Content.pck"
const CACHE_PATH := "user://kuningriigid-content.pck"
const NEXT_PATH := "user://kuningriigid-next.pck"
const HASH_PATH := "user://kuningriigid-content.sha256"
const SCENE_PATH := "res://content.tscn"
const NETWORK_TIMEOUT := 24.0

var label: Label
var http: HTTPRequest
var pack_url := ""
var expected_sha := ""
var last_reason := ""

func _ready() -> void:
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
    if pack_url == "" or expected_sha.length() != 64:
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
    var target: String = ProjectSettings.globalize_path(CACHE_PATH)
    if FileAccess.file_exists(CACHE_PATH):
        var delete_err: Error = DirAccess.remove_absolute(target)
        if delete_err != OK:
            _load_best_available("Vana paketi asendamine ebaõnnestus.")
            return
    var moved: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(NEXT_PATH), target)
    if moved != OK:
        _load_best_available("Uue paketi salvestamine ebaõnnestus.")
        return
    var hash_file := FileAccess.open(HASH_PATH, FileAccess.WRITE)
    if hash_file == null:
        _load_best_available("Uuenduse kontrollsumma salvestamine ebaõnnestus.")
        return
    hash_file.store_string(expected_sha)
    hash_file.close()
    _open_content("Sisu uuendatud.")

func _load_best_available(reason: String) -> void:
    _open_content(reason + " Käivitan olemasoleva versiooni.")

func _open_content(reason: String) -> void:
    last_reason = reason
    label.text = reason
    if _valid_cached_pack():
        var fullpath: String = ProjectSettings.globalize_path(CACHE_PATH)
        if not ProjectSettings.load_resource_pack(fullpath, true):
            push_warning("Cached content pack failed to mount; falling back to built-in preview")
    get_tree().call_deferred("change_scene_to_file", SCENE_PATH)
