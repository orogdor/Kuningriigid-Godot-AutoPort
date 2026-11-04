extends SceneTree
## V58: blocker-aware slinger shots, actual travel time, 3D stone markers,
## damage after impact and deterministic save/restore of in-flight stones.
const Nav=preload("res://scripts/battle_nav_v57.gd")
const Stones=preload("res://scripts/projectiles_v58.gd")
const Men=preload("res://scripts/individual_v56.gd")
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("PROJECTILES_V58 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var b: Dictionary={"version":58,"fighters":[]}
    var arena: Dictionary=Nav.ensure(b)
    if Stones.clear_line(Vector2(-4,0),Vector2(4,0),arena):
        fail("A slinger can shoot directly through the centre boulder")
        return
    if not Stones.clear_line(Vector2(-8,15),Vector2(0,15),arena):
        fail("Clear shooting lane incorrectly blocked")
        return
    var a: Dictionary={"id":"1:0","x":-8.0,"z":15.0,"hp":10.0}
    var victim: Dictionary={"id":"2:0","x":0.0,"z":15.0,"hp":10.0}
    b["fighters"]=[{"team":0,"men":[a]},{"team":1,"men":[victim]}]
    if not Stones.fire(b,a,victim,0,3.0,true):
        fail("Visible stone was not launched")
        return
    Stones.step(b,0.12)
    if float(victim["hp"])!=10.0 or Stones.ensure(b).size()!=1:
        fail("Stone caused instant damage or was lost in flight")
        return
    var saved: Dictionary=JSON.parse_string(JSON.stringify(b))
    if saved.get("projectiles_v58",[]).size()!=1:
        fail("A save dropped an in-flight projectile")
        return
    Stones.step(saved,1.0)
    if saved.get("projectiles_v58",[]).size()!=0 or \
            absf(float(saved["fighters"][1]["men"][0]["hp"])-7.0)>0.001:
        fail("Reloaded stone did not hit its original individual on arrival")
        return
    var blocker: Dictionary={"id":"1:1","x":-4.0,"z":0.0}
    var hidden: Dictionary={"id":"2:1","x":4.0,"z":0.0}
    if Stones.fire(b,blocker,hidden,0,3.0,true):
        fail("Boulder did not stop a shot")
        return
    var misses: Dictionary={"version":58,"fighters":[{"team":0,"men":[a]},
        {"team":1,"men":[victim.duplicate(true)]}]}
    if not Stones.fire(misses,a,victim,0,4.0,false):
        fail("The deliberately inaccurate shot could not launch")
        return
    Stones.step(misses,2.0)
    if absf(float(misses["fighters"][1]["men"][0]["hp"])-10.0)>0.001:
        fail("Deterministic missed stone damaged target")
        return
    # Integration: real slinger ammunition launches a delayed projectile;
    # direct instant damage is deliberately removed for V58 engagements.
    var fight: Dictionary={"version":58,"fighters":[
        {"id":1,"source_id":1,"team":0,"kind":"slinger",
            "grade":"standard","hp":170.0,"max_hp":170.0,
            "x":-8.0,"z":15.0,"mode":"hold","formation":"line"},
        {"id":2,"source_id":2,"team":1,"kind":"spearman",
            "grade":"standard","hp":250.0,"max_hp":250.0,
            "x":0.0,"z":15.0,"mode":"hold","formation":"line"}]}
    Men.initialize(fight)
    Nav.ensure(fight)
    Men.tick(fight,0.2)
    if Stones.ensure(fight).is_empty() or \
            absf(float(fight["fighters"][1]["hp"])-250.0)>0.001:
        fail("Slingers did not launch real delayed stones")
        return
    var in_flight: Dictionary=fight.duplicate(true)
    for n in range(10):
        Men.tick(fight,0.2)
    if float(fight["fighters"][1]["hp"])>=250.0:
        fail("In-flight slinger stones never damaged a visible opposing unit")
        return
    root.size=Vector2i(1000,690)
    var view: Control=View.new()
    root.add_child(view)
    await process_frame
    view.set_battle(in_flight)
    if view.projectiles_root==null or view.projectiles_root.get_child_count()==0:
        fail("Actual flying stones are absent from the Godot 3D battlefield")
        return
    print("PROJECTILES_V58 SUCCESS: solid cover, saved flight, delayed damage, missed stones, real slinger integration and 3D projectiles")
    quit(0)
