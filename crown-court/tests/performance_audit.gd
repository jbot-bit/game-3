extends SceneTree

var app
var output = "res://tests/performance-audit"
var seconds = 12.0
var pack_source = ""
var started = 0
var command_clock = 0.0
var path = ""
var finishing = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
		elif arg.begins_with("--duration="): seconds = clampf(float(arg.trim_prefix("--duration=")),3,30)
		elif arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func run() -> void:
	seed(173017)
	DirAccess.make_dir_recursive_absolute(output)
	app = preload("performance_app.gd").new()
	app.sim = preload("performance_sim.gd").new()
	app.manual_input_enabled = false
	path = "user://performance_audit_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(path)
	root.add_child(app)
	app.muted = true
	app.practice_game("coop")
	started = Time.get_ticks_usec()

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or finishing or started == 0: return false
	command_clock += dt
	if app.phase == "match" and app.sim.reset_time <= 0 and command_clock >= .04:
		command_clock = 0.0
		var command: Dictionary = app.sim.bot_command(app.local_seat)
		app.submit_move(command.move,command.aim)
		if str(command.action) != "": app.submit_action(command.action,command.charge)
	if Time.get_ticks_usec()-started >= seconds*1000000:
		finishing = true
		finish.call_deferred()
	return false

func statistics(values: Array) -> Dictionary:
	var ordered = values.duplicate()
	ordered.sort()
	var sum = 0.0
	for value in ordered: sum += float(value)
	return {"samples":ordered.size(),"mean":sum/ordered.size(),"median":ordered[int(ordered.size()/2)],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"p99":ordered[mini(ordered.size()-1,int(ordered.size()*.99))],"max":ordered[-1],"unit":"ms"}

func finish() -> void:
	app.set_process(false)
	app.set_physics_process(false)
	var all_metrics: Dictionary = app.measurements.duplicate(true)
	all_metrics.merge(app.sim.measurements)
	var stats: Dictionary = {}
	for metric in all_metrics:
		if not all_metrics[metric].is_empty(): stats[metric] = statistics(all_metrics[metric])
	var report = {"metrics":stats,"samples":all_metrics,"frames":app.process_rows,"initialization_ms":app.initialization_ms,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"rendering_server":DisplayServer.get_name(),"duration_seconds":float(Time.get_ticks_usec()-started)/1000000.0,"pack_source":pack_source,"pack_sha256":FileAccess.get_sha256(pack_source) if not pack_source.is_empty() else "","application_version":ProjectSettings.get_setting("application/config/version"),"fixture_mutations":false,"seed":173017,"scope":"Instrumented script work durations and process wall gaps; native CPU timers, not GPU or scheduling-cause proof"}
	var file = FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PERFORMANCE_AUDIT ",JSON.stringify({"metrics":stats,"initialization_ms":app.initialization_ms,"nodes":report.nodes,"pack_sha256":report.pack_sha256}))
	await app.close_session()
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	quit()
