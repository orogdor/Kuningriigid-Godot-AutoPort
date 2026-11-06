extends SceneTree
## V80: renderer and UI regression, fog cache, exploration/save migration.
const Game=preload("res://content.tscn")
const Fog=preload("res://scripts/scout_fog_v80.gd")
const Scout=preload("res://scripts/world_scout_v52.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")

func fail(message: String) -> void:
    printerr("SCOUT_FOG_V80 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(800,540)
    var ui: Control=Game.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    # The release job runs legacy mesh/LOD tests in separate Godot processes.
    # Their user:// fog preference may persist, so never assume the default.
    ui.world_view.fog_enabled_v80=true
    ui.world_view._apply_fog_v80()
    ui.world_view.set_scout(Scout.ensure(ui.city,ui.world_view.world))
    var map=ui.world_view
    var world: Dictionary=map.world
    var scout: Dictionary=Scout.ensure(ui.city,world)
    var far:=Vector2i((int(scout["c"])+World.COLS/2)%World.COLS,
        (int(scout["r"])+World.ROWS/2)%World.ROWS)
    var first: PackedByteArray=Fog.visibility(scout,world)
    if first.size()!=World.COLS*World.ROWS or \
            first[int(scout["r"])*World.COLS+int(scout["c"])]!=2 or \
            first[far.y*World.COLS+far.x]!=0:
        fail("new game must reveal home and hide remote territory")
        return
    var canvas=map.map_canvas
    var terrain=map.terrain_3d
    if canvas.fog_texture_v80==null or terrain.fog_texture_v80==null or \
            terrain.terrain_node.mesh==null:
        fail("2D and 3D fog textures are missing")
        return
    var material: StandardMaterial3D=terrain.terrain_node.material_override
    var surface: Array=terrain.terrain_node.mesh.surface_get_arrays(0)
    if material.albedo_texture!=terrain.fog_texture_v80 or \
            (surface[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size()!=World.COLS*World.ROWS*6:
        fail("3D terrain is not sampling a per-cell GPU fog texture")
        return
    # Headless Godot uses a dummy GPU texture server; validate image pixels
    # from the source Image instead of reading back a nonexistent framebuffer.
    var before_image: Image=Fog.atlas_image(scout,world)
    if before_image.get_pixel(far.x,far.y).a<0.7 or \
            before_image.get_pixel(int(scout["c"]),int(scout["r"])).a>0.02:
        fail("initial fog pixels do not distinguish hidden and visible cells")
        return
    var old_texture_id: int=terrain.fog_texture_v80.get_instance_id()
    var old_signature: String=terrain.fog_key_v80
    ui._advance(8)
    var moved: Dictionary=Scout.ensure(ui.city,world)
    var after: PackedByteArray=Fog.visibility(moved,world)
    if int(moved.get("visited_count_v79",0))<=1:
        # Auto mode starts disabled, so issue an actual deterministic step.
        var options: Array=[]
        for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
            var dest: Vector2i=Vector2i(int(moved["c"]),int(moved["r"]))+delta
            if dest.x>=0 and dest.x<World.COLS and dest.y>=0 and dest.y<World.ROWS and \
                    Routes.passable(world,dest.x,dest.y):
                options.append(dest)
        if options.is_empty():
            fail("no adjacent terrain to test fog reveal")
            return
        Scout.order(ui.city,world,options[0])
        Scout.tick(ui.city,world,300.0)
        ui._sync_trade_map()
        moved=Scout.ensure(ui.city,world)
        after=Fog.visibility(moved,world)
    if Fog.signature(moved,world)+str(true)==old_signature or \
            terrain.fog_key_v80!=Fog.signature(moved,world)+str(true):
        fail("fog was not refreshed when the explorer discovered new tiles")
        return
    if terrain.fog_texture_v80.get_instance_id()!=old_texture_id:
        fail("3D fog texture was recreated instead of updated in place")
        return
    if after[int(moved["r"])*World.COLS+int(moved["c"])]!=2:
        fail("new scout position was not revealed")
        return
    var toggle: Button=map.find_child("ScoutFogV80",true,false) as Button
    if toggle==null or not map.fog_enabled_v80:
        fail("fog toggle not present in the real map UI")
        return
    toggle.pressed.emit()
    if map.fog_enabled_v80 or canvas.fog_texture_v80!=null or \
            terrain.fog_key_v80!="clear"+str(false) or \
            Fog.terrain_image({},world).get_pixel(far.x,far.y).r<0.99:
        fail("fog-off must reveal the whole 2D and 3D atlas")
        return
    toggle.pressed.emit()
    if not map.fog_enabled_v80 or canvas.fog_texture_v80==null or \
            terrain.fog_key_v80!=Fog.signature(moved,world)+str(true) or \
            Fog.terrain_image(moved,world).get_pixel(far.x,far.y).r>0.4:
        fail("fog-on must restore unexplored territory")
        return
    var legacy: Dictionary=ui.city.duplicate(true)
    legacy["world_scout_v52"]={"seed":int(world["seed"]),"kind":"scout",
        "c":int(world["starts"][0]["c"]),"r":int(world["starts"][0]["r"]),
        "path":[],"travelClock":0.0,"travelDuration":0.0}
    var migrated: Dictionary=Scout.ensure(legacy,world)
    if Fog.visibility(migrated,world).size()!=World.COLS*World.ROWS or \
            int(migrated.get("visited_count_v79",0))!=1:
        fail("legacy save failed fog migration")
        return
    print("SCOUT_FOG_V80 SUCCESS: 2D/3D texture, live reveal, cache, toggle, legacy save")
    quit(0)
