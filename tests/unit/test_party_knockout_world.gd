extends GutTest

const WORLD_PATH := "res://prototypes/physics_party/party_knockout_world.gd"

func make_world(host: bool = true):
	assert_true(FileAccess.file_exists(WORLD_PATH), "Knockout has its own physical circular world")
	if not FileAccess.file_exists(WORLD_PATH): return null
	var world = load(WORLD_PATH).new()
	world.setup(host)
	add_child_autofree(world)
	world.set_physics_process(false)
	return world

func test_three_spawns_have_pad_support_and_every_outer_sector_is_void() -> void:
	var world = make_world()
	if world == null: return
	await get_tree().physics_frame
	await get_tree().physics_frame
	for slot in 3:
		var at: Vector3 = world.spawn_point(slot)
		assert_true(world.arena_contains(at))
		assert_gt(at.distance_to(world.spawn_point((slot + 1) % 3)), 8.0)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 10, 1))
		assert_false(hit.is_empty(), "Each starting place has actual support")
		if not hit.is_empty():
			assert_eq(str(hit.collider.name), "KnockoutPad", "Spawns are clear of stationary hazards")
			assert_almost_eq(hit.position.y, 4.0, 0.01)
	for sector in 12:
		var at := Vector3(cos(TAU * sector / 12.0), 0, sin(TAU * sector / 12.0)) * 10.0
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4, at + Vector3.DOWN * 12, 1))
		assert_true(hit.is_empty(), "No outer bridge or rescue floor in sector " + str(sector))
	assert_eq(world.find_children("*", "StaticBody3D", true, false).filter(func(body): return not body is AnimatableBody3D).size(), 2, "Only pad and center hub offer static collision")
	assert_eq(world.props.size(), 0)
	assert_eq(world.movers.size(), 2)
	assert_false(world.arena_contains(Vector3(NAN, 5, 0)))
	assert_false(world.arena_contains(Vector3(0, -2.1, 0)))
	assert_false(world.goal_contains(world.spawn_point(0)))

