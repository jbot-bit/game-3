extends SceneTree
## Native display fixtures, not a human match or a network test.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://logs/knockout-native-" + label + ".png")
	failed = failed or error != OK
	print("KNOCKOUT_NATIVE_CAPTURE ", label, " ", error)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This probe requires a native renderer.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	root.gui_disable_input = true
	app = Game.new()
	app.scripted = true
	app.game_port = 24973
	app.progress_path = "user://tests/knockout-native-" + str(Time.get_ticks_usec()) + ".json"
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app._host("Josh", "crossing", "knockout")
	app.session.players.crew_2 = {"peer": 1, "slot": 1, "name": "Alex"}
	app.session.players.crew_3 = {"peer": 1, "slot": 2, "name": "Sam"}
	app._roster_changed(app.session.players)
	app.contest.tick(app.avatars, {}, 1.0 / 60.0)
	app.world.set_round_phase("countdown", 1)
	for tick in 90:
		for actor: Node3D in app.avatars.values(): actor.set_controls(app._neutral())
		await physics_frame
	app._update_mode_state()
	app.hud.show_game()
	app.hud.update_view(app.state, "crew_1", true)
	app.camera.position = Vector3(18, 22, 25)
	app.camera.look_at(Vector3(0, 4.5, 0))
	await capture("arena-960")
	app.contest.phase = "fight"
	app.contest.timer = 83.0
	app.world.set_round_phase("fight", 1)
	for tick in 35: await physics_frame
	app._update_mode_state()
	app.hud.update_view(app.state, "crew_1", true)
	await capture("moving-960")
	# Explicit late-round display fixture; real shrink/fall is tested separately.
	app.world.set("_round_elapsed", 65.0)
	app.world._physics_process(1.0 / 60.0)
	app.contest.timer = 25.0
	for tick in 2: await physics_frame
	app._update_mode_state()
	app.hud.update_view(app.state, "crew_1", true)
	await capture("final-speed-shrunk-960")
	app.world.set_round_phase("complete", 1)
	app.state.phase = "complete"
	app.state.match.phase = "complete"
	app.state.match.winner = "crew_1"
	app.state.match.scores = {"crew_1": 3, "crew_2": 1, "crew_3": 2}
	app.hud.update_view(app.state, "crew_1", true)
	await capture("results-960")
	app.session.close()
	app.queue_free()
	for tick in 5: await process_frame
	quit(1 if failed else 0)
