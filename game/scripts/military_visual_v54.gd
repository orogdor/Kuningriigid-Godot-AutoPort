extends RefCounted
## v0.54: first visible paid military camp. Pure presentation, no resources.
## A simple native Godot tent/palisade visual pending an authentic camp GLB.
static func _material(hex: String) -> StandardMaterial3D:
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=Color(hex)
    mat.roughness=0.95
    return mat

static func _mesh(parent: Node3D,mesh: Mesh,position: Vector3,
        name: String,color: String) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    item.mesh=mesh
    item.position=position
    item.material_override=_material(color)
    parent.add_child(item)
    return item

static func populate(parent: Node3D,built: bool) -> void:
    var ground:=BoxMesh.new()
    ground.size=Vector3(15.0,0.25,12.0)
    _mesh(parent,ground,Vector3(0,0.0,0),"PaidCampYardV54","#775f40")
    for x in [-6.0,6.0]:
        for z in [-4.5,4.5]:
            var stake:=CylinderMesh.new()
            stake.top_radius=0.22
            stake.bottom_radius=0.30
            stake.height=5.0
            _mesh(parent,stake,Vector3(x,2.4,z),"CampPalisadePostV54","#61482d")
    var beam:=CylinderMesh.new()
    beam.top_radius=0.24
    beam.bottom_radius=0.24
    beam.height=12.0
    var frame:=_mesh(parent,beam,Vector3(0,4.55,0),"CampRoofBeamV54","#7e5c35")
    frame.rotation_degrees=Vector3(0,0,90)
    if built:
        var canvas:=PrismMesh.new()
        canvas.size=Vector3(11.0,4.1,8.5)
        var roof:=_mesh(parent,canvas,Vector3(0,2.75,0),
            "ReadyCampCanvasV54","#a88d60")
        roof.rotation_degrees=Vector3(0,0,0)
        var banner:=BoxMesh.new()
        banner.size=Vector3(0.1,2.1,1.4)
        _mesh(parent,banner,Vector3(6.2,4.7,0),
            "StoneAgeTrainingBannerV54","#b36c40")
