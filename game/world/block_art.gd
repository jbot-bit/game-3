class_name BlockArt
extends RefCounted
## Original primitive models. All character pivots are local to their feet.

const INK: Color = Color("17334c")
const WATER: Color = Color("2589a0")
const GRASS: Color = Color("54a365")
const WOOD: Color = Color("a7764a")
const CREAM: Color = Color("fff1d1")
const AMBER: Color = Color("ffc15a")
const FishData = preload("res://game/fishing/species.gd")
static var _materials: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.92
	_materials[key] = result
	return result

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = pos
	parent.add_child(instance)
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = 1
		body.collision_mask = 1
		instance.add_child(body)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var volume: BoxShape3D = BoxShape3D.new()
		volume.size = size
		collision.shape = volume
		body.add_child(collision)
	return instance

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color, collide: bool = false) -> MeshInstance3D:
	var delta: Vector3 = b - a
	var result: MeshInstance3D = box(parent, (a + b) * 0.5, Vector3(width, delta.length(), width), color, collide)
	if delta.length_squared() > 0.0001:
		result.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return result

static func _pivot(parent: Node3D, pivot_name: String, position: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = pivot_name
	node.position = position
	parent.add_child(node)
	return node

static func _oval(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 12
	shape.rings = 6
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = pos
	instance.scale = size
	parent.add_child(instance)
	return instance

static func _taper(parent: Node3D, pos: Vector3, height: float, top: float, bottom: float, depth: float, color: Color, segments: int = 10) -> MeshInstance3D:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.height = height
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.radial_segments = segments
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material(color)
	instance.position = pos
	instance.scale.z = depth
	parent.add_child(instance)
	return instance

static func _fin(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, color: Color) -> MeshInstance3D:
	# Two sides with opposing normals: fins remain readable from either shoulder.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [a,b,c,c,b,a]: surface.add_vertex(point)
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

static func _chamfered(parent: Node3D, pos: Vector3, size: Vector3, bevel: float, color: Color) -> MeshInstance3D:
	var x: float = size.x*0.5
	var z: float = size.z*0.5
	var cut: float = minf(bevel,minf(x,z)*0.7)
	var ring: Array[Vector3] = [Vector3(-x+cut,0,-z),Vector3(x-cut,0,-z),Vector3(x,0,-z+cut),Vector3(x,0,z-cut),Vector3(x-cut,0,z),Vector3(-x+cut,0,z),Vector3(-x,0,z-cut),Vector3(-x,0,-z+cut)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var high: Vector3 = Vector3.UP*size.y*0.5
	var low: Vector3 = -high
	for index: int in range(8):
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[(index+1)%8]
		var vertices: Array[Vector3] = [high,b+high,a+high,low,a+low,b+low,a+low,a+high,b+high,a+low,b+high,b+low]
		# Godot front faces use clockwise winding.
		for triangle: int in range(4):
			for offset: int in [2,1,0]: surface.add_vertex(vertices[triangle*3+offset])
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material(color)
	instance.position = pos
	parent.add_child(instance)
	return instance

static func cache_crate(color: Color) -> Node3D:
	## Visual-only replacement; the island retains its authoritative box collider.
	var root: Node3D = Node3D.new()
	root.name = "CacheVisual"
	var timber: Color = Color("9b7652")
	_chamfered(root,Vector3(0,0.38,0),Vector3(1.45,0.75,0.92),0.1,timber)
	_chamfered(root,Vector3(0,0.75,0),Vector3(1.21,0.025,0.68),0.07,INK)
	for side: int in [-1,1]:
		for level: float in [0.24,0.48]:
			box(root,Vector3(0,level,float(side)*0.461),Vector3(1.23,0.018,0.012),WOOD.darkened(0.2))
		for x: float in [-0.57,0.57]:
			box(root,Vector3(x,0.38,float(side)*0.457),Vector3(0.075,0.72,0.035),color.darkened(0.1))
	var lid: Node3D = _pivot(root,"Lid",Vector3(0,0.78,-0.46))
	_chamfered(lid,Vector3(0,0,0.46),Vector3(1.52,0.16,0.98),0.105,timber.lightened(0.11))
	for x: float in [-0.57,0.57]:
		box(lid,Vector3(x,0.085,0.46),Vector3(0.085,0.03,0.87),color)
		box(lid,Vector3(x,0,0.946),Vector3(0.085,0.18,0.03),color)
	for z: float in [0.3,0.62]:
		box(lid,Vector3(0,0.082,z),Vector3(1.34,0.014,0.018),WOOD.darkened(0.1))
	_chamfered(root,Vector3(0,0.64,0.474),Vector3(0.16,0.25,0.055),0.025,AMBER)
	box(root,Vector3(0,0.66,0.506),Vector3(0.055,0.05,0.015),INK)
	for side: int in [-1,1]:
		_taper(root,Vector3(float(side)*0.72,0.49,0),0.07,0.105,0.105,0.7,INK,8).rotation.z=PI*0.5
	return root

static func lantern(parent: Node3D, at: Vector3, size: float = 1.0) -> MeshInstance3D:
	## The caller owns emission/power state through the returned glass material.
	var housing: Node3D = _pivot(parent,"Lantern",at)
	housing.scale = Vector3.ONE*size
	box(housing,Vector3(0,-0.43,0),Vector3(0.88,0.14,0.88),INK)
	var glass: MeshInstance3D = box(housing,Vector3.ZERO,Vector3(0.66,0.72,0.66),AMBER)
	glass.name = "Glass"
	for x: int in [-1,1]:
		for z: int in [-1,1]:
			box(housing,Vector3(float(x)*0.355,0,float(z)*0.355),Vector3(0.085,0.80,0.085),INK)
	box(housing,Vector3(0,0.44,0),Vector3(0.91,0.16,0.91),INK)
	box(housing,Vector3(0,0.55,0),Vector3(0.48,0.08,0.48),WOOD)
	# A thick squared handle reads from the normal camera and echoes the beacon.
	for side: int in [-1,1]:
		box(housing,Vector3(float(side)*0.18,0.72,0),Vector3(0.07,0.30,0.075),INK)
	box(housing,Vector3(0,0.87,0),Vector3(0.43,0.075,0.075),INK)
	return glass

static func lighthouse() -> Node3D:
	## Matches the existing 5.4 m shaft and 7.2 m glass anchor, without colliders.
	var root: Node3D = Node3D.new()
	root.name = "LighthouseVisual"
	var chalk: Color = Color("d5ccb5")
	box(root,Vector3(0,0.2,0),Vector3(4.64,0.4,4.64),Color("747f80"))
	box(root,Vector3(0,2.4,0),Vector3(4.08,4.0,4.08),chalk)
	box(root,Vector3(0,4.9,0),Vector3(3.50,1.0,3.50),chalk)
	box(root,Vector3(0,3.85,0),Vector3(4.12,0.48,4.12),WATER.darkened(0.1))
	# Two broad windows and a square door give the island's landmark human scale.
	box(root,Vector3(0,1.08,2.055),Vector3(0.84,1.36,0.06),WOOD.darkened(0.12))
	box(root,Vector3(0.24,1.03,2.097),Vector3(0.09,0.09,0.04),AMBER)
	for at: Vector3 in [Vector3(0,2.9,2.055),Vector3(0,4.82,1.765)]:
		box(root,at,Vector3(0.49,0.59,0.06),INK)
		box(root,at+Vector3(0,0.01,0.035),Vector3(0.055,0.51,0.015),chalk)
	box(root,Vector3(0,5.53,0),Vector3(4.92,0.26,4.92),INK)
	box(root,Vector3(0,5.70,0),Vector3(4.92,0.08,4.92),chalk)
	for side: int in [-1,1]:
		for cross: int in [-1,1]:
			box(root,Vector3(float(side)*2.23,6.1,float(cross)*2.23),Vector3(0.1,0.72,0.1),INK)
		box(root,Vector3(0,6.44,float(side)*2.23),Vector3(4.55,0.10,0.10),INK)
		box(root,Vector3(float(side)*2.23,6.44,0),Vector3(0.10,0.10,4.55),INK)
	box(root,Vector3(0,6.45,0),Vector3(2.9,0.19,2.9),INK)
	var glass: MeshInstance3D = box(root,Vector3(0,7.2,0),Vector3(2.2,1.3,2.2),WATER)
	glass.name = "Glass"
	for side: int in [-1,1]:
		for cross: int in [-1,1]:
			box(root,Vector3(float(side)*1.12,7.2,float(cross)*1.12),Vector3(0.15,1.44,0.15),INK)
	box(root,Vector3(0,8.04,0),Vector3(3.15,0.30,3.15),Color("765b58"))
	box(root,Vector3(0,8.26,0),Vector3(0.55,0.14,0.55),AMBER)
	return root

static func crew(color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BlockCrew"
	root.set_meta("crew_color",color)
	_pivot(root, "Torso", Vector3(0.0, 1.05, 0.0))
	_pivot(root, "Head", Vector3(0.0, 1.67, 0.0))
	_pivot(root, "LeftArm", Vector3(-0.5, 1.36, 0.0))
	var right_arm: Node3D = _pivot(root, "RightArm", Vector3(0.5, 1.36, 0.0))
	for side: int in [-1, 1]:
		_pivot(root, "LeftLeg" if side < 0 else "RightLeg", Vector3(float(side) * 0.21, 0.68, 0.0))
	_pivot(right_arm, "HeldTool", Vector3(0.0, -0.5, -0.05))
	set_outfit_appearance(root,"harbour")
	set_rod_appearance(root,"starter")
	return root

static func set_outfit_appearance(crew_root: Node3D, outfit_id: String) -> void:
	if outfit_id not in ["harbour","angler","deckhand","stormwatch"]: outfit_id = "harbour"
	if str(crew_root.get_meta("outfit_id","")) == outfit_id: return
	crew_root.set_meta("outfit_id",outfit_id)
	var identity: Color = crew_root.get_meta("crew_color",WATER) as Color
	var coat: Color = identity.darkened(0.05)
	var trousers: Color = Color("344b60")
	var trim: Color = CREAM
	var boot: Color = Color("374047")
	match outfit_id:
		"angler": coat = Color("729b78"); trousers = Color("42665f"); trim = Color("efd5a0"); boot = Color("806546")
		"deckhand": coat = Color("c47c51"); trousers = Color("354e67"); trim = Color("e8bb70"); boot = Color("434a54")
		"stormwatch": coat = Color("6678a9"); trousers = Color("343e67"); trim = Color("f6cc78"); boot = Color("525e7a")
	for pivot_name: String in ["Torso","Head","LeftArm","RightArm","LeftLeg","RightLeg"]:
		var pivot: Node3D = crew_root.get_node(pivot_name)
		for child: Node in pivot.get_children():
			if child.name != "HeldTool": child.free()
	var torso: Node3D = crew_root.get_node("Torso")
	_taper(torso,Vector3(0,-0.01,0),0.77,0.32,0.4,0.67,coat).name = "Coat"
	_taper(torso,Vector3(0,-0.36,0),0.07,0.4,0.4,0.67,trim)
	box(torso,Vector3(0,0.01,-0.264),Vector3(0.025,0.66,0.026),trim)
	for side: int in [-1,1]:
		_oval(torso,Vector3(float(side)*0.2,-0.12,-0.23),Vector3(0.21,0.18,0.07),coat.darkened(0.13))
		box(torso,Vector3(float(side)*0.21,0.14,0.22),Vector3(0.075,0.55,0.06),WOOD)
	_oval(torso,Vector3(0,0.1,0.3),Vector3(0.53,0.59,0.3),WOOD.darkened(0.07)).name = "Backpack"
	_oval(torso,Vector3(0,0.3,0.35),Vector3(0.5,0.21,0.25),trim.darkened(0.12))
	box(torso,Vector3(0,0.11,0.456),Vector3(0.08,0.17,0.035),AMBER)
	var scarf: Node3D = _pivot(torso,"CrewScarf",Vector3(0,0.35,0))
	_taper(scarf,Vector3.ZERO,0.13,0.25,0.29,0.82,identity)
	var scarf_end: MeshInstance3D = _oval(scarf,Vector3(-0.19,-0.17,-0.26),Vector3(0.14,0.38,0.065),identity)
	scarf_end.rotation.z = -0.2
	var head: Node3D = crew_root.get_node("Head")
	_oval(head,Vector3.ZERO,Vector3(0.59,0.56,0.54),CREAM).name = "Face"
	for side: int in [-1,1]:
		_oval(head,Vector3(float(side)*0.13,0.03,-0.254),Vector3(0.052,0.073,0.032),INK)
		_oval(head,Vector3(float(side)*0.285,-0.04,0),Vector3(0.1,0.14,0.13),CREAM.darkened(0.06))
	_oval(head,Vector3(0,-0.045,-0.278),Vector3(0.10,0.11,0.11),Color("d9b590"))
	# Distinct hats carry the set identity even when coats are hidden by cargo.
	match outfit_id:
		"angler":
			_taper(head,Vector3(0,0.23,0),0.055,0.43,0.45,0.90,trim).name = "HatBrim"
			_taper(head,Vector3(0,0.32,0),0.2,0.24,0.31,0.9,coat)
			_taper(head,Vector3(0,0.25,0),0.06,0.31,0.32,0.9,identity)
		"deckhand":
			_oval(head,Vector3(0,0.20,0.015),Vector3(0.62,0.31,0.57),trousers)
			_taper(head,Vector3(0,0.17,0),0.13,0.31,0.31,0.91,identity)
			_oval(head,Vector3(0.09,0.37,0),Vector3(0.13,0.12,0.13),trim)
		"stormwatch":
			_taper(head,Vector3(0,0.20,0),0.1,0.4,0.47,0.94,trim).name = "HatBrim"
			_taper(head,Vector3(0,0.35,0),0.3,0.13,0.37,0.9,coat)
			_taper(head,Vector3(0,0.23,0),0.045,0.34,0.37,0.9,identity)
		_:
			_oval(head,Vector3(0,0.2,0.015),Vector3(0.63,0.36,0.56),identity.darkened(0.2))
			_taper(head,Vector3(0,0.16,0),0.11,0.32,0.32,0.88,identity)
	for arm_name: String in ["LeftArm","RightArm"]:
		var arm: Node3D = crew_root.get_node(arm_name)
		_oval(arm,Vector3(0,-0.24,0),Vector3(0.28,0.64,0.31),coat)
		_taper(arm,Vector3(0,-0.41,0),0.10,0.135,0.135,1.05,identity)
		_oval(arm,Vector3(0,-0.58,-0.015),Vector3(0.24,0.23,0.25),CREAM)
	for leg_name: String in ["LeftLeg","RightLeg"]:
		var leg: Node3D = crew_root.get_node(leg_name)
		_oval(leg,Vector3(0,-0.23,0),Vector3(0.31,0.60,0.35),trousers)
		_taper(leg,Vector3(0,-0.44,0),0.19,0.16,0.17,1.02,boot)
		_oval(leg,Vector3(0,-0.56,-0.075),Vector3(0.36,0.23,0.52),boot)
		_oval(leg,Vector3(0,-0.625,-0.075),Vector3(0.37,0.085,0.53),INK)

static func set_rod_appearance(crew_root: Node3D, rod_id: String) -> void:
	var tool: Node3D = crew_root.get_node_or_null("RightArm/HeldTool") as Node3D
	if tool == null or str(tool.get_meta("rod_id","")) == rod_id: return
	for child: Node in tool.get_children():
		child.free()
	tool.set_meta("rod_id",rod_id)
	var color: Color = {"starter":WOOD,"soft_tip":WATER,"braced_reel":INK,"drift_rod":Color("a28ad6")}.get(rod_id,WOOD) as Color
	beam(tool,Vector3.ZERO,Vector3(0,1.6,-0.53),0.045,color)
	box(tool,Vector3(0.07,0.2,-0.07),Vector3(0.16,0.18,0.14) * (1.45 if rod_id=="braced_reel" else 1.0),AMBER)
	box(tool,Vector3(0,1.63,-0.54),Vector3(0.07,0.07,0.07),CREAM).name = "RodTip"
	if rod_id=="soft_tip":
		beam(tool,Vector3(0,1.15,-0.38),Vector3(0,1.6,-0.53),0.075,Color("8acacc"))
	elif rod_id=="braced_reel":
		box(tool,Vector3(0.0,0.65,-0.22),Vector3(0.14,0.38,0.15),Color("b78a5f"))
	elif rod_id=="drift_rod":
		for side: int in [-1,1]:
			box(tool,Vector3(float(side)*0.09,1.2,-0.4),Vector3(0.08,0.25,0.07),CREAM)

static func fish_dimensions(species_id: String) -> Vector3:
	match species_id:
		"bellgill", "bell_gill": return Vector3(0.66,0.68,0.38)
		"lantern_eel", "eel": return Vector3(1.24,0.23,0.23)
		"pebble_dab": return Vector3(0.86,0.20,0.56)
		"ribbon_minnow": return Vector3(0.96,0.24,0.23)
		"moss_skipper": return Vector3(0.62,0.38,0.44)
		"cork_chub": return Vector3(0.82,0.56,0.50)
		"kite_sprat": return Vector3(0.60,0.46,0.26)
		"glass_roach": return Vector3(0.82,0.46,0.28)
		"copperfin": return Vector3(0.88,0.40,0.30)
		"cloud_carp": return Vector3(0.93,0.60,0.45)
		"crown_ray": return Vector3(0.68,0.20,0.82)
	return Vector3(0.72,0.38,0.30)

static func fish_collision_dimensions(species_id: String, oversized: bool = true) -> Vector3:
	## Stable, centred cargo boxes. Decorative trait marks never enlarge them.
	var dimensions: Dictionary = {
		"penny_perch":Vector3(1.9,0.65,0.6), "bellgill":Vector3(1.7,1.25,0.7),
		"lantern_eel":Vector3(2.5,0.45,0.45), "pebble_dab":Vector3(2.3,0.65,1.25),
		"ribbon_minnow":Vector3(2.5,0.75,0.7), "moss_skipper":Vector3(1.9,1.2,1.1),
		"cork_chub":Vector3(2.2,1.2,1.2), "kite_sprat":Vector3(1.9,1.6,0.7),
		"glass_roach":Vector3(2.15,0.95,0.7), "copperfin":Vector3(2.3,1.1,0.8),
		"cloud_carp":Vector3(2.4,1.3,1.1), "crown_ray":Vector3(2.2,0.8,2.5)
	}
	var size: Vector3 = dimensions.get(species_id,dimensions.penny_perch) as Vector3
	return size if oversized else size / 1.55

static func fish(species_id: String, oversized: bool = false, trait_id: String = "none") -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BlockFish"
	var species: String = species_id.to_lower().replace(" ", "_")
	if species == "bell_gill": species = "bellgill"
	if species == "eel": species = "lantern_eel"
	var data: Dictionary = FishData.catalog().get(species,FishData.catalog().penny_perch)
	var size: Vector3 = fish_dimensions(species)
	var body_color: Color = Color(str(data.color))
	var patch_color: Color = Color(str(data.accent))
	if trait_id == "moonlit":
		body_color = body_color.lerp(Color("b7d4e4"),0.45)
		patch_color = Color("d9eff4")
	elif trait_id == "stormmarked":
		body_color = body_color.darkened(0.2)
		patch_color = AMBER
	box(root, Vector3.ZERO, size, body_color).name = "Body"
	box(root, Vector3(size.x*0.04,-size.y*0.35,0), Vector3(size.x*0.90,size.y*0.27,size.z*1.035),patch_color.lightened(0.15))
	var tail: Node3D = _pivot(root, "Tail", Vector3(-size.x * 0.5, 0.0, 0.0))
	var tail_height: float = maxf(size.y*0.58,0.16)
	_fin(tail,Vector3(0.045,0,0),Vector3(-0.3,tail_height,0),Vector3(-0.24,0,0),patch_color)
	_fin(tail,Vector3(0.045,0,0),Vector3(-0.24,0,0),Vector3(-0.3,-tail_height,0),patch_color)
	var dorsal_height: float = size.y*0.82 if species=="kite_sprat" else size.y*0.40
	if species != "crown_ray":
		_fin(root,Vector3(-size.x*0.32,size.y*0.27,0),Vector3(-size.x*0.14,size.y*0.5+dorsal_height,0),Vector3(size.x*0.20,size.y*0.40,0),patch_color).name = "DorsalFin"
	for side: int in [-1, 1]:
		var sign_z: float = float(side)
		box(root,Vector3(size.x*0.31,size.y*0.15,sign_z*(size.z*0.5+0.013)),Vector3(0.12,0.12,0.033),CREAM)
		box(root,Vector3(size.x*0.34,size.y*0.15,sign_z*(size.z*0.5+0.035)),Vector3(0.055,0.075,0.016),INK)
		_fin(root,Vector3(0,-size.y*0.12,sign_z*size.z*0.5),Vector3(-size.x*0.21,-size.y*0.38,sign_z*(size.z*0.6+0.12)),Vector3(-size.x*0.23,size.y*0.06,sign_z*size.z*0.5),patch_color)
	box(root,Vector3(size.x*0.5+0.015,-size.y*0.05,0),Vector3(0.035,size.y*0.21,size.z*0.37),patch_color)
	match str(data.shape):
		"perch", "bell":
			for side: int in [-1,1]:
				for index: int in range(3):
					var stripe: MeshInstance3D = box(root,Vector3(-size.x*0.22+float(index)*size.x*0.18,0.035,float(side)*(size.z*0.5+0.009)),Vector3(0.035,size.y*0.59,0.025),body_color.darkened(0.3))
					stripe.rotation.z = -0.15
		"dab":
			for side: int in [-1,1]:
				box(root,Vector3(0.23,0.10,float(side)*0.12),Vector3(0.1,0.07,0.1),CREAM)
				box(root,Vector3(0.245,0.135,float(side)*0.12),Vector3(0.05,0.02,0.05),INK)
			for point: Vector3 in [Vector3(-0.16,0.112,0.11),Vector3(0.04,0.112,-0.14),Vector3(-0.22,0.112,-0.12)]:
				box(root,point,Vector3(0.09,0.035,0.085),patch_color)
		"minnow":
			_fin(tail,Vector3.ZERO,Vector3(-0.43,0.13,0.035),Vector3(-0.31,-0.02,0),patch_color)
			for side: int in [-1,1]:
				box(root,Vector3(0,0.035,float(side)*0.126),Vector3(0.67,0.045,0.025),patch_color)
		"skipper":
			for side: int in [-1,1]:
				box(root,Vector3(0.17,0.20,float(side)*0.14),Vector3(0.16,0.19,0.14),CREAM)
				box(root,Vector3(0.241,0.22,float(side)*0.15),Vector3(0.035,0.08,0.07),INK)
				box(root,Vector3(-0.11,-0.16,float(side)*0.27),Vector3(0.21,0.12,0.26),patch_color)
		"chub":
			box(root,Vector3(0.395,-0.04,0),Vector3(0.13,0.22,0.27),patch_color)
			box(root,Vector3(0.458,-0.04,0),Vector3(0.03,0.09,0.12),INK)
		"roach":
			for side: int in [-1,1]:
				box(root,Vector3(-0.025,0.02,float(side)*0.151),Vector3(0.59,0.055,0.027),patch_color)
		"copper":
			for index: int in range(3):
				var x: float = -0.23+float(index)*0.16
				_fin(root,Vector3(x-0.07,0.15,0),Vector3(x,0.40,0),Vector3(x+0.08,0.16,0),patch_color)
		"carp":
			for side: int in [-1,1]:
				beam(root,Vector3(0.47,-0.15,float(side)*0.12),Vector3(0.61,-0.34,float(side)*0.17),0.04,patch_color)
				box(root,Vector3(-0.13,0.09,float(side)*0.238),Vector3(0.25,0.18,0.035),CREAM)
		"eel":
			box(root,Vector3(0.47,0.08,0),Vector3(0.25,0.3,0.27),body_color)
			beam(root,Vector3(0.45,0.17,0),Vector3(0.56,0.34,0),0.033,patch_color)
			box(root,Vector3(0.59,0.35,0),Vector3(0.17,0.15,0.15),AMBER)
		"ray":
			for side: int in [-1,1]:
				_fin(root,Vector3(0.23,0.015,float(side)*0.24),Vector3(-0.16,-0.05,float(side)*0.9),Vector3(-0.37,-0.025,float(side)*0.12),body_color)
				_fin(root,Vector3(0.12,0.03,float(side)*0.24),Vector3(-0.16,-0.04,float(side)*0.8),Vector3(-0.19,0.03,float(side)*0.3),patch_color)
			for index: int in range(3):
				box(root,Vector3(0.21,0.16,float(index-1)*0.14),Vector3(0.08,0.2 if index==1 else 0.13,0.08),patch_color)
			beam(tail,Vector3.ZERO,Vector3(-0.35,0.0,0.0),0.06,patch_color)
	if trait_id in ["moonlit","stormmarked"]:
		var marks: Node3D = _pivot(root,"TraitMark",Vector3.ZERO)
		for side: int in [-1,1]:
			if trait_id == "moonlit":
				box(marks,Vector3(-0.03,size.y*0.15,float(side)*(size.z*0.5+0.026)),Vector3(size.x*0.58,0.045,0.028),Color("e0f4f5"))
			else:
				for index: int in range(3):
					var stripe: MeshInstance3D = box(marks,Vector3(float(index-1)*0.17,0,float(side)*(size.z*0.5+0.026)),Vector3(0.065,size.y*0.68,0.035),AMBER)
					stripe.rotation.z = -0.35
	if oversized:
		root.scale = Vector3.ONE * 1.55
	return root

static func hunter() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "LastLifeguard"
	beam(root, Vector3(-0.42, 0.1, 0.0), Vector3(-0.26, 2.55, 0.0), 0.23, INK)
	beam(root, Vector3(0.54, 0.1, 0.08), Vector3(0.28, 2.6, 0.0), 0.23, INK)
	box(root, Vector3(0.0, 2.66, 0.0), Vector3(1.1, 1.1, 0.48), INK)
	beam(root, Vector3(-0.62, 3.08, 0.0), Vector3(-0.88, 1.55, -0.25), 0.2, INK)
	beam(root, Vector3(0.59, 3.08, 0.0), Vector3(0.99, 1.91, -0.25), 0.2, INK)
	var ring: Node3D = _pivot(root, "Head", Vector3(0.11, 3.76, -0.02))
	ring.rotation.z = -0.13
	var lifering: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.32
	ring_mesh.outer_radius = 0.56
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	lifering.mesh = ring_mesh
	lifering.material_override = material(CREAM)
	lifering.rotation.x = PI*0.5
	ring.add_child(lifering)
	_oval(ring,Vector3(0,0.44,-0.09),Vector3(0.25,0.23,0.13),Color("a76556"))
	return root

static func add_odd_appearance(fish_root: Node3D, species_id: String) -> Node3D:
	## A purely visual joke: no catch trait, size, value or collision changes.
	var existing: Node3D = fish_root.get_node_or_null("OddHat") as Node3D
	if existing != null:
		return existing
	var hat: Node3D = _pivot(fish_root, "OddHat", Vector3(0.16, fish_dimensions(species_id).y * 0.5 + 0.07, 0.0))
	hat.rotation.z = -0.18
	box(hat, Vector3.ZERO, Vector3(0.55, 0.08, 0.43), INK)
	box(hat, Vector3(0, 0.2, 0), Vector3(0.32, 0.36, 0.3), INK)
	box(hat, Vector3(0, 0.1, 0), Vector3(0.335, 0.08, 0.315), AMBER)
	return hat
