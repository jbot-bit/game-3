extends GutTest

const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const LevelData = preload("res://prototypes/physics_party/party_level_data.gd")
const LevelWorld = preload("res://prototypes/physics_party/party_level_world.gd")


func test_twenty_courses_form_one_complete_cycle() -> void:
	assert_eq(Courses.IDS.size(), 20, "The pack contains twenty selectable courses")
	var seen: Array[String] = []
	var current: String = "crossing"
	for index in 20:
		assert_true(Courses.valid(current))
		assert_false(current in seen, "Every course appears once before the cycle wraps")
		seen.append(current)
		current = Courses.next_id(current)
	assert_eq(current, "crossing")
	assert_eq(seen.size(), 20)


func test_catalog_has_stable_names_numbers_and_safe_unknown_ids() -> void:
	assert_eq(Courses.IDS[0], "crossing")
	assert_eq(Courses.IDS[1], "counterweight")
	var names: Array[String] = []
	for index in Courses.IDS.size():
		var id: String = Courses.IDS[index]
		assert_eq(Courses.number(id), index + 1)
		assert_false(Courses.course_name(id) in names)
		names.append(Courses.course_name(id))
	assert_false(Courses.valid("../main"))
	assert_eq(Courses.number("../main"), 0)
	assert_eq(Courses.next_id("../main"), "crossing")
	assert_true(LevelData.course("../main").is_empty())


func test_each_added_course_has_a_distinct_bounded_route_and_no_power_requirement() -> void:
	var fingerprints: Array[String] = []
	var wind_courses: int = 0
	var bridge_courses: int = 0
	var jump_courses: int = 0
	for id: String in Courses.IDS.slice(2):
		var data: Dictionary = LevelData.course(id)
		assert_false(data.is_empty(), id)
		if data.is_empty():
			continue
		assert_eq(data.id, id)
		assert_gte(data.route.size(), 5, id + " has a complete route")
		assert_gt(data.checkpoint_index, 0)
		assert_lt(data.checkpoint_index, data.route.size() - 1)
		var fingerprint: String = str(data.route)
		assert_false(fingerprint in fingerprints, id + " has its own layout")
		fingerprints.append(fingerprint)
		for point: Vector3 in data.route:
			assert_true(point.is_finite())
			assert_lt(point.length(), 120.0)
			assert_between(point.y, 0.0, 9.0)
		var bridges: int = 0
		for link: Dictionary in data.links:
			assert_gte(float(link.width), 2.4, id + " permits normal movement")
			var span: Vector3 = link.to - link["from"]
			var horizontal := Vector2(span.x, span.z).length()
			assert_lt(absf(span.y) / horizontal, 0.18, id + " has walkable slopes")
			if link.kind == "bridge":
				bridges += 1
		assert_lte(4 + bridges, 9, id + " stays within the prop budget")
		bridge_courses += 1 if bridges > 0 else 0
		wind_courses += 1 if not data.winds.is_empty() else 0
		jump_courses += 1 if not data.route_jumps.is_empty() else 0
	assert_gte(bridge_courses, 5)
	assert_gte(wind_courses, 4)
	assert_gte(jump_courses, 5)


func test_mutating_one_course_copy_does_not_change_another_run() -> void:
	var altered: Dictionary = LevelData.course("dogleg")
	altered.route[0] = Vector3(90, 90, 90)
	altered.links[0].width = 0.1
	var fresh: Dictionary = LevelData.course("dogleg")
	assert_eq(fresh.route[0], Vector3(0, 0, 3))
	assert_gt(float(fresh.links[0].width), 2.4)


func test_rotated_loose_bridges_reset_and_replicate_in_the_selected_world() -> void:
	var host = LevelWorld.new()
	host.course_id = "split_decision"
	add_child_autofree(host)
	var client = LevelWorld.new()
	client.course_id = "split_decision"
	client.authoritative = false
	add_child_autofree(client)
	var initial: Dictionary = host.capture_prop_poses()
	assert_eq(initial.size(), 6)
	assert_eq(host.required_route_supports(), ["plank_2", "plank_4"])
	for id: String in initial:
		assert_true(client.props[id].freeze)
		assert_eq(client.capture_prop_poses()[id], initial[id], id + " deterministic initial layout")
	var plank: RigidBody3D = host.props.plank_2
	plank.position += Vector3(3, 5, 1)
	plank.rotate_y(0.3)
	var moved: Dictionary = host.capture_prop_poses()
	client.present_prop_poses(moved)
	assert_eq(client.props.plank_2.global_transform, moved.plank_2)
	host.reset_props()
	assert_eq(plank.global_transform, initial.plank_2, "Reset restores both position and diagonal orientation")


func test_wind_reverses_only_inside_the_course_wind_zones() -> void:
	var world = LevelWorld.new()
	world.course_id = "crosswind"
	add_child_autofree(world)
	assert_eq(world.wind_at(Vector3.ZERO), Vector3.ZERO)
	var blowing := Vector3(8, 2, -10)
	var before: Vector3 = world.wind_at(blowing)
	assert_gt(before.length(), 1.0)
	world.set_wind(-1)
	assert_eq(world.wind_at(blowing), -before)
	world.reset_props()
	assert_eq(world.wind_at(blowing), before)
