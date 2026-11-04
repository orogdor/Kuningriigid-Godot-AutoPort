extends SceneTree
## AutoPort V70: 216 actual imported GLB soldier actions synchronized
## with the precise deterministic combat events rather than frame timers.
## Uses identical 0.2s combat states to compare V69 vs V70 damage results.
const Scene=preload("res://content.tscn")
const Battle=preload("res://scripts/battle_v55.gd")
const Men=preload("res://scripts/individual_v56.gd")
const Anim=preload("res://scripts/battle_animation_v65.gd")
const Nav=preload("res://scripts/battle_nav_v57.gd")
const Stones=preload("res://scripts/projectiles_v58.gd")
const Targets=preload("res://scripts/battle_targets_v64.gd")

func fail(message: String) -> void:
    printerr("BATTLE_SYNC_V70 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(1080,760)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_large_demo_battle()
    var world: Dictionary=ui.world_view.world
    var view: Control=ui.battle_view
    view.auto_timer.stop()
    var b: Dictionary=Battle.current(ui.city,world)
    if int(b.get("version",0))!=70 or not b.get("large_demo_v64",false):
        fail("Large 216-person tactical stress scenario is not V70")
        return
    if view.actors_root.get_child_count()!=216:
        fail("The large test failed to instantiate all 216 original GLBs")
        return

    var baseline: Dictionary=JSON.parse_string(JSON.stringify(b))
    var attacker: Dictionary=baseline["fighters"][0]["men"][0]
    var victim: Dictionary=baseline["fighters"][5]["men"][0]
    var arena: Dictionary=Nav.ensure(baseline)
    var start: Vector2=Vector2.ZERO
    var clear: bool=false
    # Keep the test independent of the seeded rocks and unrelated soldiers.
    for x in range(-100,101,8):
        if clear:break
        for z in range(-90,91,8):
            var a:=Vector2(float(x),float(z))
            var e: Vector2=a+Vector2(1.3,0.0)
            if Nav.open_at(a,arena) and Nav.open_at(e,arena) and \
                    Stones.clear_line(a,e,arena):
                start=a
                clear=true
                break
    if not clear:
        fail("No obstacle-free place to check an actual spear strike")
        return
    attacker["x"]=start.x
    attacker["z"]=start.y
    victim["x"]=start.x+1.3
    victim["z"]=start.y
    # The defender must survive the strike so we can inspect its hit clip.
    victim["hp"]=500.0
    for man in baseline["fighters"][0]["men"]:
        man["cool"]=9.0
    attacker["cool"]=0.0
    var old: Dictionary=JSON.parse_string(JSON.stringify(baseline))
    var modern: Dictionary=JSON.parse_string(JSON.stringify(baseline))
    old["version"]=69
    modern["version"]=70
    var old_grid: Dictionary=Targets.build(old)
    var new_grid: Dictionary=Targets.build(modern)
    Men._attack(old,old["fighters"][0],0.2,old_grid)
    Men._attack(modern,modern["fighters"][0],0.2,new_grid)
    # The new markers cannot affect any real battle rule or save outcome.
    var events: int=0
    for i in range(old["fighters"].size()):
        for j in range(old["fighters"][i]["men"].size()):
            var a: Dictionary=old["fighters"][i]["men"][j]
            var c: Dictionary=modern["fighters"][i]["men"][j]
            for property in ["hp","x","z","cool","shots","ammo"]:
                if absf(float(a[property])-float(c[property]))>0.00001:
                    fail("V70 altered live combat field "+String(property))
                    return
            events+=int(c.get("strike_seq_v70",0)) + \
                int(c.get("hit_seq_v70",0))
    if events!=2 or \
            int(modern["fighters"][0]["men"][0].get("strike_seq_v70",-1))!=1 or \
            int(modern["fighters"][5]["men"][0].get("hit_seq_v70",-1))!=1 or \
            not JSON.stringify(old.get("projectiles_v58",[]))==\
                JSON.stringify(modern.get("projectiles_v58",[])):
        fail("Actual 216-man strike/hit pair was not recorded exactly once")
        return

    # Both Skeleton3D clips begin on the same real simulation snapshot.
    view.set_battle(modern)
    if view.actors_root.get_child_count()!=216:
        fail("Simultaneous hit/strike caused 3D GLB actor count mismatch")
        return
    var man_node: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_900101_0") as Node3D
    var foe_node: Node3D=view.actors_root.get_node_or_null(
        "TacticalMan_-900101_0") as Node3D
    if man_node==null or foe_node==null:
        fail("Original melee 3D models were removed")
        return
    var model: Node3D=man_node.get_child(0) as Node3D
    var enemy_model: Node3D=foe_node.get_child(0) as Node3D
    var ac: Dictionary=Anim.available_clips(model)
    var hc: Dictionary=Anim.available_clips(enemy_model)
    var ap: AnimationPlayer=model.get_meta("source_animator_v65",{})[
        "player"]
    var hp: AnimationPlayer=enemy_model.get_meta("source_animator_v65",{})[
        "player"]
    if not ap.is_playing() or not hp.is_playing() or \
            ap.current_animation!=String(ac["attack"]) or \
            hp.current_animation!=String(hc["hit"]):
        fail("Attacker and victim are not playing synchronized real GLB clips")
        return
    if ap.get_animation(String(ac["attack"])).loop_mode!=Animation.LOOP_NONE or \
            hp.get_animation(String(hc["hit"])).loop_mode!=Animation.LOOP_NONE:
        fail("Attack or hit animation loops instead of playing exactly once")
        return
    var aspeed: float=ap.get_playing_speed()
    if absf(ap.current_animation_length/maxf(aspeed,0.001)-\
            Anim.ACTION_REAL_SECONDS_V70)>0.15:
        fail("Imported attack clip duration is not synchronized to battle pace")
        return

    # Simulate one rendered time slice and another battle refresh: the
    # animation must *continue*, not rewind to its first frame every time.
    ap.advance(0.14)
    hp.advance(0.14)
    var first_time: float=ap.current_animation_position
    var victim_time: float=hp.current_animation_position
    if first_time<=0.001 or victim_time<=0.001:
        fail("The imported skeletal combat clips never advanced")
        return
    view._render_soldier_motion_v65(1.0/60.0)
    if ap.current_animation!=String(ac["attack"]) or \
            hp.current_animation!=String(hc["hit"]) or \
            ap.current_animation_position<first_time-0.001 or \
            hp.current_animation_position<victim_time-0.001:
        fail("Frame-driven rendering restarted combat animations")
        return
    view.set_battle(modern,true)
    view._render_soldier_motion_v65(1.0/60.0)
    if ap.current_animation_position<first_time-0.001:
        fail("Unchanged battle snapshot restarted a strike animation")
        return

    # One more registered attack on this same person must start a NEW clip.
    var fresh: Dictionary=JSON.parse_string(JSON.stringify(modern))
    fresh["fighters"][0]["men"][0]["cool"]=0.0
    var attack_before: int=int(fresh["fighters"][0]["men"][0]["strike_seq_v70"])
    Men._attack(fresh,fresh["fighters"][0],0.2,Targets.build(fresh))
    if int(fresh["fighters"][0]["men"][0]["strike_seq_v70"])!=attack_before+1:
        fail("A second valid attack did not generate a fresh event")
        return
    view.set_battle(fresh,true)
    view._render_soldier_motion_v65(1.0/60.0)
    if not ap.is_playing() or ap.current_animation!=String(ac["attack"]) or \
            ap.current_animation_position>0.08:
        fail("The second confirmed attack did not restart its GLB clip")
        return

    # A genuine slinger stone impact must use the same hit counter; it
    # remains distinct from the projectile launch animation.
    var target_man: Dictionary=fresh["fighters"][5]["men"][0]
    var hit_before: int=int(target_man.get("hit_seq_v70",0))
    var target_pos:=Vector2(float(target_man["x"]),float(target_man["z"]))
    Stones.ensure(fresh).append({"id":999,"team":0,
        "target_id":String(target_man["id"]),
        "origin_x":target_pos.x-2.0,"origin_z":target_pos.y,
        "dest_x":target_pos.x,"dest_z":target_pos.y,
        "x":target_pos.x-2.0,"z":target_pos.y,"height":1.0,
        "duration":0.15,"elapsed":0.0,"damage":1.0,"will_hit":true})
    Stones.step(fresh,0.2)
    if int(target_man.get("hit_seq_v70",0))!=hit_before+1:
        fail("Confirmed slinger impact did not trigger synchronized hit event")
        return
    var persisted: Variant=JSON.parse_string(JSON.stringify(fresh))
    if not persisted is Dictionary or \
            int(persisted["fighters"][5]["men"][0].get("hit_seq_v70",-1))!=\
            hit_before+1:
        fail("Saved 216-man battle lost its combat animation event state")
        return
    if view.actors_root.get_child_count()!=216:
        fail("Combat animations caused any of 216 soldier nodes to disappear")
        return
    view.set_auto_battle(false)
    print("BATTLE_SYNC_V70 SUCCESS: 216 GLBs, exact simultaneous hit/attack, source Skeleton3D clips with correct pacing, no frame replay, fresh attack event, slinger impact event, unchanged V69 damage")
    quit(0)
