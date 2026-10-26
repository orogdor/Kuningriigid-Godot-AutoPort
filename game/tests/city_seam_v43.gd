extends SceneTree
## 0.43 regression: simulated city terrain must connect seamlessly to the
## 0.42 wilderness, preserving actual city roads/river/building elevations.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Terrain=preload("res://scripts/detail_terrain_v10.gd")
const World=preload("res://scripts/world_gen_v06.gd")
const Relief=preload("res://scripts/detail_neighbor_terrain_v42.gd")
const Districts=preload("res://scripts/world_districts_v25.gd")
const Scene=preload("res://content.tscn")

func fail(message: String) -> void:
    printerr("CITY_SEAM_V43 FAIL: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var sim: Dictionary=state["detail_sim"]
    sim["terrain"]="hills"
    sim["river"]=true
    var world: Dictionary=World.generate(82026,true)
    var tile: Vector2i=Districts.origin(world)
    var w: float=Relief.WIDTH*0.5
    var d: float=Relief.DEPTH*0.5
    # The built city, its pathfinder and any ford have identical core heights.
    for x in [-50.0,-10.0,0.0,10.0,50.0]:
        for z in [-33.0,0.0,24.0,48.0]:
            var actual: float=Relief.city_height_at(world,tile,sim,x,z)
            var original: float=Terrain.elevation(sim,x,z)
            if absf(actual-original)>0.0001:
                fail("core elevation or river crossing changed")
                return
    # All four sides and corners must agree with the adjacent 3D tile.
    for z in [-d,-65.0,0.0,40.0,d]:
        for edge in [-1,1]:
            var x: float=w*float(edge)
            var actual: float=Relief.city_height_at(world,tile,sim,x,z)
            var neighbor: Vector2i=tile+Vector2i(edge,0)
            var seam: float=Relief.height_at(world,neighbor,-x,z)
            if absf(actual-seam)>0.0001:
                fail("east/west seam fails at %.1f %.1f" % [x,z])
                return
    for x in [-w,-55.0,0.0,55.0,w]:
        for edge in [-1,1]:
            var z: float=d*float(edge)
            var actual: float=Relief.city_height_at(world,tile,sim,x,z)
            var neighbor: Vector2i=tile+Vector2i(0,edge)
            var seam: float=Relief.height_at(world,neighbor,x,-z)
            if absf(actual-seam)>0.0001:
                fail("north/south seam fails at %.1f %.1f" % [x,z])
                return
    if Relief.city_edge_weight(0,0)!=0.0 or absf(Relief.city_edge_weight(w,0)-1.0)>0.0001:
        fail("blending alters center or does not fully reach world border")
        return
    if Relief.city_edge_weight(w-15.0,0)<=0.0 or Relief.city_edge_weight(w-15.0,0)>=1.0:
        fail("border interpolation is not gradual")
        return
    root.size=Vector2i(720,420)
    var ui: Control=Scene.instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._reset()
    var home: Vector2i=Districts.origin(ui.world_view.world)
    ui._show_detail(home.x,home.y)
    await process_frame
    if ui.detail_view.combined_city:
        fail("unmodified new city should use single detail tile geometry")
        return
    var view=ui.detail_view
    var cell: Dictionary=World.cell(ui.world_view.world,home.x,home.y)
    var town_height: float=view._elevation(w,20.0,float(cell["h"])*0.02,true)
    var border_height: float=Relief.height_at(ui.world_view.world,home,w,20.0)
    if absf(town_height-border_height)>0.0001:
        fail("actual playable detail mesh does not use seamless town border")
        return
    if view.seam_preview_root.get_child_count()<3:
        fail("city lost preview of surrounding detail terrain")
        return
    if view.controller.size.y<180.0:
        fail("terrain correction hides 3D viewport on mobile")
        return
    print("CITY_SEAM_V43 SUCCESS: original playable city core, real river/bridge elevation, smooth 4-side/corner borders, 3D mobile detail")
    quit(0)
