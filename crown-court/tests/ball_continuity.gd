extends SceneTree

var app
var sequence = 0
var checks: Array[Dictionary] = []
var output = "res://tests/ball-continuity"
var profile_path = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func expect(ok: bool, label: String, observed = null) -> void:
	checks.append({"check":label,"passed":ok,"observed":observed})
	print("PASS " if ok else "FAIL ", label, " ", observed if observed != null else "")

func packet(position: Vector3, velocity: Vector3, owner: int = 0, reset: float = 0) -> void:
	sequence += 1
	var wire: Dictionary = app.state.duplicate(true)
	wire.match_id = app.match_id
	wire._snapshot_seq = sequence
	wire.clock = sequence * .05
	wire.reset_time = reset
	wire.ball.pos = position
	wire.ball.vel = velocity
	wire.ball.owner = owner
	app.receive_state(var_to_bytes(wire).compress(FileAccess.COMPRESSION_DEFLATE))

func rendered(dt: float) -> Dictionary:
	app.ui_clock += dt
	return app.predict_render_state(app.ui_clock - app.snapshot_received_at)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	app = load("res://main.gd").new()
	profile_path = "user://ball_continuity_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.state.reset_time = 0
	app.state.celebration_time = 0
	var samples: Array = []
	packet(Vector3(-4, 8, 0), Vector3(20, 0, 0))
	var before: Dictionary
	for index in 5:
		before = rendered(1.0 / 60)
		samples.append({"clock":app.ui_clock,"x":before.ball.pos.x})
	# This is the next 50 ms simulation sample arriving after 83 ms.
	# No direction change occurred; a backwards visual step is a correction bug.
	var accepted_before: int = app.snapshot_count
	packet(Vector3(-3, 7.9625, 0), Vector3(20, -1.5, 0))
	expect(app.snapshot_count == accepted_before + 1, "Jittered packet actually passes the production receive path")
	var authority = var_to_bytes(app.state)
	var after = rendered(1.0 / 60)
	var packet_step: float = after.ball.pos.x - before.ball.pos.x
	expect(packet_step >= -0.001, "Forward flight does not rewind on a delayed snapshot", packet_step)
	var last_x: float = after.ball.pos.x
	var starved_min_step = 0.0
	for index in 12:
		after = rendered(1.0 / 60)
		starved_min_step = minf(starved_min_step, after.ball.pos.x-last_x)
		last_x = after.ball.pos.x
	expect(starved_min_step >= -0.001, "Extrapolation cap holds a starved ball without correction rewinds", starved_min_step)
	var min_step = packet_step
	for index in 30:
		if index % 3 == 0:
			packet(Vector3(-2 + float(index)/3, 7.7, 0), Vector3(20, 0, 0))
		after = rendered(1.0 / 60)
		min_step = minf(min_step, after.ball.pos.x-last_x)
		last_x = after.ball.pos.x
		samples.append({"clock":app.ui_clock,"x":last_x})
	expect(min_step >= -0.001, "Correction converges without repeated reverse steps", min_step)
	# Keep a fresh immutable-state check separate from the preceding packet writes.
	authority = var_to_bytes(app.state)
	after = rendered(1.0 / 60)
	expect(authority == var_to_bytes(app.state), "Ball presentation never mutates authoritative state")
	packet(Vector3.ZERO, Vector3.ZERO, 1)
	after = rendered(1.0 / 60)
	app.presentation_sim.players = after.players
	expect(after.ball.pos.distance_to(app.presentation_sim.hand_position(1)) < .001, "Catch attaches to the hand with no leftover loose-flight correction")
	packet(Vector3(10, 8, 2), Vector3(5, 3, 0))
	after = rendered(0)
	expect(after.ball.pos.distance_to(Vector3(10, 8, 2)) < .001, "Release leaves transition gathering to the world renderer")
	packet(Vector3(-15, 8, 2), Vector3.ZERO)
	after = rendered(0)
	expect(after.ball.pos.distance_to(Vector3(-15, 8, 2)) < .001, "Large authoritative relocation snaps instead of dragging the ball")
	packet(Vector3(0, 2, 0), Vector3.ZERO, 0, 3)
	after = rendered(.016)
	expect(after.ball.pos == app.state.ball.pos, "Kickoff resets clear presentation correction")
	# Regular 20 Hz delivery must not gain a permanent interpolation delay.
	app.match_id += "-steady"
	app.state.match_id = app.match_id
	var start = Vector3(-8, 12, 0)
	var launch = Vector3(12, 4, 0)
	var steady_error = 0.0
	for frame in 45:
		var t = float(frame) / 60
		if frame % 3 == 0:
			packet(start + launch*t + Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*t*t, launch + Vector3.DOWN*app.Sim.BALL_GRAVITY*t)
		after = rendered(1.0 / 60)
		t += 1.0 / 60
		var expected = start + launch*t + Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*t*t
		steady_error = maxf(steady_error, after.ball.pos.distance_to(expected))
	expect(steady_error < .001, "Regular ballistic delivery gains no extra interpolation delay", steady_error)
	var report = {"checks":checks,"passed":checks.all(func(item):return item.passed),"samples":samples,"scope":"Injected compressed production snapshot delivery; no ENet/GPU/physical controller claim"}
	var file = FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BALL CONTINUITY ",JSON.stringify({"passed":report.passed,"checks":checks.size()}))
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	quit(0 if report.passed else 1)
