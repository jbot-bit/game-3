extends SceneTree

var app
var checks: Array = []
var folder = ""
var capture = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): folder = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture = true
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"passed":ok,"label":label})
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	app = load("res://main.tscn").instantiate()
	app.profile = load("res://profile.gd").new("user://result-clarity.json")
	root.add_child(app)
	app.practice_game("coop")
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.sim.reset_time = 0.0
	app.state = app.sim.snapshot()
	app.state.time_left = 12.0
	app.update_hud(.016)
	check(app.clock_label.text == "0:12", "Live regulation retains remaining time")
	app.state.time_left = 0.0
	app.state.scores = {0:2,1:2}
	app.update_hud(.016)
	check(app.rule_label.text.begins_with("Overtime"), "Tied live match correctly says overtime")
	app.state.scores = {0:5,1:2}
	app.state.winner = 0
	app.state.celebration_time = 0.0
	app.state.match_id = "result-clarity-v14"
	app.state.reward_peers = [1]
	app.update_hud(.016)
	check(app.clock_label.text == "FINAL", "Completed regulation replaces expired timer with FINAL")
	check(app.rule_label.text.begins_with("Full time"), "Declared winner cannot display overtime")
	check(app.result_panel.visible and not app.event_label.visible, "Result panel replaces the temporary basket announcement")
	check(app.profile.data.bags == 1, "Winning reward is retained")
	check(not app.possession_label.visible and not app.target_label.visible, "Finished match hides obsolete possession and target cues")
	check(not app.jump_label.visible and not app.prompt_label.visible and not app.controls_hint.visible, "Finished match hides obsolete gameplay controls")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("regulation-result.png"))
	app.state.time_left = 105.0
	app.update_hud(.016)
	check(app.clock_label.text == "FINAL" and app.rule_label.text.begins_with("Full time"), "Early victory also reads as final rather than live game point")
	app.start_match()
	app.set_process(false)
	app.set_physics_process(false)
	app.state = app.sim.snapshot()
	app.update_hud(.016)
	check(not app.result_panel.visible and app.possession_label.visible and app.target_label.visible, "Rematch restores live cues and hides old result")
	check(app.profile.data.bags == 1, "Rematch does not duplicate or clear the earned bag")
	var passed = checks.all(func(c): return c.passed)
	if not folder.is_empty():
		var file = FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":passed,"checks":checks},"\t"))
	app.close_session()
	app.queue_free()
	await process_frame
	print("RESULT_CLARITY ", JSON.stringify({"passed":passed,"checks":checks.size()}))
	quit(0 if passed else 1)