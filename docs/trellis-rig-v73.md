# AutoPort V0.73 – Skeletal TRELLIS.2 combat models

The V262 TRELLIS.2 mesh files from the pinned Three.js source contain one
textured mesh each but **no skin, bones or animation**. The original
`models-v148/glb/{axeman,spearman,slinger}.glb` include a 14-joint rig
and six or seven working skeletal clips.

`tools/rig-trellis-v73.py` creates the three rigged deliverables as part
of the GitHub Actions synchronization and release build:

- Preserves the original rig, inverse bind matrices, and idle/walk/run/
  attack/hit/death (+ spearman brace) animation channels.
- Substitutes the V262 textured mesh, with position normalization, the
  source Web-version slinger rotation, and computed JOINTS_0/WEIGHTS_0.
- Assigns rigid influences to extended weapon sections where recognizable.
- Runs once at build time, not per-soldier; every battle instance loads
  the same packed GLB through Godot's resource cache.
- Retains the V148 source GLBs as fallback for unsupported future assets.
- Records input checksums, output checksums and linked source revision in
  `game/assets/web73/manifest.json`.

`res://tests/trellis_rig_v73.gd` verifies original high-poly textured
geometry, real Skeleton3D, AnimationPlayer clips, and all 216 3D battlefield
actors actually using the new source. Existing V65/V69/V70/V71 animation
and battle parity regressions must remain green.

The old V148 skeleton controls animation; this is a geometry-and-skin
transfer, not a new authored animation set. Skin weights are algorithmic
and may require visual retouching around hands and weapons.
