extends RefCounted
## Original block camp props. Decoration never owns routes or collision.
const Art=preload("res://game/world/block_art.gd")
const Terrain=preload("res://game/world/island_terrain.gd")
const CAMERA_OCCLUDER_LAYER: int=16

static func prop(parent: Node3D,pack: String,id: String,at: Vector3,size: Vector3,yaw: float=0.0) -> Node3D:
	var result:=Node3D.new()
	result.name=id.validate_node_name()
	result.position=at
	if pack=="nature": result.position.y=Terrain.height_at(at)
	result.scale=size
	result.rotation.y=yaw
	parent.add_child(result)
	match id:
		"tree_oak", "tree_oak_dark", "tree_pineRoundA": _tree(result,id)
		"rock_largeA":
			Art.box(result,Vector3(0,0.31,0),Vector3(0.9,0.62,0.72),Color("759b9e"))
			Art.box(result,Vector3(-0.13,0.67,0.05),Vector3(0.58,0.15,0.52),Color("aac5bb"))
		"grass":
			# Two broad blades read as a tuft at the normal camera distance.
			Art.box(result,Vector3(-0.04,0.13,0),Vector3(0.06,0.26,0.05),Art.GRASS.darkened(0.12)).rotation.z=0.18
			Art.box(result,Vector3(0.05,0.1,0.025),Vector3(0.055,0.2,0.05),Art.GRASS).rotation.z=-0.18
		"flower_yellowA", "flower_purpleA":
			Art.box(result,Vector3(0,0.12,0),Vector3(0.035,0.24,0.035),Art.GRASS.darkened(0.1))
			Art.box(result,Vector3(0,0.25,0),Vector3(0.14,0.1,0.13),Art.AMBER if id=="flower_yellowA" else Color("a28ad6"))
		"plant_bushLarge": Art.box(result,Vector3(0,0.22,0),Vector3(0.66,0.44,0.5),Color("448b62"))
		"tent": _tent(result)
		"barrel":
			Art.box(result,Vector3(0,0.31,0),Vector3(0.4,0.62,0.4),Color("b67b55"))
			for y: float in [0.13,0.49]: Art.box(result,Vector3(0,y,0),Vector3(0.42,0.06,0.42),Art.INK)
			Art.box(result,Vector3(0,0.63,0),Vector3(0.37,0.035,0.37),Art.WOOD)
		"bucket":
			Art.box(result,Vector3(0,0.16,0),Vector3(0.28,0.32,0.28),Art.WATER)
			Art.box(result,Vector3(0,0.325,0),Vector3(0.22,0.01,0.22),Art.INK)
			Art.beam(result,Vector3(-0.14,0.24,0),Vector3(-0.14,0.49,0),0.025,Art.CREAM)
			Art.beam(result,Vector3(0.14,0.24,0),Vector3(0.14,0.49,0),0.025,Art.CREAM)
			Art.box(result,Vector3(0,0.49,0),Vector3(0.3,0.025,0.025),Art.CREAM)
		"bedroll-packed":
			Art.box(result,Vector3(0,0.12,0),Vector3(0.5,0.24,0.3),Art.WATER)
			for x: float in [-0.15,0.15]: Art.box(result,Vector3(x,0.12,0),Vector3(0.035,0.255,0.315),Art.CREAM)
		"campfire-fishing-stand":
			for x: float in [-0.55,0.55]: Art.box(result,Vector3(x,0.47,0),Vector3(0.09,0.94,0.09),Art.WOOD)
			Art.box(result,Vector3(0,0.97,0),Vector3(1.25,0.1,0.1),Art.WOOD)
			Art.box(result,Vector3(0,0.68,0),Vector3(0.03,0.5,0.03),Art.INK)
		"workbench": _workbench(result)
		"boat-row-large": _skiff(result)
		_: push_error("Unknown block camp prop: "+pack+"/"+id)
	return result

