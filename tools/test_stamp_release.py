#!/usr/bin/env python3
"""Regression: no stale v0.51 APK releases, no decreasing Android versionCode."""
import unittest
from pathlib import Path
from stamp_release import build_version


class StampVersionTest(unittest.TestCase):
    def setUp(self):
        self.project = Path("game/project.godot").read_text(encoding="utf-8")
        self.preset = Path("game/export_presets.cfg").read_text(encoding="utf-8")

    def test_project_version_used_for_apk_and_release(self):
        version, result = build_version(self.project, self.preset, 900)
        self.assertEqual(version, "0.56.900")
        self.assertIn('package/version_name="0.56.900"', result)
        self.assertIn('version/name="0.56.900"', result)
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


if __name__ == "__main__":
    unittest.main()
