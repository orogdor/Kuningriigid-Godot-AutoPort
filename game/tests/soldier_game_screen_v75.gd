extends SceneTree
## V75: real gameplay UI, not an isolated glTF in a studio viewport.
## Compare with and without actors at the shipped camera/viewport size.
const Scene=preload("res://content.tscn")

func _initialize() -> void:
    call_deferred("_run")

func fail(reason: String) -> void:
    printerr("SOLDIER_GAME_SCREEN_V75 FAIL: "+reason)
    quit(1)

func snap(viewport: Viewport) -> Image:
    for _i in range(6):await process_frame
    await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()

func pixel_delta(one: Image,two: Image) -> int:
    if one.is_empty() or two.is_empty() or one.get_size()!=two.get_size():return -1
    var count: int=0
    for y in range(one.get_height()):
        for x in range(one.get_width()):
            var a: Color=one.get_pixel(x,y)
            var b: Color=two.get_pixel(x,y)
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.07:
                count+=1
    return count

func _save(image: Image,name: String) -> void:
    if image.is_empty():return
    var dir: String=ProjectSettings.globalize_path("res://test-output")
    DirAccess.make_dir_recursive_absolute(dir)
    image.save_png(dir.path_join("soldier-"+name+".png"))

func _run() -> void:
    root.size=Vector2i(1280,800)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    ui._start_demo_battle()
    var battle: Control=ui.battle_view
    battle.auto_timer.stop()
    if battle.actors_root.get_child_count()!=96:
        fail("Real demo battle does not contain 96 models")
        return
    var full: Image=await snap(root)
    _save(full,"actual-battle-ui")
    battle.actors_root.hide()
    var empty: Image=await snap(battle.viewport)
    battle.actors_root.show()
    var army: Image=await snap(battle.viewport)
    _save(army,"actual-battle-viewport")
    var difference: int=pixel_delta(empty,army)
    print("SOLDIER_GAME_SCREEN_V75 battle pixels=",difference,
        " viewport=",battle.viewport.size," window=",root.size,
        " camera_size=",battle.battle_camera.size,
        " actor_count=",battle.actors_root.get_child_count())
    if army.is_empty() or difference<700:
        fail("Actual battle has too few visible soldier pixels: "+str(difference))
        return

    ui._show_world()
    var atlas=ui.world_view.terrain_3d
    var starts: Array=atlas.world.get("starts",[])
    if starts.is_empty():
        fail("World has no valid starting tile")
        return
    var origin: Dictionary=starts[0]
    var cc: int=int(origin["c"])
    var rr: int=int(origin["r"])
    var soldier: Dictionary={"id":75001,"kind":"axeman","c":cc,"r":rr,"path":[]}
    atlas.set_armies_v54([soldier])
    atlas.camera_target=Vector2(cc,rr)
    atlas.zoom=235.0
    atlas._update_camera()
    var world_full: Image=await snap(root)
    _save(world_full,"actual-world-ui")
    atlas.army_root_v54.hide()
    var world_empty: Image=await snap(atlas.viewport)
    atlas.army_root_v54.show()
    var world_units: Image=await snap(atlas.viewport)
    _save(world_units,"actual-world-viewport")
    var map_pixels: int=pixel_delta(world_empty,world_units)
    print("SOLDIER_GAME_SCREEN_V75 world pixels=",map_pixels,
        " viewport=",atlas.viewport.size," camera_size=",atlas.camera.size,
        " actors=",atlas.army_root_v54.get_child_count())

    ui._show_detail(cc,rr)
    var detail=ui.detail_view
    detail.set_world_armies_v54([soldier])
    var detail_full: Image=await snap(root)
    _save(detail_full,"actual-detail-ui")
    detail.army_detail_root_v54.hide()
    var detail_empty: Image=await snap(detail.view_port)
    detail.army_detail_root_v54.show()
    var detail_units: Image=await snap(detail.view_port)
    _save(detail_units,"actual-detail-viewport")
    var detail_pixels: int=pixel_delta(detail_empty,detail_units)
    print("SOLDIER_GAME_SCREEN_V75 detail pixels=",detail_pixels,
        " viewport=",detail.view_port.size,
        " actors=",detail.army_detail_root_v54.get_child_count())
    if map_pixels<100 or detail_pixels<80:
        fail("An army disappears on a real atlas/detail map: world="+str(map_pixels)+" detail="+str(detail_pixels))
        return
    print("SOLDIER_GAME_SCREEN_V75 SUCCESS: real scene images and soldier pixel deltas captured")
    quit(0)
