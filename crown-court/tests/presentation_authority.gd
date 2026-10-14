extends SceneTree
## Presentation pulses must never alter authority, input charge or send cadence.
var app
var checks: Array = []

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String, detail = null) -> void:
	checks.append({"passed": ok, "check": label, "detail": detail})
	print("PASS " if ok else "FAIL ", label, " ", detail if detail != null else "")

func run() -> void:
	app = load("res://main.gd").new()
	app.profile = load("res://profile.gd").new("user://presentation_authority_%d.json" % Time.get_ticks_usec())
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.muted = true
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(0, 6, app.NETWORK_CHANNELS)
	expect(error == OK, "Isolated server starts for real snapshot scheduling", error)
	if error != OK:
		app.queue_free()
		await process_frame
		quit(1)
		return
	app.multiplayer.multiplayer_peer = peer
	for scenario in ["rendered_tackler", "rendered_victim", "rendered_uninvolved", "headless", "paused", "cinematics_off"]:
		app.sim.reset("coop")
		app.sim.reset_time = 0
		# Occupied seats suppress bot actions; the probe drives the local input.
		app.seats = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6}
		app.local_seat = 1
		app.presentation_enabled = scenario != "headless"
		app.cinematics_enabled = scenario != "cinematics_off"
		app.paused = scenario == "paused"
		app.hitstop_until = -1
		app.slowmo_until = -1
		app._hud_announcement_until = -1
		app._hud_scores = app.sim.scores.duplicate()
		app.last_event = 0
		app.sim.players[1].cooldown = .85
		app.sim.secure_ball(1)
		app.sim.emit("tackle", "BALL LOOSE", Vector3.ZERO, 2 if scenario in ["rendered_victim", "rendered_uninvolved"] else 1)
		app.state = app.sim.snapshot()
		if scenario == "rendered_victim": app.state.players[1].stun = .1
		app.update_hud(0)
		app.update_time_scale()
		var expected = .12 if scenario in ["rendered_tackler", "rendered_victim"] else 1.0
		expect(is_equal_approx(app.presentation_time_scale, expected), scenario + " selects only a presentation pulse", app.presentation_time_scale)
		expect(is_equal_approx(Engine.time_scale, 1.0), scenario + " leaves engine real time", Engine.time_scale)
		app.state = app.sim.snapshot()
		app.net_clock = 0
		app.snapshot_serial = 0
		app.input_armed = true
		app.charging = false
		app.shoot_previous = false
		app.charge_time = 0
		app.manual_input_enabled = true
		Input.action_press("throw_ball")
		for frame in 30:
			# Godot supplies this scaled dt: regressions in Engine.time_scale must
			# propagate into the assertion instead of being hidden by fixed dt.
			app._physics_process((1.0 / 60) * Engine.time_scale)
		Input.action_release("throw_ball")
		app.manual_input_enabled = false
		expect(is_equal_approx(app.sim.time_left, 299.5), scenario + " preserves match clock", app.sim.time_left)
		expect(is_equal_approx(app.sim.players[1].cooldown, .35), scenario + " preserves cooldown", app.sim.players[1].cooldown)
		expect(app.snapshot_serial == 10, scenario + " preserves 20 Hz snapshot scheduling", app.snapshot_serial)
		expect(is_equal_approx(app.charge_time, 0.0 if app.paused else .5), scenario + " preserves input charge and pause gate", app.charge_time)
	app.paused = false
	app.cinematics_enabled = true
	app.presentation_enabled = true
	app.hitstop_until = -1
	app.start_slowmo(1.0, .3)
	app.update_time_scale()
	expect(is_equal_approx(app.presentation_time_scale, .3) and Engine.time_scale == 1.0, "Score slow-motion is presentation only")
	app.start_hitstop(1.0)
	app.update_time_scale()
	expect(is_equal_approx(app.presentation_time_scale, .12) and Engine.time_scale == 1.0, "Hit-stop wins overlap without changing engine time")
	app.phase = "menu"
	app.update_time_scale()
	expect(app.presentation_time_scale == 1.0 and Engine.time_scale == 1.0, "Leaving match restores presentation time")
	peer.close()
	app.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	app.queue_free()
	await process_frame
	var failures = checks.filter(func(item): return not item.passed).size()
	print("PRESENTATION_AUTHORITY_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures, "results": checks}))
	quit(1 if failures else 0)
