extends SceneTree

var failures = 0
var checks = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var app = load("res://main.gd").new()
	var path = "user://headless_presentation_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	expect(not app.presentation_enabled, "Native headless peer skips presentation by default")
	app.practice_game("coop")
	app.state.players[1].team = 1
	app.yaw = 0
	app._camera_spawn_pending = true
	app._process(1.0 / 60)
	expect(is_equal_approx(app.yaw, PI) and not app._camera_spawn_pending, "Orange-side spawn still sets input-facing orientation")
	app.ball_camera = true
	app.state.ball.owner = 0
	app.state.ball.pos = app.state.players[1].pos + Vector3.RIGHT * 10
	var old_yaw: float = app.yaw
	app._process(.1)
	expect(not is_equal_approx(old_yaw, app.yaw), "Ball-camera steering still updates without a renderer")
	app.ball_camera = false
	app.presentation_enabled = true
	app._process(.1)
	app.presentation_enabled = false
	var shown_before: Transform3D = app.world.actors[1].root.transform
	app.state.players[1].pos = Vector3(8, 1, 0)
	var authority_before = var_to_bytes(app.state)
	app._process(.1)
	expect(app.world.actors[1].root.transform == shown_before, "Invisible actor transforms do not animate")
	expect(var_to_bytes(app.state) == authority_before, "Skipping presentation preserves authoritative snapshot")
	app.presentation_enabled = true
	app._process(.1)
	expect(app.world.actors[1].root.transform != shown_before, "Explicit presentation override supports headless transform probes")
	app.presentation_enabled = false
	app.state.reset_time = 0
	app.state.celebration_time = 0
	app.state.winner = 1
	app.state.reward_peers = [1]
	app.state.reward_seats = [1]
	app._process(.1)
	expect(app.result_panel.visible and app._winner_shown, "Headless winner still opens the result UI")
	expect(app.profile.data.bags == 1, "Headless winner still persists its eligible reward")
	app._process(.1)
	expect(app.profile.data.bags == 1, "Repeated headless result cannot duplicate its reward")
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("HEADLESS PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
