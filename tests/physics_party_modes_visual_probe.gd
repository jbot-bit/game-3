extends SceneTree
## Explicit native display fixtures; results below do not claim match/race clears.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var failed: bool = false
var captures: Array[String] = []
var facings: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://logs/modes-native-" + label + ".png")
	failed = failed or result != OK
	captures.append(label)
	print("MODES_NATIVE_CAPTURE ", label, " ", result)

func _settle(ticks: int) -> void:
	for tick in ticks:
		for id: String in app.avatars:
			var controls: Dictionary = app._neutral()
			controls.yaw = float(facings.get(id, 0.0))
			app.avatars[id].set_controls(controls)
		await physics_frame

func _frame(at: Vector3, target: Vector3) -> void:
	app.camera.position = at
	app.camera.look_at(target)

func _show_state() -> void:
	app.hud.show_game()
	app.hud.update_view(app.state, "crew_1", true)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this display fixture with the native renderer.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.gui_disable_input = true
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/modes-native-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24971
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(0.3).timeout
	for mode: String in ["gladiator", "wipeout", "coop"]:
		app.hud._select_mode(mode)
		await _capture("menu-" + mode)
	app._host("Josh", "crossing", "gladiator")
	# Display-only roster fixture. No remote peer IDs or claim of LAN transport.
	app.session.players.crew_2 = {"peer": 1, "slot": 1, "name": "Alex"}
	app.session.players.crew_3 = {"peer": 1, "slot": 2, "name": "Sam"}
	app._roster_changed(app.session.players)
	for id: String in app.avatars:
		var slot: int = int(app.session.players[id].slot)
		var style: Dictionary = [{"color": "orange", "accessory": "cap"}, {"color": "blue", "accessory": "none"}, {"color": "lilac", "accessory": "beanie"}][slot]
		app.state.players[id].appearance = style
		app.avatars[id].set_appearance(style)
		app.avatars[id].reset_at(Vector3(float(slot - 1) * 3.1, 7, 1.2))
		facings[id] = PI
		app.avatars[id].set_combat_visual(true, 0.0, false, PI)
	app.state.match = {"version": 1, "phase": "fight", "timer": 74.0, "round": 2,
		"scores": {"crew_1": 1, "crew_2": 0, "crew_3": 1}, "entrants": ["crew_1", "crew_2", "crew_3"],
		"alive": ["crew_1", "crew_2", "crew_3"], "winner": "", "round_winner": "", "fighters": {}}
	app.state.mode_text = "ROUND 2 / 3 standing / 74s / First to 3 wins"
	app.state.mode_hint = app.contest.hint_text()
	_show_state()
	_frame(Vector3(11, 11, 21), Vector3(0, 5.3, 0))
	await _settle(90)
	await _capture("gladiator-resting")
	# Freeze only the displayed swing phase; physics remains the real puppet.
	app.avatars.crew_1.set_combat_visual(true, 0.28, false, PI)
	app.avatars.crew_2.set_combat_visual(true, 0.0, true, PI)
	app.avatars.crew_3.set_combat_visual(true, 0.64, false, PI)
	await _capture("gladiator-swing-brace")
	_frame(Vector3(24, 27, 28), Vector3(0, 3, 0))
	await _capture("gladiator-arena")
	app.state.phase = "complete"
	app.state.match.phase = "complete"
	app.state.match.winner = "crew_1"
	app.state.match.scores = {"crew_1": 3, "crew_2": 1, "crew_3": 2}
	app.state.reward_cards = []
	app.state.reward_run_id = ""
	_show_state()
	await _capture("gladiator-results")
	app._make_world(true, "crossing", "wipeout")
	app._new_run_state()
	app._roster_changed(app.session.players)
	for id: String in app.avatars:
		var slot: int = int(app.session.players[id].slot)
		facings[id] = 0.0
		app.avatars[id].reset_at(app.world.spawn_point(slot))
	app.state.challenge = {"version": 1, "phase": "running", "elapsed": 27.5, "remaining": 272.5, "winner": "", "results": {},
		"runners": {"crew_1": {"checkpoint": 1, "falls": 0, "finished": false, "time": 0.0}, "crew_2": {"checkpoint": 0, "falls": 1, "finished": false, "time": 0.0}, "crew_3": {"checkpoint": 0, "falls": 0, "finished": false, "time": 0.0}}}
	app.state.mode_text = "WIPEOUT / 00:27 / KEEP YOUR BALANCE"
	app.state.mode_hint = app.race.hint_text()
	_show_state()
	_frame(Vector3(81, 89, 1), Vector3(0, 3, -63))
	await _settle(45)
	await _capture("wipeout-overview")
	for id: String in app.avatars:
		var slot: int = int(app.session.players[id].slot)
		app.avatars[id].reset_at(Vector3(float(slot - 1) * 0.7, 6.5, -10.0 - float(slot) * 2.5))
	_frame(Vector3(14, 13, 4), Vector3(0, 4, -13))
	await _settle(30)
	await _capture("wipeout-balance")
	for id: String in app.avatars:
		var slot: int = int(app.session.players[id].slot)
		app.avatars[id].reset_at(Vector3(float(slot - 1) * 3.0, 7, -40))
	_frame(Vector3(18, 17, -23), Vector3(0, 4, -43))
	await _settle(30)
	await _capture("wipeout-sweeper")
	app.state.phase = "complete"
	app.state.challenge.phase = "complete"
	app.state.challenge.results = {"crew_1": {"finished": true, "time": 78.42, "falls": 1}, "crew_2": {"finished": true, "time": 82.16, "falls": 2}, "crew_3": {"finished": false, "time": 0.0, "falls": 5}}
	_show_state()
	await _capture("wipeout-results")
	# Timing keeps three physical puppets, tipping boards and both moving bars
	# active; safe checkpoint positions prevent fixture falls dominating view.
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app.state.phase = "play"
	_show_state()
	for id: String in app.avatars:
		var slot: int = int(app.session.players[id].slot)
		app.avatars[id].reset_at(app.world.spawn_point(slot, 1))
	_frame(Vector3(22, 21, -14), Vector3(0, 4, -35))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _settle(120)
	var mover_before: Dictionary = app.world.capture_movers()
	var times: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var start: int = previous
	while Time.get_ticks_usec() - start < 5000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	var slow: int = 0
	for value: float in times:
		if value > 16.667: slow += 1
	var moving: int = 0
	var mover_after: Dictionary = app.world.capture_movers()
	for id: String in mover_before:
		if not mover_before[id].is_equal_approx(mover_after[id]): moving += 1
	failed = failed or moving != 2 or app.avatars.size() != 3
	await _capture("wipeout-performance")
	var report := {"gpu": RenderingServer.get_video_adapter_name(), "frame_p95_ms": times[int(times.size() * 0.95)],
		"frame_max_ms": times[-1], "over_16_7": slow, "frames": times.size(), "seconds": 5,
		"physical_puppets": app.avatars.size(), "moving_sweepers": moving, "resolution": "1280x720", "captures": captures,
		"limits": "Native display fixtures, explicit swing and result states, and 5s local render timing. No match clear, race finish, network transport or human play is proven by these screenshots."}
	var file := FileAccess.open("res://logs/modes-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MODES_NATIVE ", JSON.stringify(report))
	app.session.close()
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