func test_countdown_pauses_and_every_round_resets_the_same_hazard_phase() -> void:
	var world = make_world()
	if world == null: return
	world.set_round_phase("countdown", 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var initial: Dictionary = world.capture_movers()
	var untrusted: Dictionary = initial.duplicate(true)
	untrusted.SweepLow.basis = Basis(Vector3.UP, 2.0)
	world.apply_presented_movers(untrusted)
	assert_poses_equal(world.capture_movers(), initial, "Host ignores remote mover presentation")
	for tick in 10: world._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_poses_equal(world.capture_movers(), initial, "Countdown obstacles remain still")
	world.set_round_phase("fight", 1)
	for tick in 10: world._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moving: Dictionary = world.capture_movers()
	assert_ne(moving.SweepLow.basis, initial.SweepLow.basis)
	assert_ne(moving.SweepHigh.basis, initial.SweepHigh.basis)
	world.set_round_phase("fight", 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(world.capture_movers(), moving, "Repeated match sync cannot reset a running round")
	assert_lt(moving.SweepLow.basis.get_euler().y * moving.SweepHigh.basis.get_euler().y, 0.0, "Arms rotate in opposite directions from their shared starting lane")
	world.set_round_phase("intermission", 1)
	for tick in 10: world._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(world.capture_movers(), moving)
	world.set_round_phase("countdown", 2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_poses_equal(world.capture_movers(), initial, "Next round has identical starting angles")
	world.set_round_phase("fight", 2)
	for tick in 10: world._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(world.capture_movers(), moving, "Round speed progression also resets")
	world.set_round_phase("complete", 2)
	world._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(world.capture_movers(), moving)
	world.reset_props()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_poses_equal(world.capture_movers(), initial, "Reset restores the starting hazard and floor transforms")

func test_client_only_accepts_finite_yaw_rotations_at_fixed_hazard_centers() -> void:
	var client = make_world(false)
	if client == null: return
	var initial: Dictionary = client.capture_movers()
	for body: AnimatableBody3D in client.movers.values():
		assert_eq(body.collision_layer, 0)
		assert_eq(body.collision_mask, 0)
	client.set_round_phase("fight", 1)
	client._physics_process(0.1)
	assert_eq(client.capture_movers(), initial, "Clients never advance obstacle physics")
	var valid: Dictionary = initial.duplicate(true)
	valid.SweepLow.basis = Basis(Vector3.UP, 1.0)
	client.apply_presented_movers(valid)
	assert_eq(client.capture_movers(), valid, "Shared presentation timeline drives remote display")
	for bad_pose: Transform3D in [
		Transform3D(Basis.IDENTITY, Vector3(80, 4.62, 0)),
		Transform3D(Basis(Vector3.RIGHT, 0.5), valid.SweepLow.origin),
		Transform3D(Basis.IDENTITY.scaled(Vector3(2, 1, 0.5)), valid.SweepLow.origin),
		Transform3D(Basis.IDENTITY.scaled(Vector3(-1, 1, 1)), valid.SweepLow.origin),
		Transform3D(Basis.IDENTITY, Vector3(NAN, 4.62, 0))]:
		client.apply_presented_movers({"SweepLow": bad_pose})
		assert_eq(client.capture_movers(), valid, "Malformed snapshots cannot move, tilt, scale or reflect hazards")
	client.apply_presented_movers({"SweepLow": "bad", "untrusted": Transform3D.IDENTITY})
	assert_eq(client.capture_movers(), valid)

func test_speed_ramp_is_bounded_and_invalid_delta_does_not_corrupt_hazards() -> void:
	var world = make_world()
	if world == null: return
	world.set_round_phase("fight", 1)
	assert_almost_eq(world.hazard_speed_scale(), 1.0, 0.001)
	for tick in 450: world._physics_process(0.1)
	assert_almost_eq(world.hazard_speed_scale(), 1.7, 0.001)
	for tick in 1400: world._physics_process(0.1)
	assert_almost_eq(world.hazard_speed_scale(), 2.5, 0.001)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before: Dictionary = world.capture_movers()
	world._physics_process(NAN)
	world._physics_process(-0.1)
	world._physics_process(INF)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(world.capture_movers(), before)
	world.set_round_phase("countdown", 2)
	assert_almost_eq(world.hazard_speed_scale(), 1.0, 0.001)



func test_center_hub_cannot_be_reached_by_jumping_from_the_highest_arm() -> void:
	var world = make_world()
	if world == null: return
	var hub: StaticBody3D = world.get_node("CenterHub")
	var hub_collision: CollisionShape3D = hub.find_children("*", "CollisionShape3D", false, false)[0]
	var hub_shape: CylinderShape3D = hub_collision.shape
	var hub_top: float = hub.global_position.y + hub_shape.height * 0.5
	var highest_arm_top: float = -INF
	for body: AnimatableBody3D in world.movers.values():
		var collision: CollisionShape3D = body.find_children("*", "CollisionShape3D", false, false)[0]
		var shape: BoxShape3D = collision.shape
		highest_arm_top = maxf(highest_arm_top, body.global_position.y + shape.size.y * 0.5)
	var jump_speed: float = preload("res://prototypes/physics_party/puppet.gd").BASE_JUMP_SPEED
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var normal_jump_rise: float = jump_speed * jump_speed / (2.0 * gravity)
	assert_gt(hub_top - highest_arm_top, normal_jump_rise + 0.5, "Even riding the high arm cannot provide a normal jump route onto the hub")


func advance_round(world: Node3D, seconds: float) -> void:
	for tick in int(roundf(seconds * 10.0)): world._physics_process(0.1)

func test_speed_stages_warn_then_ramp_smoothly_without_exceeding_final_speed() -> void:
	var world = make_world()
	if world == null: return
	assert_true(world.has_method("hazard_status_text"), "Round escalation has a readable advance warning")
	if not world.has_method("hazard_status_text"): return
	world.set_round_phase("fight", 1)
	assert_eq(world.hazard_status_text(), "ROUND START")
	advance_round(world, 13.0)
	assert_true(world.hazard_status_text().contains("FASTER SWEEPERS IN"))
	assert_almost_eq(world.hazard_speed_scale(), 1.0, 0.001)
	advance_round(world, 3.0)
	assert_almost_eq(world.hazard_speed_scale(), 1.15, 0.001, "First acceleration ramps over two seconds")
	advance_round(world, 1.0)
	assert_almost_eq(world.hazard_speed_scale(), 1.3, 0.001)
	advance_round(world, 9.0)
	assert_true(world.hazard_status_text().contains("ARENA SHRINKS IN"))
	advance_round(world, 5.0)
	assert_almost_eq(world.hazard_speed_scale(), 1.5, 0.001)
	assert_true(world.hazard_status_text().contains("ARENA SHRINKING"))
	advance_round(world, 16.0)
	assert_almost_eq(world.hazard_speed_scale(), 2.1, 0.001)
	advance_round(world, 15.0)
	assert_almost_eq(world.hazard_speed_scale(), 2.5, 0.001)
	assert_true(world.hazard_status_text().contains("FINAL SPEED"))
	advance_round(world, 60.0)
	assert_almost_eq(world.hazard_speed_scale(), 2.5, 0.001)

func test_floor_retracts_real_collision_and_shared_timeline_then_resets() -> void:
	var world = make_world()
	if world == null: return
	assert_true(world.has_method("arena_radius"), "Shrinking arena exposes its current supported radius")
	if not world.has_method("arena_radius"): return
	world.set_round_phase("fight", 1)
	advance_round(world, 30.0)
	assert_almost_eq(world.arena_radius(), 9.0, 0.001)
	advance_round(world, 15.0)
	assert_almost_eq(world.arena_radius(), 7.5, 0.001)
	var pad: StaticBody3D = world.get_node("KnockoutPad")
	var collision: CollisionShape3D = pad.find_children("*", "CollisionShape3D", false, false)[0]
	assert_almost_eq(collision.shape.radius, 7.5, 0.001, "Actual floor support retracts with the visible edge")
	assert_eq(pad.scale, Vector3.ONE, "Shrinking visuals cannot double-scale physical collision")
	for visual: MeshInstance3D in pad.find_children("*", "MeshInstance3D", false, false):
		assert_almost_eq(visual.scale.x, 7.5 / 9.0, 0.001)
		assert_almost_eq(visual.scale.z, 7.5 / 9.0, 0.001)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 4.1, 8), Vector3(0, -3, 8), 1))
	assert_true(hit.is_empty(), "The original outer lane loses actual support")
	var sample: Dictionary = world.capture_movers()
	assert_true(sample.has("ArenaFloor"), "Floor radius travels on the shared mover timeline")
	assert_eq(world.movers.size(), 2, "The floor marker is not a third rotating hazard")
	var client = make_world(false)
	client.apply_presented_movers(sample)
	assert_almost_eq(client.arena_radius(), 7.5, 0.001)
	client.set_round_phase("fight", 1)
	advance_round(client, 30.0)
	assert_almost_eq(client.arena_radius(), 7.5, 0.001, "Clients cannot independently retract their arena")
	advance_round(world, 60.0)
	assert_almost_eq(world.arena_radius(), 6.0, 0.001)
	world.set_round_phase("intermission", 1)
	advance_round(world, 5.0)
	assert_almost_eq(world.arena_radius(), 6.0, 0.001)
	world.set_round_phase("countdown", 2)
	assert_almost_eq(world.arena_radius(), 9.0, 0.001)
	assert_almost_eq(collision.shape.radius, 9.0, 0.001)

