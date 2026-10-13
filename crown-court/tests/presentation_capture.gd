extends SceneTree
# Native presentation review: captures the intro fly-over, team card, lineup,
# live play, the score cam and the full-time card as PNGs for inspection.
# Visual evidence only; it asserts nothing about enjoyment.
var app
var evidence := "res://tests"
var shots: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	_run.call_deferred()

func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := evidence.path_join("presentation-%s.png" % label)
	root.get_texture().get_image().save_png(path)
	shots.append({"label": label, "path": path, "reset": app.sim.reset_time, "celebration": app.sim.celebration_time, "time_scale": Engine.time_scale, "camera": app.world.camera.position, "kind": app.world.cinematic_kind})
	print("CAPTURE ", label, " ", path)

func force_score() -> void:
	# Put the local player on a clean assisted shot from eight metres.
	var sim = app.sim
	sim.reset_time = 0.0
	sim.celebration_time = 0.0
	sim.ball.lock = 0.0
	var hoop: Vector3 = sim.hoop(1)
	sim.players[1].pos = hoop + Vector3.BACK * 8.0 - Vector3.UP * sim.HOOP_Y
	sim.players[1].pos.y = sim.floor_height(sim.players[1].pos.x, sim.players[1].pos.z)
	sim.players[1].vel = Vector3.ZERO
	sim.players[1].aim = Vector3.FORWARD
	sim.secure_ball(1)
	sim.set_shot_aim(1, Vector3.FORWARD * cos(deg_to_rad(48)) + Vector3.UP * sin(deg_to_rad(48)))
	sim.action(1, "throw", sim.ideal_charge(1))

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var scene: PackedScene = load("res://main.tscn")
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.profile = load("res://profile.gd").new("user://presentation_capture_%d.json" % Time.get_ticks_usec())
	app.manual_input_enabled = false
	app.nickname = "Evie"
	app.names[1] = "Evie"
	app.practice_game("coop")
	await wait(0.9)
	await capture("intro-flyover")
	await wait(1.8)
	await capture("intro-card")
	await wait(1.9)
	await capture("lineup")
	await wait(2.3)
	await capture("kickoff-flight")
	await wait(2.5)
	await capture("live-play")
	force_score()
	var baskets_before: int = app.sim.baskets
	for frame in 400:
		await process_frame
		if app.sim.baskets > baskets_before: break
	await wait(0.25)
	await capture("score-slowmo")
	await wait(0.9)
	await capture("score-cam")
	await wait(1.6)
	await capture("score-lineup")
	# Force the winning basket and the full-time sequence.
	app.sim.scores[0] = 3
	app.sim.scores[1] = 0
	force_score()
	baskets_before = app.sim.baskets
	for frame in 400:
		await process_frame
		if app.sim.baskets > baskets_before: break
	await wait(1.1)
	await capture("fulltime-cam")
	await wait(3.2)
	await capture("fulltime-card")
	print("PRESENTATION_CAPTURE_RESULT ", JSON.stringify({"shots": shots, "time_scale_restored": Engine.time_scale == 1.0}))
	quit(0)
