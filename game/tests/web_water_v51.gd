extends SceneTree
## Godot 0.51: use real river_to data (no fake tile painted rivers);
## exactly matching river widths/elevations on neighboring 3D detail tiles.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Rivers=preload("res://scripts/web_water_v51.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")

func fail(reason: String) -> void:
    printerr("WEB_WATER_V51 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    var world: Dictionary=ui.world_view.world
    var atlas=ui.world_view.terrain_3d
    if atlas.river_root==null:
        fail("world map lost its river render root")
        return
    var ribbon: Node3D=atlas.river_root.get_node_or_null("WebWorldRiverNetwork51") as Node3D
    if ribbon==null:
        fail("real continuous river atlas geometry missing")
        return
    var expected: int=0
    var river_tile:=Vector2i(-1,-1)
    var next_tile:=Vector2i(-1,-1)
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var to: Vector2i=Rivers.downstream(world,c,r)
            if to.x<0:continue
            expected+=1
            if river_tile.x<0 and \
                    not bool(World.cell(world,c,r).get("mountain",false)):
                river_tile=Vector2i(c,r)
                next_tile=to
    if expected<1 or int(ribbon.get_meta("river_segments",-1))!=expected:
        fail("river geometry doesn't match true saved downstream segments")
        return
    var rivers: MeshInstance3D=ribbon.get_node_or_null("WebRiverWater51") as MeshInstance3D
    var banks: MeshInstance3D=ribbon.get_node_or_null("WebRiverBanks51") as MeshInstance3D
    if rivers==null or banks==null or rivers.mesh==null or banks.mesh==null:
        fail("world atlas doesn't have both batched water and shore geometry")
        return
    var water_mesh: ArrayMesh=rivers.mesh as ArrayMesh
    var bank_mesh: ArrayMesh=banks.mesh as ArrayMesh
    if water_mesh==null or bank_mesh==null:
        fail("river surfaces are not real Godot ArrayMesh geometries")
        return
    if water_mesh.surface_get_array_len(0)!=expected*6:
        fail("world river water doesn't match saved drainage segments")
        return
    if bank_mesh.surface_get_array_len(0)!=expected*12:
        fail("world river bank geometry isn't aligned with water segments")
        return
    var before_buildings: int=ui.city["buildings"].size()
    var before_stock: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    var w: float=225.0
    var d: float=195.0
    var delta: Vector2i=next_tile-river_tile
    var x: float=float(delta.x)*w*0.5
    var z: float=float(delta.y)*d*0.5
    var a: float=Rivers.border_height(world,river_tile,x,z)
    var b: float=Rivers.border_height(world,next_tile,-x,-z)
    if absf(a-b)>0.0001:
        fail("actual 3D water channel has a height discontinuity at map border")
        return
    var first: Node3D=Rivers.detail(world,river_tile)
    var second: Node3D=Rivers.detail(world,next_tile)
    if int(first.get_meta("river_segments",0))<1 or \
            int(second.get_meta("river_segments",0))<1:
        fail("incoming river doesn't continue across the second tile")
        return
    if first.get_node_or_null("WebRiverWater51")==null or \
            second.get_node_or_null("WebRiverBanks51")==null:
        fail("river or shoreline was dropped at shared detail edge")
        return
    var at_home: Vector2i=Districts.origin(world)
    ui._show_detail(river_tile.x,river_tile.y)
    await process_frame
    if ui.detail_view.can_build and river_tile!=at_home:
        fail("render-only river accidentally granted ownership rights")
        return
    if ui.detail_view.scene_root.get_node_or_null("WebDetailRiverNetwork51")==null:
        fail("active wilderness detail doesn't show the original river")
        return
    if ui.city["buildings"].size()!=before_buildings or \
            ui.city["realms"][0]["resources"]!=before_stock:
        fail("water rendering altered city buildings or resource inventory")
        return
    if ui.detail_view.controller.size.y<180.0:
        fail("river geometry broke 720x420 mobile detail viewport")
        return
    print("WEB_WATER_V51 SUCCESS: true saved river_to network; shared 3D atlas ribbons/banks, continuous neighbor detail water, 720x420 viewport, unchanged economy")
    quit(0)