static func _tree(parent: Node3D,id: String) -> void:
	# A few designed masses, with daylight between them and readable silhouettes.
	Art.box(parent,Vector3(0,0.43,0),Vector3(0.13,0.86,0.13),Art.WOOD).name="Trunk"
	Art.beam(parent,Vector3(0,0.59,0),Vector3(0.19,0.88,0.02),0.065,Art.WOOD)
	var canopy:=Node3D.new()
	canopy.name="Canopy"
	parent.add_child(canopy)
	if id=="tree_pineRoundA":
		Art.box(canopy,Vector3(0,0.79,0),Vector3(0.54,0.26,0.54),Color("337d65"))
		Art.box(canopy,Vector3(0,1.01,0),Vector3(0.40,0.25,0.40),Color("409b6a"))
		Art.box(canopy,Vector3(0,1.22,0),Vector3(0.23,0.23,0.23),Color("77b870"))
	else:
		var shade: Color=Color("418b53") if id=="tree_oak_dark" else Color("4b9e57")
		Art.box(canopy,Vector3(-0.10,0.91,-0.04),Vector3(0.52,0.38,0.50),shade)
		Art.box(canopy,Vector3(0.10,1.16,0.02),Vector3(0.43,0.31,0.41),shade.lightened(0.16))
		Art.box(canopy,Vector3(0.23,0.91,0.04),Vector3(0.34,0.31,0.39),shade.lightened(0.055))
	for cluster: MeshInstance3D in canopy.get_children(): _camera_occluder(cluster)

static func _camera_occluder(mesh: MeshInstance3D) -> void:
	# Match each visible foliage box exactly, including its parent's scale/yaw.
	# Layer 16 is camera-only; existing movement queries still use world layer 1.
	var blocker:=StaticBody3D.new()
	blocker.name="CameraOccluder"
	blocker.collision_layer=CAMERA_OCCLUDER_LAYER
	blocker.collision_mask=0
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=(mesh.mesh as BoxMesh).size
	collision.shape=shape
	blocker.add_child(collision)
	mesh.add_child(blocker)

static func _tent(parent: Node3D) -> void:
	var roof:=PrismMesh.new()
	roof.size=Vector3(1.08,0.78,1.0)
	var cloth:=MeshInstance3D.new()
	cloth.mesh=roof
	cloth.material_override=Art.material(Color("ed985c"))
	cloth.position.y=0.39
	parent.add_child(cloth)
	var door:=PrismMesh.new()
	door.size=Vector3(0.62,0.53,0.015)
	var entrance:=MeshInstance3D.new()
	entrance.mesh=door
	entrance.material_override=Art.material(Art.INK)
	entrance.position=Vector3(0,0.27,0.507)
	parent.add_child(entrance)
	Art.box(parent,Vector3(0,0.015,0),Vector3(1.13,0.03,1.06),Art.CREAM)
	Art.box(parent,Vector3(0,0.79,0),Vector3(0.065,0.055,1.04),Art.CREAM)
	# Cream seams and pegged lines make the simple folded silhouette feel sewn.
	for side: float in [-1,1]:
		Art.beam(parent,Vector3(0,0.77,0.51),Vector3(side*0.53,0.03,0.51),0.035,Art.CREAM)
		Art.beam(parent,Vector3(side*0.30,0.36,0.40),Vector3(side*0.73,0.025,0.61),0.014,Art.CREAM)
		Art.box(parent,Vector3(side*0.73,0.025,0.61),Vector3(0.035,0.05,0.13),Art.WOOD)

static func _workbench(parent: Node3D) -> void:
	Art.box(parent,Vector3(0,0.46,0),Vector3(1.0,0.14,0.55),Art.WOOD)
	for x: float in [-0.39,0.39]:
		for z: float in [-0.19,0.19]: Art.box(parent,Vector3(x,0.2,z),Vector3(0.09,0.4,0.09),Art.WATER)
	Art.box(parent,Vector3(0,0.21,0),Vector3(0.92,0.07,0.43),Art.WOOD.darkened(0.08))
	Art.box(parent,Vector3(-0.18,0.538,0.025),Vector3(0.31,0.012,0.32),Art.CREAM)
	Art.box(parent,Vector3(0.24,0.57,-0.1),Vector3(0.15,0.08,0.12),Art.AMBER)
	# A chart, tackle box and rod rack sit within the existing bench footprint.
	Art.box(parent,Vector3(0.28,0.61,0.11),Vector3(0.22,0.16,0.14),Color("3e6970"))
	Art.box(parent,Vector3(0.28,0.699,0.11),Vector3(0.24,0.025,0.16),Art.CREAM)
	Art.box(parent,Vector3(-0.15,0.548,0.025),Vector3(0.017,0.006,0.24),Art.WATER)
	Art.box(parent,Vector3(-0.18,0.548,0.065),Vector3(0.20,0.006,0.017),Art.WATER)
	for x: float in [-0.40,-0.27]:
		Art.beam(parent,Vector3(x,0.06,-0.20),Vector3(x+0.11,1.25,-0.27),0.018,Color("e3bb7c"))
		Art.box(parent,Vector3(x+0.025,0.29,-0.17),Vector3(0.065,0.065,0.045),Art.INK)

