extends SceneTree
# Native presentation review: captures the intro fly-over, team card, lineup,
# live play, the score cam and the full-time card as PNGs for inspection.
# Visual evidence only; it asserts nothing about enjoyment.
var app
var evidence := "res://tests"
var shots: Array = []
var failures = 0

func _initialize() -> void:
	if not "--full-presentation" in OS.get_cmdline_user_args():
		printerr("PRESENTATION_CAPTURE requires -- --full-presentation so intro and cinematic cameras are exercised.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	_run.call_deferred()

func capture_stage(label: String, expected_kind: String, ready: Callable, timeout: float = 20.0) -> bool:
	# Renderer load can cap the simulation's catch-up steps. Wait for the actual
	# match stage and inspect the completed frame, never infer it from wall time.
	var deadline = Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		if ready.call() and app.world.cinematic_kind == expected_kind and app.world.cinematic_active == (not expected_kind.is_empty()):
			capture(label, expected_kind, ready)
			return true
	failures += 1
	printerr("FAIL stage deadline ", label, " expected camera=", expected_kind, " observed=", app.world.cinematic_kind, " reset=", app.sim.reset_time, " celebration=", app.sim.celebration_time, " winner=", app.sim.winner)
	print("PRESENTATION_CAPTURE_RESULT ", JSON.stringify({"shots": shots, "failures": failures, "timed_out_stage": label}))
	quit(1)
	return false

func capture(label: String, expected_kind: String, ready: Callable) -> void:
	var camera_matches = app.world.cinematic_kind == expected_kind and app.world.cinematic_active == (not expected_kind.is_empty())
	var stage_matches = bool(ready.call())
	if not camera_matches or not stage_matches:
		failures += 1
		printerr("FAIL ", label, " expected camera ", expected_kind, " observed ", app.world.cinematic_kind, " active=", app.world.cinematic_active, " stage_matches=", stage_matches)
	var path := evidence.path_join("presentation-%s.png" % label)
	root.get_texture().get_image().save_png(path)
	shots.append({"label": label, "path": path, "reset": app.sim.reset_time, "celebration": app.sim.celebration_time, "time_left": app.sim.time_left, "winner": app.sim.winner, "time_scale": Engine.time_scale, "presentation_time_scale": app.presentation_time_scale, "camera": app.world.camera.position, "kind": app.world.cinematic_kind, "expected_kind": expected_kind, "camera_matches": camera_matches, "stage_matches": stage_matches})
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
	if not await capture_stage("intro-flyover", "intro", func(): return app.sim.reset_time <= 6.0 and app.sim.reset_time > 5.0): return
	if not await capture_stage("intro-card", "intro", func(): return app.sim.reset_time <= 4.8 and app.sim.reset_time > 3.4 and app.intro_card.visible): return
	if not await capture_stage("lineup", "lineup", func(): return app.sim.reset_time <= 2.5 and app.sim.reset_time > 1.5 and app.sim.celebration_time <= 0): return
	if not await capture_stage("kickoff-flight", "", func(): return app.sim.reset_time <= 0 and app.sim.celebration_time <= 0 and app.sim.players[1].boost_time <= 2.2 and app.sim.players[1].boost_time > 1.5 and not app.sim.players[1].grounded): return
	if not await capture_stage("live-play", "", func(): return app.sim.reset_time <= 0 and app.sim.celebration_time <= 0 and app.sim.time_left <= 297.0 and app.sim.winner < 0): return
	var baskets_before: int = app.sim.baskets
	force_score()
	if not await capture_stage("score-slowmo", "score", func(): return app.sim.baskets > baskets_before and app.sim.celebration_time <= .7 and app.sim.celebration_time > .35 and app.sim.winner < 0): return
	if not await capture_stage("score-cam", "score", func(): return app.sim.celebration_time <= .3 and app.sim.celebration_time > 0 and app.sim.winner < 0): return
	if not await capture_stage("score-lineup", "lineup", func(): return app.sim.celebration_time <= 0 and app.sim.reset_time <= 2.0 and app.sim.reset_time > 1.3 and app.sim.winner < 0): return
	# Force the winning basket and the full-time sequence.
	app.sim.scores[0] = 3
	app.sim.scores[1] = 0
	baskets_before = app.sim.baskets
	force_score()
	if not await capture_stage("fulltime-cam", "final", func(): return app.sim.baskets > baskets_before and app.sim.winner == 0 and app.sim.celebration_time <= 2.2 and app.sim.celebration_time > 1.0): return
	if not await capture_stage("fulltime-card", "", func(): return app.sim.winner == 0 and app.sim.celebration_time <= 0 and app.result_panel.visible): return
	print("PRESENTATION_CAPTURE_RESULT ", JSON.stringify({"shots": shots, "failures": failures, "time_scale_restored": Engine.time_scale == 1.0}))
	quit(1 if failures else 0)
