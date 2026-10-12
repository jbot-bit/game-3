extends "res://tests/active_network_peer.gd"

var probe = preload("runtime_probe_log.gd").new()
var probe_saved = false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--probe-host": role = "host"
	boot.call_deferred()

func _process(dt: float) -> bool:
	probe.sample(app,dt)
	if is_instance_valid(app) and not result_written and played > 35 and FileAccess.file_exists(output_dir.path_join("view/active-play.json")):
		final_state = app.state.duplicate(true)
		reason = "Bounded no-capture runtime probe finished"
		sanity = true
		write_report(false)
	return super._process(dt)

func shutdown() -> void:
	if not probe_saved:
		probe_saved = true
		probe.save(output_dir.path_join("runtime-"+role+".json"),role)
	# This diagnostic intentionally stops before the result; no game state is changed.
	sanity = true
	super.shutdown()
