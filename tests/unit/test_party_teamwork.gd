extends GutTest
const World = preload("res://prototypes/physics_party/party_world.gd")
const MODULE_PATH: String = "res://prototypes/physics_party/party_teamwork.gd"

func _fixture(authoritative: bool = true) -> Node3D:
	assert_true(ResourceLoader.exists(MODULE_PATH), "The three-person physical stage module exists")
	if not ResourceLoader.exists(MODULE_PATH): return null
	var world := World.new()
	world.setup(authoritative)
	add_child_autofree(world)
	var module: Node3D = load(MODULE_PATH).new()
	module.world = world
	module.course_id = "crossing"
	world.add_child(module)
	return module

func test_three_stage_tail_cannot_be_finished_by_visiting_extraction() -> void:
	var module := _fixture()
	if module == null: return
	assert_eq(module.stages.size(), 3)
	assert_false(module.completed())
	assert_false(module.goal_contains(module.goal_spawn(1)))
	assert_gt(module.goal_spawn(1).distance_to(module.world.spawn_point(1, 2)), 120.0)
	assert_lt(module.goal_spawn(1).length(), 600.0)
	assert_eq(module.checkpoint_number(), 0)

func test_no_players_or_stale_controls_cannot_power_the_stages() -> void:
	var module := _fixture()
	if module == null: return
	for index in 600: module.tick({}, {"crew_1": {"interact": true}}, 1.0 / 60.0)
	assert_eq(module.capture().amounts, [0.0, 0.0, 0.0])
	assert_false(module.completed())
	assert_true(module.status_text(1).contains("3"))

func test_cargo_is_one_real_replicated_and_resettable_body() -> void:
	var module := _fixture()
	if module == null: return
	assert_true(module.world.props.has("team_cargo"))
	var cargo: RigidBody3D = module.world.props.team_cargo
	assert_false(cargo.freeze)
	var initial: Transform3D = cargo.global_transform
	cargo.position += Vector3(10, 4, 0)
	module.reset()
	assert_eq(cargo.global_transform, initial)
	assert_true(module.world.capture_prop_poses().has("team_cargo"))
	assert_eq(module.world._prop_ids.count("team_cargo"), 1)

func test_remote_presentation_accepts_bounded_state_and_moves_real_geometry() -> void:
	var module := _fixture(false)
	if module == null: return
	module.present({"version": 1, "latched": [true, false, false], "amounts": [1.0, 0.5, 0.0]})
	assert_eq(module.capture().latched, [true, false, false])
	assert_eq(module.checkpoint_number(), 3)
	assert_true(module.checkpoint_contains(module.checkpoint_spawn(1)))
	assert_almost_eq(module.stages[1].mover.global_position.y, module.stages[1].near.y + 4.0 - 0.18, 0.001)
	assert_true(module.world.props.team_cargo.freeze)

func test_invalid_remote_states_are_rejected_atomically() -> void:
	var module := _fixture(false)
	if module == null: return
	var initial: Dictionary = module.capture()
	for bad: Dictionary in [
		{}, {"version": 2, "latched": [false, false, false], "amounts": [0.0, 0.0, 0.0]},
		{"version": 1, "latched": [false, true, false], "amounts": [0.0, 1.0, 0.0]},
		{"version": 1, "latched": [true, false, false], "amounts": [0.5, 0.0, 0.0]},
		{"version": 1, "latched": [false, false, false], "amounts": [NAN, 0.0, 0.0]},
		{"version": 1, "latched": [false, false, false], "amounts": [2.0, 0.0, 0.0]},
		{"version": 1, "latched": [false, false, false], "amounts": [0.0, 0.0]},
		{"version": 1, "latched": [false, false, false], "amounts": [0.0, 0.0, 0.0], "extra": true}]:
		module.present(bad)
		assert_eq(module.capture(), initial)

func test_host_never_accepts_client_progress_claims() -> void:
	var module := _fixture()
	if module == null: return
	module.present({"version": 1, "latched": [true, true, true], "amounts": [1.0, 1.0, 1.0]})
	assert_false(module.completed())
	assert_eq(module.checkpoint_number(), 0)

func test_capture_is_detached_and_reset_closes_all_stages() -> void:
	var module := _fixture(false)
	if module == null: return
	module.present({"version": 1, "latched": [true, true, true], "amounts": [1.0, 1.0, 1.0]})
	assert_true(module.completed())
	assert_true(module.goal_contains(module.goal_spawn(1)))
	var copied: Dictionary = module.capture()
	copied.latched[0] = false
	assert_true(module.completed())
	module.reset()
	assert_false(module.completed())
	assert_eq(module.checkpoint_number(), 0)
	assert_eq(module.capture().amounts, [0.0, 0.0, 0.0])

func test_actor_replacement_and_recovery_discard_unlatched_physical_proofs() -> void:
	var module := _fixture()
	if module == null: return
	var old := Node3D.new()
	var replacement := Node3D.new()
	add_child_autofree(old)
	add_child_autofree(replacement)
	module.stages[0].amount = 0.8
	module._crossers.crew_1 = old.get_instance_id()
	module._carriers.crew_1 = old.get_instance_id()
	module._rider = "crew_1"
	module._rider_instance = old.get_instance_id()
	module._ride_height = 8.0
	module.tick({"crew_1": replacement}, {}, 1.0 / 60.0)
	assert_true(module._crossers.is_empty())
	assert_true(module._carriers.is_empty())
	assert_eq(module._ride_height, 0.0)
	assert_eq(module._rider, "")
	module._crossers.crew_1 = replacement.get_instance_id()
	module.forget_actor("crew_1")
	assert_true(module._crossers.is_empty())
	assert_gt(module.stages[0].amount, 0.0, "Closing motion remains gradual while proof invalidation is immediate")

func test_shared_timeline_blends_motion_and_keeps_latches_atomic() -> void:
	var module := _fixture(false)
	if module == null: return
	var script: Script = module.get_script()
	var before := {"version": 1, "latched": [false, false, false], "amounts": [0.5, 0.0, 0.0]}
	var after := {"version": 1, "latched": [true, false, false], "amounts": [1.0, 0.0, 0.0]}
	var midpoint: Dictionary = script.interpolate(before, after, 0.5)
	assert_almost_eq(midpoint.amounts[0], 0.75, 0.001)
	assert_false(midpoint.latched[0])
	assert_true(script.valid_snapshot(midpoint))
	assert_eq(script.interpolate(before, after, 1.0), after)
	assert_eq(script.interpolate(after, before, 0.5), before, "Run resets are applied atomically")
