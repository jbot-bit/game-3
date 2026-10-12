extends SceneTree

var output = "res://tests/performance-replay"
var app
var profile_path = ""
var states: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func summarize(values: Array) -> Dictionary:
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for value in sorted: total += float(value)
	return {"count":sorted.size(),"mean":total/sorted.size(),"median":sorted[int(sorted.size()/2)],"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted[-1],"unit":"ms"}

func run() -> void:
	seed(173017)
	DirAccess.make_dir_recursive_absolute(output)
	var model = load("res://sim.gd").new()
	model.reset("coop")
	for frame in 900:
		for id in model.players:
			var command: Dictionary = model.bot_command(id)
			model.move_input(id,command.move,command.aim)
			if not str(command.action).is_empty(): model.action(id,command.action,command.charge)
		model.step(1.0/60)
		if model.winner >= 0: break
		states.append(model.snapshot())
	app = preload("performance_app.gd").new()
	profile_path = "user://performance_replay_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.muted = true
	app.practice_game("coop")
	app.set_process(false)
	app.set_physics_process(false)
	var rows: Array[Dictionary] = []
	var before = var_to_bytes(states)
	# ABBA ordering gives each configuration an early and late trial.
	for enabled in [true,false,false,true]:
		app.presentation_enabled = enabled
		var work: Array = []
		var ui_signatures: Array = []
		for index in states.size():
			app.state = states[index]
			var start = Time.get_ticks_usec()
			app._process(1.0/60)
			var elapsed_ms = float(Time.get_ticks_usec()-start)/1000.0
			if index >= 120: work.append(elapsed_ms)
			if index % 60 == 0: ui_signatures.append([app.score_label.text,app.clock_label.text,app._winner_shown,int(app.profile.data.bags)])
		rows.append({"presentation_enabled":enabled,"metric":"app.process_work_ms","statistics":summarize(work),"samples":work,"ui_signatures":ui_signatures})
	var identical_ui = rows.all(func(row): return row.ui_signatures == rows[0].ui_signatures)
	var unchanged = before == var_to_bytes(states)
	var report = {"trials":rows,"snapshots":states.size(),"warmup_frames":120,"unchanged_authoritative_states":unchanged,"identical_hud_and_rewards":identical_ui,"passed":unchanged and identical_ui,"source_hashes":{},"scope":"Deterministic snapshot replay, native script-work timing, same process ABBA; no GPU/frame-time or OS-scheduling proof"}
	for file in ["main.gd","sim.gd","world.gd","audio.gd","hud.gd"]: report.source_hashes[file] = FileAccess.get_sha256("res://"+file)
	var result = FileAccess.open(output.path_join("replay.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify(report,"\t"))
	for row in rows: print("PERFORMANCE_REPLAY enabled=",row.presentation_enabled," ",JSON.stringify(row.statistics))
	print("PERFORMANCE_REPLAY_CHECKS ",JSON.stringify({"unchanged_states":unchanged,"identical_ui":identical_ui}))
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path+suffix))
	quit(0 if report.passed else 1)
