extends SceneTree
## Native rendering + scripted controls. Three simulated puppets, not three PCs.
const Game = preload("res://prototypes/physics_party/main.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
var app: Node3D
var report: Dictionary = {}
var selected_course: String = "crossing"
var output_prefix: String = "hands-full-"

func _initialize() -> void:
	call_deferred("run_probe")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("res://logs/" + output_prefix + label + ".png")
	if error != OK: push_error("Capture failed: " + label)

func run_probe() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	var args = OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--course": selected_course = args[i + 1]
	if not Courses.valid(selected_course): quit(1); return
	if selected_course != "crossing": output_prefix = "hands-full-" + selected_course + "-"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.gui_disable_input = true
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/party-visual-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24673
	root.add_child(app)
	app.rng.seed = 2242026
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	await create_timer(0.8).timeout
	await capture("menu")
	app._host("Dad", selected_course)
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Player 2"}
	app.session.players.crew_3 = {"peer": 33, "slot": 2, "name": "Player 3"}
	app._roster_changed(app.session.players)
	await create_timer(1.5).timeout
	await capture("draft")
	for id in app.state.players: app._action(id, "power", app.state.offers[id][0])
	await create_timer(0.5).timeout
	await capture("play")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await create_timer(3.0).timeout
	var samples: Array[float] = []
	var started = Time.get_ticks_usec()
	var previous = started
	var index = 0
	var finite = true
	while Time.get_ticks_usec() - started < 10000000:
		await process_frame
		var now = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		var t = (now - started) / 1000000.0
		for id in app.avatars:
			var slot: int = app.session.players[id].slot
			var controls = app._neutral()
			controls.move = Vector2(sin(t * 1.4 + slot), cos(t * 1.4 + slot)) * 0.5
			controls.yaw = 0.0
			controls.jump = fmod(t, 3.0) < 0.12
			controls.left = fmod(t, 4.0) < 1.0
			app._controls(id, controls)
			finite = finite and app.avatars[id].body_position().is_finite()
		index += 1
	for id in app.avatars: app._controls(id, app._neutral())
	var sorted = samples.duplicate()
	sorted.sort()
	var total = 0.0
	var slow = 0
	for value in samples:
		total += value
		if value > 16.667: slow += 1
	report = {"course_id": app.course_id, "renderer": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"resolution": "1280x720", "seconds": 10, "physical_puppets": 3, "physical_bones": 30,
		"props": app.world.props.size(), "network_clients": 0, "finite_bodies": finite,
		"frame_ms": {"count": samples.size(), "mean": total / samples.size(), "p95": sorted[int((sorted.size() - 1) * 0.95)],
			"p99": sorted[int((sorted.size() - 1) * 0.99)], "max": sorted[-1], "over_16_7": slow},
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"limits": "Scripted movement/grab/jump, 3s warmup excluded. Not human play or weak-PC/remote-client latency evidence."}
	await capture("physics")
	if selected_course != "crossing":
		var overview := Camera3D.new()
		root.add_child(overview)
		var focus := Vector3(5, 2, -8)
		var distance: float = 38.0
		if app.world.has_method("route_points"):
			var points: Array[Vector3] = app.world.route_points()
			var bounds := AABB(points[0], Vector3.ZERO)
			for point in points: bounds = bounds.expand(point)
			focus = bounds.get_center()
			distance = maxf(38.0, bounds.size.length() * 0.95)
		overview.position = focus + Vector3(0.48, 0.78, 0.66).normalized() * distance
		overview.look_at(focus)
		overview.current = true
		await capture("overview")
		overview.queue_free()
		app.camera.current = true
	for id in app.avatars: app.avatars[id].reset_at(app.world.spawn_point(int(app.session.players[id].slot), 2))
	await create_timer(0.8).timeout
	report.completion_after_native_recovery = app.state.get("phase", "") == "complete"
	if not report.completion_after_native_recovery:
		push_error("Native recovery did not reach completion: " + str(app.state))
	await capture("finish")
	root.size = Vector2i(960, 540)
	await create_timer(0.3).timeout
	await capture("finish-small")
	app._restart()
	await create_timer(0.2).timeout
	await capture("collected-small")
	# Worst-case layout fixture: all five collected buttons plus three offers.
	var layout_state: Dictionary = app.state.duplicate(true)
	layout_state.unlocked_power_ids = ["spring", "heavy", "swift", "feather", "grip"]
	app.hud.update_view(layout_state, "crew_1", true)
	await capture("all-powers-small")
	app.hud.show_menu()
	await capture("host-menu-small")
	var file = FileAccess.open("res://logs/" + output_prefix + "native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("HANDS_FULL_NATIVE " + JSON.stringify(report))
	app.session.close()
	app.queue_free()
	await process_frame
	quit(0 if finite and report.completion_after_native_recovery else 1)
