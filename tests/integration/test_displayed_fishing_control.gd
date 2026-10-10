extends GutTest

const Rules = preload("res://game/fishing/fishing_rules.gd")
const Rail = preload("res://game/ui/fishing_pull_rail.gd")
const Gear = preload("res://game/progression/equipment.gd")
const Controller = preload("res://game/expedition/run_controller.gd")
const Game = preload("res://game/main.gd")
const STEP_SECONDS: float = 1.0 / 60.0
const SNAPSHOT_FRAMES: int = roundi(Controller.FISHING_SNAPSHOT_SECONDS / STEP_SECONDS)
const INPUT_FRAMES: int = 3 # The main scene sends input every 0.05 seconds.

func _publish_to_rail(rules, rail) -> void:
	# Authority is read only by the publisher, never by the input driver.
	var state: Dictionary = rules.snapshot().angler
	rail.set_tracking(float(state.bar_position), float(state.bar_width), float(state.fish_position), bool(state.tracking))

func _track_display(species: String, rod: String, snapshot_frames: int = SNAPSHOT_FRAMES) -> Dictionary:
	var rules = Rules.new()
	rules.start("angler", species, species + ":" + rod)
	rules.configure_rod("angler", rod)
	var rail = Rail.new()
	add_child(rail)
	rail.set_process(false)
	assert_true(rail.is_node_ready(), "The actual rail node initializes its presentation state")
	_publish_to_rail(rules, rail)
	var held: bool = false
	var result: Dictionary = {}
	var seconds: float = 0.0
	var interpolated_frames: int = 0
	for frame: int in range(60 * 26):
		if frame % INPUT_FRAMES == 0:
			# These are the positions drawn on screen, including snapshot delay
			# and the rail's own 80 ms interpolation. No target/authority peek.
			held = float(rail._shown_fish) > float(rail._shown_bar)
			rail.set_input_direction(held)
		result = rules.step("angler", held, 0.0, STEP_SECONDS)
		seconds = float(frame + 1) * STEP_SECONDS
		if result.get("code", "") in ["caught", "fish_escaped"]: break
		if (frame + 1) % snapshot_frames == 0:
			_publish_to_rail(rules, rail)
		rail._process(STEP_SECONDS)
		if absf(float(rail._shown_bar) - float(rail._target_bar)) > 0.000001 or absf(float(rail._shown_fish) - float(rail._target_fish)) > 0.000001:
			interpolated_frames += 1
	rail.free()
	return {"code": result.get("code", ""), "seconds": seconds, "interpolated_frames": interpolated_frames}

func _assert_species_caught(species: String, deadline: float) -> void:
	for rod: String in Gear.rods_all():
		var result: Dictionary = _track_display(species, rod)
		var label: String = species + " / " + rod
		print("DISPLAYED_FISHING %s code=%s seconds=%.3f interpolated_frames=%d" % [label, result.code, result.seconds, result.interpolated_frames])
		assert_eq(result.code, "caught", label + " must be catchable using visible positions")
		assert_true(is_finite(float(result.seconds)), label + " duration is finite")
		assert_lte(float(result.seconds), deadline, label + " remains a short fishing challenge")
		assert_gt(int(result.interpolated_frames), 0, label + " actually experiences interpolation")

func test_ordinary_fish_is_catchable_through_display_latency_with_every_rod() -> void:
	_assert_species_caught("penny_perch", 10.0)

func test_lantern_eel_is_catchable_through_display_latency_with_every_rod() -> void:
	_assert_species_caught("lantern_eel", 16.0)

func test_crown_ray_is_catchable_through_display_latency_with_every_rod() -> void:
	_assert_species_caught("crown_ray", 16.0)

func test_real_controller_publishes_faster_only_while_fishing() -> void:
	var app = Game.new()
	app.game_port = 24937
	var fixture: String = "user://tests/displayed-fishing-" + str(Time.get_ticks_usec())
	app.save_path = fixture + "-household.json"
	app.settings_path = fixture + "-settings.json"
	add_child_autofree(app)
	app._host("Display angler")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	app.controller.avatars.crew_1.global_position = app.world.markers.jetty
	app.controller.avatars.crew_1.last_dry = app.world.markers.jetty
	await get_tree().physics_frame
	var publications: Array[int] = [0]
	var count_snapshot: Callable = func(_data: Dictionary) -> void: publications[0] += 1
	app.session.snapshot_received.connect(count_snapshot)
	app.controller.state_time = 0.0
	for frame: int in range(20): app.controller._physics_process(0.01)
	assert_eq(publications[0], 1, "Idle state still publishes once per 0.2 seconds")
	assert_true(app.controller.apply_intent(1, "cast", {}, "display-cadence-cast").ok)
	publications[0] = 0 # Exclude the immediate cast acknowledgement.
	app.controller.state_time = 0.0
	for frame: int in range(20): app.controller._physics_process(0.01)
	assert_eq(publications[0], 4, "A real cast sends tracking state every 0.05 seconds")
	assert_true(app.controller.apply_intent(1, "cancel_cast", {}, "display-cadence-cancel").ok)
	publications[0] = 0
	app.controller.state_time = 0.0
	for frame: int in range(20): app.controller._physics_process(0.01)
	assert_eq(publications[0], 1, "Ending the last cast restores idle publication cadence")
	app.session.snapshot_received.disconnect(count_snapshot)
	app.session.close()
