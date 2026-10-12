extends SceneTree

var app
var sequence = 0
var checks: Array[Dictionary] = []
var output = "res://tests/snapshot-recovery"
var profile_path = ""
var frames: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func expect(ok: bool, label: String, observed = null) -> void:
	checks.append({"check":label,"passed":ok,"observed":observed})
	print("PASS " if ok else "FAIL ",label," ",observed if observed != null else "")

func begin_case(label: String) -> void:
	app.match_id = label
	app.sim.reset("coop")
	app.state = app.sim.snapshot()
	app.state.match_id = label
	app.state.reset_time = 0
	app.state.celebration_time = 0
	app.state.players[2].grounded = true
	app.state.players[2].boost_time = 1.0
	app.state.players[2].pos = Vector3(-10,0,0)
	app.state.players[2].vel = Vector3.RIGHT*18
	app.state.players[2].move = Vector3.RIGHT
	if app.world.actors.has(2): app.world.actors[2]["initialized"] = false
	app.local_render_clock = -1
	app.reset_ball_presentation()

func packet(time: float, player_position: Vector3, player_velocity: Vector3, ball_position: Vector3, ball_velocity: Vector3, owner: int = 0) -> void:
	sequence += 1
	var wire: Dictionary = app.state.duplicate(true)
	wire.match_id = app.match_id
	wire._snapshot_seq = sequence
	wire.clock = time
	wire.players[2].pos = player_position
	wire.players[2].vel = player_velocity
	wire.ball.pos = ball_position
	wire.ball.vel = ball_velocity
	wire.ball.owner = owner
	app.receive_state(var_to_bytes(wire).compress(FileAccess.COMPRESSION_DEFLATE))

