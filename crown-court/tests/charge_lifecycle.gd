extends SceneTree

var checks = 0
var failures = 0
var app

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func shoot(pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick() -> void:
	await process_frame
	app.read_controls(1.0 / 60)

func run() -> void:
	app = load("res://tests/controller_app.gd").new()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.sim.players[1].pos = Vector3.ZERO
	app.sim.players[1].grounded = true
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.input_armed = true
	shoot(true)
	await tick()
	expect(app.charging, "Holding shoot starts charge with possession")
	for frame in 15: await tick()
	expect(app.charge_time > .2, "Held charge accumulates")
	# Authoritative possession loss arrives while the original button stays held.
	app.sim.ball.owner = 2
	app.state = app.sim.snapshot()
	await tick()
	expect(not app.charging and app.charge_time == 0, "Losing possession immediately cancels stale charge")
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	await tick()
	expect(not app.charging, "Recatching with shoot still held does not restore old charge")
	app.commands.clear()
	shoot(false)
	await tick()
	expect(not app.commands.has("throw") and app.sim.ball.owner == 1, "Release after recatch cannot fire the previous possession's shot")
	shoot(true)
	await tick()
	expect(app.charging, "Fresh press after recatch starts a new charge")
	shoot(false)
	await tick()
	expect(app.commands.count("throw") == 1 and app.sim.ball.owner == 0, "Fresh charge still releases exactly one normal throw")
	app.sim.clock = 10
	app.sim.secure_ball(1)
	app.state = app.sim.snapshot()
	shoot(true)
	await tick()
	for frame in 15: await tick()
	expect(app.charging and app.charge_time>.2,"Charge starts for an identified possession")
	# A dropped snapshot hides the intermediate loss; same owner, new catch token.
	app.sim.clock = 12
	app.sim.ball.owner = 0
	app.sim.secure_ball(1)
	app.state = app.sim.snapshot()
	await tick()
	expect(not app.charging and app.charge_time==0,"Same-owner recatch snapshot cancels old possession charge")
	app.commands.clear()
	shoot(false)
	await tick()
	expect(not app.commands.has("throw") and app.sim.ball.owner==1,"Releasing after unseen loss and recatch cannot fire stale shot")
	app.queue_free()
	await process_frame
	print("CHARGE LIFECYCLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
