extends SceneTree
## V99: no 120-soldier dropdown churn on repeated tactical snapshots.
## HP-only text updates retain the selected squad/soldier and popup state.
const View=preload("res://scripts/battle_view_v55.gd")

func fail(reason: String) -> void:
    printerr("BATTLE_ROSTER_DELTA_V99 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view: Control=View.new()
    var squad_picker:=OptionButton.new()
    var individual_picker:=OptionButton.new()
    view.order_picker=squad_picker
    view.individual_picker=individual_picker
    view.add_child(squad_picker)
    view.add_child(individual_picker)
    var fighters: Array=[]
    for i in range(5):
        var men: Array=[]
        for j in range(24):
            men.append({"index":j,"hp":10.0,"escaped":false})
        fighters.append({"id":100+i,"team":0,"kind":"spearman",
            "hp":240.0,"men":men})
    fighters.append({"id":900,"team":1,"kind":"enemy","hp":240.0,
        "men":[{"index":0,"hp":10.0,"escaped":false}]})
    view.current_battle={"fighters":fighters}
    view._refresh_squad_picker_v99()
    view._refresh_individual_picker()
    if squad_picker.item_count!=5 or individual_picker.item_count!=24 or \
            view.squad_picker_rebuilds_v99!=1 or \
            view.individual_picker_rebuilds_v99!=1:
        fail("initial 5 squads and 24 individuals not populated")
        return

    # Select squad #101, soldier 8 and mark exact popup instances. Repeated
    # tick rendering must not clear those controls or alter selection.
    squad_picker.select(1)
    view._refresh_individual_picker()
    individual_picker.select(7)
    squad_picker.get_popup().set_item_metadata(1,"STABLE_SQUAD")
    individual_picker.get_popup().set_item_metadata(7,"STABLE_SOLDIER")
    var prior_squad_builds: int=view.squad_picker_rebuilds_v99
    var prior_man_builds: int=view.individual_picker_rebuilds_v99
    for step in range(180):
        view._refresh_squad_picker_v99()
        view._refresh_individual_picker()
    if view.squad_picker_rebuilds_v99!=prior_squad_builds or \
            view.individual_picker_rebuilds_v99!=prior_man_builds or \
            squad_picker.selected!=1 or individual_picker.selected!=7 or \
            squad_picker.get_popup().get_item_metadata(1)!="STABLE_SQUAD" or \
            individual_picker.get_popup().get_item_metadata(7)!="STABLE_SOLDIER":
        fail("unchanged snapshot rebuilt popup or lost selected soldier")
        return

    # HP change updates only the affected text; keep other selections,
    # metadata and actor identities exactly as before.
    var allied: Dictionary=fighters[1]
    allied["hp"]=195.0
    var target: Dictionary=allied["men"][7]
    target["hp"]=6.5
    view._refresh_squad_picker_v99()
    view._refresh_individual_picker()
    if not squad_picker.get_item_text(1).contains("195 HP") or \
            not individual_picker.get_item_text(7).contains("6.5 HP") or \
            view.squad_picker_rebuilds_v99!=prior_squad_builds or \
            view.individual_picker_rebuilds_v99!=prior_man_builds or \
            individual_picker.selected!=7 or \
            individual_picker.get_popup().get_item_metadata(7)!="STABLE_SOLDIER":
        fail("HP-only change destroyed the selected dropdown or failed to update text")
        return

    # A casualty must remove only the dead individual from the available
    # roster and preserve the selected index if that individual survived.
    var fallen: Dictionary=allied["men"][0]
    fallen["hp"]=0.0
    view._refresh_individual_picker()
    if individual_picker.item_count!=23 or \
            view.individual_picker_rebuilds_v99!=prior_man_builds+1 or \
            view.man_indices[individual_picker.selected]!=7:
        fail("casualty did not rebuild roster while preserving surviving selection")
        return
    # Switching squads changes the displayed individual roster but never
    # invents enemy choices and preserves a valid selected person.
    squad_picker.select(2)
    view._refresh_individual_picker()
    if individual_picker.item_count!=24 or \
            view.man_indices[individual_picker.selected]!=7:
        fail("new friendly squad not reflected in the individual picker")
        return
    # Escape removes a soldier, while stale enemy data stays excluded.
    var runaway: Dictionary=fighters[2]["men"][7]
    runaway["escaped"]=true
    view._refresh_individual_picker()
    if individual_picker.item_count!=23 or \
            view.man_indices.has(7) or squad_picker.item_count!=5:
        fail("escaped soldier or enemy leaked into friendly roster")
        return
    # Removing an entire squad retains another selected squad by ID, not
    # by its old UI position (the index changes after removing earlier row).
    fighters.remove_at(0)
    view._refresh_squad_picker_v99()
    view._refresh_individual_picker()
    if squad_picker.item_count!=4 or \
            view.id_list[squad_picker.selected]!=102 or \
            view.id_list.has(900):
        fail("squad removal changed selected identity or exposed enemy")
        return

    view.current_battle={"fighters":[]}
    view._refresh_squad_picker_v99()
    view._refresh_individual_picker()
    if squad_picker.item_count!=0 or individual_picker.item_count!=0 or \
            not view.id_list.is_empty() or not view.man_indices.is_empty():
        fail("ending the battle left stale selectable soldiers")
        return
    print("BATTLE_ROSTER_DELTA_V99 SUCCESS: 5 squads, 120 soldiers, 180 unchanged ticks, HP-only updates, casualties, escape, selection, full cleanup")
    quit(0)
