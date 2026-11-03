extends SceneTree
## v0.54: paid camp, 4-slot FIFO training, grade costs, hp, population,
## real world path orders, 2D/3D/detail continuity and JSON persistence.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Mil=preload("res://scripts/military_v54.gd")
const Research=preload("res://scripts/research_v35.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")

func fail(message: String) -> void:
    printerr("MILITARY_V54 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if Mil.CAMP_COST!={"wood":20.0,"stone":9.0} or Mil.CAMP_SECONDS!=18.0:
        fail("V128 final barracks prices/timing changed")
        return
    for expected in [
        {"kind":"slinger","wood":6.0,"stone":12.0,"seconds":19.0,"hp":170.0},
        {"kind":"spearman","wood":15.0,"stone":3.0,"seconds":23.0,"hp":250.0},
        {"kind":"axeman","wood":10.0,"stone":10.0,"seconds":27.0,"hp":280.0}]:
        var def: Dictionary=Mil.TROOPS[expected["kind"]]
        if def["cost"]["wood"]!=expected["wood"] or def["cost"]["stone"]!=expected["stone"] or \
                def["seconds"]!=expected["seconds"] or def["hp"]!=expected["hp"]:
            fail("troop rule diverged from Three.js: "+expected["kind"])
            return
    if Mil.cost("spearman","elite")!={"wood":19.5,"stone":3.9} or \
            Mil.cost("spearman","mobilized")!={"wood":7.5,"stone":1.5}:
        fail("V88 grade pricing is inaccurate")
        return
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var m: Dictionary=Mil.ensure(ui.city,world)
    if not m["armies"].is_empty() or bool(m["camp"]["ready"]):
        fail("a fresh game began with unpaid troops")
        return
    var stock: Dictionary=ui.city["realms"][0]["resources"]
    if Mil.recruit(ui.city,world,"spearman")=="":
        fail("recruited troops without a built military camp")
        return
    if Mil.build(ui.city,world)=="" or not m["queue"].is_empty():
        fail("unresearched Stone Age warfare allowed a military camp")
        return
    Research.ensure(ui.city)["known"].append("warfare")
    var pop_before: float=float(ui.city["realms"][0]["pop"])
    var wood_before: float=float(stock["wood"])
    var stone_before: float=float(stock["stone"])
    ui._build_military_camp()
    if not bool(m["camp"]["under_construction"]) or \
            absf(float(stock["wood"])-(wood_before-20))>0.000001 or \
            absf(float(stock["stone"])-(stone_before-9))>0.000001 or \
            float(ui.city["realms"][0]["pop"])!=pop_before:
        fail("building the camp did not charge exactly once")
        return
    Mil.tick(ui.city,world,18.0)
    if not bool(m["camp"]["ready"]) or bool(m["camp"]["under_construction"]):
        fail("paid barracks did not complete")
        return
    ui.city["realms"][0]["pop"]=12
    stock["wood"]=200.0
    stock["stone"]=200.0
    if Mil.recruit(ui.city,world,"spearman","elite")!="" or \
            Mil.recruit(ui.city,world,"slinger","mobilized")!="" or \
            Mil.recruit(ui.city,world,"axeman","standard")!="":
        fail("one of the three source recruits failed with abundant resources")
        return
    if m["queue"].size()!=3 or float(ui.city["realms"][0]["pop"])!=9.0 or \
            absf(float(stock["wood"])-(200.0-19.5-3.0-10.0))>0.000001 or \
            absf(float(stock["stone"])-(200.0-3.9-6.0-10.0))>0.000001:
        fail("recruitment did not pay exact grade costs and population")
        return
    for i in range(3):Mil.tick(ui.city,world,60.0)
    if m["armies"].size()!=3 or not m["queue"].is_empty():
        fail("military training did not create exactly three distinct units")
        return
    if String(m["armies"][0]["kind"])!="spearman" or \
            absf(float(m["armies"][0]["hp"])-350.0)>0.00001 or \
            absf(float(m["armies"][1]["hp"])-68.0)>0.00001 or \
            absf(float(m["armies"][2]["hp"])-280.0)>0.00001:
        fail("trained grades or V99 doubled HP don't agree with source")
        return
    var saved: Dictionary=JSON.parse_string(JSON.stringify(ui.city))
    if Mil.ensure(saved,world)["armies"].size()!=3:
        fail("military state could not survive a saved JSON round trip")
        return
    ui._sync_trade_map()
    if ui.world_view.army_ids_v54.size()!=3 or \
            ui.world_view.terrain_3d.army_root_v54.get_child_count()!=3 or \
            ui.world_view.map_canvas.army_state_v54.size()!=3:
        fail("trained units did not appear on 2D/3D world atlases")
        return
    var home: Dictionary=world["starts"][0]
    ui._show_detail(int(home["c"]),int(home["r"]))
    if ui.detail_view.army_detail_root_v54.get_child_count()!=3 or \
            not ui.detail_view.camp_detail_root_v54.visible:
        fail("home detail tile lacks the real source soldiers or paid camp")
        return
    var start:=Vector2i(int(home["c"]),int(home["r"]))
    var target:=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        if Routes.passable(world,start.x+delta.x,start.y+delta.y):
            target=start+delta
            break
    if target.x<0:
        fail("no reachable adjacent world tile for army regression")
        return
    var first: Dictionary=m["armies"][0]
    if Mil.order(ui.city,world,int(first["id"]),Vector2i(-1,-1))=="":
        fail("army could march outside world boundaries")
        return
    if Mil.order(ui.city,world,int(first["id"]),target)!="":
        fail("real marching order failed for adjacent land")
        return
    var duration: float=float(first["travelDuration"])
    Mil.tick(ui.city,world,duration*0.5)
    if absf(float(Mil.sample(first)["fraction"])-0.5)>0.000001:
        fail("army interpolation does not match V258")
        return
    ui._sync_trade_map()
    var actual: Node3D=ui.world_view.terrain_3d.army_root_v54.get_node_or_null(
        "ArmyActorV54_"+str(first["id"])) as Node3D
    if actual==null or actual.position.distance_to(
            ui.world_view.terrain_3d.scout_point_for(first))>0.00001:
        fail("halfway 3D soldier position diverged from the saved travel clock")
        return
    Mil.tick(ui.city,world,duration*0.5)
    if int(first["c"])!=target.x or int(first["r"])!=target.y or \
            not first["path"].is_empty():
        fail("recruited army did not reach its destination")
        return
    ui._show_detail(target.x,target.y)
    if ui.detail_view.army_detail_root_v54.get_child_count()!=1:
        fail("destination detail tile did not show exactly one moved unit")
        return
    ui._show_detail(start.x,start.y)
    if ui.detail_view.army_detail_root_v54.get_child_count()!=2:
        fail("leaving home duplicated or erased the remaining army")
        return
    print("MILITARY_V54 SUCCESS: source prices/HP, paid camp, grade costs, pop, FIFO, JSON, marching, 2D/3D/detail, no ghosts")
    quit(0)
