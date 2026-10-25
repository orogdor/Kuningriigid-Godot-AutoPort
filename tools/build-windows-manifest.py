#!/usr/bin/env python3
"""Manifest for the native Windows launcher. Every listed file is a real file
stored in the Git repository at a pinned, immutable commit SHA."""
import argparse
import hashlib
import json
import re
from pathlib import Path

IGNORED_DIRS = {".godot", "tests", "__pycache__"}
IGNORED_FILES = {"export_presets.cfg", ".DS_Store"}
VALID_EXT = {
    ".godot", ".tscn", ".tres", ".gd", ".uid", ".json", ".png",
    ".jpg", ".jpeg", ".webp", ".svg", ".glb", ".gltf", ".obj",
    ".wav", ".ogg", ".mp3", ".ttf", ".otf", ".gdshader", ".import",
    ".csv", ".txt", ".cfg", ".res", ".theme", ".mesh", ".material",
}

def generate(source: Path, output: Path, commit: str) -> dict:
    if not re.fullmatch(r"[a-f0-9]{40}", commit):
        raise ValueError("Commit must be a full 40-character Git SHA")
    files = []
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(source)
        if set(relative.parts) & IGNORED_DIRS or path.name in IGNORED_FILES:
            continue
        if path.suffix.lower() not in VALID_EXT:
            raise ValueError(f"Unknown source file extension, review before publishing: {relative}")
        files.append({
            "path": relative.as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()
        })
    required = {"project.godot", "main.tscn", "content.tscn"}
    if not required.issubset({f["path"] for f in files}):
        raise ValueError("Missing Godot entrypoint(s)")
    if len(files) < 10:
        raise ValueError("Unexpectedly few game files")
    document = {"format": 1, "commit": commit, "files": files}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return document

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="game")
    parser.add_argument("--out", default="dist/Windows-files.json")
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    result = generate(Path(args.source), Path(args.out), args.commit)
    print(f"WINDOWS_DIRECTORY_MANIFEST: {len(result['files'])} files at {result['commit']}")
