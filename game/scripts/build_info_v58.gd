extends RefCounted
## Version of the ACTUALLY MOUNTED game content, not the old Android APK.
## Embedded in each release PCK by tools/stamp_release.py before export.
const FILE: String="res://data/generated/release.json"
const SOURCE_FALLBACK: String="0.93"

static func release_version() -> String:
    if not FileAccess.file_exists(FILE):
        return SOURCE_FALLBACK
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(FILE))
    if not data is Dictionary:return SOURCE_FALLBACK
    var version: String=String(data.get("version","")).strip_edges()
    if version.length()<3 or version.length()>40:return SOURCE_FALLBACK
    if not version.begins_with("0."):return SOURCE_FALLBACK
    return version

static func release_tag() -> String:
    return "v"+release_version()

static func content_caption() -> String:
    return "GODOT "+release_version()
