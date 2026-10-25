extends SceneTree
## 0.24: deterministic urban planning, protected mobility corridors,
## unchanged building economics, and shared visual resources.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Planner=preload("res://scripts/city_planner_v24.gd")
const Paths=preload("res://scripts/spatial_paths_v09.gd")
const Access=preload("res://scripts/building_access_v22.gd")
const Screen=preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("CITY_GROWTH_V24 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var untouched: String=JSON.stringify(state)
    var home: Dictionary=Planner.plan(state,"house")
    var home_again: Dictionary=Planner.plan(state,"house")
    if home.is_empty() or home_again.is_empty():
        fail("no residential build plot found for initial city")
        return
    if home["position"]!=home_again["position"] or home["rotation"]!=home_again["rotation"]:
        fail("same unchanged city produced inconsistent placement recommendations")
        return
    if JSON.stringify(state)!=untouched:
        fail("planning changed building materials, citizens or save data")
        return
    var home_pos: Vector2=home["position"]
    if not Spatial.can_place(state,home_pos) or home_pos.length()>70.0:
        fail("residential plot is not legal or close to the town core")
        return
    var industry: Dictionary=Planner.plan(state,"lumber")
    if industry.is_empty() or not Spatial.can_place(state,industry["position"]):
        fail("resource workshop has no legal build plot")
        return
    # Compare a dense existing town. The planner may not take blocked plots,
    # reuse houses or propose a doorway that no worker can reach.
    var placed: int=0
    for n in range(12):
        var plan: Dictionary=Planner.plan(state,"house" if n%3!=0 else "lumber")
        if plan.is_empty():break
        var loc: Vector2=plan["position"]
        if not Spatial.can_place(state,loc):
            fail("city planner recommended overlapping buildings")
            return
        state["buildings"].append({"type":"house" if n%3!=0 else "lumber",
            "x":loc.x,"z":loc.y,"rotation":plan["rotation"],
            "hp":350.0,"ready":true})
        placed+=1
    if placed<8:
        fail("planner could not support eight additional buildings in town")
        return
    var sim: Dictionary=state["detail_sim"]
    var origin: Vector2=Access.entrance(state["buildings"][0])
    var connected: Dictionary=Paths.connected_cells(state,origin,0)
    if connected.size()<25:
        fail("dense town blocked the road network around the hall")
        return
    for i in range(1,state["buildings"].size()):
        var direct: Vector2=Access.reachable(state,i,origin,0)
        var cached: Vector2=Access.reachable_from_map(state,i,connected,0)
        if direct!=cached:
            fail("shared access map disagrees with direct A* at building %d" % i)
            return
    var json: Variant=JSON.parse_string(JSON.stringify(state))
    if not json is Dictionary or json["buildings"].size()!=placed+1:
        fail("planning was not compatible with existing city JSON")
        return
    # Build the actual 3D scene. Equal colors and box dimensions should
    # reuse the exact same Resource without merging independent instances.
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var capital: Dictionary=ui.world_view.world["starts"][0]
    ui._show_detail(int(capital["c"]),int(capital["r"]))
    await process_frame
    var detail: Control=ui.detail_view
    var tint:=Color("#aabbcc")
    var mat_a: Material=detail._material(tint)
    var mat_b: Material=detail._material(tint)
    if mat_a!=mat_b:
        fail("identical Godot building materials were recreated")
        return
    var holder:=Node3D.new()
    detail.scene_root.add_child(holder)
    var a: MeshInstance3D=detail._box(holder,Vector3.ZERO,Vector3(7,3,5),tint,"ReuseBoxA")
    var b: MeshInstance3D=detail._box(holder,Vector3(10,0,0),Vector3(7,3,5),tint,"ReuseBoxB")
    if a==b or a.mesh!=b.mesh or a.material_override!=b.material_override:
        fail("building box meshes were not shared across independent instances")
        return
    if detail.shared_boxes.size()<1 or detail.shared_materials.size()<1:
        fail("mesh/material caches never populated")
        return
    detail.select_building("house")
    if detail.suggested_site.is_empty() or detail.placement_marker==null:
        fail("planner did not display a house plot in the 3D scene")
        return
    detail._recommend_placement()
    if detail.placement_cell!=detail.suggested_site["position"]:
        fail("suggested 3D placement did not adopt the chosen plot")
        return
    if not Spatial.can_place(ui.city,detail.placement_cell):
        fail("suggested placement is blocked")
        return
    var old_count: int=ui.city["buildings"].size()
    var old_wood: float=float(ui.city["realms"][0]["resources"]["wood"])
    var selected: Vector2=detail.placement_cell
    detail._ground_clicked(Vector3(selected.x,0.0,selected.y))
    await process_frame
    if ui.city["buildings"].size()!=old_count+1:
        fail("planned plot was not buildable using the real city economy")
        return
    if float(ui.city["realms"][0]["resources"]["wood"])>=old_wood:
        fail("real planned building did not charge its existing wood cost")
        return
    detail._refresh_grid()
    await process_frame
    var cached_palette: int=detail.grid_materials.size()
    detail._refresh_grid()
    await process_frame
    if detail.grid_materials.size()!=cached_palette or cached_palette>8:
        fail("build-grid refresh created duplicate grid materials")
        return
    print("CITY_GROWTH_V24 SUCCESS: deterministic compact growth, %d buildings, safe door map, shared meshes, editable plot and prepaid economy" % placed)
    quit(0)
