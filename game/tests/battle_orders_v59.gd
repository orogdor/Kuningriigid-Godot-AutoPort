extends SceneTree
## V59: explicit tactical destinations, team/terrain validation,
## Godot 24-man movement, save persistence, command cancellation and touch UI.
const Orders=preload("res://scripts/battle_orders_v59.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")
const View=preload("res://scripts/battle_view_v55.gd")

func fail(message: String) -> void:
    printerr("BATTLE_ORDERS_V59 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var b: Dictionary={"version":59,"result":"","fighters":[
        {"id":7,"source_id":7,"team":0,"kind":"spearman",
            "grade":"standard","hp":250.0,"max_hp":250.0,
            "x":-30.0,"z":22.0,"mode":"hold","formation":"line"},
        {"id":-3,"source_id":-3,"team":1,"kind":"axeman",
            "grade":"standard","hp":280.0,"max_hp":280.0,
            "x":100.0,"z":75.0,"mode":"hold","formation":"line"}]}
    Men.initialize(b)
    Nav.ensure(b)
    if Orders.issue(b,-3,Vector2(20,22))=="":
        fail("A hostile unit accepted player move order")
        return
    if Orders.issue(b,7,Vector2.ZERO)=="":
        fail("Move order entered the central solid boulder")
        return
    if Orders.issue(b,7,Vector2(400,22))=="":
        fail("Move order entered the retreat-only ring")
        return
    if Orders.issue(b,7,Vector2(24,22))!="":
        fail("Valid player move order was rejected")
        return
    if String(b["fighters"][0]["mode"])!="move":
        fail("Accepted order did not set move state")
        return
    var stored: Dictionary=JSON.parse_string(JSON.stringify(b))
    if not stored["fighters"][0].has(Orders.KEY):
        fail("Move target was not preserved in a campaign save")
        return
    var start_x: float=float(stored["fighters"][0]["men"][0]["x"])
    var crossed: bool=false
    for i in range(170):
        Men.tick(stored,0.2)
        if float(stored["fighters"][0]["men"][0]["x"])>start_x+5.0:
            crossed=true
        for man in stored["fighters"][0]["men"]:
            if float(man.get("hp",0))<=0:continue
            if not Nav.open_at(Vector2(float(man["x"]),float(man["z"])),
                    Nav.ensure(stored)):
                fail("Individually marching soldier entered an obstacle")
                return
    if not crossed or float(stored["fighters"][0]["x"])<22.0 or \
            String(stored["fighters"][0]["mode"])!="hold":
        fail("Saved order did not drive formation to its destination")
        return
    if stored["fighters"][0].has(Orders.KEY):
        fail("Reached waypoint was not cleared")
        return
    if Orders.issue(b,7,Vector2(24,22))!="":
        fail("Second move order failed")
        return
    Orders.cancel(b["fighters"][0])
    if b["fighters"][0].has(Orders.KEY):
        fail("Attack/retreat cancellation left a stale waypoint")
        return
    root.size=Vector2i(1000,690)
    var view: Control=View.new()
    root.add_child(view)
    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    await process_frame
    await process_frame
    if view.battle_canvas_container==null or \
            view.battle_canvas_container.size.x<50.0 or \
            view.battle_canvas_container.size.y<50.0:
        fail("Battlefield tap canvas has no usable size")
        return
    view.set_battle(b)
    if view.move_mode_enabled:
        fail("Tap-to-move armed without explicit player intent")
        return
    var issued: Array=[]
    view.battle_move_requested.connect(func(id: int,x: float,z: float):
        issued.append({"id":id,"x":x,"z":z}))
    view._toggle_move_mode()
    var desired:=Vector3(40.0,0.0,35.0)
    var pos: Vector2=view.battle_camera.unproject_position(desired)
    var scale:=Vector2(
        view.battle_canvas_container.size.x/maxf(float(view.viewport.size.x),1.0),
        view.battle_canvas_container.size.y/maxf(float(view.viewport.size.y),1.0))
    var touch:=InputEventScreenTouch.new()
    touch.pressed=true
    touch.position=pos*scale
    view._on_battle_canvas_input(touch)
    if issued.size()!=1 or issued[0]["id"]!=7:
        fail("Touch did not emit selected friendly squad's move order (count=%d armed=%s selected=%d)" % [
            issued.size(),str(view.move_mode_enabled),view.order_picker.selected])
        return
    var emitted:=Vector2(float(issued[0]["x"]),float(issued[0]["z"]))
    if emitted.distance_to(Vector2(40,35))>2.0:
        fail("Camera projection mapped touch to wrong battlefield coordinate")
        return
    view._on_battle_canvas_input(touch)
    if issued.size()!=1:
        fail("Tap-to-move emitted repeat commands without re-arming")
        return
    print("BATTLE_ORDERS_V59 SUCCESS: player touch orders, valid cover, 24-man saved move and waypoint completion")
    quit(0)
