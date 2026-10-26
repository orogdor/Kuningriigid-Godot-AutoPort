extends SceneTree
## v0.44 preview actual owned city buildings when viewing its adjacent tile.
## The preview is visual only; it must never create buildings or resources.
const Scene=preload("res://content.tscn")
const World=preload("res://scripts/world_gen_v06.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const LOD=preload("res://scripts/city_building_lod_v32.gd")

func fail(message: String) -> void:
    printerr("CITY_PREVIEW_V44 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var world: Dictionary=ui.world_view.world
    var home: Vector2i=Districts.origin(world)
    var neighbor: Vector2i=home+Vector2i(1,0)
    if World.cell(world,neighbor.x,neighbor.y).is_empty():
        fail("adjacent test tile does not exist")
        return
    var original_buildings: int=ui.city["buildings"].size()
    var original_resources: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    ui._show_detail(neighbor.x,neighbor.y)
    await process_frame
    var view=ui.detail_view
    var adjacent_preview: Node3D=view.seam_preview_root.get_node_or_null(
        "DetailNeighbor_-1_0") as Node3D
    if adjacent_preview==null:
        fail("capital tile is missing from the adjacent 3D preview")
        return
    var cluster: Node3D=adjacent_preview.get_node_or_null("ActualNeighborBuildings") as Node3D
    if cluster==null:
        fail("neighbor preview still hides real capital buildings")
        return
    var expected: int=LOD.eligible(ui.city["buildings"],"").size()
    var total: int=0
    for child in cluster.get_children():
        if child is MultiMeshInstance3D and child.multimesh!=null:
            total+=child.multimesh.instance_count
    if expected<1 or total!=expected:
        fail("preview building count does not match actual saved city")
        return
    if view.can_build:
        fail("looking at an unowned neighbor granted capital building rights")
        return
    if ui.city["buildings"].size()!=original_buildings or \
            ui.city["realms"][0]["resources"]!=original_resources:
        fail("render-only preview mutated city buildings or its stock")
        return
    ui._show_detail(home.x,home.y)
    await process_frame
    if not view.can_build or view.selected!=home:
        fail("switching home did not restore actual city view")
        return
    if view.construction_root.get_child_count()<1:
        fail("actual city buildings disappeared after returning")
        return
    # Far wilderness cannot contain a duplicate ghost of the capital.
    var far: Vector2i=home+Vector2i(10,10)
    if not World.cell(world,far.x,far.y).is_empty():
        ui._show_detail(far.x,far.y)
        await process_frame
        for entry in view.seam_preview_root.get_children():
            if entry.get_node_or_null("ActualNeighborBuildings")!=null:
                fail("remote wilderness invented duplicate capital structures")
                return
    print("CITY_PREVIEW_V44 SUCCESS: actual capital building LOD previews, same saved buildings, no ghost city, no economy effects, mobile 3D")
    quit(0)
