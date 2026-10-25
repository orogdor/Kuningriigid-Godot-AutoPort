extends SceneTree
## 0.10 regression: river routing/ford, new bridge route, cost, slope, save
## and compatibility with existing 0.9 town traffic.
const City = preload("res://scripts/city_sim_v05.gd")
const Spatial = preload("res://scripts/spatial_economy_v08.gd")
const Paths = preload("res://scripts/spatial_paths_v09.gd")
const Terrain = preload("res://scripts/detail_terrain_v10.gd")

func fail(message: String) -> void:
    printerr("TERRAIN_V10 FAILED: "+message)
    quit(1)

func crosses_x(route: Array, x_cell: int) -> bool:
    for p in route:
        if absf(float(p["z"])-20.0)<=5.0 or absf(float(p["z"])-30.0)<=5.0:
            if int(roundf(float(p["x"])/10.0))==x_cell:return true
    return false

func _initialize() -> void:
    var state: Dictionary=City.default_state()
    Spatial.initialize(state)
    var sim: Dictionary=state["detail_sim"]
    sim["terrain"]="river"
    sim["river"]=true
    if not Terrain.blocked_cell(sim,Vector2i(3,2)) or Terrain.blocked_cell(sim,Vector2i(0,2)):
        fail("river cells and fords do not agree with pathfinding")
        return
    var a:=Vector2(30,-50)
    var b:=Vector2(30,60)
    var before: Array=Paths.find_path(state,a,b,-1)
    if before.is_empty():
        fail("river cannot be crossed using a shallow ford")
        return
    if crosses_x(before,3):
        fail("worker crossed unopened bridge location")
        return
    var stock: Dictionary=state["realms"][0]["resources"]
    var wood: float=float(stock["wood"])
    var stone: float=float(stock["stone"])
    if Spatial.build_bridge(state,30.0)!="":
        fail("town cannot build legal bridge using existing resources")
        return
    if sim["bridges"].size()!=1 or not Terrain.has_bridge(sim,3):
        fail("bridge was not persisted in spatial state")
        return
    if not is_equal_approx(float(stock["wood"]),wood-28.0) or not is_equal_approx(float(stock["stone"]),stone-18.0):
        fail("bridge construction did not deduct 28 wood and 18 stone")
        return
    var after: Array=Paths.find_path(state,a,b,-1)
    if after.is_empty() or not crosses_x(after,3):
        fail("new bridge does not open shorter river crossing")
        return
    if Spatial.build_bridge(state,30.0)=="":
        fail("duplicate bridge incorrectly accepted")
        return
    if float(stock["wood"])!=wood-28.0:
        fail("duplicate bridge deducted resources")
        return
    if Spatial.build_bridge(state,10.0)=="":
        fail("bridge built outside a permitted location")
        return
    var hills: Dictionary=City.default_state()
    Spatial.initialize(hills)
    hills["detail_sim"]["terrain"]="hills"
    var found_slope: bool=false
    for x in range(-7,7):
        for z in range(-7,7):
            var cell:=Vector2i(x,z)
            if Terrain.too_steep(hills["detail_sim"],cell,cell+Vector2i(1,0)):
                found_slope=true
                break
        if found_slope:break
    if not found_slope:
        fail("hill heightfield contains no blocked steep neighbor")
        return
    var serialized: Variant=JSON.parse_string(JSON.stringify(state))
    if not serialized is Dictionary:
        fail("JSON serialization of bridges failed")
        return
    Spatial.initialize(serialized)
    if int(serialized["detail_sim"]["version"])!=3 or not Terrain.has_bridge(serialized["detail_sim"],3):
        fail("bridge data was not preserved after save/reload")
        return
    var old: Dictionary=City.default_state()
    Spatial.initialize(old)
    old["detail_sim"].erase("bridges")
    old["detail_sim"].erase("river")
    old["detail_sim"]["version"]=2
    old["detail_sim"]["sites"][0]["remaining"]=7.0
    Spatial.initialize(old)
    if old["detail_sim"]["version"]!=3 or old["detail_sim"]["bridges"].size()!=0:
        fail("0.9 spatial save was not upgraded to 0.10")
        return
    if float(old["detail_sim"]["sites"][0]["remaining"])!=7.0:
        fail("save migration destroyed existing resources")
        return
    print("TERRAIN_V10 SUCCESS: river fords, real bridge, pathfinding, materials, slope and save migration")
    quit(0)
