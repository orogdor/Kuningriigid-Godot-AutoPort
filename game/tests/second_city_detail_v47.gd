extends SceneTree
## AutoPort 0.47: satellite 3D town is independent, seen across its border,
## and its local AI switch never controls the capital.
const Scene=preload("res://content.tscn")
const City=preload("res://scripts/city_sim_v05.gd")
const Trade=preload("res://scripts/two_city_trade_v15.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const CapitalAI=preload("res://scripts/capital_auto_v38.gd")
const Town=preload("res://scripts/second_city_detail_v47.gd")

func fail(reason: String) -> void:
    printerr("SECOND_CITY_DETAIL_V47 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._found_trade_city()
    var site: Dictionary=ui._satellite_tile()
    var tile: Vector2i=Town.satellite_position(site,ui.world_view.world)
    if tile.x<0:
        fail("second town has no stable world position")
        return
    var satellite: Dictionary=Trade.ensure_city(ui.city)
    var capital_count: int=ui.city["buildings"].size()
    var capital_ai: bool=CapitalAI.enabled(ui.city)
    if Town.source(ui.world_view.world,tile,ui.city,satellite,tile).get("town",{})!=satellite:
        fail("second town's tile resolves to the wrong owner")
        return
    if not Town.source(ui.world_view.world,tile+Vector2i(2,2),ui.city,
            satellite,tile).is_empty():
        fail("unowned wilderness was assigned to a city")
        return
    ui._open_satellite()
    await process_frame
    if ui.detail_town!="outpost" or not ui.detail_view.can_build or \
            ui.world_view.selected_cell!=tile:
        fail("second city button didn't open its real owned world detail")
        return
    var detail=ui.detail_view
    if detail.city_state!=satellite or \
            detail.construction_root.get_node_or_null("hall_0")==null:
        fail("second city's town hall or independent state disappeared")
        return
    detail.capital_ai_requested.emit()
    if bool(ui.city["trade_v15"].get("ai_enabled",true)) or \
            bool(satellite.get("auto_build_v47",true)):
        fail("second city AI button didn't turn its own AI off")
        return
    if CapitalAI.enabled(ui.city)!=capital_ai:
        fail("second city toggle inadvertently changed capital AI")
        return
    var ui_switch: bool=false
    for element in detail.actions.get_children():
        if element is Button and String(element.text).begins_with("Teise linna AI:"):
            ui_switch=true
            if not String(element.text).ends_with("väljas"):
                fail("second city AI toolbar still has old state")
                return
    if not ui_switch:
        fail("missing second city AI toolbar button")
        return
    var starting_wood: float=float(satellite["realms"][0]["resources"]["wood"])
    if Trade.send(ui.city,"outpost","wood",15.0)!="":
        fail("could not dispatch legal wood caravan from capital")
        return
    var capital_after_send: float=float(ui.city["realms"][0]["resources"]["wood"])
    var duration: int=int(ui.city["trade_v15"]["route_v17"]["duration"])
    for turn in range(duration):
        City.tick(ui.city)
    if float(satellite["realms"][0]["resources"]["wood"])<starting_wood+14.9:
        fail("wood wasn't delivered to satellite's private warehouse")
        return
    ui._show_detail(tile.x,tile.y)
    ui._build_at("lumber",30,-10,90)
    await process_frame
    if satellite["buildings"].size()!=2 or ui.city["buildings"].size()!=capital_count:
        fail("second-city building was not local to its own city")
        return
    if absf(float(ui.city["realms"][0]["resources"]["wood"])-capital_after_send)>0.0001:
        fail("satellite building spent capital wood")
        return
    var building: Dictionary=satellite["buildings"][1]
    if String(building.get("type",""))!="lumber" or int(building.get("rotation",-1))!=90:
        fail("independent 3D construction lost kind or rotation")
        return
    var neighbor: Vector2i=tile+Vector2i(1,0)
    if World.cell(ui.world_view.world,neighbor.x,neighbor.y).is_empty():
        fail("no adjacent second-city world square")
        return
    ui._show_detail(neighbor.x,neighbor.y)
    await process_frame
    if detail.can_build:
        fail("neighbor wilderness was accidentally made buildable")
        return
    var part: Node3D=detail.seam_preview_root.get_node_or_null("DetailNeighbor_-1_0") as Node3D
    var group: Node3D=part.get_node_or_null("ActualNeighborBuildings") as Node3D if part!=null else null
    if group==null:
        fail("neighboring 3D preview hides saved second-city buildings")
        return
    var count: int=0
    for node in group.get_children():
        if node is MultiMeshInstance3D and node.multimesh!=null:
            count+=node.multimesh.instance_count
        elif node is Node3D:
            count+=1
    if count!=satellite["buildings"].size():
        fail("neighboring preview count differs from actual city")
        return
    var camera=detail.controller
    camera.distance=93.0
    camera.wheel_target=93.0
    var previous_yaw: float=camera.yaw
    camera.look_at=Vector3(-camera.seam_half.x-2.0,0.0,0.0)
    camera.check_detail_boundary()
    await process_frame
    if detail.selected!=tile or ui.detail_town!="outpost" or not detail.can_build:
        fail("crossing into second town didn't activate its detail map")
        return
    if absf(camera.distance-93.0)>0.2 or absf(camera.yaw-previous_yaw)>0.001:
        fail("city border crossing reset camera zoom or heading")
        return
    var saved: Variant=JSON.parse_string(JSON.stringify(ui.city))
    if not saved is Dictionary:
        fail("save serialization broke")
        return
    var restored: Dictionary=Trade.ensure_city(saved)
    if restored["buildings"].size()!=2 or \
            float(restored["realms"][0]["resources"]["wood"])!=\
                float(satellite["realms"][0]["resources"]["wood"]):
        fail("saved second city lost buildings or independent inventory")
        return
    print("SECOND_CITY_DETAIL_V47 SUCCESS: local AI, independent materials, 3D neighbor houses, camera seam, world selection, saves")
    quit(0)
