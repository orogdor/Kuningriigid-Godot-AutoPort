#!/usr/bin/env python3
"""Stamp release/APK versions from game/project.godot (single source of truth).

Never hardcode the previous APK's major/minor version in GitHub Actions.
The monotonically increasing Actions run number becomes Android versionCode.
"""
import argparse
import json
import re
from pathlib import Path


def build_version(project_text: str, preset_text: str, run_number: int) -> tuple[str, str]:
    if not 1 <= run_number <= 2_100_000_000:
        raise ValueError("GitHub run number outside Android versionCode range")
    versions = re.findall(
        r'(?m)^config/name="Kuningriigid Godot AutoPort (\d+\.\d+)"$',
        project_text,
    )
    if len(versions) != 1:
        raise ValueError("Could not identify exactly one AutoPort project version")
    version = f"{versions[0]}.{run_number}"
    values = {
        "version/code": str(run_number),
        "version/name": f'"{version}"',
        "package/version_code": str(run_number),
        "package/version_name": f'"{version}"',
    }
    for field, value in values.items():
        preset_text, count = re.subn(
            r"(?m)^" + re.escape(field) + r"=.*$",
            lambda _match, k=field, v=value: f"{k}={v}",
            preset_text,
        )
        if count != 1:
            raise ValueError(f"Expected one {field} in Android export preset, got {count}")
    return version, preset_text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="game/project.godot")
    parser.add_argument("--preset", default="game/export_presets.cfg")
    parser.add_argument("--run-number", type=int, required=True)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument(
        "--content-version-file",
        default="game/data/generated/release.json",
        help="Release identity embedded in exported Android/Windows PCK",
    )
    args = parser.parse_args()
    preset_path = Path(args.preset)
    original = preset_path.read_text(encoding="utf-8")
    version, updated = build_version(
        Path(args.project).read_text(encoding="utf-8"), original, args.run_number
    )
    if not args.check_only:
        preset_path.write_text(updated, encoding="utf-8")
        version_path = Path(args.content_version_file)
        version_path.parent.mkdir(parents=True, exist_ok=True)
        version_path.write_text(
            json.dumps({"version": version, "tag": "v" + version,
                        "run_number": args.run_number}, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    print(version)


if __name__ == "__main__":
    main()
