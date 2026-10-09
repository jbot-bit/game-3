class_name BlockArt
extends RefCounted
## Original primitive models. All character pivots are local to their feet.

const INK: Color = Color("202d3a")
const WATER: Color = Color("397884")
const GRASS: Color = Color("77935b")
const WOOD: Color = Color("826347")
const CREAM: Color = Color("e4d4af")
const AMBER: Color = Color("ffd071")
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

static func crew(color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BlockCrew"
	var torso: Node3D = _pivot(root, "Torso", Vector3(0.0, 1.05, 0.0))
	box(torso, Vector3.ZERO, Vector3(0.74, 0.78, 0.44), color)
	box(torso, Vector3(0.0, -0.27, -0.235), Vector3(0.7, 0.09, 0.035), CREAM)
	box(torso, Vector3(0.0, 0.15, 0.27), Vector3(0.49, 0.52, 0.23), WOOD)
	box(torso, Vector3(0.0, 0.2, 0.4), Vector3(0.21, 0.15, 0.04), AMBER)
	var head: Node3D = _pivot(root, "Head", Vector3(0.0, 1.67, 0.0))
	box(head, Vector3.ZERO, Vector3(0.6, 0.54, 0.54), CREAM)
	box(head, Vector3(-0.13, 0.025, -0.279), Vector3(0.065, 0.075, 0.025), INK)
	box(head, Vector3(0.13, 0.025, -0.279), Vector3(0.065, 0.075, 0.025), INK)
	box(head, Vector3(0.0, 0.29, 0.0), Vector3(0.68, 0.09, 0.62), color.darkened(0.24))
	var left_arm: Node3D = _pivot(root, "LeftArm", Vector3(-0.5, 1.36, 0.0))
	var right_arm: Node3D = _pivot(root, "RightArm", Vector3(0.5, 1.36, 0.0))
	for arm: Node3D in [left_arm, right_arm]:
		box(arm, Vector3(0.0, -0.25, 0.0), Vector3(0.26, 0.55, 0.3), color)
		box(arm, Vector3(0.0, -0.57, 0.0), Vector3(0.26, 0.18, 0.3), CREAM)
	for side: int in [-1, 1]:
		var leg: Node3D = _pivot(root, "LeftLeg" if side < 0 else "RightLeg", Vector3(float(side) * 0.21, 0.68, 0.0))
		box(leg, Vector3(0.0, -0.25, 0.0), Vector3(0.31, 0.5, 0.36), INK)
		box(leg, Vector3(0.0, -0.56, -0.045), Vector3(0.34, 0.2, 0.48), color.darkened(0.32))
	var tool: Node3D = _pivot(right_arm, "HeldTool", Vector3(0.0, -0.5, -0.05))
	beam(tool, Vector3.ZERO, Vector3(0.0, 1.6, -0.53), 0.045, WOOD)
	box(tool, Vector3(0.07, 0.2, -0.07), Vector3(0.16, 0.18, 0.14), AMBER)
	box(tool, Vector3(0.0, 1.63, -0.54), Vector3(0.07, 0.07, 0.07), CREAM)
	return root

static func fish(species_id: String, oversized: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BlockFish"
	var species: String = species_id.to_lower().replace(" ", "_")
	var size: Vector3 = Vector3(0.72, 0.38, 0.3)
	var body_color: Color = Color("d99b54")
	var patch_color: Color = Color("bd624d")
	if species in ["bellgill", "bell_gill"]:
		size = Vector3(0.66, 0.68, 0.38)
		body_color = Color("7ea8a3")
		patch_color = CREAM
	elif species in ["lantern_eel", "eel"]:
		size = Vector3(1.24, 0.23, 0.23)
		body_color = Color("727899")
		patch_color = AMBER
	box(root, Vector3.ZERO, size, body_color)
	box(root, Vector3(size.x * 0.25, -size.y * 0.33, 0.0), Vector3(size.x * 0.38, size.y * 0.34, size.z * 1.03), patch_color)
	var tail: Node3D = _pivot(root, "Tail", Vector3(-size.x * 0.5, 0.0, 0.0))
	var fin: MeshInstance3D = box(tail, Vector3(-0.14, 0.0, 0.0), Vector3(0.3, size.y * 0.63, 0.1), patch_color)
	fin.rotation.z = PI * 0.25
	for side: int in [-1, 1]:
		box(root, Vector3(size.x * 0.32, size.y * 0.18, float(side) * (size.z * 0.5 + 0.013)), Vector3(0.075, 0.075, 0.027), INK)
		box(root, Vector3(-size.x * 0.03, -size.y * 0.1, float(side) * size.z * 0.5), Vector3(0.13, 0.08, 0.18), patch_color)
	if species in ["bellgill", "bell_gill"]:
		for index: int in range(3):
			box(root, Vector3(0.12 - float(index) * 0.13, 0.0, size.z * 0.51), Vector3(0.04, 0.28, 0.018), INK)
		box(root, Vector3(-0.12, 0.39, 0.0), Vector3(0.23, 0.14, 0.1), AMBER)
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
	box(ring, Vector3(0.0, 0.46, 0.0), Vector3(1.12, 0.24, 0.28), CREAM)
	box(ring, Vector3(0.0, -0.46, 0.0), Vector3(1.12, 0.24, 0.28), CREAM)
	box(ring, Vector3(-0.44, 0.0, 0.0), Vector3(0.24, 0.72, 0.28), CREAM)
	box(ring, Vector3(0.44, 0.0, 0.0), Vector3(0.24, 0.72, 0.28), CREAM)
	box(ring, Vector3(0.0, 0.46, -0.155), Vector3(0.28, 0.24, 0.04), Color("a76556"))
	return root

static func add_odd_appearance(fish_root: Node3D, species_id: String) -> Node3D:
	## A purely visual joke: no catch trait, size, value or collision changes.
	var existing: Node3D = fish_root.get_node_or_null("OddHat") as Node3D
	if existing != null:
		return existing
	var hat: Node3D = _pivot(fish_root, "OddHat", Vector3(0.16, 0.26, 0.0))
	if species_id in ["bellgill", "bell_gill"]:
		hat.position.y = 0.43
	elif species_id in ["lantern_eel", "eel"]:
		hat.position.y = 0.16
	hat.rotation.z = -0.18
	box(hat, Vector3.ZERO, Vector3(0.55, 0.08, 0.43), INK)
	box(hat, Vector3(0, 0.2, 0), Vector3(0.32, 0.36, 0.3), INK)
	box(hat, Vector3(0, 0.1, 0), Vector3(0.335, 0.08, 0.315), AMBER)
	return hat
