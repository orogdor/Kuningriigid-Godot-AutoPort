extends SceneTree
## V75: an actual pixel-readback test. Previous tests only verified
## Node3D/Skeleton3D/AnimationPlayer and did not detect invisible meshes.
const Units=preload("res://scripts/web_units_v53.gd")
var scene: Node3D
var viewport: SubViewport
var camera: Camera3D

func fail(message: String) -> void:
    printerr("SOLDIER_PIXELS_V75 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _snap() -> Image:
    for _i in range(4):
        await process_frame
    await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()

func _difference(left: Image,right: Image) -> int:
    if left.is_empty() or right.is_empty():return -1
    if left.get_size()!=right.get_size():return -1
    var pixels: int=0
    for y in range(left.get_height()):
        for x in range(left.get_width()):
            var a: Color=left.get_pixel(x,y)
            var b: Color=right.get_pixel(x,y)
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.08:
                pixels+=1
    return pixels

func _run() -> void:
    root.size=Vector2i(400,400)
    viewport=SubViewport.new()
    viewport.name="ActualRenderVisibilityV75"
    viewport.size=Vector2i(320,320)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    viewport.own_world_3d=true
    root.add_child(viewport)
    scene=Node3D.new()
    viewport.add_child(scene)
    var env:=WorldEnvironment.new()
    var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color(0.11,0.19,0.27)
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color.WHITE
    environment.ambient_light_energy=1.0
    env.environment=environment
    scene.add_child(env)
    var light:=DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-45,-35,0)
    light.light_energy=1.5
    scene.add_child(light)
    camera=Camera3D.new()
    camera.position=Vector3(0.0,3.0,10.5)
    scene.add_child(camera)
    camera.look_at(Vector3(0.0,2.6,0.0),Vector3.UP)
    camera.current=true
    camera.near=0.05
    camera.far=100.0

    var empty: Image=await _snap()
    if empty.is_empty():
        fail("No GPU rendering available; use xvfb-run instead of --headless")
        return
    var directory: String="res://test-output"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    var sanity:=MeshInstance3D.new()
    var box:=BoxMesh.new()
    box.size=Vector3(1.8,5.2,1.3)
    sanity.mesh=box
    sanity.position.y=2.6
    scene.add_child(sanity)
    var check: Image=await _snap()
    var sanity_pixels: int=_difference(empty,check)
    check.save_png(directory+"/soldier-reference.png")
    sanity.queue_free()
    await process_frame
    print("SOLDIER_PIXELS_V75 sanity pixels: ",sanity_pixels)
    if sanity_pixels<1000:
        fail("Control box is invisible; renderer/environment cannot be trusted")
        return

    var missing: Array=[]
    for kind in ["axeman","spearman","slinger"]:
        for version in ["legacy","trellis_raw","trellis_rig"]:
            var model: Node3D=Units.instance(kind,5.2,
                version=="trellis_raw",version=="trellis_rig")
            if model==null:
                fail("Cannot instantiate "+version+" "+kind)
                return
            scene.add_child(model)
            var bounds: Dictionary=Units.bounds_of(model)
            var shot: Image=await _snap()
            var diff: int=_difference(empty,shot)
            shot.save_png(directory+"/soldier-"+kind+"-"+version+".png")
            print("SOLDIER_PIXELS_V75 ",kind," ",version,
                " drawn=",diff," geometry=",bounds.get("meshes",0),
                " source=",model.get_meta("source_glb",""))
            if diff<400:missing.append(kind+"/"+version+"="+str(diff))
            model.queue_free()
            await process_frame
            await process_frame
    if not missing.is_empty():
        fail("Invisible 3D soldier geometry: "+", ".join(missing))
        return
    print("SOLDIER_PIXELS_V75 SUCCESS: all three soldiers render real pixels with legacy, raw and rigged glTF")
    quit(0)