func test_client_rejects_floor_marker_translations_rotations_and_invalid_scales() -> void:
	var client = make_world(false)
	if client == null: return
	assert_true(client.has_method("arena_radius"))
	if not client.has_method("arena_radius"): return
	var center := Vector3(0, 3.3, 0)
	client.apply_presented_movers({"ArenaFloor": Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 1, 0.8)), center)})
	assert_almost_eq(client.arena_radius(), 7.2, 0.001)
	for invalid: Transform3D in [
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, 1, 0.5)), center),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.1, 1, 1.1)), center),
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 1, 0.7)), center),
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 2, 0.8)), center),
		Transform3D(Basis(Vector3.UP, 0.1).scaled(Vector3(0.8, 1, 0.8)), center),
		Transform3D(Basis.IDENTITY, center + Vector3.UP),
		Transform3D(Basis.IDENTITY.scaled(Vector3(NAN, 1, NAN)), center)]:
		client.apply_presented_movers({"ArenaFloor": invalid})
		assert_almost_eq(client.arena_radius(), 7.2, 0.001, "Malformed floor marker cannot change supported geometry")

func assert_poses_equal(actual: Dictionary, expected: Dictionary, detail: String) -> void:
	assert_eq(actual.keys(), expected.keys(), detail)
	for id: String in expected:
		assert_true((actual[id] as Transform3D).is_equal_approx(expected[id]), detail + ": " + id)

func test_final_circle_has_a_body_sized_lane_outside_the_high_arm() -> void:
	var world = make_world()
	if world == null: return
	var high: AnimatableBody3D = world.movers.SweepHigh
	var collision: CollisionShape3D = high.find_children("*", "CollisionShape3D", false, false)[0]
	var high_shape: BoxShape3D = collision.shape
	var high_reach: float = Vector2(high_shape.size.x, high_shape.size.z).length() * 0.5
	var puppet: Node3D = preload("res://prototypes/physics_party/puppet.tscn").instantiate()
	var body_shape: BoxShape3D = puppet.get_node("Physical/Armature/Skeleton3D/Physical Bone Body/CollisionShape3D").shape
	var lane_radius: float = 5.3
	assert_gt(lane_radius - high_reach, body_shape.size.z * 0.5 + 0.1, "Inward-facing torso has clearance from the high arm in the final outer lane")
	assert_gt(world.MIN_PAD_RADIUS - lane_radius, maxf(body_shape.size.x, body_shape.size.z) * 0.5 + 0.1, "The same lane keeps a whole torso half-width plus margin inside real floor support")
	puppet.free()
