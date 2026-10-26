extends RefCounted
## AutoPort 0.49: 3D visuals for REAL saved v0.17 world routes and v0.15
## caravans. No second simulation or free goods; 2D-compatible progress.
const World=preload("res://scripts/world_gen_v06.gd")
const Routes=preload("res://scripts/world_trade_routes_v17.gd")
const MAX_CARAVANS: int=40

static func _ground_height(cell: Dictionary) -> float:
    return maxf(-4.0,float(cell.get("h",0.0))*0.33)

static func _corner(world: Dictionary,c: int,r: int) -> float:
    # Same corner average as world_terrain_v40.
    var sum: float=0.0
    var count: int=0
    for dz in [-1,0]:
        for dx in [-1,0]:
            var cell: Dictionary=World.cell(world,c+dx,r+dz)
            if cell.is_empty():continue
            sum+=_ground_height(cell)
            count+=1
    return sum/float(maxi(count,1))

static func tile_point(world: Dictionary,c: int,r: int) -> Vector3:
    var y: float=(_corner(world,c,r)+_corner(world,c+1,r)+
        _corner(world,c,r+1)+_corner(world,c+1,r+1))*0.25
    return Vector3(float(c)+0.5,y+1.0,float(r)+0.5)

static func route_points(world: Dictionary,route: Dictionary) -> Array[Vector3]:
    var points: Array[Vector3]=[]
    if world.is_empty() or route.is_empty():return points
    if int(route.get("seed",-1))!=int(world.get("seed",-2)):return points
    var path: Array=route.get("tiles",[])
    if path.size()<2:return points
    var previous: Vector2i=Vector2i(-1,-1)
    for segment in path:
        if not segment is Dictionary:return []
        var tile:=Vector2i(int(segment.get("c",-1)),int(segment.get("r",-1)))
        if not Routes.passable(world,tile.x,tile.y):return []
        if previous.x>=0 and absi(tile.x-previous.x)+absi(tile.y-previous.y)!=1:
            return [] # Reject jumping straight across water or mountains.
        points.append(tile_point(world,tile.x,tile.y))
        previous=tile
    return points

static func caravan_positions(points: Array[Vector3],caravans: Array) -> Array:
    var placements: Array=[]
    if points.size()<2:return placements
    for item in caravans:
        if placements.size()>=MAX_CARAVANS:break
        if not item is Dictionary:continue
        var duration: float=maxf(1.0,float(item.get("duration",6)))
        var elapsed: float=clampf(float(item.get("progress",0))/duration,0.0,1.0)
        var backwards: bool=String(item.get("from","capital"))=="outpost"
        var pct: float=1.0-elapsed if backwards else elapsed
        var position: float=pct*float(points.size()-1)
        var index: int=clampi(int(floor(position)),0,points.size()-2)
        var alpha: float=clampf(position-float(index),0.0,1.0)
        var a: Vector3=points[index]
        var b: Vector3=points[index+1]
        var direction: Vector3=(a-b) if backwards else (b-a)
        placements.append({"id":int(item.get("id",placements.size())),
            "point":a.lerp(b,alpha),"rotation":atan2(direction.x,direction.z),
            "progress":elapsed,"from":String(item.get("from","capital")),
            "kind":String(item.get("kind","wood")),
            "quantity":float(item.get("quantity",0))})
    return placements

static func _material(hex: String) -> StandardMaterial3D:
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color(hex)
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.roughness=0.9
    return mat

static func _marker(parent: Node3D,point: Vector3,name: String,
        radius: float,color: String) -> void:
    var node:=MeshInstance3D.new()
    node.name=name
    var pin:=CylinderMesh.new()
    pin.top_radius=radius*0.7
    pin.bottom_radius=radius
    pin.height=2.8
    node.mesh=pin
    node.position=point+Vector3(0,1.2,0)
    node.material_override=_material(color)
    parent.add_child(node)

static func populate_road(parent: Node3D,points: Array[Vector3]) -> void:
    if points.size()<2:return
    var road_mesh:=BoxMesh.new()
    road_mesh.size=Vector3(0.5,0.13,1.0)
    var batches:=MultiMesh.new()
    batches.transform_format=MultiMesh.TRANSFORM_3D
    batches.mesh=road_mesh
    batches.instance_count=points.size()-1
    for i in range(points.size()-1):
        var a: Vector3=points[i]
        var b: Vector3=points[i+1]
        var direction: Vector3=b-a
        var turn: float=atan2(direction.x,direction.z)
        var scale:=Vector3(1.0,1.0,Vector2(direction.x,direction.z).length()+0.12)
        batches.set_instance_transform(i,Transform3D(
            Basis(Vector3.UP,turn).scaled(scale),(a+b)*0.5))
    var road:=MultiMeshInstance3D.new()
    road.name="SavedTradeRoad3D"
    road.multimesh=batches
    road.material_override=_material("#d2aa68")
    road.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(road)
    _marker(parent,points[0],"CapitalTradePin3D",0.6,"#8fc8e8")
    _marker(parent,points[points.size()-1],"SatelliteTradePin3D",0.6,"#ffd170")

static func populate_caravans(parent: Node3D,placements: Array) -> void:
    var wagon_mat:=_material("#a16b40")
    var goods_mat:=_material("#dfb46d")
    for item in placements:
        var cart:=Node3D.new()
        cart.name="TradeCaravan3D_"+str(item["id"])
        cart.position=item["point"]
        cart.rotation.y=float(item["rotation"])
        cart.set_meta("goods",item["kind"])
        cart.set_meta("quantity",item["quantity"])
        parent.add_child(cart)
        var body:=MeshInstance3D.new()
        body.name="CaravanBody"
        var shape:=BoxMesh.new()
        shape.size=Vector3(0.92,0.65,1.38)
        body.mesh=shape
        body.position=Vector3(0,0.38,0)
        body.material_override=wagon_mat
        cart.add_child(body)
        var load:=MeshInstance3D.new()
        load.name="CaravanCargo"
        var pile:=BoxMesh.new()
        pile.size=Vector3(0.71,0.38,1.04)
        load.mesh=pile
        load.position=Vector3(0,0.88,0)
        load.material_override=goods_mat
        cart.add_child(load)
