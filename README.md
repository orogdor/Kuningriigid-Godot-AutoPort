# Kuningriigid → Godot AutoPort

Independent automated data and rules porting pipeline for [orogdor/Kuningriigid](https://github.com/orogdor/Kuningriigid).

This repository never modifies the original Three.js game or the existing Godot port.

**Phase 1:** statically export 15 classes of game data, verify against the source and load them into Godot 4. This is a data bridge, **not** a complete JS-to-GDScript conversion or a playable APK.

Once the workflow is installed, use **Actions → Sync Three.js rules to Godot** to generate a versioned source snapshot.

Requirements: Node.js 22+, Godot 4.4+ for the optional preview.
