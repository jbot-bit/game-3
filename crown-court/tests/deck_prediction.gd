extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var app = load("res://main.gd").new()
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.sim.reset_time = 0
	app.state = app.sim.snapshot()
	app.state.ball.owner = 0
	var player: Dictionary = app.state.players[2]
	player.pos = Vector3(0,app.Sim.KICKOFF_Y + .1,app.Sim.KICKOFF_Z)
	player.vel = Vector3(0,-20,0)
	player.grounded = false
	app.state.ball.pos = player.pos + Vector3.UP * app.Sim.BALL_RADIUS
	app.state.ball.vel = player.vel
	var before = var_to_bytes(app.state)
	var rendered = app.predict_render_state(.08)
	assert(is_equal_approx(rendered.players[2].pos.y,app.Sim.KICKOFF_Y),"predicted falling player lands on kickoff deck")
	assert(is_equal_approx(rendered.ball.pos.y,app.Sim.KICKOFF_Y + app.Sim.BALL_RADIUS),"predicted falling ball lands on kickoff deck")
	assert(var_to_bytes(app.state) == before,"deck prediction does not mutate authoritative snapshot")
	player.pos.y = 4.0
	player.vel = Vector3.UP * 3
	app.state.ball.pos.y = 4.0
	app.state.ball.vel = Vector3.UP * 3
	rendered = app.predict_render_state(.08)
	assert(rendered.players[2].pos.y < 4.3,"player below the deck remains below it")
	assert(rendered.ball.pos.y < 4.3,"ball below the deck remains below it")
	app.queue_free()
	await process_frame
	print("DECK PREDICTION PASS: player/ball top contact, underside passage, snapshot immutability")
	quit()
