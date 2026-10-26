extends SceneTree
## 0.46 verifies real models + instanced fallback in dense neighboring cities.
const Screen=preload("res://content.tscn")
const Districts=preload("res://scripts/world_districts_v25.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Hybrid=preload("res://scripts/detail_hybrid_v46.gd")
const V45=preload("res://scripts/detail_neighbor_buildings_v45.gd")

func fail(s: String) -> void:
    printerr("DETAIL_HYBRID_V46 FAIL: "+s)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var east: Vector2i=home+Vector2i(1,0)
    if World.cell(world,east.x,east.y).is_empty():
        fail("no adjacent tile")
        return
    var houses: Array=ui.city["buildings"]
    var old: Array=houses.duplicate(true)
    var stock: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    for i in range(27):
        houses.append({"type":"house","ready":true,"hp":100.0,
            "x":float(i%8)*20.0-80.0,"z":float(i/8)*23.0-46.0,
            "rotation":0})
    houses.append({"type":"house","ready":false,"hp":100.0,
        "x":105.0,"z":-13.0,"rotation":0,"progress":0.0})
    var count: int=houses.size()
    if not Hybrid.active(135,76,count) or Hybrid.active(225,76,count) \
            or Hybrid.active(135,76,V45.MAX_DETAILED_BUILDINGS):
        fail("dense city thresholds are wrong")
        return
    var plan: Dictionary=Hybrid.split(houses,Vector2i(1,0),Hybrid.MAX_MOBILE)
    if plan["models"].size()!=Hybrid.MAX_MOBILE or \
            plan["lod"].size()+plan["models"].size()!=count:
        fail("every structure must occur once in a mobile preview")
        return
    var selected_hall: bool=false
    var selected_site: bool=false
    for e in plan["models"]:
        var b: Dictionary=e["data"]
        if String(b.get("type",""))=="hall":selected_hall=true
        if not bool(b.get("ready",true)):selected_site=true
    if not selected_hall or not selected_site:
        fail("hall or forward construction excluded from full geometry")
        return
    ui._show_detail(east.x,east.y)
    await process_frame
    var view=ui.detail_view
    var control=view.controller
    var neighbor: Node3D=view.seam_preview_root.get_node_or_null("DetailNeighbor_-1_0") as Node3D
    if neighbor==null:
        fail("capital preview missing")
        return
    control.look_at=Vector3(-92,0,0)
    view._refresh_seam_neighbor_buildings()
    var display: Node3D=neighbor.get_node_or_null("ActualNeighborBuildings") as Node3D
    if display==null or String(display.get_meta("mode",""))!="hybrid":
        fail("large town still shows only LOD cubes")
        return
    var full_models: int=0
    var lod_count: int=0
    var hall: bool=false
    var site: bool=false
    for n in display.get_children():
        if n is MultiMeshInstance3D and n.multimesh!=null:
            lod_count+=n.multimesh.instance_count
        elif n is Node3D:
            full_models+=1
            if n.get_node_or_null("HallWalls")!=null:hall=true
            if n.get_node_or_null("Stage0Foundation")!=null:site=true
    if full_models!=Hybrid.MAX_DESKTOP or lod_count!=count-Hybrid.MAX_DESKTOP \
            or not hall or not site:
        fail("wrong model counts, hall geometry, or construction stage")
        return
    var unchanged: Node3D=display
    view._refresh_seam_neighbor_buildings()
    if neighbor.get_node_or_null("ActualNeighborBuildings")!=unchanged:
        fail("unchanged buildings needlessly regenerated")
        return
    var old_signature: String=String(display.get_meta("render_key",""))
    houses.back()["progress"]=0.45
    view._refresh_seam_neighbor_buildings()
    display=neighbor.get_node_or_null("ActualNeighborBuildings") as Node3D
    if String(display.get_meta("render_key",""))==old_signature:
        fail("construction changes not reflected")
        return
    if view.can_build or ui.city["realms"][0]["resources"]!=stock:
        fail("preview changed permissions or stock")
        return
    control.look_at=Vector3.ZERO
    view._refresh_seam_neighbor_buildings()
    display=neighbor.get_node_or_null("ActualNeighborBuildings") as Node3D
    if display==null or String(display.get_meta("mode",""))!="lod":
        fail("far town did not switch back to LOD")
        return
    ui._show_detail(home.x,home.y)
    await process_frame
    if not view.can_build or view.construction_root.get_child_count()<1:
        fail("return to playable city lost detailed geometry")
        return
    ui.city["buildings"]=old
    if ui.city["realms"][0]["resources"]!=stock:
        fail("render changes spent city resources")
        return
    print("DETAIL_HYBRID_V46 SUCCESS: dense city real meshes + fallback, no duplicates, preserved economy")
    quit(0)
