extends SceneTree
## AutoPort 0.25: real neighboring world-tile annexes with pooled economy,
## independent local building coordinates, world-map link lines and saved
## legacy city compatibility. Cross-tile 3D hauling is not simulated here.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Screen=preload("res://content.tscn")

func fail(reason: String) -> void:
    printerr("WORLD_DISTRICTS_V25 FAIL: "+reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func neighbor(world: Dictionary, origin: Vector2i) -> Vector2i:
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var p: Vector2i=origin+delta
        var tile: Dictionary=World.cell(world,p.x,p.y)
        if not tile.is_empty() and bool(tile.get("land",false)) and String(tile.get("biome",""))!="hills":
            return p
    return Vector2i(-1,-1)

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    if ui.world_view.world.is_empty():ui.world_view._generate()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var p: Vector2i=neighbor(world,home)
    if home.x<0 or p.x<0:
        fail("generated world did not provide a valid adjacent land tile")
        return
    if Districts.cells(ui.city,world).size()!=1 or not Districts.owns(ui.city,world,home.x,home.y):
        fail("old city without districts no longer owns its original capital")
        return
    var resources: Dictionary=ui.city["realms"][0]["resources"]
    resources["wood"]=200.0
    resources["stone"]=200.0
    if Districts.reason(ui.city,world,p.x,p.y)=="":
        fail("a three-population city annexed territory prematurely")
        return
    ui.city["realms"][0]["pop"]=18
    var wood: float=float(resources["wood"])
    var stone: float=float(resources["stone"])
    ui._expand_district(p.x,p.y)
    if not Districts.owns(ui.city,world,p.x,p.y):
        fail("a legal adjacent land tile was not annexed")
        return
    if Districts.cells(ui.city,world).size()!=2 or Districts.connections(ui.city,world).size()!=1:
        fail("district territory or adjacent street links were not stored")
        return
    if not is_equal_approx(float(resources["wood"]),wood-20.0) or not is_equal_approx(float(resources["stone"]),stone-10.0):
        fail("district paid an incorrect resource cost")
        return
    var after_wood: float=float(resources["wood"])
    if Districts.expand(ui.city,world,p.x,p.y)=="" or float(resources["wood"])!=after_wood:
        fail("duplicate annexation created another charge")
        return
    if Districts.expand(ui.city,world,p.x+2,p.y+2)=="":
        fail("noncontiguous district was annexed")
        return
    var saved: Dictionary=ui._load_city()
    if not Districts.owns(saved,world,p.x,p.y):
        fail("annexed tile did not survive JSON save")
        return
    if ui.world_view.map_canvas.city_district_tiles.size()!=2 or ui.world_view.map_canvas.city_district_links.size()!=1:
        fail("world-map ownership and street overlays were not refreshed")
        return
    # Reuse the same local x/z on two different world squares. It is not
    # a collision because the structures are rendered on separate tiles.
    ui._show_detail(home.x,home.y)
    if not ui.detail_view.can_build or ui.detail_view.district_id!="":
        fail("old capital detail was no longer editable")
        return
    ui._build_at("house",30.0,-10.0)
    await process_frame
    if ui.city["buildings"].size()!=2:
        fail("capital building failed before annex test")
        return
    ui._show_detail(p.x,p.y)
    await process_frame
    var district: String=Districts.key(p)
    if not ui.detail_view.can_build or ui.detail_view.district_id!=district:
        fail("owned neighbor was not a separate 3D construction district")
        return
    if ui.detail_view.rendered_buildings!=0 or ui.detail_view.construction_root.get_node_or_null("hall_0")!=null:
        fail("capital buildings appeared inside an annex")
        return
    if not Spatial.can_place(ui.city,Vector2(30,-10),district):
        fail("the same local position remained blocked by capital's house")
        return
    var count: int=ui.city["buildings"].size()
    var start_wood: float=float(resources["wood"])
    ui._build_at("house",30.0,-10.0,90)
    await process_frame
    if ui.city["buildings"].size()!=count+1:
        fail("3D annex building did not create a real economic house")
        return
    var annex: Dictionary=ui.city["buildings"][count]
    if String(annex.get("district",""))!=district or int(annex.get("rotation",-1))!=90:
        fail("new building lost its world tile or rotation")
        return
    if float(resources["wood"])>=start_wood:
        fail("annex did not pay the normal house cost")
        return
    if ui.detail_view.rendered_buildings!=1 or ui.detail_view.construction_root.get_node_or_null("house_"+str(count))==null:
        fail("3D annex did not show its own structure")
        return
    ui._show_detail(home.x,home.y)
    await process_frame
    if ui.detail_view.rendered_buildings!=2 or ui.detail_view.construction_root.get_node_or_null("house_"+str(count))!=null:
        fail("returning to capital duplicated the annex building")
        return
    var reopened: Dictionary=ui._load_city()
    if String(reopened["buildings"][count].get("district",""))!=district:
        fail("building's district was missing after reload")
        return
    var other: Vector2i=p+Vector2i(2,2)
    if not World.cell(world,other.x,other.y).is_empty():
        ui._show_detail(other.x,other.y)
        await process_frame
        if ui.detail_view.can_build:
            fail("unowned world tile accidentally enabled construction")
            return
    print("WORLD_DISTRICTS_V25 SUCCESS: adjacency, cost, save, overlays, independent local plots, 3D render and shared resources")
    quit(0)