static func _skiff(parent: Node3D) -> void:
	# A blunt square stern, open deck, and short V bow make Moth readable.
	Art.box(parent,Vector3(0,0.025,0.13),Vector3(1.24,0.19,2.38),Color("235b7a"))
	for x: float in [-0.62,0.62]:
		Art.box(parent,Vector3(x,0.28,0.13),Vector3(0.12,0.42,2.42),Art.WOOD)
		Art.box(parent,Vector3(x,0.51,0.13),Vector3(0.16,0.07,2.45),Art.CREAM)
	Art.box(parent,Vector3(0,0.28,1.31),Vector3(1.22,0.42,0.12),Art.WOOD)
	Art.box(parent,Vector3(0,0.51,1.31),Vector3(1.32,0.07,0.16),Art.CREAM)
	for side: float in [-1,1]:
		var side_rail:=Art.box(parent,Vector3(side*0.32,0.28,-1.23),Vector3(0.12,0.42,0.74),Art.WOOD)
		side_rail.rotation.y=side*0.97
		var rail_cap:=Art.box(parent,Vector3(side*0.32,0.51,-1.23),Vector3(0.16,0.07,0.79),Art.CREAM)
		rail_cap.rotation.y=side*0.97
	for z: float in [-0.72,0.22,0.98]: Art.box(parent,Vector3(0,0.37,z),Vector3(1.18,0.1,0.24),Art.WOOD.lightened(0.12))

