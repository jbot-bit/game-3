extends GutTest

const Game = preload("res://prototypes/physics_party/main.gd")

class FailingSave extends RefCounted:
	var progress: Dictionary = {"level": 1, "completions": 0, "unlocked_power_ids": []}
	var attempts: Array = []
	func load_progress(_path: String) -> Dictionary:
		return {"ok": true}
	func draw_offers(_rng: RandomNumberGenerator) -> Array[String]:
		return ["spring", "heavy", "grip"]
	func complete(_run: String, powers: Array = []) -> Dictionary:
		attempts.append(powers.duplicate())
		if attempts.size() == 1: return {"ok": false}
		progress.completions = 1
		progress.unlocked_power_ids = powers.duplicate()
		return {"ok": true}

func test_failed_completion_keeps_departed_players_power_when_retrying() -> void:
	var app = Game.new()
	var storage = FailingSave.new()
	app.rules = storage
	app.scripted = true
	app.game_port = 24973
	add_child_autofree(app)
	app._host("Host")
	app.set_physics_process(false)
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Player 2"}
	app._roster_changed(app.session.players)
	assert_true(app.hud.blocks_input(), "Power selection initially blocks movement")
	assert_false(app.hud.is_menu_open(), "Power selection is not the connected menu")
	# Exercise the same event handler as a player pressing Esc during the draft.
	app.scripted = false
	var escape = InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	app._unhandled_input(escape)
	assert_true(app.hud.is_menu_open(), "Esc opens the join-address menu before choosing a power")
	app._unhandled_input(escape)
	assert_false(app.hud.is_menu_open())
	assert_true(app.hud.blocks_input(), "Returning keeps the pending power choice")
	app.scripted = true
	app._action("crew_1", "power", "spring")
	app._action("crew_2", "power", "heavy")
	for id in app.state.players: app.state.players[id].finished = true
	app._physics_process(1.0 / 60.0)
	assert_true(app.state.save_failed)
	assert_eq(storage.attempts.size(), 1)
	app.session.players.erase("crew_2")
	app._roster_changed(app.session.players)
	assert_false(app.state.players.has("crew_2"))
	app._restart()
	assert_eq(storage.attempts.size(), 2)
	assert_has(storage.attempts[1], "heavy", "Retry retains the power earned before the player left")
	assert_has(storage.progress.unlocked_power_ids, "heavy")
	assert_eq(app.state.phase, "play")
	assert_false(app.state.has("save_failed"))
	app.session.close()
	await get_tree().process_frame

func test_camera_orbit_is_immediate_and_ignores_other_players() -> void:
	var app = Game.new()
	app.rules = FailingSave.new()
	app.scripted = true
	app.game_port = 24974
	add_child_autofree(app)
	app._host("Host")
	app.set_process(false)
	app.set_physics_process(false)
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Friend"}
	app._roster_changed(app.session.players)
	app.pitch = 0.0
	app.yaw = 0.0
	app._update_camera(0.0)
	var focus: Vector3 = app.camera_focus
	app.avatars.crew_2.reset_at(focus + Vector3(5, 1.5, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	app.yaw = PI / 2.0
	app._update_camera(0.0)
	var arm: Vector3 = app.camera.global_position - app.camera_focus
	assert_almost_eq(atan2(arm.x, arm.z), PI / 2.0, 0.01, "Mouse orbit is not delayed by follow smoothing")
	assert_gt(arm.length(), 9.0, "A teammate behind the player does not force a camera zoom")
	app.session.close()
	await get_tree().process_frame

func test_short_jump_tap_survives_until_control_sample_but_not_a_menu() -> void:
	var app = Game.new()
	app.rules = FailingSave.new()
	app.scripted = true
	app.game_port = 24975
	add_child_autofree(app)
	app._host("Host")
	app.set_process(false)
	app.set_physics_process(false)
	app._action("crew_1", "power", "spring")
	app.scripted = false
	var press = InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	var release = InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	app._unhandled_input(press)
	app._unhandled_input(release)
	assert_true(app._local_controls().jump, "A tap between network samples still reaches the next sample")
	assert_false(app._local_controls().jump, "The same tap is not sent again")
	app._unhandled_input(press)
	var escape = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_input(escape)
	app._unhandled_input(escape)
	assert_false(app._local_controls().jump, "A pending jump cannot fire after opening and closing a menu")
	app.hud.show_menu()
	app.yaw = 1.1
	app.pitch = -0.4
	var menu_controls: Dictionary = app._local_controls()
	assert_almost_eq(menu_controls.yaw, 1.1, 0.001, "Opening the menu does not turn the puppet")
	assert_almost_eq(menu_controls.pitch, -0.4, 0.001)
	assert_eq(menu_controls.move, Vector2.ZERO)
	app._unhandled_input(press)
	app.hud.show_game()
	app.hud.update_view(app.state, "crew_1", true)
	assert_false(app._local_controls().jump, "Menu input cannot queue a gameplay jump")
	app.scripted = true
	app.session.close()
	await get_tree().process_frame

func test_host_can_restart_ruined_course_from_menu_without_losing_collection() -> void:
	var app = Game.new()
	var storage = FailingSave.new()
	storage.progress.unlocked_power_ids = ["swift"]
	app.rules = storage
	app.scripted = true
	app.game_port = 24976
	add_child_autofree(app)
	app._host("Host")
	app.set_process(false)
	app.set_physics_process(false)
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Friend"}
	app._roster_changed(app.session.players)
	app._action("crew_1", "power", "spring")
	var original_run: String = app.run_id
	var plank: RigidBody3D = app.world.props.plank_left
	var home: Vector3 = plank.global_position
	plank.global_position = Vector3(30, 0, 0)
	app._action("crew_2", "restart", "")
	assert_eq(app.run_id, original_run, "A client cannot reset everybody's course")
	app.hud.show_menu()
	app.hud.update_view(app.state, "crew_1", true)
	var buttons = app.hud.find_children("*", "Button", true, false)
	var restart_button: Button
	for button in buttons:
		if button.text == "Restart course": restart_button = button
	assert_not_null(restart_button, "A ruined movable bridge has a discoverable recovery path")
	if restart_button != null:
		assert_true(restart_button.is_visible_in_tree())
		restart_button.pressed.emit()
		assert_ne(app.run_id, original_run)
		assert_lt(plank.global_position.distance_to(home), 0.01, "Restart restores the displaced bridge")
		assert_false(app.hud.is_menu_open(), "Host returns directly to power selection")
		assert_true(app.hud.blocks_input(), "New run waits for a power choice")
		assert_has(app.state.unlocked_power_ids, "swift", "Collected powers survive restarting")
		assert_eq(storage.attempts.size(), 0, "Restarting an incomplete course awards no clear")
		app.hud.show_menu()
		app.hud.update_view(app.state, "crew_2", false)
		assert_false(restart_button.is_visible_in_tree(), "Clients do not see host-only restart")
	app.session.close()
	await get_tree().process_frame
