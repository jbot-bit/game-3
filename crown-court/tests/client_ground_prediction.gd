extends SceneTree

var checks = 0
var failures = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String, observed = null) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label," ",observed if observed != null else "")

func run() -> void:
	var app = load("res://main.gd").new()
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.ball.owner = 0
	app.sim.players[1].pos = Vector3.ZERO
	app.sim.players[1].vel = Vector3.RIGHT * app.Sim.SPEED
	app.sim.players[1].grounded = true
	app.sim.players[1].boost_time = 0
	app.sim.players[1].stun = 0
	app.sim.players[1].dive = 0
	app.sim.players[1].dunk = 0
	app.local_direction = Vector3.LEFT
	app.state = app.sim.snapshot()
	var before = var_to_bytes(app.state)
	var shown: Dictionary = app.predict_render_state(.05)
	expect(shown.players[1].pos.x > 0, "Sharp reverse input preserves forward momentum in the client", shown.players[1].pos.x)
	app.sim.move_input(1,Vector3.LEFT,Vector3.LEFT)
	for frame in 3: app.sim.step(1.0 / 60)
	expect(shown.players[1].pos.distance_to(app.sim.players[1].pos) < .001, "Client turn displacement matches three authoritative traction steps", shown.players[1].pos.distance_to(app.sim.players[1].pos))
	expect(shown.players[1].move == Vector3.LEFT and shown.players[1].vel.distance_to(app.sim.players[1].vel) < .001, "Local animation receives current reversal intent and predicted momentum before ACK")
	expect(var_to_bytes(app.state) == before, "Local traction prediction leaves the snapshot immutable")
	for carrying in [false,true]:
		app.sim.players[1].pos = Vector3.ZERO
		app.sim.players[1].vel = Vector3.ZERO
		app.sim.players[1].giant = 5
		app.sim.ball.owner = 1 if carrying else 0
		app.sim.move_input(1,Vector3.RIGHT,Vector3.RIGHT)
		app.local_direction = Vector3.RIGHT
		app.state = app.sim.snapshot()
		shown = app.predict_render_state(.05)
		if carrying: expect(shown.ball.vel == shown.players[1].vel, "Carried ball receives the same predicted carrier velocity")
		for frame in 3: app.sim.step(1.0 / 60)
		expect(shown.players[1].pos.distance_to(app.sim.players[1].pos) < .001, "Giant/carry speed modifiers agree with authority (%s)" % carrying, shown.players[1].pos.distance_to(app.sim.players[1].pos))
	app.state.players[1].boost_time = 1.0
	app.state.players[1].vel = Vector3.RIGHT * 18
	app.local_direction = Vector3.LEFT
	shown = app.predict_render_state(.05)
	expect(is_equal_approx(shown.players[1].pos.x-app.state.players[1].pos.x,.9), "Boost extrapolation does not apply ground braking")
	app.queue_free()
	await process_frame
	print("CLIENT GROUND PREDICTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
