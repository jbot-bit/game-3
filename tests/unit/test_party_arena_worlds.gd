extends GutTest

const Arena = preload("res://prototypes/physics_party/party_arena_world.gd")
const Wipeout = preload("res://prototypes/physics_party/party_wipeout_world.gd")


func make_world(script: GDScript, host: bool = true):
	var world = script.new()
	world.setup(host)
	add_child_autofree(world)
	return world


func test_arena_has_three_separated_supported_spawns_and_no_rescue_floor() -> void:
	var world = make_world(Arena)
	await get_tree().physics_frame
	for slot in 3:
		var at: Vector3 = world.spawn_point(slot)
		assert_true(world.arena_contains(at))
		assert_gt(at.distance_to(world.spawn_point((slot + 1) % 3)), 6.0)
		var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 10, 1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		assert_false(hit.is_empty(), "Each starting place has a real pad")
		if not hit.is_empty(): assert_almost_eq(hit.position.y, 4.0, 0.01)
	var outside := PhysicsRayQueryParameters3D.create(Vector3(0, 4, 13), Vector3(0, -12, 13), 1)
	assert_true(world.get_world_3d().direct_space_state.intersect_ray(outside).is_empty(), "Pool and bleachers cannot catch eliminated players")
	assert_false(world.arena_contains(Vector3(0, -2.1, 0)))
	assert_false(world.arena_contains(Vector3(20, 5, 0)))
	assert_false(world.goal_contains(world.spawn_point(0)))
	assert_eq(world.props.size(), 0)


func test_wipeout_checkpoint_islands_reject_flying_underwater_and_wrong_positions() -> void:
	var world = make_world(Wipeout)
	for checkpoint in range(1, 4):
		var at: Vector3 = world.spawn_point(1, checkpoint)
		assert_eq(world.checkpoint_index(at), checkpoint)
		assert_eq(world.checkpoint_index(at + Vector3.UP * 10), 0)
		assert_eq(world.checkpoint_index(at + Vector3.DOWN * 10), 0)
		assert_eq(world.checkpoint_index(at + Vector3.RIGHT * 9), 0)
	assert_eq(world.checkpoint_index(world.goal_spawn(1)), 0, "Goal cannot fabricate the three checkpoint visits")
	assert_true(world.goal_contains(world.goal_spawn(1)))
	assert_false(world.goal_contains(world.goal_spawn(1) + Vector3.UP * 10))
	assert_gt(world.spawn_point(1).distance_to(world.goal_spawn(1)), 125.0)
	assert_eq(world.props.size(), 2)
	assert_eq(world.movers.size(), 2)
	assert_eq(world.find_children("*Hinge", "HingeJoint3D", true, false).size(), 2)
	assert_eq(world.route_jumps().size(), 6)


func test_movers_are_host_owned_resettable_and_client_presented_without_simulation() -> void:
	var world = make_world(Wipeout)
	world.set_physics_process(false)
	var initial: Dictionary = world.capture_movers()
	world._physics_process(0.1)
	await get_tree().physics_frame
	# physics_frame fires before the server consumes sync_to_physics transforms.
	# Cross a full boundary before inspecting the physical mover pose.
	await get_tree().physics_frame
	var later: Dictionary = world.capture_movers()
	assert_ne(initial.SweepOne.basis, later.SweepOne.basis)
	world.reset_props()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_almost_eq(world.capture_movers().SweepOne.basis.get_euler().y, initial.SweepOne.basis.get_euler().y, 0.001)
	world.free()
	var client = make_world(Wipeout, false)
	client.set_physics_process(false)
	assert_eq(client.find_children("*Hinge", "HingeJoint3D", true, false).size(), 0)
	for body: RigidBody3D in client.props.values(): assert_true(body.freeze)
	for body: AnimatableBody3D in client.movers.values(): assert_eq(body.collision_layer, 0)
	client.apply_presented_movers(later)
	assert_eq(client.capture_movers(), later)
	client._physics_process(0.1)
	assert_eq(client.capture_movers(), later, "Clients never advance obstacle physics on their own")
	var bad: Dictionary = later.duplicate(true)
	bad.SweepOne.origin += Vector3.RIGHT * 30
	client.apply_presented_movers(bad)
	assert_eq(client.capture_movers(), later, "Invalid sweeper translations cannot relocate a hazard")
	client.apply_presented_movers({"SweepOne": "bad", "untrusted": Transform3D.IDENTITY})
	assert_eq(client.capture_movers(), later)
	var stretched: Dictionary = later.duplicate(true)
	stretched.SweepOne.basis = stretched.SweepOne.basis.scaled(Vector3(2, 1, 0.5))
	client.apply_presented_movers(stretched)
	assert_eq(client.capture_movers(), later, "Even unit-determinant scaling is rejected")
