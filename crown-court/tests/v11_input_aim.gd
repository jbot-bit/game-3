extends SceneTree

class InputApp:
	extends "res://main.gd"
	var captured_aim = Vector3.ZERO
	var captured_command = ""
	func _ready() -> void:
		pass
	func host_action(slot: int, command: String, charge: float, aim: Vector3 = Vector3.ZERO, movement: Vector3 = Vector3.INF) -> void:
		captured_aim = aim
		captured_command = command
		super.host_action(slot, command, charge, aim, movement)

var app
var checks = 0
var failures = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func fixture() -> void:
	app.sim.reset("coop")
	app.sim.reset_time = 0
	app.sim.players = {1: app.sim.players[1]}
	app.sim.players[1].pos = Vector3(0, 8, 0)
	app.sim.players[1].vel = Vector3.ZERO
	app.sim.ball.owner = 1
	app.sim.ball.lock = 0
	app.state = app.sim.snapshot()
	app.phase = "match"
	app.charging = true
	app.charge_time = .575

func run() -> void:
	app = InputApp.new()
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	fixture()
	app.pitch = .43
	app.yaw = 0
	var neutral: Vector3 = app.shot_direction()
	expect(neutral.is_equal_approx(Vector3.FORWARD * cos(deg_to_rad(48)) + Vector3.UP * sin(deg_to_rad(48))), "neutral look gives physical 48 degree loft")
	app.pitch = .15
	var high: Vector3 = app.shot_direction()
	app.pitch = .9
	var low: Vector3 = app.shot_direction()
	expect(high.y > neutral.y and neutral.y > low.y, "mouse/controller pitch controls actual launch elevation")
	app.yaw = 1.1
	expect(Vector3(low.x, 0, low.z).normalized().is_equal_approx(Vector3.FORWARD), "pitch leaves yaw unchanged")
	for pitch in [.15, .43, .9]:
		fixture()
		app.pitch = pitch
		var direction: Vector3 = app.shot_direction()
		var before = var_to_bytes(app.state)
		expect(app.prepare_aim_sim() and app.aim_sim.players[1].shot_aim.is_equal_approx(direction) and var_to_bytes(app.state) == before, "preview uses current 3D controls without changing snapshot pitch %.2f" % pitch)
		var forecast: Vector3 = app.aim_sim.throw_velocity(1, .5)
		var points: PackedVector3Array = app.trajectory_preview()
		app.submit_action("throw", .5)
		expect(app.captured_command == "throw" and app.captured_aim.is_equal_approx(direction), "throw action carries full press-time aim pitch %.2f" % pitch)
		expect(app.sim.ball.vel.is_equal_approx(forecast) and forecast.normalized().is_equal_approx(direction), "preview and host launch match manual yaw/pitch %.2f" % pitch)
		var path = PackedVector3Array()
		var event_id = app.sim.event_id
		for step in 720:
			if step % 3 == 0: app.sim.clock += 1.0 / 60
			app.sim.ball_step(1.0 / 180)
			path.append(app.sim.ball.pos)
			if app.sim.event_id != event_id: break
		var error = 0.0
		for point in points:
			var nearest = INF
			for actual in path: nearest = minf(nearest, actual.distance_to(point))
			error = maxf(error, nearest)
		expect(not points.is_empty() and error < .002 and points[-1].distance_to(path[-1]) < .002, "preview follows real trajectory through first contact pitch %.2f" % pitch)
	fixture()
	app.manual_input_enabled = false
	app.last_aim = Vector3.RIGHT
	expect(app.shot_direction().is_equal_approx(Vector3.RIGHT * cos(deg_to_rad(48)) + Vector3.UP * sin(deg_to_rad(48))), "legacy flat record-driver aim retains default loft")
	app.last_aim = Vector3(-.2, .9, .4)
	expect(app.shot_direction().is_equal_approx(app.last_aim.normalized()), "explicit record-driver 3D aim is literal")
	app.submit_action("request_pass")
	expect(app.captured_aim.y == 0 and app.captured_aim.is_equal_approx(Vector3(-.2, 0, .4).normalized()), "non-shot actions keep flat control aim")
	var wire_aim: Vector3 = bytes_to_var(var_to_bytes(app.last_aim.normalized()))
	app.host_action(1, "throw", .7, wire_aim, Vector3.RIGHT)
	expect(app.sim.ball.vel.normalized().is_equal_approx(wire_aim) and app.sim.players[1].move == Vector3.RIGHT and app.sim.players[1].aim.y == 0, "RPC Vector3 survives host action and preserves flat movement")
	app.queue_free()
	await process_frame
	print("V11 INPUT AIM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
