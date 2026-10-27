extends SceneTree
## Validate actual imported Web GLB resources and their presence in Godot 3D.
const Scene=preload("res://content.tscn")
const Source=preload("res://scripts/web_graphics_v50.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
func fail(why: String) -> void:
    printerr("WEB_ART_V50 FAIL: "+why)
    quit(1)
func _initialize() -> void:
    call_deferred("_test")
func _test() -> void:
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    for kind in ["oak","pine","rock","timber_house","market","windmill",
            "forest_cluster","rock_outcrop","world_village","ancient_ruin"]:
        var imported: PackedScene=Source.asset(kind)
        if imported==null:
            fail("original Web GLB resource missing: "+kind)
            return
    var atlas=ui.world_view.terrain_3d
    if atlas.web_props_root==null:
        fail("world map doesn't contain original Web models")
        return
    var settlement: Node3D=atlas.web_props_root.get_node_or_null("WebWorldSettlements") as Node3D
    var forest: Node3D=atlas.web_props_root.get_node_or_null("WebForestClusters") as Node3D
    if settlement==null or forest==null:
        fail("world contains no original Web settlement or forest layers")
        return
    if int(settlement.get_meta("placements",0))<1 or settlement.get_child_count()<1:
        fail("real starting settlements are not rendered as GLB")
        return
    var stage:=Node3D.new()
    root.add_child(stage)
    for kind in ["house","market","mill"]:
        ui.detail_view._building(stage,kind,Vector3.ZERO,true)
    for name in ["WebTimberHouse","WebMarketStalls","WebWindmill"]:
        var group: Node3D=stage.get_node_or_null(name) as Node3D
        if group==null or group.get_node_or_null("WebGLB")==null:
            fail("3D city still uses dummy primitives instead of "+name)
            return
    var before: Dictionary=ui.city["realms"][0]["resources"].duplicate(true)
    var home: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(home.x,home.y)
    await process_frame
    if ui.detail_view.construction_root.get_node_or_null("hall_0")==null:
        fail("playable city center got hidden by the new original Web assets")
        return
    if ui.city["realms"][0]["resources"]!=before:
        fail("Web models changed simulated resources")
        return
    if ui.detail_view.controller.size.y<180:
        fail("GLB graphics broke mobile 720x420 detail view")
        return
    print("WEB_ART_V50 SUCCESS: 10 original Web GLBs imported, batched atlas forest and real settlements, house/market/mill 3D buildings, working capital and unchanged economy")
    quit(0)
