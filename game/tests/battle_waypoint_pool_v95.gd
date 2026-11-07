extends SceneTree
## V95: 6 tactical squads and 23 individual orders share just two reusable
## marker meshes and two materials. Orders and saved battle are unmodified.
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_WAYPOINT_POOL_V95 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=View.new()
    var markers:=Node3D.new()
    view.move_markers_root=markers
    view.add_child(markers)
    var fighters: Array=[]
    for i in range(6):
        var people: Array=[]
        for j in range(4):
            people.append({"index":j,"hp":0.0 if i==5 and j==3 else 10.0,
                "individual_target_v60":{"x":float(i*10+j),
                    "z":float(j*3)}})
        fighters.append({"id":500+i,"team":0,"mode":"move",
            "move_target_v59":{"x":float(i*5),"z":float(i*7)},
            "men":people})
    # Enemy waypoints must not be rendered as player orders.
    fighters.append({"id":900,"team":1,"mode":"move",
        "move_target_v59":{"x":99.0,"z":99.0},
        "men":[{"index":0,"hp":10.0,
            "individual_target_v60":{"x":98.0,"z":99.0}}]})
    view.current_battle={"fighters":fighters}
    var original_json: String=JSON.stringify(view.current_battle)
    view._refresh_move_markers()
    if markers.get_child_count()!=29 or \
            view.squad_waypoint_mesh_v95==null or \
            view.personal_waypoint_mesh_v95==null or \
            view.squad_waypoint_material_v95==null or \
            view.personal_waypoint_material_v95==null:
        fail("expected 6 squad + 23 living individual waypoint markers")
        return
    if view.squad_waypoint_mesh_v95==view.personal_waypoint_mesh_v95 or \
            view.squad_waypoint_material_v95==view.personal_waypoint_material_v95:
        fail("different order types incorrectly share one appearance")
        return
    for i in range(6):
        var squad: MeshInstance3D=markers.get_node_or_null(
            "Waypoint_"+str(500+i)) as MeshInstance3D
        if squad==null or squad.mesh!=view.squad_waypoint_mesh_v95 or \
                squad.material_override!=view.squad_waypoint_material_v95 or \
                squad.position!=Vector3(float(i*5),0.12,float(i*7)):
            fail("squad marker appearance or position mismatch")
            return
        for j in range(4):
            var personal: MeshInstance3D=markers.get_node_or_null(
                "PersonalWaypoint_"+str(500+i)+"_"+str(j)) as MeshInstance3D
            if i==5 and j==3:
                if personal!=null:
                    fail("dead soldier's waypoint must not appear")
                    return
                continue
            if personal==null or \
                    personal.mesh!=view.personal_waypoint_mesh_v95 or \
                    personal.material_override!=view.personal_waypoint_material_v95 or \
                    personal.position!=Vector3(float(i*10+j),0.2,float(j*3)):
                fail("individual waypoint appearance or position mismatch")
                return
    if markers.get_node_or_null("Waypoint_900")!=null or \
            markers.get_node_or_null("PersonalWaypoint_900_0")!=null or \
            JSON.stringify(view.current_battle)!=original_json:
        fail("enemy order revealed or rendering changed saved battle state")
        return

    var stable: MeshInstance3D=markers.get_node("Waypoint_500") as MeshInstance3D
    var stable_id: int=stable.get_instance_id()
    view._refresh_move_markers()
    if (markers.get_node("Waypoint_500") as MeshInstance3D).get_instance_id()!=stable_id:
        fail("unchanged waypoint was rebuilt")
        return
    fighters[0]["move_target_v59"]={"x":42.0,"z":-5.0}
    fighters[1]["mode"]="hold"
    fighters[2]["men"][0]["individual_target_v60"]={}
    view._refresh_move_markers()
    if stable.position!=Vector3(42,0.12,-5) or \
            stable.get_instance_id()!=stable_id or \
            markers.get_child_count()!=27 or \
            markers.get_node_or_null("Waypoint_501")!=null or \
            markers.get_node_or_null("PersonalWaypoint_502_0")!=null:
        fail("waypoint positions, stable nodes or cleanup diverged")
        return

    # All markers can disappear, then be rebuilt using exactly the same
    # immutable resources with no cross-battle state leakage.
    view.current_battle={"fighters":[]}
    view._refresh_move_markers()
    if markers.get_child_count()!=0:
        fail("disbanded order markers remain visible")
        return
    view.current_battle={"fighters":fighters}
    view._refresh_move_markers()
    var rebuilt: MeshInstance3D=markers.get_node_or_null("Waypoint_500") as MeshInstance3D
    if rebuilt==null or \
            rebuilt.mesh!=view.squad_waypoint_mesh_v95 or \
            rebuilt.material_override!=view.squad_waypoint_material_v95:
        fail("new order did not reuse preexisting mesh and material")
        return
    print("BATTLE_WAYPOINT_POOL_V95 SUCCESS: 29 shared markers, selection, movement, cleanup and save isolation")
    quit(0)
