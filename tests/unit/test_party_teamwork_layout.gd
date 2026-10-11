extends GutTest

const World = preload("res://prototypes/physics_party/party_world.gd")
const Counterweight = preload("res://prototypes/physics_party/party_counterweight_world.gd")
const LevelWorld = preload("res://prototypes/physics_party/party_level_world.gd")
const Teamwork = preload("res://prototypes/physics_party/party_teamwork.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")

func _fixture(id: String) -> Node3D:
	var world: Node3D = World.new() if id == "crossing" else (Counterweight.new() if id == "counterweight" else LevelWorld.new())
	if world is LevelWorld: world.course_id = id
	world.setup(false)
	add_child(world)
	return world

func _boxes(parent: Node) -> Array[CollisionShape3D]:
	var result: Array[CollisionShape3D] = []
	for node: Node in parent.find_children("*", "CollisionShape3D", true, false):
		if node.shape is BoxShape3D: result.append(node)
	return result

func _bounds(boxes: Array[CollisionShape3D]) -> AABB:
	var result := AABB()
	for index in boxes.size():
		var collider: CollisionShape3D = boxes[index]
		var size: Vector3 = collider.shape.size
		var current: AABB = collider.global_transform * AABB(-size * 0.5, size)
		result = current if index == 0 else result.merge(current)
	return result

func _intersects(a: CollisionShape3D, b: CollisionShape3D, trim_start: float = 0) -> bool:
	# SAT tests the oriented collision boxes, avoiding diagonal-course AABB false positives.
	var a_size: Vector3 = a.shape.size
	var a_center: Vector3 = a.global_position
	if trim_start > 0:
		a_size.z -= trim_start
		a_center -= a.global_basis.z * trim_start * 0.5
	var axes: Array[Vector3] = [a.global_basis.x, a.global_basis.y, a.global_basis.z,
		b.global_basis.x, b.global_basis.y, b.global_basis.z]
	for aa: Vector3 in [a.global_basis.x, a.global_basis.y, a.global_basis.z]:
		for bb: Vector3 in [b.global_basis.x, b.global_basis.y, b.global_basis.z]: axes.append(aa.cross(bb))
	var separation: Vector3 = b.global_position - a_center
	for axis: Vector3 in axes:
		if axis.length_squared() < 0.00001: continue
		axis = axis.normalized()
		var radius: float = 0
		for index in 3:
			radius += absf(axis.dot(a.global_basis[index])) * a_size[index] * 0.5
			radius += absf(axis.dot(b.global_basis[index])) * b.shape.size[index] * 0.5
		if absf(axis.dot(separation)) >= radius - 0.04: return false
	return true

func _finish_join_length(approach: CollisionShape3D, original: Array[CollisionShape3D]) -> float:
	# The approach deliberately shares the finish deck and the last walkway endpoint.
	# Trim only as far as that deck's forward edge; audit the entire exposed approach.
	var forward: Vector3 = -approach.global_basis.z
	for collider: CollisionShape3D in original:
		if collider.get_parent().name != "Finish": continue
		var radius: float = 0
		for index in 3: radius += absf(forward.dot(collider.global_basis[index])) * collider.shape.size[index] * 0.5
		return (collider.global_position - approach.global_position).dot(forward) + radius + approach.shape.size.z * 0.5
	return 0

func test_twenty_teamwork_tails_do_not_cross_the_original_playable_course() -> void:
	for id: String in Courses.IDS:
		var world := _fixture(id)
		var original: Array[CollisionShape3D] = _boxes(world)
		var module := Teamwork.new()
		module.world = world
		module.course_id = id
		world.add_child(module)
		var overlaps: Array[String] = []
		for opened: bool in [false, true]:
			if opened: module.present({"version": 1, "latched": [true, true, true], "amounts": [1.0, 1.0, 1.0]})
			for tail: CollisionShape3D in _boxes(module):
				var trim: float = _finish_join_length(tail, original) if tail.get_parent().name == "TeamApproach" else 0.0
				for base: CollisionShape3D in original:
					if _intersects(tail, base, trim):
						var pair: String = str(tail.get_parent().name) + "/" + str(base.get_parent().name)
						if not pair in overlaps: overlaps.append(pair)
		assert_eq(overlaps, [], id + " has only its intended finish-to-approach join")
		world.free()

func test_backdrop_relocation_preserves_physics_and_clears_every_course_tail() -> void:
	for id: String in Courses.IDS:
		var world := _fixture(id)
		assert_eq(world.get_node("BackgroundCraneLeft").position, Vector3(-32, -8, -42), "The original backdrop stays unchanged before a tail is added")
		assert_eq(world.get_node("BackgroundCraneRight").position, Vector3(32, -8, -42))
		var module := Teamwork.new()
		module.world = world
		module.course_id = id
		world.add_child(module)
		var boxes: Array[CollisionShape3D] = _boxes(world)
		var transforms: Array[Transform3D] = []
		for box: CollisionShape3D in boxes: transforms.append(box.global_transform)
		world.clear_background_obstructions()
		var play_bounds: AABB = _bounds(boxes).grow(5.0)
		var crane_positions: Array[Vector3] = []
		for crane: Node3D in world._background_cranes:
			crane_positions.append(crane.global_position)
			assert_lt(crane.global_position.length(), 600.0, id + " backdrop remains bounded")
			for visual: Node in crane.find_children("*", "MeshInstance3D", true, false):
				assert_false(play_bounds.intersects(visual.global_transform * visual.get_aabb()), id + " crane stays outside the expanded playable bounds")
		world.clear_background_obstructions()
		for index in world._background_cranes.size():
			assert_eq(world._background_cranes[index].global_position, crane_positions[index], "Repeated calls do not drift decoration")
		for index in boxes.size(): assert_eq(boxes[index].global_transform, transforms[index], "Backdrop relocation cannot move physics geometry")
		world.free()
