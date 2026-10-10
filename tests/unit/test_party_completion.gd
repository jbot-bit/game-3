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
