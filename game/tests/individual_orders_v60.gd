extends SceneTree
## V60: persistent per-man move and hold, 24-person parity, collision,
## enemy rejection, independent movement, rejoin and real mobile touch UI.
const Orders=preload("res://scripts/individual_orders_v60.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")
const View=preload("res://scripts/battle_view_v55.gd")

func fail(why: String) -> void:
    printerr("INDIVIDUAL_ORDERS_V60 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var battle: Dictionary={"version":60,"result":"","fighters":[
        {"id":5,"source_id":5,"team":0,"kind":"spearman",
            "grade":"standard","hp":250.0,"max_hp":250.0,
            "x":-30.0,"z":22.0,"mode":"hold","formation":"line"},
        {"id":-6,"source_id":-6,"team":1,"kind":"axeman",
            "grade":"standard","hp":280.0,"max_hp":280.0,
            "x":100.0,"z":75.0,"mode":"hold","formation":"line"}]}
    Men.initialize(battle)
    Nav.ensure(battle)
    if battle["fighters"][0]["men"].size()!=24:
        fail("Original source 24-person squad disappeared")
        return
    if Orders.issue(battle,-6,0,Vector2(10,30))=="":
        fail("A hostile soldier accepted player movement")
        return
    if Orders.issue(battle,5,24,Vector2(10,30))=="":
        fail("Invalid soldier index accepted")
        return
    if Orders.issue(battle,5,23,Vector2.ZERO)=="":
        fail("An individual can be ordered inside a boulder")
        return
    if Orders.issue(battle,5,23,Vector2(360,0))=="":
        fail("An individual can be ordered outside the active 3x3 arena")
        return
    if Orders.issue(battle,5,23,Vector2(0,30))!="":
        fail("Valid individual move order was rejected")
        return
    var before: Dictionary=JSON.parse_string(JSON.stringify(battle))
    if not before["fighters"][0]["men"][23].has(Orders.KEY):
        fail("The individual order did not survive a JSON save")
        return
    var ordered: Dictionary=before["fighters"][0]["men"][23]
    var initial_x: float=float(ordered["x"])
    var other_x: float=float(before["fighters"][0]["men"][0]["x"])
    for i in range(150):
        Men.tick(before,0.2)
        for man in before["fighters"][0]["men"]:
            if float(man.get("hp",0))<=0:continue
            if not Nav.open_at(Vector2(float(man["x"]),float(man["z"])),
                    Nav.ensure(before)):
                fail("Independent walking crossed a solid obstacle")
                return
    ordered=before["fighters"][0]["men"][23]
    if float(ordered["x"])<initial_x+17:
        fail("Individually controlled soldier did not leave formation")
        return
    if String(ordered.get(Orders.STATUS,""))!="hold":
        fail("Reached soldier does not hold its independent destination")
        return
    if absf(float(before["fighters"][0]["x"])+30.0)>0.1:
        fail("Individual movement dragged the entire squad anchor")
        return
    if absf(float(before["fighters"][0]["men"][0]["x"])-other_x)>1.5:
        fail("Another soldier was teleported by the individual order")
        return
    var held: Vector2=Vector2(float(ordered["x"]),float(ordered["z"]))
    for i in range(20):Men.tick(before,0.2)
    var still: Dictionary=before["fighters"][0]["men"][23]
    if Vector2(float(still["x"]),float(still["z"])).distance_to(held)>0.7:
        fail("Held soldier was pulled back to formation automatically")
        return
    if Orders.rejoin(before,5,23)!="":
        fail("Rejoin order rejected")
        return
    if before["fighters"][0]["men"][23].has(Orders.KEY):
        fail("Rejoin failed to clear saved individual target")
        return
    var old_gap: float=Vector2(float(still["x"])+28.425,
        float(still["z"])-24.625).length()
    for i in range(100):Men.tick(before,0.2)
    still=before["fighters"][0]["men"][23]
    var new_gap: float=Vector2(float(still["x"])+28.425,
        float(still["z"])-24.625).length()
    if new_gap>=old_gap-3.0:
        fail("Rejoined soldier did not move back toward its source slot")
        return
    if Orders.issue(battle,5,23,Vector2(0,30))!="":
        fail("Second individual move order failed")
        return
    Orders.clear_squad(battle["fighters"][0])
    if battle["fighters"][0]["men"][23].has(Orders.KEY):
        fail("Whole-squad command left an old independent waypoint")
        return
    battle["fighters"][0]["men"][23]["hp"]=0.0
    if Orders.issue(battle,5,23,Vector2(0,30))=="":
        fail("A fallen soldier accepted an individual order")
        return

    # Interactive UI fixture: alive soldier index is explicitly selected.
    var visual_battle: Dictionary={"version":60,"result":"","fighters":[
        {"id":5,"source_id":5,"team":0,"kind":"spearman",
            "grade":"standard","hp":250.0,"max_hp":250.0,
            "x":-30.0,"z":22.0,"mode":"hold","formation":"line"}]}
    Men.initialize(visual_battle)
    Nav.ensure(visual_battle)
    root.size=Vector2i(1050,740)
    var view: Control=View.new()
    root.add_child(view)
    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    await process_frame
    await process_frame
    view.set_battle(visual_battle)
    if view.man_indices.size()!=24 or view.individual_picker==null:
        fail("Mobile battle selector did not list 24 living men")
        return
    view.individual_picker.select(23)
    view.set_battle(visual_battle)
    var selected: Dictionary=view._chosen_man()
    if int(selected.get("squad",-1))!=5 or int(selected.get("index",-1))!=23:
        fail("Selected individual was not stable across a battle redraw")
        return
    var requested: Array=[]
    view.battle_individual_move_requested.connect(
        func(id: int,index: int,x: float,z: float):
            requested.append({"squad":id,"index":index,"x":x,"z":z}))
    view._toggle_individual_move()
    if not view.individual_move_mode or view.move_mode_enabled:
        fail("Individual move is not armed exclusively")
        return
    var target:=Vector3(12.0,0.0,28.0)
    var image_point: Vector2=view.battle_camera.unproject_position(target)
    var scale:=Vector2(
        view.battle_canvas_container.size.x/maxf(float(view.viewport.size.x),1.0),
        view.battle_canvas_container.size.y/maxf(float(view.viewport.size.y),1.0))
    var touch:=InputEventScreenTouch.new()
    touch.pressed=true
    touch.position=image_point*scale
    view._on_battle_canvas_input(touch)
    if requested.size()!=1 or requested[0]["squad"]!=5 or \
            requested[0]["index"]!=23:
        fail("Tactical touch did not command the selected soldier")
        return
    var clicked:=Vector2(float(requested[0]["x"]),float(requested[0]["z"]))
    if clicked.distance_to(Vector2(12,28))>2.0:
        fail("Tactical individual touch projected to wrong ground coordinate")
        return
    view._on_battle_canvas_input(touch)
    if requested.size()!=1:
        fail("Touch emitted repeated individual move orders")
        return
    var returns: Array=[]
    view.battle_individual_return_requested.connect(
        func(id: int,index: int):returns.append({"id":id,"index":index}))
    view._individual_rejoin()
    if returns.size()!=1 or returns[0]["index"]!=23:
        fail("Rejoin button did not target the selected individual")
        return
    view._focus_individual()
    if view.battle_camera.size>120.01:
        fail("Tactical camera cannot zoom to an individual")
        return
    print("INDIVIDUAL_ORDERS_V60 SUCCESS: saved individual movement, live collision, hold/rejoin, 24-man squad unchanged, camera and mobile touch")
    quit(0)
