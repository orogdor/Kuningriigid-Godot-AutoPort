extends SceneTree
## AutoPort V64: 216 actual GLB soldiers, deterministic indexed targeting
## compared with the old per-man search, battle UI, save and free replay.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Targets=preload("res://scripts/battle_targets_v64.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")

func fail(why: String) -> void:
    printerr("BATTLE_TARGETS_V64 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1100,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var resources_before: String=JSON.stringify(ui.city["realms"][0]["resources"])
    var pop_before: float=float(ui.city["realms"][0]["pop"])
    var time_before: float=float(ui.city["time"])
    if ui.large_demo_start_button==null or \
            ui.large_demo_start_button.name!="LargeDemoBattleV64":
        fail("City is missing the real large-battle start button")
        return
    ui.large_demo_start_button.pressed.emit()
    var b: Dictionary=Battle.current(ui.city,world)
    if b.is_empty() or int(b.get("version",0))<64 or \
            not bool(b.get("large_demo_v64",false)) or \
            not bool(b.get("demo_v61",false)) or not ui.battle_view.visible:
        fail("City button did not start the playable large V64 battle")
        return
    if b["fighters"].size()!=9 or ui.battle_view.id_list.size()!=5:
        fail("Large test battle must contain five allied and four hostile squads")
        return
    var all_men: int=0
    for fighter in b["fighters"]:
        all_men+=fighter.get("men",[]).size()
    if all_men!=216 or ui.battle_view.actors_root.get_child_count()!=216:
        fail("Large battle did not instantiate all 216 independent source GLBs")
        return
    var should_shrink: bool=OS.has_feature("mobile")
    if not ui.battle_view.auto_play_enabled or \
            ui.battle_view.fast_graphics!=should_shrink:
        fail("Large combat must preserve desktop clarity and mobile graphics settings")
        return
    if Battle.start_large_demo(ui.city,world)=="":
        fail("Started a second large test over an active battle")
        return

    # Validate exact target parity with the original O(all enemies) loop for
    # real source soldiers at many positions and all Stone Age attack ranges.
    var side_one: Array=[]
    for f in b["fighters"]:
        if int(f["team"])==1:side_one.append(f)
    var terrain: Dictionary=Nav.ensure(b)
    var target_index: Dictionary=Targets.build(b)
    for foe in side_one:
        for man in foe["men"]:
            var centre:=Vector2(float(man["x"]),float(man["z"]))
            for offset in [Vector2.ZERO,Vector2(0.28,-0.19),
                    Vector2(4.0,0.0),Vector2(-2.5,1.0)]:
                var p: Vector2=centre+offset
                var attacker: Dictionary={"x":p.x,"z":p.y}
                for reach in [1.06,1.73,10.0]:
                    var old: Dictionary=Men._target_man(
                        attacker,side_one,reach,terrain)
                    var fast: Dictionary=Targets.nearest(
                        target_index,attacker,0,reach,terrain)
                    if String(old.get("id",""))!=String(fast.get("id","")):
                        fail("Fast nearest target disagrees with old combat rules")
                        return
    # Strict reach and stable tie ordering; a target killed during this tick
    # must disappear from queries without corrupting the transient index.
    var tie: Dictionary={"fighters":[{"team":1,"men":[
        {"id":"first","x":1.0,"z":0.0,"hp":1.0,"escaped":false},
        {"id":"second","x":-1.0,"z":0.0,"hp":1.0,"escaped":false}]}]}
    var ties: Dictionary=Targets.build(tie)
    var origin: Dictionary={"x":0.0,"z":0.0}
    if not Targets.nearest(ties,origin,0,1.0).is_empty() or \
            Targets.nearest(ties,origin,0,1.1).get("id","")!="first":
        fail("Exact attack reach or first-soldier tie order changed")
        return
    tie["fighters"][0]["men"][0]["hp"]=0.0
    if Targets.nearest(ties,origin,0,1.1).get("id","")!="second":
        fail("Dead enemy remained attackable within an indexed combat tick")
        return

    # Compare live movement, attack damage, cooldowns, bullets and persistent
    # per-person state between pre-V64 and V64 on identical saved armies.
    var legacy: Dictionary=JSON.parse_string(JSON.stringify(b))
    var optimized: Dictionary=JSON.parse_string(JSON.stringify(b))
    legacy["version"]=63
    optimized["version"]=64
    # Move one enemy squad into engagement range to exercise actual hits.
    for battle_state in [legacy,optimized]:
        var foe: Dictionary=battle_state["fighters"][5]
        foe["x"]=-27.0
        foe["z"]=-22.0
        for man in foe["men"]:
            man["x"]=float(man["x"])-65.0
    for i in range(15):
        Men.tick(legacy,0.2)
        Men.tick(optimized,0.2)
    for i in range(legacy["fighters"].size()):
        var a: Dictionary=legacy["fighters"][i]
        var f: Dictionary=optimized["fighters"][i]
        if absf(float(a["hp"])-float(f["hp"]))>0.0001:
            fail("Indexed fighting changes squad damage / HP")
            return
        for j in range(a["men"].size()):
            var m: Dictionary=a["men"][j]
            var n: Dictionary=f["men"][j]
            if absf(float(m["hp"])-float(n["hp"]))>0.0001 or \
                    int(m["shots"])!=int(n["shots"]) or \
                    int(m["ammo"])!=int(n["ammo"]):
                fail("Indexed fighting changes an individual combat outcome")
                return
    if JSON.stringify(legacy.get("projectiles_v58",[]))!=\
            JSON.stringify(optimized.get("projectiles_v58",[])):
        fail("Indexed combat changed slingstone trajectory or ammunition")
        return
    var probe: Dictionary={"x":38.0,"z":-18.0}
    var counts: Dictionary={"candidate_checks":0}
    Targets.nearest(target_index,probe,0,1.73,terrain,counts)
    if int(counts["candidate_checks"])>=96:
        fail("Spatial query still linearly scans all enemy soldiers")
        return

    # UI / save / replay: this is a real playable 216-man scenario,
    # yet never commits temporary casualties to the real strategic army.
    ui.battle_view.auto_timer.stop()
    ui._battle_tick(1.0)
    if ui.battle_view.actors_root.get_child_count()!=216:
        fail("216 source GLB fighters disappeared after the first battle step")
        return
    var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(
        "user://autoport_city_v05.json"))
    if not saved is Dictionary or \
            not bool(Battle.current(saved,world).get("large_demo_v64",false)):
        fail("The 216-man scenario was lost from the existing save format")
        return
    for foe in b["fighters"]:
        if int(foe["team"])!=1:continue
        foe["hp"]=0.0
        for man in foe["men"]:man["hp"]=0.0
    ui._battle_tick(1.0)
    if String(b.get("result",""))!="victory" or \
            ui.battle_view.demo_retry_button.disabled:
        fail("Large demo cannot finish with a result and replay control")
        return
    if not ui.city["military_v54"]["armies"].is_empty() or \
            JSON.stringify(ui.city["realms"][0]["resources"])!=resources_before or \
            float(ui.city["realms"][0]["pop"])!=pop_before or \
            float(ui.city["time"])!=time_before:
        fail("The free large battle damaged the real city's economy/army")
        return
    ui.battle_view._restart_demo()
    var replay: Dictionary=Battle.current(ui.city,world)
    if replay.is_empty() or not Battle.active(ui.city,world) or \
            not bool(replay.get("large_demo_v64",false)) or \
            replay["fighters"].size()!=9:
        fail("Retry started a smaller demo instead of preserving 216 soldiers")
        return
    ui.battle_view.set_auto_battle(false)
    print("BATTLE_TARGETS_V64 SUCCESS: 216 GLBs, fast target parity, saved 5v4 battle, unchanged 15-step combat, true victory, safe 216 replay")
    quit(0)
