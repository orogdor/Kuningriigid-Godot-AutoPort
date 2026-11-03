# AutoPort update and signing policy

## Current installed Android app (older v0.51.* APK)

- Keep the APK installed to preserve its user:// saves.
- On each launch, the embedded launcher checks GitHub's **latest Release**
  for **Kuningriigid-Content.pck**, validates the published SHA-256 and
  mounts it over the built-in game resources. It does **not** install APKs
  silently. After a new Release is published, relaunching the existing app
  should load the updated Stone Age game content.
- An old APK signed with an ephemeral debug key **cannot** be replaced in
  place by a new APK signed with a different key. Android enforces this.
  Future APK signing must be fixed once with a persistent key; this does not
  retroactively change the old APK signing certificate. Do **not** uninstall
  without backing up saves. A newly signed APK may require an intentional
  migration / fresh install if the prior signing key is not recoverable.
- The Android PCK updater now preserves the previously verified pack across
  interrupted writes and rejects changed/invalid hashes. It records a short
  status in user://last-update-status.txt.

## Windows launcher

- Kuningriigid.exe checks GitHub Releases and validates the pinned
  **Windows-files.json** and each fetched file's SHA-256; the engine is
  downloaded once (or when it changes). On download failure it uses the
  last verified offline install.
- Diagnostics reside next to the launcher in
  Kuningriigid-Data/last-update-progress.log and
  Kuningriigid-Data/last-update-error.txt.
- Existing 0.51 launcher is able to load newly released 0.56+ manifests.
  Installing a newer launcher is optional if the existing one works.

## When a Release is generated

- The **Sync Three.js rules to Godot** workflow runs tests. After its main
  branch run **passes**, build-apps checks whether the Godot project
  major.minor version differs from the latest release. It publishes
  **once per validated project version series**, not on every source commit.
- Manual **Run workflow** or a deliberate change to
  .github/release-request.txt forces an additional hotfix release.
- Both workflows are serialised to avoid colliding releases.
- The version string is read from game/project.godot and the GitHub run
  number forms the patch version and Android's monotonically increasing
  versionCode (for example v0.56.750).
- PCK + Windows assets always publish when the export tests succeed.
  An Android APK is **only** published if a persistent signing key exists.

## Configure a persistent release APK signing key

In repository Settings > Secrets and variables > Actions, configure all
three secrets. Do not commit the key or passwords to source control:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded **private** JKS/PKCS12 keystore
- `ANDROID_KEY_ALIAS`: its signing alias
- `ANDROID_KEY_PASSWORD`: both store and key password (same value)

The CI validates that the keystore can be opened with that password before
export. APK generation is skipped if the secrets are absent, rather than
publishing an APK with a different new debug signature each run.

For an **in-place upgrade**, the certificate must match the installed
APK's certificate. Do not assume that newly creating a persistent keystore
can update APKs signed with any previously generated temporary key.

## Quick verification

- Open GitHub Releases and confirm the latest release shows the project
  version, PCK digest, and Windows manifest.
- On Android, launch with network, then re-open. The app checks the latest
  Content.pck hash automatically; saved games remain in user://.
- On Windows, check last-update-progress.log and active.json. The active
  commit should match the latest release's Windows manifest commit.
- In CI: `python3 tools/test_stamp_release.py`, and Godot test
  `res://tests/updater_v57.gd` confirm versioning and atomic PCK rollback.
