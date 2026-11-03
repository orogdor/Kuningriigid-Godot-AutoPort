#!/usr/bin/env python3
"""Regression: no stale v0.51 APK releases, no decreasing Android versionCode."""
import unittest
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from stamp_release import build_version


class StampVersionTest(unittest.TestCase):
    def setUp(self):
        self.project = Path("game/project.godot").read_text(encoding="utf-8")
        self.preset = Path("game/export_presets.cfg").read_text(encoding="utf-8")

    def test_project_version_used_for_apk_and_release(self):
        version, result = build_version(self.project, self.preset, 900)
        self.assertRegex(version, r"^\d+\.\d+\.900$")
        self.assertIn(f'package/version_name="{version}"', result)
        self.assertIn(f'version/name="{version}"', result)
        self.assertIn("package/version_code=900", result)
        self.assertIn("version/code=900", result)

    def test_stamp_is_idempotent(self):
        v1, once = build_version(self.project, self.preset, 900)
        v2, twice = build_version(self.project, once, 900)
        self.assertEqual((v1, once), (v2, twice))

    def test_invalid_config_rejected(self):
        with self.assertRaises(ValueError):
            build_version(self.project, "", 900)
        with self.assertRaises(ValueError):
            build_version(self.project, self.preset, 0)

    def test_cli_embeds_exact_release_id_before_export(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "project.godot").write_text(self.project, encoding="utf-8")
            (root / "export_presets.cfg").write_text(self.preset, encoding="utf-8")
            manifest = root / "release.json"
            argv = [
                sys.executable, "tools/stamp_release.py",
                "--project", str(root / "project.godot"),
                "--preset", str(root / "export_presets.cfg"),
                "--content-version-file", str(manifest),
                "--run-number", "900",
            ]
            result = subprocess.run(argv, check=True, capture_output=True, text=True)
            version = result.stdout.strip()
            self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["version"], version)
            self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["tag"], "v" + version)
            self.assertIn(f'package/version_name="{version}"',
                          (root / "export_presets.cfg").read_text(encoding="utf-8"))
            manifest.unlink()
            subprocess.run(argv + ["--check-only"], check=True, capture_output=True)
            self.assertFalse(manifest.exists(), "Check-only must not mutate the release manifest")


if __name__ == "__main__":
    unittest.main()
