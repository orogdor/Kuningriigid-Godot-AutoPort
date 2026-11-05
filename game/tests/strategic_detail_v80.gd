extends SceneTree
## V80: actual world/detail 3D projection, with a genuine paid two-district
## town. Tests the 225x195 wilderness tile and the 160x160 shared city mesh.
const Scene=preload("res://content.tscn")
const Pose80=preload("res://scripts/strategic_detail_pose_v80.gd")
const Terrain28=preload("res://scripts/continuous_terrain_v28.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Transit=preload("res://scripts/district_transit_v26.gd")

func fail(why: String) -> void:
    printerr("STRATEGIC_DETAIL_V80 FAIL: "+why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _pose(home: Vector2i,neighbour: Vector2i,fraction: float) -> Dictionary:
    return {"c":float(home.x)+float(neighbour.x-home.x)*fraction,
        "r":float(home.y)+float(neighbour.y-home.y)*fraction}

func _walking(home: Vector2i,neighbour: Vector2i,fraction: float) -> Dictionary:
    return {"seed":82026,"c":home.x,"r":home.y,
        "travelClock":fraction*100.0,"travelDuration":100.0,
        "path":[{"c":neighbour.x,"r":neighbour.y}]}

func _check_vec(a: Vector3,b: Vector3,message: String) -> bool:
    if a.distance_to(b)>0.005:
        fail(message+" actual="+str(a)+" expected="+str(b))
        return false
    return true

func _run() -> void:
    root.size=Vector2i(900,540)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var neighbour:=Vector2i(-1,-1)
    for direction in [Vector2i(1,0),Vector2i(0,1),
            Vector2i(-1,0),Vector2i(0,-1)]:
        var candidate: Vector2i=home+direction
        var tile: Dictionary=World.cell(world,candidate.x,candidate.y)
        if not tile.is_empty() and bool(tile.get("land",false)) and \
                String(tile.get("biome",""))!="hills":
            neighbour=candidate
            break
    if neighbour.x<0:
        fail("no passable adjacent world tile")
        return
    ui._show_detail(home.x,home.y)
    var detail=ui.detail_view
    if detail.combined_city:
        fail("a new town unexpectedly starts in combined 160m mode")
        return
    var isolated: Dictionary=_pose(home,neighbour,0.25)
    var standalone: Vector2=Pose80.local(isolated,home,false)
    if absf(standalone.x-float(neighbour.x-home.x)*56.25)>0.001 or \
            absf(standalone.y-float(neighbour.y-home.y)*48.75)>0.001:
        fail("standalone map changed the original 225x195m scale")
        return
    var moving: Dictionary=_walking(home,neighbour,0.25)
    moving["seed"]=int(world["seed"])
    detail.set_world_scout_v53(moving)
    if not detail.world_scout_actor_v53.visible or \
            not _check_vec(detail.world_scout_actor_v53.position,
                Vector3(standalone.x,detail._elevation(
                    standalone.x,standalone.y,0.0,true),standalone.y),
                "standalone scout is not on the original detail terrain"):
        return
    moving["travelClock"]=75.0
    detail.set_world_scout_v53(moving)
    if detail.world_scout_actor_v53.visible:
        fail("standalone map draws scout in adjacent tile")
        return
    # Open the same capital after paying for a real adjacent city district.
    var stock: Dictionary=ui.city["realms"][0]["resources"]
    stock["wood"]=500.0
    stock["stone"]=500.0
    ui.city["realms"][0]["pop"]=18
    if Districts.expand(ui.city,world,neighbour.x,neighbour.y)!="":
        fail("could not build real neighboring city district")
        return
    Transit.configure(ui.city,world)
    ui._show_detail(home.x,home.y)
    if not detail.combined_city or detail.shown_district_tiles.size()!=2:
        fail("paid neighboring district did not enable 160m combined city")
        return
    var moved: Dictionary=_pose(home,neighbour,0.75)
    if not Pose80.visible(moved,home,true,detail.shown_district_tiles):
        fail("moving scout disappears from the combined adjacent district")
        return
    if Pose80.owner(moved)!=neighbour:
        fail("half-tile ownership does not switch at the shared midpoint")
        return
    var local: Vector2=Pose80.local(moved,home,true)
    if not local.is_equal_approx(Vector2(float(neighbour.x-home.x)*120.0,
            float(neighbour.y-home.y)*120.0)):
        fail("combined city still uses the obsolete 225x195m model scale")
        return
    var in_tile: Vector2=Pose80.in_owner_local(moved,home,true,local)
    if not in_tile.is_equal_approx(Vector2(
            float(neighbour.x-home.x)*-40.0,
            float(neighbour.y-home.y)*-40.0)):
        fail("actor is not on its actual 160m district terrain")
        return
    moving["travelClock"]=75.0
    detail.set_world_scout_v53(moving)
    if not detail.world_scout_actor_v53.visible or \
            not _check_vec(detail.world_scout_actor_v53.position,
                Vector3(local.x,Terrain28.height(world,neighbour,
                    in_tile.x,in_tile.y),local.y),
                "combined scout floats above or intersects district terrain"):
        return
    # A real rigged warrior follows the identical coordinate projection and
    # preserves its mesh identity while crossing the city-district boundary.
    var soldier: Dictionary=_walking(home,neighbour,0.45)
    soldier["kind"]="axeman"
    soldier["id"]=80000
    detail.set_world_armies_v54([soldier])
    var actor: Node3D=detail.army_detail_root_v54.get_node_or_null(
        "DetailArmyV54_80000") as Node3D
    if actor==null or actor.get_child_count()!=1:
        fail("real army GLB missing in connected district")
        return
    var unique_id: int=actor.get_instance_id()
    var model: Node3D=actor.get_child(0) as Node3D
    soldier["travelClock"]=55.0
    detail.set_world_armies_v54([soldier])
    var after: Node3D=detail.army_detail_root_v54.get_node_or_null(
        "DetailArmyV54_80000") as Node3D
    if after==null or after.get_instance_id()!=unique_id or \
            after.get_child(0)!=model:
        fail("cross-district movement recreated or lost the skeleton")
        return
    var warrior_pose: Dictionary=_pose(home,neighbour,0.55)
    var warrior_local: Vector2=Pose80.local(warrior_pose,home,true)
    var drawn: Vector2=warrior_local+Vector2(24,16)
    var warrior_inside: Vector2=Pose80.in_owner_local(
        warrior_pose,home,true,drawn)
    if not _check_vec(after.get_meta("motion_goal_v78",Vector3.INF),
            Vector3(drawn.x,Terrain28.height(world,neighbour,
                warrior_inside.x,warrior_inside.y),drawn.y),
            "live warrior target is not on adjacent 160m terrain"):
        return
    ui._show_detail(neighbour.x,neighbour.y)
    detail.set_world_scout_v53(moving)
    var neighbor_local: Vector2=Pose80.local(moved,neighbour,true)
    if not detail.world_scout_actor_v53.visible or \
            absf(detail.world_scout_actor_v53.position.x-neighbor_local.x)>0.001 or \
            absf(detail.world_scout_actor_v53.position.z-neighbor_local.y)>0.001:
        fail("switching active district duplicated or displaced the scout")
        return
    var before: String=JSON.stringify(ui.city)
    detail.set_world_scout_v53(moving)
    detail.set_world_armies_v54([soldier])
    if before!=JSON.stringify(ui.city):
        fail("visual projection altered actual saved simulation/game state")
        return
    print("STRATEGIC_DETAIL_V80 SUCCESS: standalone 225x195m, real 160m two-district terrain, scouts, rigged warriors and stable cross-tile pose")
    quit(0)
