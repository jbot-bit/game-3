extends GutTest

const Game = preload("res://prototypes/physics_party/main.gd")
var test_port: int = 24981

class StorageFake extends RefCounted:
	var progress = {"level": 1, "completions": 0, "unlocked_power_ids": ["swift"]}
	var fail_writes = false
	var completed: Array[String] = []
	func load_progress(_path: String) -> Dictionary: return {"ok": true}
	func draw_offers(_rng: RandomNumberGenerator) -> Array[String]: return ["spring", "heavy", "grip"]
	func complete(id: String, powers: Array = []) -> Dictionary:
		if fail_writes: return {"ok": false}
		if id not in completed:
			completed.append(id)
			progress.completions += 1
			for power in powers:
				if power not in progress.unlocked_power_ids: progress.unlocked_power_ids.append(power)
		return {"ok": true}

func make_host():
	var app = Game.new()
	app.scripted = true
	app.rules = StorageFake.new()
	app.game_port = test_port
	test_port += 1
	add_child_autofree(app)
	app._host("Host")
	app.set_physics_process(false)
	app.set_process(false)
	return app

func finish_course(app) -> void:
	app._action("crew_1", "power", "spring")
	app.state.players.crew_1.finished = true
	app._physics_process(1.0 / 60.0)

func test_next_course_requires_host_completion_and_keeps_saved_choices() -> void:
	var app = make_host()
	var first_run: String = app.run_id
	app._action("crew_1", "next_course", "")
	assert_eq(app.run_id, first_run, "An unfinished course cannot be skipped")
	finish_course(app)
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Friend"}
	app._roster_changed(app.session.players)
	app._action("crew_2", "next_course", "")
	assert_eq(app.run_id, first_run, "Only the host advances the crew")
	app._action("crew_1", "next_course", "")
	assert_eq(app.state.get("course_id", ""), "counterweight", "The next clear opens the second course")
	assert_ne(app.run_id, first_run, "New course receives a new packet/save identity")
	assert_eq(app.state.phase, "play")
	assert_eq(app.state.completions, 1, "Advancing awards no extra clear")
	assert_has(app.state.unlocked_power_ids, "swift")
	assert_has(app.state.unlocked_power_ids, "spring")
	assert_eq(app.world.props.size(), 7)
	for id in app.avatars:
		assert_lt(app.avatars[id].body_position().distance_to(app.world.spawn_point(int(app.session.players[id].slot), 0)), 0.02)
		assert_eq(app.state.players[id].checkpoint, 0)
		assert_eq(app.state.players[id].power, "")
	var second_world = app.world
	app._restart()
	assert_eq(app.state.get("course_id", ""), "counterweight", "Pause restart repeats the selected course")
	assert_eq(app.world, second_world, "Restart reuses and resets this course")
	app.session.close()
	await get_tree().process_frame

func test_failed_save_cannot_be_bypassed_by_next_course() -> void:
	var app = make_host()
	app.rules.fail_writes = true
	finish_course(app)
	var first_run: String = app.run_id
	var first_world = app.world
	assert_true(app.state.save_failed)
	app._action("crew_1", "next_course", "")
	assert_eq(app.run_id, first_run)
	assert_eq(app.world, first_world)
	assert_eq(app.state.phase, "complete")
	app.rules.fail_writes = false
	app._action("crew_1", "next_course", "")
	assert_eq(app.state.get("course_id", ""), "counterweight", "Successful retry can advance without losing the earned power")
	assert_eq(app.state.completions, 1)
	assert_has(app.state.unlocked_power_ids, "spring")
	app.session.close()
	await get_tree().process_frame

func test_client_rebuilds_before_poses_and_rejects_old_course_snapshot() -> void:
	var app = Game.new()
	app.scripted = true
	add_child_autofree(app)
	app.set_physics_process(false)
	app.set_process(false)
	app.session.local_id = "crew_2"
	app.session.players = {"crew_2": {"slot": 1, "name": "Friend", "peer": 2}}
	app._roster_changed(app.session.players)
	var old_world = app.world
	var state = {"run_id": "second-run", "course_id": "counterweight", "wind": -1,
		"players": {"crew_2": {"power": "heavy"}}}
	app._state_received(state)
	assert_ne(app.world, old_world, "Late join rebuilds the authoritative course")
	assert_false(app.world.authoritative)
	assert_eq(app.world.wind_direction, -1)
	assert_eq(app.world.props.size(), 7)
	for body in app.world.props.values(): assert_true(body.freeze, "Clients never simulate props")
	var stale = {"run_id": "first-run", "pose_msec": 1.0, "puppets": {}, "props": app.world.capture_prop_poses()}
	app._poses_received(stale)
	assert_true(app.presentation.sample(float(Time.get_ticks_msec())).is_empty(), "Old course poses never enter new presentation")
	var current = stale.duplicate(true)
	current.run_id = "second-run"
	app._poses_received(current)
	assert_false(app.presentation.sample(float(Time.get_ticks_msec())).is_empty())
	var current_world = app.world
	app._state_received({"run_id": "bad-run", "course_id": "../other"})
	assert_eq(app.world, current_world, "Unknown course values cannot load arbitrary resources")
	assert_eq(app.run_id, "second-run")
	app.session.close()
	await get_tree().process_frame

func test_host_can_start_second_course_directly_and_invalid_selection_is_nonmutating() -> void:
	var app = Game.new()
	app.scripted = true
	app.rules = StorageFake.new()
	app.game_port = 24989
	add_child_autofree(app)
	app.set_process(false)
	app.set_physics_process(false)
	app._host("Host", "counterweight")
	assert_eq(app.state.course_id, "counterweight")
	assert_true(app.world.authoritative)
	assert_gt(app.world.spawn_point(1, 2).x, 10.0)
	assert_has(app.state.unlocked_power_ids, "swift")
	var world = app.world
	var run: String = app.run_id
	app._host("Host", "missing-course")
	assert_eq(app.world, world)
	assert_eq(app.run_id, run)
	app.session.close()
	await get_tree().process_frame
