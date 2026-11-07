extends SceneTree
## V93: render-time cleanup must scale with fallen combatants only,
## independent of how many living original GLB soldiers are on screen.
## Death/replay logic stays visual-only; no HP, combat or saves are modified.
const View=preload("res://scripts/battle_view_v55.gd")

func fail(message: String) -> void:
    printerr("BATTLE_FALLEN_SET_V93 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=View.new()
    var actors:=Node3D.new()
    view.actors_root=actors
    view.add_child(actors)
    var soldiers: Array[Node3D]=[]
    for i in range(216):
        var soldier:=Node3D.new()
        soldier.name="TacticalTest_"+str(i)
        actors.add_child(soldier)
        soldier.add_child(Node3D.new())
        soldiers.append(soldier)
    for frame in range(120):
        view._render_fallen_v69(1.0/60.0)
    if not view.fallen_actors_v93.is_empty() or actors.get_child_count()!=216:
        fail("216 living actors incurred corpse work or changed during idle")
        return

    var first: Node3D=soldiers[0]
    var revived: Node3D=soldiers[1]
    view._start_fallen_v69(first)
    view._start_fallen_v69(revived)
    view._start_fallen_v69(first)
    if view.fallen_actors_v93.size()!=2:
        fail("duplicate deaths created duplicate expiry entries")
        return
    view._render_fallen_v69(0.5)
    if not first.has_meta("fallen_since_v69") or \
            absf(float(first.get_meta("fallen_since_v69"))-0.5)>0.0001:
        fail("death rendering did not advance an active corpse")
        return
    if actors.get_child_count()!=216:
        fail("corpse was removed before original 1.8s lifetime")
        return

    # Reusing an old battle ID restores this actual actor, never kills it.
    revived.remove_meta("fallen_since_v69")
    view._render_fallen_v69(0.1)
    if view.fallen_actors_v93.size()!=1 or \
            not is_instance_valid(revived):
        fail("revived actor was not unregistered safely")
        return
    view._start_fallen_v69(revived)
    if view.fallen_actors_v93.size()!=2:
        fail("second legitimate death was not registered")
        return

    # A separate scene cleanup may free an actor between render frames.
    revived.free()
    view._render_fallen_v69(0.1)
    if view.fallen_actors_v93.size()!=1 or actors.get_child_count()!=215:
        fail("freed old corpse left a stale active reference")
        return
    view._render_fallen_v69(1.2)
    if view.fallen_actors_v93.size()!=0 or \
            actors.get_child_count()!=214 or is_instance_valid(first):
        fail("expired corpse was not removed after exactly its visual lifetime")
        return

    # New scene objects must not inherit expired registrations.
    var new_actor:=Node3D.new()
    actors.add_child(new_actor)
    new_actor.add_child(Node3D.new())
    view._start_fallen_v69(new_actor)
    var detached:=Node3D.new()
    view.add_child(detached)
    actors.remove_child(new_actor)
    detached.add_child(new_actor)
    view._render_fallen_v69(0.2)
    if view.fallen_actors_v93.size()!=0 or not is_instance_valid(new_actor):
        fail("removed/moved actor was not detached from corpse registry")
        return
    print("BATTLE_FALLEN_SET_V93 SUCCESS: 216 living, exact deaths, revival, free, expiry and scene transfer")
    quit(0)
