extends RefCounted
## Curated CC0 props. This layer never changes routes or collision authority.
const ROOT="res://assets/kenney/"
const Terrain=preload("res://game/world/island_terrain.gd")
static var models: Dictionary={}
static var surfaces: Dictionary={}

static func prop(parent: Node3D,pack: String,id: String,at: Vector3,size: Vector3,yaw: float=0.0) -> Node3D:
	var path: String=ROOT+pack+"/"+id+".glb"
	if not models.has(path): models[path]=load(path)
	var result: Node3D=models[path].instantiate()
	result.name=id.validate_node_name()
	result.position=at
	if pack=="nature": result.position.y=Terrain.height_at(at)
	result.scale=size
	result.rotation.y=yaw
	parent.add_child(result)
	_natural_materials(result)
	return result

static func _natural_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var source: Material=node.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			var key: int=source.get_instance_id()
			if not surfaces.has(key):
				var mat: StandardMaterial3D=source.duplicate()
				# The source Nature GLBs mark bark/foliage fully metallic. Matte
				# surfaces keep the authored facets readable with cheap lighting.
				mat.metallic=0.0
				mat.roughness=1.0
				if "leaf" in source.resource_name.to_lower(): mat.albedo_color=Color("70954b")
				elif "grass" in source.resource_name.to_lower(): mat.albedo_color=Color("85a85b")
				elif "bark" in source.resource_name.to_lower(): mat.albedo_color=Color("90623f")
				surfaces[key]=mat
			node.set_surface_override_material(index,surfaces[key])
	for child in node.get_children(): _natural_materials(child)

static func stone(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh=SphereMesh.new()
	mesh.radial_segments=7
	mesh.rings=3
	mesh.radius=0.5
	mesh.height=1.0
	var node=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=BlockArt.material(color)
	node.position=at
	node.scale=size
	parent.add_child(node)
	return node

static func shore(parent: Node3D,center: Vector3,size: Vector3) -> void:
	# Scalloped sand and rock below the playable top disguise slab edges.
	var perimeter: Array[Vector3]=[]
	for x in range(int(-size.x/2),int(size.x/2),7):
		perimeter.append(center+Vector3(x,-0.55,-size.z/2))
		perimeter.append(center+Vector3(x,-0.55,size.z/2))
	for z in range(int(-size.z/2),int(size.z/2),7):
		perimeter.append(center+Vector3(-size.x/2,-0.55,z))
		perimeter.append(center+Vector3(size.x/2,-0.55,z))
	for i in range(perimeter.size()):
		var p: Vector3=perimeter[i]
		p+=Vector3(sin(float(i)*1.7)*0.65,-0.35,cos(float(i)*2.3)*0.6)
		var shelf: MeshInstance3D=stone(parent,p,Vector3(8.0+sin(float(i))*2.0,1.3+float(i%3)*0.22,6.8),Color("c5b492") if i%5 else Color("778a89"))
		shelf.rotation.y=float(i)*0.73

static func meadow(parent: Node3D) -> void:
	var rng=RandomNumberGenerator.new()
	rng.seed=7413
	for index in range(80):
		var side: int=index%4
		var at: Vector3
		match side:
			0: at=Vector3(rng.randf_range(-80,-74),2.01,rng.randf_range(-60,61))
			1: at=Vector3(rng.randf_range(73,80),2.01,rng.randf_range(-60,61))
			2: at=Vector3(rng.randf_range(-67,65),2.01,rng.randf_range(-66,-61))
			_: at=Vector3(rng.randf_range(-60,-19),2.01,rng.randf_range(62,66))
		var flower: bool=index%9==0
		at=Terrain.layout_point(at)
		prop(parent,"nature",("flower_yellowA" if index%2 else "flower_purpleA") if flower else "grass",at,Vector3.ONE*rng.randf_range(1.1,2.2),rng.randf()*TAU)
	for at in [Vector3(-77,2,37),Vector3(-74,2,-25),Vector3(-29,2,-64),Vector3(13,2,-64),Vector3(74,2,-7),Vector3(76,2,53),Vector3(-22,2,63)]:
		prop(parent,"nature","plant_bushLarge",Terrain.layout_point(at),Vector3.ONE*3.5,rng.randf()*TAU)
	for index in range(20):
		var west: bool=index%2==0
		var at:=Vector3(-77.5 if west else 78.5,2.0,-58.0+float(index/2)*12.0)
		# Keep spawn's camera corridor clear; trees remain outside the path.
		if west and at.z>32: continue
		at=Terrain.layout_point(at)
		var size: float=rng.randf_range(4.6,6.8)
		prop(parent,"nature","tree_oak_dark" if index%3 else "tree_pineRoundA",at,Vector3.ONE*size,rng.randf()*TAU)
		var body=StaticBody3D.new()
		body.collision_layer=1
		body.collision_mask=1
		body.position=at+Vector3.UP*1.8
		var collision=CollisionShape3D.new()
		var shape=CylinderShape3D.new()
		shape.radius=0.25
		shape.height=3.6
		collision.shape=shape
		body.add_child(collision)
		parent.add_child(body)

static func camp(parent: Node3D) -> void:
	prop(parent,"survival","tent",Vector3(-30.7,2,24),Vector3.ONE*2.5,-0.5)
	prop(parent,"survival","barrel",Vector3(-28,2,23),Vector3.ONE*2.0)
	prop(parent,"survival","bucket",Vector3(-22.8,2.05,21.8),Vector3.ONE*1.5)
	prop(parent,"survival","bedroll-packed",Vector3(-33,2.05,23),Vector3.ONE*1.8)
	prop(parent,"survival","campfire-fishing-stand",Vector3(-32.5,2.05,20),Vector3.ONE*1.4,0.9)
