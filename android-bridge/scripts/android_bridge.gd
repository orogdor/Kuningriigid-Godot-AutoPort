extends Control
## Bridge for legacy Android 0.51: the APK's original PCK updater times
## out after 24 seconds. This small scene downloads the large game pack
## with a long timeout and then opens a distinct noncached game entrypoint.
const API: String="https://api.github.com/repos/orogdor/Kuningriigid-Godot-AutoPort/releases/latest"
const ASSET: String="Kuningriigid-Full-Content.pck"
const GAME_SCENE: String="res://game_content.tscn"
const PACK: String="user://kuningriigid-full-content.pck"
const HASH: String="user://kuningriigid-full-content.sha256"
const NEXT: String="user://kuningriigid-full-next.pck"
const BACKUP: String="user://kuningriigid-full-backup.pck"
const BACKUP_HASH: String="user://kuningriigid-full-backup.sha256"
const STATUS: String="user://kuningriigid-bridge-status.txt"
const TIMEOUT: float=1800.0
var label: Label
var retry: Button
var http: HTTPRequest
var stage: String=""
var download_url: String=""
var expected_sha: String=""
var display_clock: int=0

func _ready() -> void:
    var column:=VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    column.add_theme_constant_override("separation",14)
    add_child(column)
    var heading:=Label.new()
    heading.text="Kuningriigid • mängu uuendamine"
    heading.add_theme_font_size_override("font_size",25)
    column.add_child(heading)
    label=Label.new()
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",19)
    column.add_child(label)
    retry=Button.new()
    retry.text="Proovi uuesti"
    retry.pressed.connect(_check_release)
    retry.hide()
    column.add_child(retry)
    http=HTTPRequest.new()
    http.timeout=TIMEOUT
    http.max_redirects=8
    http.request_completed.connect(_on_done)
    add_child(http)
    _recover()
    if OS.get_environment("AUTOPORT_BRIDGE_SMOKE")!="1":
        _check_release()

func _process(_delta: float) -> void:
    if stage!="download" or http==null:return
    var now: int=Time.get_ticks_msec()
    if now-display_clock<300:return
    display_clock=now
    var received: float=float(http.get_downloaded_bytes())/1048576.0
    var total: int=http.get_body_size()
    if total>0:
        label.text="Laadin mängu: %.1f / %.1f MB (%.0f%%). Ära sulge rakendust." % [
            received,float(total)/1048576.0,
            float(http.get_downloaded_bytes())*100.0/float(total)]
    else:
        label.text="Laadin mängu: %.1f MB. Ära sulge rakendust." % received

func _note(value: String) -> void:
    if label!=null:label.text=value
    var file:=FileAccess.open(STATUS,FileAccess.WRITE)
    if file!=null:
        file.store_string(value)
        file.close()

func _exists(path: String) -> bool:
    return FileAccess.file_exists(path)

func _remove(path: String) -> void:
    if _exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _move(source: String,destination: String) -> bool:
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(source),
        ProjectSettings.globalize_path(destination))==OK

func _valid(path: String,checksum_path: String) -> bool:
    if not _exists(path) or not _exists(checksum_path):return false
    var sha: String=FileAccess.get_file_as_string(checksum_path).strip_edges().to_lower()
    return sha.length()==64 and sha.is_valid_hex_number() and \
        FileAccess.get_sha256(path).to_lower()==sha

func _recover() -> void:
    if _valid(PACK,HASH):
        _remove(BACKUP)
        _remove(BACKUP_HASH)
        return
    if _valid(BACKUP,BACKUP_HASH):
        _remove(PACK)
        _remove(HASH)
        _move(BACKUP,PACK)
        _move(BACKUP_HASH,HASH)

func _check_release() -> void:
    if http==null:return
    retry.hide()
    stage="release"
    http.download_file=""
    _note("Kontrollin GitHubist mängu uut versiooni...")
    var err: Error=http.request(API,PackedStringArray([
        "Accept: application/vnd.github+json","User-Agent: Kuningriigid-AutoPort"]))
    if err!=OK:
        stage=""
        _offline_or_error("Uuenduste serveriga ühenduse loomine ebaõnnestus.")

func _on_done(result: int,code: int,
        _headers: PackedStringArray,body: PackedByteArray) -> void:
    var completed: String=stage
    stage=""
    if completed=="release":
        _received_release(result,code,body)
    elif completed=="download":
        _received_download(result,code)