func render(dt: float) -> Dictionary:
	app.ui_clock += dt
	var shown: Dictionary = app.predict_render_state(app.ui_clock-app.snapshot_received_at)
	app.world.present(shown,1,dt,0,.43)
	frames.append({"round":app.match_id,"time":app.ui_clock,"clock":app.state.clock,"age":app.ui_clock-app.snapshot_received_at,"actor_x":app.world.actors[2].root.position.x,"target_x":shown.players[2].pos.x,"ball_x":shown.ball.pos.x})
	return shown

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	app = load("res://main.gd").new()
	profile_path = "user://snapshot_recovery_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.world.build("coop")
	app.phase = "match"
	begin_case("delayed-carrier")
	packet(0,Vector3(-4,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
	var before = render(0)
	for index in 12: before = render(1.0/60)
	var actor_before: Vector3 = app.world.actors[2].root.position
	var accepted: int = app.snapshot_count
	packet(.05,Vector3(-3.6,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
	var authority = var_to_bytes(app.state)
	var after = render(1.0/60)
	var actor_step: float = app.world.actors[2].root.position.x-actor_before.x
	expect(app.snapshot_count == accepted+1,"Delayed carrier packet actually applies through receive_state")
	expect(after.players[2].pos.x >= before.players[2].pos.x-.001,"Delayed forward carrier target does not rewind",after.players[2].pos.x-before.players[2].pos.x)
	expect(actor_step >= -.001,"Actual rendered remote actor does not reverse on delayed forward packet",actor_step)
	app.presentation_sim.players = after.players
	expect(after.ball.pos.distance_to(app.presentation_sim.hand_position(2)) < .001,"Held ball shares recovered carrier target")
	expect(var_to_bytes(app.state)==authority,"Remote recovery preserves authoritative packet bytes")
	begin_case("half-second-gap")
	packet(0,Vector3(-10,0,0),Vector3.RIGHT*18,Vector3(-10,12,0),Vector3.RIGHT*20)
	before = render(0)
	for index in 31: before = render(1.0/60)
	actor_before = app.world.actors[2].root.position
	packet(.525,Vector3(-.55,0,0),Vector3.RIGHT*18,Vector3(-10,12,0)+Vector3.RIGHT*20*.525+Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*.525*.525,Vector3.RIGHT*20+Vector3.DOWN*app.Sim.BALL_GRAVITY*.525)
	after = render(1.0/60)
	expect(app.world.actors[2].root.position.distance_to(actor_before) < 2,"Plausible half-second remote movement recovers without actor teleport",app.world.actors[2].root.position.distance_to(actor_before))
	expect(after.ball.pos.distance_to(before.ball.pos) < 2,"Plausible half-second ball flight recovers without a single large cut",after.ball.pos.distance_to(before.ball.pos))
	var maximum_ball_step = 0.0
	var maximum_actor_step = 0.0
	var prior_ball: Vector3 = after.ball.pos
	var prior_actor: Vector3 = app.world.actors[2].root.position
	for frame in 30:
		var t = .525+float(frame+1)/60
		if frame%3 == 0:
			packet(t,Vector3(-10+18*t,0,0),Vector3.RIGHT*18,Vector3(-10,12,0)+Vector3.RIGHT*20*t+Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*t*t,Vector3.RIGHT*20+Vector3.DOWN*app.Sim.BALL_GRAVITY*t)
		after = render(1.0/60)
		maximum_ball_step = maxf(maximum_ball_step,after.ball.pos.distance_to(prior_ball))
		maximum_actor_step = maxf(maximum_actor_step,app.world.actors[2].root.position.distance_to(prior_actor))
		prior_ball = after.ball.pos
		prior_actor = app.world.actors[2].root.position
	var age = minf(.08,app.ui_clock-app.snapshot_received_at)
	var expected_player: Vector3 = app.state.players[2].pos+app.state.players[2].vel*age
	var expected_ball: Vector3 = app.state.ball.pos+app.state.ball.vel*age+Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*age*age
	expect(after.players[2].pos.distance_to(expected_player)<.08 and after.ball.pos.distance_to(expected_ball)<.08,"Recovered stream converges within half a second instead of retaining permanent lag",[after.players[2].pos.distance_to(expected_player),after.ball.pos.distance_to(expected_ball)])
	expect(maximum_ball_step<2 and maximum_actor_step<2,"Catch-up remains spread over rendered frames",[maximum_actor_step,maximum_ball_step])
	var starvation_actor: Vector3
	var starvation_ball: Vector3
	for frame in 24:
		after = render(1.0/60)
		if frame == 12:
			starvation_actor = after.players[2].pos
			starvation_ball = after.ball.pos
	expect(after.players[2].pos.distance_to(starvation_actor)<.001 and after.ball.pos.distance_to(starvation_ball)<.001,"Both correction offsets freeze with the80ms extrapolation cap")
	# Counterexamples must snap or keep impulses immediate, not turn stale
	# history into a new movement/ownership authority.
	packet(app.state.clock+.1,Vector3(-8,0,0),Vector3.RIGHT*18,Vector3(-8,8,0),Vector3.ZERO)
	after = render(0)
	expect(after.players[2].pos==app.state.players[2].pos and after.ball.pos==app.state.ball.pos,"Inconsistent large warp is not smoothed even inside the600ms admission interval")
	begin_case("too-old")
	packet(0,Vector3(-10,0,0),Vector3.RIGHT*18,Vector3(-10,12,0),Vector3.RIGHT*20)
	render(0)
	for frame in 42: render(1.0/60)
	packet(.7,Vector3(2.6,0,0),Vector3.RIGHT*18,Vector3(4,7.59,0),Vector3(20,-12.6,0))
	after = render(0)
	expect(after.players[2].pos==app.state.players[2].pos and after.ball.pos==app.state.ball.pos,"Gap older than600ms is not admitted as continuous recovery")
	for impulse in ["jump_count","stun","dunk","boost_time"]:
		begin_case("impulse-"+impulse)
		app.state.players[2].boost_time = 0
		packet(0,Vector3(-4,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
		render(0)
		for frame in 12: render(1.0/60)
		app.state.players[2][impulse] = 1
		packet(.05,Vector3(-3.6,0,0),Vector3.LEFT*8,Vector3.ZERO,Vector3.ZERO,2)
		after = render(0)
		expect(after.players[2].pos==app.state.players[2].pos,"Authoritative %s transition stays immediate"%impulse)
	begin_case("regular-stream")
	var regular_error = 0.0
	for frame in 30:
		var t = float(frame)/60
		if frame%3==0: packet(t,Vector3(-10+8*t,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
		after = render(1.0/60)
		regular_error = maxf(regular_error,absf(after.players[2].pos.x-(-10+8*(t+1.0/60))))
	expect(regular_error<.001,"Regular20Hz remote motion gains no interpolation delay",regular_error)
	app.state.reset_time = 3
	after = render(1.0/60)
	expect(after.players[2].pos==app.state.players[2].pos and after.ball.pos==app.state.ball.pos,"Kickoff clears player and ball recovery")
	for fps in [30,120]:
		begin_case("cadence-%d"%fps)
		packet(0,Vector3(-10,0,0),Vector3.RIGHT*18,Vector3(-10,12,0),Vector3.RIGHT*20)
		before = render(0)
		for frame in int(fps*.525): before = render(1.0/fps)
		var previous_ball: Vector3 = before.ball.pos
		var previous_actor: Vector3 = app.world.actors[2].root.position
		var maximum_step = 0.0
		var last_send = -.05
		for frame in int(fps*.5):
			var time = float(frame)/fps
			var t = .525+time
			if time-last_send >= .05-.0001:
				packet(t,Vector3(-10+18*t,0,0),Vector3.RIGHT*18,Vector3(-10,12,0)+Vector3.RIGHT*20*t+Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*t*t,Vector3.RIGHT*20+Vector3.DOWN*app.Sim.BALL_GRAVITY*t)
				last_send = time
			after = render(1.0/fps)
			maximum_step = maxf(maximum_step,maxf(after.ball.pos.distance_to(previous_ball),app.world.actors[2].root.position.distance_to(previous_actor)))
			previous_ball = after.ball.pos
			previous_actor = app.world.actors[2].root.position
		age = minf(.08,app.ui_clock-app.snapshot_received_at)
		expected_ball = app.state.ball.pos+app.state.ball.vel*age+Vector3.DOWN*.5*app.Sim.BALL_GRAVITY*age*age
		expect(maximum_step < 70.0/fps and after.ball.pos.distance_to(expected_ball)<.12,"Recovery stays bounded and converges at%dHz"%fps,[maximum_step,after.ball.pos.distance_to(expected_ball)])
	begin_case("pending-local-jump")
	app.state.players[1].pos = Vector3.ZERO
	app.state.players[1].vel = Vector3.ZERO
	app.state.players[1].grounded = true
	app.state.players[1].jump_count = 0
	packet(0,Vector3(-4,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
	render(0)
	app.begin_jump_prediction(app.state.players[1])
	before = render(1.0/60)
	packet(.05,Vector3(-3.6,0,0),Vector3.RIGHT*8,Vector3.ZERO,Vector3.ZERO,2)
	after = render(1.0/60)
	expect(before.players[1].pos.y>.1 and after.players[1].pos.y>before.players[1].pos.y,"Ground contact correction preserves pending local jump through a stale grounded packet")
	var report = {"checks":checks,"passed":checks.all(func(item):return item.passed),"frames":frames,"scope":"Production compressed receive path and real world transform updates, headless; controlled temporal fixture, no GPU/network/human claim"}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if report.passed else 1)
