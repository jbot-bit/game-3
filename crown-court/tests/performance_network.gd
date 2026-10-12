extends "res://tests/active_network_peer.gd"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	boot.call_deferred()

func boot() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output_dir = argument.trim_prefix("--evidence-dir=")
		elif argument.begins_with("--room-url="): room_url = argument.trim_prefix("--room-url=")
		elif argument.begins_with("--room-code="): room_code = argument.trim_prefix("--room-code=")
	limit_seconds = 35
	DirAccess.make_dir_recursive_absolute(output_dir)
	app = preload("performance_app.gd").new()
	app.name = "CrownCourt"
	app.sim = preload("performance_sim.gd").new()
	app.manual_input_enabled = false
	profile_path = "user://performance_network_%s_%d.json" % [role,Time.get_ticks_usec()]
	app.profile = load("res://profile.gd").new(profile_path)
	root.add_child(app)
	app.nickname = role
	app.muted = true
	app.room_server_url = room_url
	if role == "host": app.host_room("coop")
	else: app.join_room(room_code)

func _process(dt: float) -> bool:
	if is_instance_valid(app) and not quitting and played >= (15.0 if role == "host" else 13.0):
		final_state = app.state.duplicate(true)
		reason = "Bounded script-work profiling run"
		sanity = true
		write_report(false)
		shutdown()
		return false
	return super._process(dt)

func shutdown() -> void:
	if not quitting:
		var measurements: Dictionary = app.measurements.duplicate(true)
		measurements.merge(app.sim.measurements)
		var file = FileAccess.open(output_dir.path_join("profile-"+role+".json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"role":role,"measurements":measurements,"frames":app.process_rows,"scope":"Three real room processes; native CPU work timers, not GPU/scheduling-cause proof"},"\t"))
		sanity = played >= 12 and peak_roster == 3 and opponent_bots == 3
	super.shutdown()
