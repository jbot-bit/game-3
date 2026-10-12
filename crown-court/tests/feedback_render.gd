extends SceneTree

var app
var folder = ""

func _initialize() -> void:
	run.call_deferred()

func capture(label: String) -> void:
	for frame in 12:
		var shown: Dictionary = app.presentation_state()
		shown["names"] = app.display_names()
		shown["pass_target_preview"] = app.pass_target_preview()
		app.world.present(shown, 1, 1.0 / 60, app.yaw, app.pitch)
		app.update_controller_labels()
		app.update_hud(1.0 / 60)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): folder = argument.trim_prefix("--evidence-dir=")
	assert(not folder.is_empty())
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://tests/controller_app.gd").new()
	app.profile = load("res://profile.gd").new("user://hud_render_%d.json" % Time.get_ticks_usec())
	root.add_child(app)
	app.manual_input_enabled = false
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.ui_clock = 20
	app.names = {1:"You", 2:"Jamie", 3:"Alex"}
	app.sim.players[1].pos = Vector3(-4, 1, -15)
	app.sim.players[1].jump_count = 1
	app.sim.players[1].grounded = false
	app.sim.players[2].pos = Vector3(2, 0, -24)
	app.sim.players[3].pos = Vector3(9, 0, -18)
	app.sim.players[1].aim = (app.sim.players[2].pos - app.sim.players[1].pos).normalized()
	app.sim.ball.owner = 1
	app.sim.ball.pos = app.sim.hand_position(1)
	app.state = app.sim.snapshot()
	await capture("01-pass-jump")
	app.state.scores[0] = 1
	app.state.event_id += 2
	app.state.event_kind = "jump"
	await capture("02-score")
	app.ui_clock += 3
	app.device_label = "DualSense Wireless Controller"
	app.controller_device = 11
	app.state.players[1].pos = Vector3(0, 2, -29)
	app.state.players[1].facing = Vector3.FORWARD
	app.state.ball.pos = Vector3(0, 3.95, -29.7)
	await capture("03-dunk-pad")
	print("FEEDBACK RENDER PASS: 3 native fixture captures, not natural gameplay")
	app.queue_free()
	await process_frame
	quit()
