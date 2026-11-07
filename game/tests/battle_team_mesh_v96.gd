extends SceneTree
## V96: all 216 tactical soldiers reuse one team-disc geometry while
## keeping individual material instances for independent selection colors.
## Source GLBs, saved game state, hit/death and movement remain unchanged.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_TEAM_MESH_V96 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_large_demo_battle()
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    var army: Node3D=view.actors_root
    if army==null or army.get_child_count()!=216 or \
            view.team_marker_mesh_v96==null:
        fail("216 original soldier GLBs or their shared team disc are missing")
        return

    var mesh: Mesh=view.team_marker_mesh_v96
    var seen_materials: Dictionary={}
    var allies: Array[MeshInstance3D]=[]
    var enemies: Array[MeshInstance3D]=[]
    for holder in army.get_children():
        var marker: MeshInstance3D=holder.get_node_or_null("TeamMarker") as MeshInstance3D
        var original: Node3D=holder.get_child(0) as Node3D
        if marker==null or marker.mesh!=mesh or \
                original==null or not original.has_meta("source_glb"):
            fail("GLB soldier uses an independent team mesh or missing source GLB")
            return
        var mat: StandardMaterial3D=marker.material_override as StandardMaterial3D
        if mat==null or seen_materials.has(mat.get_instance_id()):
            fail("team markers share materials and would overwrite selection colors")
            return
        seen_materials[mat.get_instance_id()]=true
        if int(holder.get_meta("team_v67",-1))==0:
            allies.append(marker)
        else:
            enemies.append(marker)
    if seen_materials.size()!=216 or allies.size()!=120 or enemies.size()!=96:
        fail("216 team markers not split into 120 allies / 96 enemies")
        return

    # Changing one marker's highlight must NOT recolor another soldier.
    var first: StandardMaterial3D=allies[0].material_override as StandardMaterial3D
    var second: StandardMaterial3D=allies[1].material_override as StandardMaterial3D
    var enemy: StandardMaterial3D=enemies[0].material_override as StandardMaterial3D
    var ally_before: Color=second.albedo_color
    var enemy_before: Color=enemy.albedo_color
    var saved: String=JSON.stringify(ui.city)
    first.albedo_color=Color("#123456")
    if second.albedo_color!=ally_before or enemy.albedo_color!=enemy_before:
        fail("changing one soldier's highlight recolored other soldiers")
        return

    # A snapshot refresh should reset selection coloring and retain the
    # exact soldier nodes, source 3D models and shared mesh resources.
    var original_actor_id: int=army.get_child(0).get_instance_id()
    var current: Dictionary=Battle.current(ui.city,ui.world_view.world)
    view.set_battle(current)
    if army.get_child_count()!=216 or \
            army.get_child(0).get_instance_id()!=original_actor_id or \
            view.team_marker_mesh_v96!=mesh or \
            first.albedo_color==Color("#123456"):
        fail("snapshot refresh rebuilt the source soldier or kept stale highlight")
        return
    if JSON.stringify(ui.city)!=saved:
        fail("render-only team mesh pooling changed the saved battle state")
        return

    # Moving a marker's parent cannot modify any other model geometry.
    var parent: Node3D=allies[0].get_parent() as Node3D
    var other: Node3D=allies[1].get_parent() as Node3D
    var unchanged: Vector3=other.position
    parent.position+=Vector3(0.25,0,0)
    if other.position.distance_to(unchanged)>0.00001:
        fail("moving one soldier unexpectedly moved another soldier")
        return
    # Mesh resource dimensions are float32 in Godot. Exact equality with
    # the GDScript float64 literal 0.39 falsely fails despite identical
    # resource geometry. Test within physically negligible tolerance.
    var radius: float=(allies[0].mesh as CylinderMesh).top_radius
    if absf(radius-0.39)>0.00001:
        fail("shared team disc radius was unexpectedly modified: "+str(radius))
        return
    view.set_auto_battle(false)
    print("BATTLE_TEAM_MESH_V96 SUCCESS: 216 source GLBs, one mesh, 216 individual materials, selection, snapshot and save isolation")
    quit(0)
