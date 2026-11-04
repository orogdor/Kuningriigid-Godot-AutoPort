#!/usr/bin/env python3
"""Copy currently used V299 Three.js GLBs, unchanged, into the Godot build.

All imports are pinned to the checked-out source SHA. No generated proxy meshes,
geometry rewriting, silent fallback downloads or historical test revisions.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

STONES = ("archery", "barracks", "claypit", "farm", "fisher",
          "house", "hunter", "lumber", "mason", "palisade", "pasture",
          "peamaja", "pottery_kiln", "quarry", "study", "watchtower",
          "well", "woodgate")
UNITS = {"axeman": "kirvemees", "spearman": "odamees",
         "slinger": "lingmees"}
NATURE = {"oak": "tamm_low", "pine": "mand_low", "bush": "poosas_low",
          "deer": "hirv_low", "stag": "harg_low", "fish": "kala_low"}


def entries():
    for role, name in UNITS.items():
        yield "unit", role, f"models-trellis-v262/{name}.glb"
    for name in STONES:
        yield "building", name, f"models-stone-lod-v244/{name}_mid.glb"
        yield "world", name, f"models-world-v269/{name}.glb"
    for role, name in NATURE.items():
        yield "nature", role, f"models-nature-v230/{name}.glb"


def metadata(data: bytes):
    if len(data) < 20:
        raise ValueError("truncated glTF 2.0")
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("incorrect binary glTF header")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A or chunk_length > len(data) - 20:
        raise ValueError("invalid glTF JSON chunk")
    gltf = json.loads(data[20:20 + chunk_length])
    if not gltf.get("meshes") or not gltf.get("nodes"):
        raise ValueError("GLB has no drawable mesh")
    accessors = gltf.get("accessors", [])
    triangles = 0
    for mesh in gltf["meshes"]:
        for part in mesh.get("primitives", []):
            if part.get("mode", 4) != 4:
                continue
            index = part.get("indices", part.get("attributes", {}).get("POSITION"))
            if index is None or index < 0 or index >= len(accessors):
                raise ValueError("missing triangle accessor")
            triangles += int(accessors[index]["count"]) // 3
    if triangles < 1:
        raise ValueError("GLB contains no triangles")
    return {"triangles": triangles, "mesh_count": len(gltf["meshes"]),
            "skins": len(gltf.get("skins", [])),
            "animations": len(gltf.get("animations", []))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--commit", required=True)
    args = ap.parse_args()
    src = Path(args.source)
    dst = Path(args.out)
    manifest = {"source_repository": "orogdor/Kuningriigid",
                "source_commit": args.commit, "models": {
                    "unit": {}, "building": {}, "world": {}, "nature": {}}}
    for group, role, relative in entries():
        source = src / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        data = source.read_bytes()
        detail = metadata(data)
        path = dst / group / f"{role}.glb"
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_bytes() != data:
            path.write_bytes(data)
        manifest["models"][group][role] = {
            "source": relative, "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), **detail}
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8")
    print("WEB_V299_IMPORT " + json.dumps({
        "commit": args.commit,
        "count": sum(map(len, manifest["models"].values())),
        "bytes": sum(d["bytes"] for group in manifest["models"].values()
                     for d in group.values())}))


if __name__ == "__main__":
    main()
