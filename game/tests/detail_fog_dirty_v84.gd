extends SceneTree
## V84: scout moves outside a detail view must not rebuild static terrain.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")
const Fog=preload("res://scripts/scout_fog_v80.gd")

func fail(reason: String) -> void:
    printerr("DETAIL_FOG_DIRTY_V84 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(800,560)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    var world: Dictionary=ui.world_view.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var far:=Vector2i((int(scout["c"])+int(World.COLS/2))%World.COLS,
        (int(scout["r"])+int(World.ROWS/2))%World.ROWS)
    if Fog.visible_at(scout,world,far.x,far.y):
        fail("chosen detail tile is already visible")
        return
    ui._show_detail(far.x,far.y)
    var detail=ui.detail_view
    if detail.seam_preview_root.get_child_count()<1 or \
            detail.fog_root_v81.get_child_count()!=1:
        fail("unexplored detail/neighbor fixtures were not created")
        return
    var preview_id: int=detail.seam_preview_root.get_child(0).get_instance_id()
    var cover_id: int=detail.fog_root_v81.get_child(0).get_instance_id()
    var shifted: Dictionary=scout.duplicate(true)
    shifted["c"]=clampi(int(scout["c"])+1,0,World.COLS-1)
    shifted["r"]=clampi(int(scout["r"])+1,0,World.ROWS-1)
    if shifted["c"]==scout["c"] and shifted["r"]==scout["r"]:
        shifted["c"]=maxi(0,int(scout["c"])-1)
    detail.set_visibility_v81(shifted,true)
    if detail.seam_preview_root.get_child(0).get_instance_id()!=preview_id or \
            detail.fog_root_v81.get_child(0).get_instance_id()!=cover_id:
        fail("unrelated scout movement rebuilt static neighboring terrain or fog mesh")
        return
    shifted["c"]=far.x
    shifted["r"]=far.y
    detail.set_visibility_v81(shifted,true)
    if detail.fog_root_v81.get_child_count()!=0 or \
            detail.seam_preview_root.get_child(0).get_instance_id()==preview_id or \
            detail.fog_last_state_v81!=2:
        fail("reaching tile did not rebuild newly revealed terrain")
        return
    var revealed_id: int=detail.seam_preview_root.get_child(0).get_instance_id()
    detail.set_visibility_v81(scout,true)
    if detail.fog_root_v81.get_child_count()!=1 or \
            detail.seam_preview_root.get_child(0).get_instance_id()==revealed_id or \
            detail.fog_last_state_v81!=0:
        fail("leaving tile did not restore fog concealment")
        return
    print("DETAIL_FOG_DIRTY_V84 SUCCESS: stable geometry for unrelated movement, local reveal and re-hide")
    quit(0)
