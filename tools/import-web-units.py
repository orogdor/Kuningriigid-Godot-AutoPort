#!/usr/bin/env python3
"""Import the exact original Kuningriigid Stone Age GLBs into Godot.

Runs in GitHub Actions after checkout of the upstream Three.js source.
Never regenerates geometry and never silently substitutes different assets.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

UNITS = ("scout", "spearman", "axeman", "slinger")


def glb_metadata(data: bytes) -> dict:
    if len(data) < 20:
        raise ValueError("GLB file is truncated")
    magic, version, byte_length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or byte_length != len(data):
        raise ValueError("Expected an intact binary glTF 2.0")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A or chunk_length > len(data) - 20:
        raise ValueError("GLB has no valid JSON chunk")
    scene = json.loads(data[20:20 + chunk_length])
    if not scene.get("nodes") or not scene.get("meshes"):
        raise ValueError("GLB has no 3D scene or meshes")
    accessors = scene.get("accessors", [])
    triangles = 0
    for mesh in scene["meshes"]:
        for primitive in mesh.get("primitives", []):
            mode = primitive.get("mode", 4)
            if mode != 4:
                continue
            accessor_id = primitive.get("indices", primitive.get("attributes", {}).get("POSITION"))
            if accessor_id is not None:
                triangles += int(accessors[accessor_id]["count"]) // 3
    if triangles <= 0:
        raise ValueError("GLB has no triangles")
    return {"mesh_count": len(scene["meshes"]), "triangles": triangles}


def save_if_changed(path: Path, data: bytes) -> None:
    if not path.is_file() or path.read_bytes() != data:
        path.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    source = Path(args.source) / "models-v148" / "glb"
    destination = Path(args.out)
    destination.mkdir(parents=True, exist_ok=True)
    files = {}
    for kind in UNITS:
        source_file = source / (kind + ".glb")
        if not source_file.is_file():
            raise FileNotFoundError(source_file)
        data = source_file.read_bytes()
        info = glb_metadata(data)
        save_if_changed(destination / (kind + ".glb"), data)
        files[kind] = {
            "source": "models-v148/glb/" + kind + ".glb",
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
            **info,
        }
    manifest = {
        "source_repository": "orogdor/Kuningriigid",
        "source_commit": args.commit,
        "models": files,
    }
    save_if_changed(destination / "manifest.json",
                    (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode())
    print("ORIGINAL_WEB_UNITS_V53 " + json.dumps({
        "source_commit": args.commit,
        "models": {name: {"triangles": info["triangles"],
                           "bytes": info["bytes"]} for name, info in files.items()},
    }))


if __name__ == "__main__":
    main()