func _received_release(result: int,code: int,body: PackedByteArray) -> void:
    if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
        _offline_or_error("GitHubi vastus ebaõnnestus (HTTP %d)." % code)
        return
    var data: Variant=JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        _offline_or_error("GitHubi vastus ei ole korrektne.")
        return
    var assets: Variant=data.get("assets",[])
    if not assets is Array:
        _offline_or_error("Väljalaske failide loend puudub.")
        return
    download_url=""
    expected_sha=""
    for candidate in assets:
        if not candidate is Dictionary or String(candidate.get("name",""))!=ASSET:
            continue
        download_url=String(candidate.get("browser_download_url",""))
        var digest: String=String(candidate.get("digest",""))
        if digest.begins_with("sha256:"):
            expected_sha=digest.substr(7).to_lower()
        break
    if not download_url.begins_with(
            "https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/download/") \
            or expected_sha.length()!=64 or not expected_sha.is_valid_hex_number():
        _offline_or_error("Kontrollitud täisversiooni pakett puudub.")
        return
    if _valid(PACK,HASH) and \
            FileAccess.get_file_as_string(HASH).strip_edges().to_lower()==expected_sha:
        if _mount_full_from_path(PACK):return
        _offline_or_error("Salvestatud mängu avamine ebaõnnestus.")
        return
    _remove(NEXT)
    stage="download"
    _note("Laadin uut mängu. Suur fail, vajadusel kasuta Wi-Fi ühendust.")
    http.download_file=NEXT
    var err: Error=http.request(download_url,PackedStringArray([
        "User-Agent: Kuningriigid-AutoPort"]))
    if err!=OK:
        stage=""
        _offline_or_error("Allalaadimise käivitamine ebaõnnestus.")

func _received_download(result: int,code: int) -> void:
    if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not _exists(NEXT):
        _offline_or_error("Mängu allalaadimine katkes (HTTP %d)." % code)
        return
    _note("Kontrollin allalaaditud mängu SHA-256 kontrollsummat...")
    if FileAccess.get_sha256(NEXT).to_lower()!=expected_sha:
        _remove(NEXT)
        _offline_or_error("Allalaaditud fail ei läbinud SHA-256 kontrolli.")
        return
    if not _promote():
        _offline_or_error("Mängu salvestamine ebaõnnestus.")
        return
    if not _mount_full_from_path(PACK):
        _offline_or_error("Uue mängu avamine ebaõnnestus.")

func _promote() -> bool:
    if not _exists(NEXT) or FileAccess.get_sha256(NEXT).to_lower()!=expected_sha:
        return false
    _remove(BACKUP)
    _remove(BACKUP_HASH)
    var previous: bool=_valid(PACK,HASH)
    if previous:
        if not _move(PACK,BACKUP):return false
        if not _move(HASH,BACKUP_HASH):
            _move(BACKUP,PACK)
            return false
    else:
        _remove(PACK)
        _remove(HASH)
    if not _move(NEXT,PACK):
        _recover()
        return false
    var file:=FileAccess.open(HASH,FileAccess.WRITE)
    if file==null:
        _recover()
        return false
    file.store_string(expected_sha)
    file.close()
    if not _valid(PACK,HASH):
        _recover()
        return false
    _remove(BACKUP)
    _remove(BACKUP_HASH)
    return true

func _mount_full_from_path(path: String) -> bool:
    if not _exists(path):return false
    if not ProjectSettings.load_resource_pack(
            ProjectSettings.globalize_path(path),true):
        return false
    var resource: Resource=ResourceLoader.load(GAME_SCENE,
        "PackedScene",ResourceLoader.CACHE_MODE_REPLACE_DEEP)
    if not resource is PackedScene:return false
    if not FileAccess.file_exists("res://data/generated/release.json"):return false
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/generated/release.json"))
    if not data is Dictionary:return false
    var version: String=String(data.get("version",""))
    if version.is_empty():return false
    _note("Käivitan Kuningriigid "+version+"...")
    get_tree().call_deferred("change_scene_to_packed",resource as PackedScene)
    return true

func _offline_or_error(message: String) -> void:
    if _valid(PACK,HASH) and _mount_full_from_path(PACK):
        return
    _note(message+" Puuduta „Proovi uuesti“. Vana 0.51 ei ole uus mänguversioon.")
    retry.show()
