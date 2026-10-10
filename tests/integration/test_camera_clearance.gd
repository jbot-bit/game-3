extends GutTest

const Camera = preload("res://game/player/camera_rig.gd")
var scene: Node3D
var actor: Node3D
var camera: Camera3D

func before_each() -> void:
	scene = Node3D.new()
	add_child_autofree(scene)
	actor = Node3D.new()
	scene.add_child(actor)
	camera = Camera.new()
	scene.add_child(camera)
	camera.target = actor
	camera.position = Vector3(0, 4.962, 6.753)
	await get_tree().physics_frame
	await get_tree().physics_frame

func obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	scene.add_child(body)
	body.position = at
	return body

func clear_view_of(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
	return camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func test_side_of_pillar_cannot_hide_the_avatars_shoulder() -> void:
	obstacle(Vector3(0.58, 3.2, 3.5), Vector3(0.7, 5, 0.8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var focus := actor.global_position + Vector3(0, 1.7, 0)
	assert_true(clear_view_of(focus), "The old center ray misses this pillar edge")
	camera.follow(1.0)
	assert_lt(camera.global_position.z, 3.1, "Camera must move in front of the nearby pillar edge")
	assert_true(clear_view_of(focus + Vector3(0.45, 0, 0)), "Keep the full avatar visible, including its shoulder")
	assert_true(clear_view_of(focus - Vector3(0.45, 0, 0)))

func test_new_wall_is_resolved_on_actual_camera_before_rendering() -> void:
	obstacle(Vector3(0, 3, 4), Vector3(6, 7, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0 / 60.0)
	assert_lt(camera.global_position.z, 3.75, "Interpolation cannot leave the camera behind a newly encountered wall")
	assert_true(clear_view_of(actor.global_position + Vector3(0, 1.7, 0)))

func test_avatar_close_to_wall_still_gets_an_unblocked_view() -> void:
	# A standing avatar can fit here while a wider camera sweep begins overlapping
	# the wall. Physics shape sweeps ignore an obstacle they already overlap.
	obstacle(Vector3(0, 3, 0.6), Vector3(6, 7, 0.2))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0)
	assert_lt(camera.global_position.z, 0.5, "Do not ignore a wall beside the starting camera corridor")
	assert_true(clear_view_of(actor.global_position + Vector3(0, 1.7, 0)))

func test_camera_restores_distance_smoothly_after_obstacle_is_removed() -> void:
	var wall := obstacle(Vector3(0, 3, 4), Vector3(6, 7, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0)
	var nearby: Vector3 = camera.global_position
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0 / 60.0)
	assert_gt(camera.global_position.z, nearby.z, "Clearance returns camera toward normal framing")
	assert_lt(camera.global_position.z, 6.0, "Removing a wall must not snap to full camera distance")
	for frame in range(120): camera.follow(1.0 / 60.0)
	assert_almost_eq(camera.global_position.distance_to(actor.global_position + Vector3(0, 1.7, 0)), 7.5, 0.02)

func test_open_space_preserves_orbit_and_movement_controls() -> void:
	camera.apply_settings({"mouse_sensitivity": 2.0, "invert_y": true})
	camera.orbit(Vector2(10, 10))
	camera.follow(1.0)
	assert_almost_eq(camera.yaw, -0.08, 0.0001)
	assert_almost_eq(camera.pitch, -0.39, 0.0001)
	assert_almost_eq(camera.movement(Vector2.UP).length(), 1.0, 0.0001)
	assert_almost_eq(camera.global_position.distance_to(actor.global_position + Vector3(0, 1.7, 0)), 7.5, 0.02)
