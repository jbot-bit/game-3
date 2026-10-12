extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app = load("res://main.gd").new()
	var profile_path := "user://audio_priority_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.muted = false
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.players[1].pos = Vector3.ZERO
	app.sim.players[4].pos = Vector3(16,0,0)
	app.sounds.set_process(false)
	app.sounds.initialize_bank()
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	app.sim.action(4,"jump")
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	var remote_count: int = app.sounds.played_count
	app.sounds.clock += .05
	app.sim.action(1,"jump")
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	var local_count: int = app.sounds.played_count
	var accepted: bool = app.sim.players[1].jump_count == 1
	var local_audible := local_count == remote_count+1
	print("PASS " if accepted else "FAIL ","Local jump genuinely occurred")
	print("PASS " if local_audible else "FAIL ","Remote cue from preceding snapshot cannot suppress local jump feedback ",JSON.stringify({"after_remote":remote_count,"after_local":local_count,"separation_seconds":.05}))
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if accepted and local_audible else 1)
