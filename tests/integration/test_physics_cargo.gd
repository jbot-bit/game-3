extends GutTest

func make_fish() -> RigidBody3D:
	var fish_script: GDScript = load("res://game/fishing/physical_fish.gd")
	var fish: RigidBody3D = fish_script.new()
	fish.setup("fixture:1", "penny_perch", true)
	fish.position = Vector3(0, 2, 0)
	add_child_autofree(fish)
	fish.set_host_simulated(true)
	return fish

func make_floor() -> void:
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	floor_body.collision_layer = 1
	add_child_autofree(floor_body)

func test_free_body_lands_on_world_with_bounded_speed_and_excludes_players() -> void:
	make_floor()
	var fish: RigidBody3D = make_fish()
	fish.linear_velocity = Vector3(0, -30, 0)
	for frame: int in range(100):
		await get_tree().physics_frame
	assert_true(fish.global_position.is_finite())
	assert_gt(fish.global_position.y, 0.0)
	assert_lt(fish.global_position.y, 1.0)
	assert_lte(fish.linear_velocity.length(), 8.05)
	assert_eq(fish.collision_mask, 1)
	assert_eq(fish.catch_id, "fixture:1")

func test_pause_preserves_flight_and_resumes_once() -> void:
	make_floor()
	var fish: RigidBody3D = make_fish()
	fish.toss(Vector3.RIGHT)
	await get_tree().physics_frame
	fish.set_game_paused(true)
	var stopped: Vector3 = fish.global_position
	for frame: int in range(20):
		await get_tree().physics_frame
	assert_lt(fish.global_position.distance_to(stopped), 0.01)
	fish.set_game_paused(false)
	for frame: int in range(15):
		await get_tree().physics_frame
	assert_gt(fish.global_position.distance_to(stopped), 0.3)

func test_water_recovery_preserves_id_and_pauses_its_two_second_timer() -> void:
	make_floor()
	var fish: RigidBody3D = make_fish()
	var anchor := Vector3(3, 1, 0)
	assert_true(fish.set_carry_pose(Transform3D(Basis.IDENTITY, anchor), anchor))
	fish.drop()
	fish.enter_water()
	for frame: int in range(60):
		await get_tree().physics_frame
	assert_true(fish.recovering)
	fish.set_game_paused(true)
	for frame: int in range(80):
		await get_tree().physics_frame
	assert_true(fish.recovering)
	fish.set_game_paused(false)
	for frame: int in range(70):
		await get_tree().physics_frame
	assert_false(fish.recovering)
	assert_lt(Vector2(fish.global_position.x, fish.global_position.z).distance_to(Vector2(3, 0)), 0.1)
	assert_eq(fish.catch_id, "fixture:1")

func test_carry_does_not_cross_world_and_client_ignores_stale_pose() -> void:
	make_floor()
	var fish: RigidBody3D = make_fish()
	assert_false(fish.set_carry_pose(Transform3D(Basis.IDENTITY, Vector3(0, -0.2, 0)), Vector3.ZERO))
	fish.set_host_simulated(false)
	fish.apply_network_pose({"sequence": 2, "transform": Transform3D(Basis.IDENTITY, Vector3(4, 2, 0))})
	fish.apply_network_pose({"sequence": 1, "transform": Transform3D(Basis.IDENTITY, Vector3(9, 2, 0))})
	assert_eq(fish.global_position.x, 4.0)
	assert_true(fish.freeze)

func test_carry_checks_path_even_when_endpoint_is_clear() -> void:
	make_floor()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 4, 4)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(1.5, 2, 0)
	add_child_autofree(wall)
	var fish: RigidBody3D = make_fish()
	await get_tree().physics_frame
	assert_false(fish.set_carry_pose(Transform3D(Basis.IDENTITY, Vector3(3, 2, 0)), Vector3(3, 2, 0)))
	assert_lt(fish.global_position.x, 1.0)
