extends SceneTree
## V94: projectile markers share immutable mesh/material resources; changes
## to per-projectile position and removal remain correct and visual-only.
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_PROJECTILE_BATCH_V94 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=View.new()
    # Test the isolated renderer without _ready() creating unrelated UI.
    var shots:=Node3D.new()
    shots.name="ProjectilesV94"
    view.projectiles_root=shots
    view.add_child(shots)
    var projectiles: Array=[]
    for i in range(128):
        projectiles.append({"id":i+1,"x":float(i)*0.4,
            "height":1.3,"z":float(i)*0.2})
    view.current_battle={"projectiles_v58":projectiles}
    var original: String=JSON.stringify(view.current_battle)
    view._refresh_projectiles()
    if shots.get_child_count()!=128 or view.projectile_mesh_v94==null or \
            view.projectile_material_v94==null:
        fail("128 original projectile markers/resources missing")
        return
    var mesh: Mesh=view.projectile_mesh_v94
    var material: Material=view.projectile_material_v94
    var original_marker: MeshInstance3D=shots.get_node_or_null("Stone_1") as MeshInstance3D
    if original_marker==null:
        fail("original projectile ID is missing")
        return
    for i in range(128):
        var marker: MeshInstance3D=shots.get_node_or_null("Stone_"+str(i+1)) as MeshInstance3D
        if marker==null or marker.mesh!=mesh or \
                marker.material_override!=material:
            fail("each stone incorrectly allocated separate mesh/material")
            return
        if marker.position.distance_to(Vector3(float(i)*0.4,1.3,float(i)*0.2))>0.001:
            fail("projectile position changed while sharing geometry")
            return
    if JSON.stringify(view.current_battle)!=original:
        fail("rendering modified projectile simulation state")
        return

    # Existing projectile nodes must be reused as their authoritative
    # positions change; disappearing projectiles must be removed.
    var reduced: Array=[]
    for i in range(1,128,2):
        reduced.append({"id":i+1,"x":-float(i),"height":2.2,"z":10.0})
    view.current_battle={"projectiles_v58":reduced}
    view._refresh_projectiles()
    if shots.get_child_count()!=64 or \
            shots.get_node_or_null("Stone_1")!=null or \
            view.projectile_mesh_v94!=mesh or \
            view.projectile_material_v94!=material:
        fail("projectile cleanup recreated or lost shared resources")
        return
    var remaining: MeshInstance3D=shots.get_node_or_null("Stone_2") as MeshInstance3D
    if remaining==null or remaining.position!=Vector3(-1,2.2,10):
        fail("surviving projectile no longer follows its simulation position")
        return
    var surviving_id: int=remaining.get_instance_id()
    view._refresh_projectiles()
    var stable: MeshInstance3D=shots.get_node_or_null("Stone_2") as MeshInstance3D
    if stable==null or stable.get_instance_id()!=surviving_id:
        fail("unchanged projectile was rebuilt on identical snapshot")
        return
    view.current_battle={"projectiles_v58":[
        {"id":999,"x":0.0,"height":1.0,"z":0.0}]}
    view._refresh_projectiles()
    var added: MeshInstance3D=shots.get_node_or_null("Stone_999") as MeshInstance3D
    if shots.get_child_count()!=1 or added==null or \
            added.mesh!=mesh or added.material_override!=material:
        fail("new projectile did not reuse shared rendering resources")
        return
    print("BATTLE_PROJECTILE_BATCH_V94 SUCCESS: 128 stones, shared mesh/material, movement, cleanup, reuse, no save change")
    quit(0)