static func stone(parent: Node3D,at: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	if size.y<6.0: return Art.box(parent,at,size,color)
	# Far shores stay low wedge silhouettes instead of enormous floating cubes.
	var shape:=PrismMesh.new()
	shape.size=size
	shape.left_to_right=0.35
	var ridge:=MeshInstance3D.new()
	ridge.mesh=shape
	ridge.position=at
	ridge.material_override=Art.material(color)
	parent.add_child(ridge)
	return ridge

static func shore(parent: Node3D,center: Vector3,size: Vector3) -> void:
	# Legacy slab scenery API; the playable island uses Terrain.build.
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
		# Consume the original random sequence so the trees keep their sizes/yaw.
		var size: float=rng.randf_range(1.1,2.2)
		var yaw: float=rng.randf()*TAU
		if not flower and index%3!=0: continue
		prop(parent,"nature",("flower_yellowA" if index%2 else "flower_purpleA") if flower else "grass",at,Vector3.ONE*size,yaw)
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
	# The camp's warm woven mat is a visual footprint, never a new floor.
	Art.box(parent,Vector3(-30.15,2.025,23.1),Vector3(2.3,0.025,1.5),Color("c77750"))
	for offset: float in [-0.58,-0.42,0.42,0.58]:
		Art.box(parent,Vector3(-30.15,2.043,23.1+offset),Vector3(2.3,0.009,0.045),Color("efca8c"))

static func station_details(parent: Node3D) -> void:
	# A painted timber apron replaces the blank cream square visually, without
	# introducing collision or extending the station's navigable footprint.
	for plank in range(9):
		Art.box(parent,Vector3(-3.08+float(plank)*0.77,0.044,0),Vector3(0.73,0.018,6.92),Color("d3b582") if plank%3 else Color("c5a778"))
	for z: float in [-3.38,3.38]:
		Art.box(parent,Vector3(0,0.06,z),Vector3(6.96,0.025,0.09),Art.CREAM)
	Art.box(parent,Vector3(2.0,2.1,1.89),Vector3(1.30,0.43,0.09),Color("326d79"))
	# A tiny graphic fish reads at play distance without another floating label.
	Art.box(parent,Vector3(2.0,2.11,1.95),Vector3(0.52,0.16,0.025),Art.CREAM)
	var tail:=Art.box(parent,Vector3(2.31,2.11,1.95),Vector3(0.18,0.18,0.025),Art.CREAM)
	tail.rotation.z=PI*0.25
	Art.box(parent,Vector3(1.84,2.14,1.97),Vector3(0.04,0.04,0.015),Art.INK)
	Art.box(parent,Vector3(2,0.91,1.72),Vector3(0.81,0.05,0.61),Color("478797"))

static func dock_details(parent: Node3D) -> void:
	# Trim and rope wraps attach to the existing seaward piles.
	Art.box(parent,Vector3(-24.36,1.93,22.72),Vector3(6.73,0.17,0.12),Color("684e3c"))
	for x: float in [-26.46,-23.52,-21.21]:
		Art.box(parent,Vector3(x,2.69,22.66),Vector3(0.58,0.10,0.58),Art.CREAM)
		for y: float in [2.33,2.42]:
			Art.box(parent,Vector3(x,y,22.66),Vector3(0.54,0.045,0.54),Color("d9c79f"))
	# Two tied floats give the landing its own visual identity.
	for x: float in [-25.7,-25.0]:
		Art.beam(parent,Vector3(x,2.05,22.70),Vector3(x,0.67,22.98),0.032,Art.CREAM)
		Art.box(parent,Vector3(x,0.49,22.98),Vector3(0.37,0.53,0.37),Color("da8659"))
		Art.box(parent,Vector3(x,0.55,22.98),Vector3(0.385,0.14,0.385),Art.CREAM)

static func ground_cover(parent: Node3D) -> void:
	# All the small grass blades share one mesh/draw instead of hundreds of nodes.
	var rng:=RandomNumberGenerator.new()
	rng.seed=1831
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clusters: Array[Vector3]=[Vector3(-34,2,-19),Vector3(-34,2,-8),Vector3(-35,2,8),Vector3(-33,2,25),Vector3(-13,2,-29),Vector3(8,2,-29),Vector3(29,2,-27),Vector3(34,2,-16),Vector3(34,2,10),Vector3(27,2,27),Vector3(14,2,29),Vector3(-14,2,28)]
	for center: Vector3 in clusters:
		for index in range(18):
			var at: Vector3=center+Vector3(rng.randf_range(-2.6,2.6),0,rng.randf_range(-1.5,1.5))
			at.y=Terrain.height_at(at)
			if at.y<1.95: continue
			var tall: float=rng.randf_range(0.19,0.41)
			var blade_color: Color=Color("679859").lerp(Color("a5bb69"),rng.randf()*0.55)
			for blade in range(3):
				var angle: float=float(blade)*TAU/3.0+rng.randf()*0.5
				var side:=Vector3(cos(angle),0,sin(angle))*0.12
				for point: Vector3 in [at-side,at+Vector3(0.08,tall,0.04),at+side]:
					surface.set_color(blade_color)
					surface.add_vertex(point)
	surface.generate_normals()
	var cover:=MeshInstance3D.new()
	cover.name="CoastalGrassPatches"
	cover.mesh=surface.commit()
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=1.0
	cover.material_override=mat
	cover.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cover)

static func atmosphere(parent: Node3D) -> Array[Node3D]:
	var drifting: Array[Node3D]=[]
	# Broad, low block clouds give the sky a scale reference and frame the cove.
	for index in range(9):
		var angle: float=float(index)*TAU/9.0
		var cloud:=Node3D.new()
		cloud.name="SeaCloud"+str(index)
		cloud.position=Vector3(cos(angle)*130,25+float(index%3)*5,sin(angle)*130)
		cloud.set_meta("origin",cloud.position)
		parent.add_child(cloud)
		for piece in range(3):
			var block:=Art.box(cloud,Vector3(float(piece-1)*6,1.2 if piece==1 else 0,0.8 if piece==0 else 0),Vector3(9,2.0 if piece==1 else 1.1,4),Color("e7eff0"))
			block.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drifting.append(cloud)
	# A few sea stacks, made of deliberate stepped layers, ground the horizon.
	for at: Vector3 in [Vector3(-115,-1,-118),Vector3(145,-1,-95),Vector3(114,-1,112)]:
		Art.box(parent,at,Vector3(52,4,23),Color("698f92"))
		Art.box(parent,at+Vector3(-8,3,1),Vector3(31,5,18),Color("729c99"))
		Art.box(parent,at+Vector3(-13,5.9,0),Vector3(18,1.0,14),Color("83a58e"))
	return drifting
