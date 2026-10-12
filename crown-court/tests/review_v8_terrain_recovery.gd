extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app = load("res://main.gd").new()
	var profile_path := "user://terrain_recovery_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.players = {2:app.sim.players[2]}
	var player: Dictionary = app.sim.players[2]
	var bank_x = lerpf(app.Sim.SIDE_BANK_START,app.Sim.HALF_WIDTH,.56)
	player.pos = Vector3(bank_x,app.Sim.floor_height(bank_x,0),0)
	player.vel = Vector3.LEFT*app.Sim.SPEED
	player.move = Vector3.LEFT
	player.grounded = true
	player.guard = 0
	app.sim.ball.owner = 2
	app.sim.ball.pos = app.sim.hand_position(2)
	var sequence := 0
	var minimum_target_clearance := 0.0
	var minimum_actor_clearance := 0.0
	var samples: Array = []
	for frame in 30:
		if frame > 0: app.sim.step(1.0/60)
		# One200ms delivery gap, then normal20Hz samples. Physics is never moved
		# or rewritten after the initial bank descent setup.
		if frame == 0 or (frame >= 12 and frame%3 == 0):
			sequence += 1
			var wire: Dictionary = app.sim.snapshot()
			wire.match_id = app.match_id
			wire._snapshot_seq = sequence
			app.receive_state(var_to_bytes(wire).compress(FileAccess.COMPRESSION_DEFLATE))
		app.ui_clock += 1.0/60
		var authority := var_to_bytes(app.state)
		var shown: Dictionary = app.predict_render_state(app.ui_clock-app.snapshot_received_at)
		app.world.present(shown,1,1.0/60,0,.43)
		if var_to_bytes(app.state) != authority:
			print("FAIL Presentation mutated authority")
			quit(1)
			return
		var target: Vector3 = shown.players[2].pos
		var actor: Vector3 = app.world.actors[2].root.position
		var target_clearance: float = target.y-app.Sim.floor_height(target.x,target.z)
		var actor_clearance: float = actor.y-app.Sim.floor_height(actor.x,actor.z)
		minimum_target_clearance = minf(minimum_target_clearance,target_clearance)
		minimum_actor_clearance = minf(minimum_actor_clearance,actor_clearance)
		samples.append({"frame":frame,"target":target,"actor":actor,"target_clearance":target_clearance,"actor_clearance":actor_clearance})
	var passed := minimum_target_clearance >= -.025 and minimum_actor_clearance >= -.08
	print("PASS " if passed else "FAIL ","Delayed real bank descent never buries the grounded target/actor ",JSON.stringify({"minimum_target_clearance":minimum_target_clearance,"minimum_actor_clearance":minimum_actor_clearance}))
	var output := "C:/game-3/build/crown-court-evidence/v8-terrain-recovery-red"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"samples":samples},"  "))
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if passed else 1)
