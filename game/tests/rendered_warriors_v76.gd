extends SceneTree
## Actual OpenGL offscreen pixel regression for GLB warriors (NOT --headless).
## Previous tests counted imported MeshInstance3D nodes even when zero pixels
## of the soldier were ever drawn. Must run under xvfb-run and real OpenGL.
const Units=preload("res://scripts/web_units_v53.gd")
const W: int=512
const H: int=512

func fail(reason: String) -> void:
    printerr("RENDERED_WARRIORS_V76 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _grab(view: SubViewport) -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func _difference(a: Image,b: Image) -> int:
    if a==null or b==null or a.get_width()!=W or b.get_width()!=W:
        return -1
    var count: int=0
    for y in range(24,H-24,4):
        for x in range(24,W-24,4):
            var first: Color=a.get_pixel(x,y)
            var second: Color=b.get_pixel(x,y)
            if first.distance_to(second)>0.12:
                count+=1
    return count

func _run() -> void:
    root.size=Vector2i(640,640)
    var vp:=SubViewport.new()
    vp.size=Vector2i(W,H)
    vp.own_world_3d=true
    vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var scene:=Node3D.new()
    vp.add_child(scene)
    var env_node:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color(0.08,0.16,0.23)
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color.WHITE
    env.ambient_light_energy=1.0
    env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    env_node.environment=env
    scene.add_child(env_node)
    var light:=DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-35,-35,0)
    light.light_energy=1.8
    scene.add_child(light)
    var camera:=Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=8.0
    camera.position=Vector3(0,2.6,12)
    camera.far=300
    camera.current=true
    scene.add_child(camera)
    camera.look_at(Vector3(0,2.6,0),Vector3.UP)
    var baseline: Image=await _grab(vp)
    var screenshot_dir: String=OS.get_environment("GITHUB_WORKSPACE")
    if screenshot_dir!="":
        screenshot_dir+="/warrior-visuals-v76"
        DirAccess.make_dir_recursive_absolute(screenshot_dir)
    for kind in ["axeman","spearman","slinger"]:
        for rigged in [false,true]:
            var actor: Node3D=Units.instance(kind,5.2,false,rigged)
            if actor==null:
                fail("no actor scene for "+kind)
                return
            if rigged and not actor.has_meta("rigged_trellis_v73"):
                fail("new TRELLIS not selected for "+kind)
                return
            scene.add_child(actor)
            var current: Image=await _grab(vp)
            var changed: int=_difference(baseline,current)
            if screenshot_dir!="":
                var suffix: String="rigged" if rigged else "legacy"
                current.save_png(screenshot_dir+"/"+kind+"_"+suffix+".png")
            if changed<90:
                fail("%s rigged=%s: %d changed pixel samples versus blank viewport; model exists but is invisible" % [kind,str(rigged),changed])
                return
            var mesh_count: int=actor.find_children("*","MeshInstance3D",true,false).size()
            print("RENDERED_WARRIORS_V76",kind," rigged=",rigged,
                " changed_samples=",changed," mesh_count=",mesh_count)
            scene.remove_child(actor)
            actor.free()
    print("RENDERED_WARRIORS_V76 SUCCESS: six actual GLB renders have visible non-background pixels")
    quit(0)
