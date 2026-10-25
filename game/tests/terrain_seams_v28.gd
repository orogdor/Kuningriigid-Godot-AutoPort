extends SceneTree
## 0.28: exact matching terrain edges, coherent river centerlines, retained
## district mesh resources and moving actors in a 0.27 multi-tile game.
const Screen=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Continuous=preload("res://scripts/continuous_city_v27.gd")
const Terrain28=preload("res://scripts/continuous_terrain_v28.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")

func fail(why: String) -> void:
    printerr("TERRAIN_SEAMS_V28 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var ui: Control=Screen.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var adjacent: Vector2i=Vector2i(-1,-1)
    for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
        var tile: Vector2i=home+delta
        var cell: Dictionary=World.cell(world,tile.x,tile.y)
        if not cell.is_empty() and bool(cell.get("land",false)) and String(cell.get("biome",""))!="hills":
            adjacent=tile
            break
    if adjacent.x<0:
        fail("generated world has no adjacent land for continuous city")
        return
    var different: Vector2i=adjacent-home
    var samples: int=0
    # Adjacent 160m terrain planes share the EXACT same global edge point,
    # even if each tile uses a different biome or river flag.
    for step in range(-8,9):
        var along: float=float(step)*10.0
        var a: Vector2=Vector2(80.0*float(different.x),80.0*float(different.y))
        var b: Vector2=-a
        if different.x!=0:
            a.y=along
            b.y=along
        else:
            a.x=along
            b.x=along
        var first: float=Terrain28.height(world,home,a.x,a.y)
        var second: float=Terrain28.height(world,adjacent,b.x,b.y)
        if not is_equal_approx(first,second):
            fail("terrain edge height mismatched at "+str(along)+" m")
            return
        samples+=1
    var terrain: MeshInstance3D=Terrain28.surface(world,home,"SeamTest")
    if terrain.mesh.get_surface_count()!=1:
        fail("terrain was not compiled into a single 3D surface")
        return
    var expected_vertices: int=Terrain28.RESOLUTION*Terrain28.RESOLUTION*6
    var arrays: Array=terrain.mesh.surface_get_arrays(0)
    if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()!=expected_vertices:
        fail("surface resolution unexpectedly inflated by the city size")
        return
    # Build a synthetic paired river from two existing passable map cells.
    # Both halves must reach the same centerline at the exact common edge.
    var river_world: Dictionary=world.duplicate(true)
    for p in [home,adjacent]:
        var index: int=p.y*World.COLS+p.x
        river_world["cells"][index]["river"]=true
    var end_a: Vector2=Vector2(80.0*float(different.x),80.0*float(different.y))
    var end_b: Vector2=-end_a
    if different.x!=0:
        end_a.y=25.0
        end_b.y=25.0
    else:
        end_a.x=0.0
        end_b.x=0.0
    var found_a: bool=false
    var found_b: bool=false
    for segment in Terrain28.segments(river_world,home):
        if (segment["end"] as Vector2).is_equal_approx(end_a):found_a=true
    for segment in Terrain28.segments(river_world,adjacent):
        if (segment["end"] as Vector2).is_equal_approx(end_b):found_b=true
    if not found_a or not found_b:
        fail("two river districts do not align across their shared border")
        return
    if Terrain28.water(river_world,home).is_empty() or Terrain28.water(river_world,adjacent).is_empty():
        fail("river links have no 3D water geometry")
        return
    if not is_equal_approx(
        Terrain28.height(river_world,home,end_a.x,end_a.y),
        Terrain28.height(river_world,adjacent,end_b.x,end_b.y)):
        fail("riverbed height is not continuous at the joint")
        return
    # The complete 3D scene keeps the same MeshInstance3D over repeated
    # turns, and keeps the same building instance if its state did not change.
    var city: Dictionary=ui.city
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=500.0
    stock["stone"]=500.0
    city["realms"][0]["pop"]=18
    if Districts.expand(city,world,adjacent.x,adjacent.y)!="":
        fail("could not annex adjacent tile")
        return
    Transit.configure(city,world)
    ui._show_detail(home.x,home.y)
    await process_frame
    var view: Control=ui.detail_view
    if not view.combined_city:
        fail("multi-tile terrain did not activate")
        return
    var capital_ground: MeshInstance3D=view.scene_root.get_node_or_null("DetailTerrain") as MeshInstance3D
    var passive: Node3D=view.combined_root.get_node_or_null("DistrictTile_"+Districts.key(adjacent).replace(":","_")) as Node3D
    if passive==null or capital_ground==null:
        fail("one of the two adjoining 3D terrain sections is absent")
        return
    var adjacent_ground: MeshInstance3D=passive.get_node_or_null("DistrictTerrain") as MeshInstance3D
    if adjacent_ground==null or not adjacent_ground.mesh is ArrayMesh:
        fail("neighbor is still a flat box instead of an efficient height-mesh")
        return
    var generated: int=view.terrain_mesh_builds
    if generated<2:
        fail("combined city did not initially generate two separate terrains")
        return
    view.refresh_buildings()
    view.refresh_buildings()
    if view.terrain_mesh_builds!=generated or not is_instance_valid(adjacent_ground):
        fail("consecutive economy refreshes rebuilt permanent terrain")
        return
    var a_id: String=Transit.home_key(city)
    var agent: Dictionary={"id":123456,"district":a_id,"role":"wagon",
        "x":10.0,"z":20.0,"load":3.0}
    city["transport_v26"]["agents"].append(agent)
    view._activate_district(adjacent)
    await process_frame
    var capital: Node3D=view.combined_root.get_node("DistrictTile_Capital") as Node3D
    var moving: Node3D=capital.get_node_or_null("DistrictAgent_123456") as Node3D
    if moving==null:
        fail("physical wagon is not present on passive district")
        return
    var old_ground: MeshInstance3D=passive.get_node("DistrictTerrain") as MeshInstance3D
    agent["x"]=30.0
    agent["z"]=-10.0
    view.refresh_buildings()
    var updated: Node3D=capital.get_node_or_null("DistrictAgent_123456") as Node3D
    if updated!=moving or not updated.position.is_equal_approx(Vector3(30,0,-10)):
        fail("moving wagon was re-instantiated instead of updating in place")
        return
    if passive.get_node_or_null("DistrictTerrain")!=old_ground:
        fail("focusing a new district regenerated the static adjacent terrain")
        return
    ui._save()
    if not Districts.owns(ui._load_city(),world,adjacent.x,adjacent.y):
        fail("v28 rendering changed saved district ownership")
        return
    print("TERRAIN_SEAMS_V28 SUCCESS: %d identical height samples, matching river gates, one-mesh terrain, cached districts and actors, legacy save" % samples)
    quit(0)
