extends SceneTree
## V57: obstacles, detours, team-vs-team collision, real source GLB
## locomotion, permanent health, and saved tactical terrain.
const Nav=preload("res://scripts/battle_nav_v57.gd")
const Men=preload("res://scripts/individual_v56.gd")
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_NAV_V57 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    if absf(Nav.RADIUS-0.34)>0.00001:
        fail("Stone Age soldier body radius no longer matches V90/V96 source")
        return
    var arena: Dictionary=Nav.ensure({"version":57})
    if arena.get("obstacles",[]).size()!=3:
        fail("Expected three deterministic battlefield stone obstacles")
        return
    if Nav.open_at(Vector2.ZERO,arena):
        fail("Centre rock is not solid")
        return
    var navigator: Dictionary={"index":0,"x":-16.0,"z":0.0,"hp":10.0}
    var bent: bool=false
    for step_id in range(150):
        Nav.step(navigator,Vector2(16,0),0.50,arena)
        var p:=Vector2(float(navigator["x"]),float(navigator["z"]))
        if not Nav.open_at(p,arena):
            fail("A soldier moved through a boulder")
            return
        if absf(p.x)<4.0 and absf(p.y)>2.0:bent=true
    if not bent or float(navigator["x"])<12.0:
        fail("Obstacle route stalled or went directly through solid rock")
        return
    # Two opposing soldiers cannot occupy the same body space. This fixture
    # explicitly uses two DIFFERENT teams, not just friendly formation peers.
    var left: Dictionary={"id":"a","index":0,"x":8.0,"z":20.0,"hp":10.0}
    var right: Dictionary={"id":"b","index":0,"x":9.0,"z":20.0,"hp":10.0}
    var crowd: Dictionary={"fighters":[{"team":0,"men":[left]},
        {"team":1,"men":[right]}]}
    var grid: Dictionary=Nav.index_people(crowd)
    for i in range(15):
        Nav.step(left,Vector2(9.0,20.0),0.40,arena,grid)
        if Vector2(float(left["x"]),float(left["z"])).distance_to(
                Vector2(float(right["x"]),float(right["z"]))) < 0.69:
            fail("Opposing soldier bodies overlap")
            return
    # Run an entire 24-v-24 actual Stone Age clash around the same rock.
    var b: Dictionary={"version":57,"seed":7,"fighters":[
        {"id":1,"source_id":1,"team":0,"kind":"spearman",
            "grade":"standard","hp":250.0,"max_hp":250.0,
            "x":-34.0,"z":0.0,"mode":"attack","formation":"line"},
        {"id":-1,"source_id":-1,"team":1,"kind":"axeman",
            "grade":"standard","hp":280.0,"max_hp":280.0,
            "x":34.0,"z":0.0,"mode":"attack","formation":"line"}
    ]}
    Men.initialize(b)
    Nav.ensure(b)
    if b["fighters"][0]["men"].size()!=24 or b["fighters"][1]["men"].size()!=24:
        fail("Failed to initialize the original 24-man Stone Age squad")
        return
    var first: Dictionary=b["fighters"][0]["men"][0]
    var start_x: float=float(first["x"])
    var caught: bool=false
    var wounded: bool=false
    for tick_id in range(360):
        Men.tick(b,0.2)
        for fighter in b["fighters"]:
            for man in fighter["men"]:
                if float(man["hp"])<=0 or bool(man.get("escaped",false)):continue
                var at:=Vector2(float(man["x"]),float(man["z"]))
                if not Nav.open_at(at,arena):
                    fail("Active combatant entered an obstacle during battle")
                    return
                if bool(man.get("moving",false)):caught=true
        if float(b["fighters"][0]["hp"])<250.0 or \
                float(b["fighters"][1]["hp"])<280.0:
            wounded=true
            break
    if not caught or absf(float(first["x"])-start_x)<0.5:
        fail("The first Stone Age GLB figure never marched")
        return
    if not wounded:
        fail("Fighters became stuck avoiding the boulder; no melee occurred")
        return
    var copied: Dictionary=JSON.parse_string(JSON.stringify(b))
    if copied.get("terrain_v57",{}).get("obstacles",[]).size()!=3 or \
            copied["fighters"][0]["men"].size()!=24:
        fail("Saved battle dropped terrain or independent soldiers")
        return
    # Visual mesh test with explicit gait and strike state; no model import
    # should happen each simulation frame, old GLBs are reused by Node3D.
    first["moving"]=true
    first["anim_phase"]=1.2
    first["attack_anim"]=0.18
    root.size=Vector2i(1000,690)
    var view: Control=View.new()
    root.add_child(view)
    await process_frame
    view.set_battle(b)
    if view.obstacles_root.get_child_count()!=3 or \
            view.actors_root.get_child_count()<1:
        fail("Battle 3D scene lacks stone obstacles or original soldier GLBs")
        return
    var figure: Node3D=view.actors_root.get_node_or_null("TacticalMan_1_0") as Node3D
    if figure==null or figure.get_child_count()<2:
        fail("Missing expected original spearman mesh and team marker")
        return
    var model: Node3D=figure.get_child(0) as Node3D
    if model==null or model.position.y<=0.0 or model.rotation.x>=0.0:
        fail("Individual GLB walking bob and attack pose not applied")
        return
    print("BATTLE_NAV_V57 SUCCESS: saved solid boulders, safe detour, two-team collision, moving 24-man clash, permanent wounds and GLB gait/strike")
    quit(0)
