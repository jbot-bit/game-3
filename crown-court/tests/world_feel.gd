extends SceneTree
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var world
var sim
var checks: Array = []
var unchanged := true
var evidence := "C:/game-3/build/crown-court-evidence/v7-world-feel-headless"
var capture_enabled := false
var captures := {}
var pack_source := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"pass":ok,"label":label,"details":details})

func present(dt: float = 1.0 / 60) -> void:
	if sim.ball.owner > 0: sim.ball.pos = sim.hand_position(sim.ball.owner)
	var state: Dictionary = sim.snapshot()
	state.players = {1:state.players[1]}
	var before := var_to_bytes(state)
	world.present(state,1,dt,.6,.43)
	unchanged = unchanged and before == var_to_bytes(state)

func capture(label: String) -> void:
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func prepare() -> void:
	sim = Sim.new()
	sim.reset("coop")
	sim.players = {1:sim.players[1]}
	sim.reset_time = 0
	sim.players[1].pos = Vector3.ZERO
	sim.players[1].vel = Vector3.ZERO
	sim.players[1].move = Vector3.ZERO
	sim.players[1].aim = Vector3.FORWARD
	sim.players[1].facing = Vector3.FORWARD
	sim.ball.owner = 0
	sim.ball.lock = 0
	sim.ball.pos = Vector3(0,.65,-.85)
	for i in 45: present()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	prepare()
	sim.players[1].move = Vector3.FORWARD
	for i in 35: present()
	var stroke := 0.0
	var previous: Vector3 = world.actors[1].left_foot.position
	for i in 12:
		present()
		stroke += previous.distance_to(world.actors[1].left_foot.position)
		previous = world.actors[1].left_foot.position
	check(stroke > .10,"held movement intent keeps feet working through zero speed",{"foot_travel_m":stroke})
	await capture("01-start-scramble")
	sim.players[1].vel = Vector3.FORWARD*8
	sim.players[1].move = Vector3.FORWARD
	sim.players[1].facing = Vector3.BACK
	for i in 45: present()
	var normal_tilt: float = world.actors[1].rig.rotation.x
	sim.players[1].move = Vector3.BACK
	for i in 12: present()
	var skid_tilt: float = world.actors[1].rig.rotation.x
	check(absf(skid_tilt-normal_tilt) > .10,"opposed intent and velocity produces a distinct grounded braking pose",{"normal_tilt":normal_tilt,"reverse_tilt":skid_tilt})
	await capture("02-reversal-brake")
	sim.players[1].grounded = false
	sim.players[1].pos.y = 2
	sim.players[1].vel.y = 4
	for i in 35: present()
	check(absf(world.actors[1].rig.rotation.x+.052)<.07,"ground traction pose clears in the air")
	await capture("03-airborne")
	sim.players[1].grounded = true
	sim.players[1].pos.y = 0
	sim.players[1].vel.y = 0
	sim.players[1].boost_time = .8
	for i in 35: present()
	check(absf(world.actors[1].rig.rotation.x+.104)<.07,"speed boosts retain their own pose instead of a false skid")
	prepare()
	var before: Vector3 = world.ball_root.position
	sim.action(1,"catch")
	present(0)
	var catch_step: float = world.ball_root.position.distance_to(before)
	check(sim.ball.owner==1 and catch_step<.10,"nearby catch begins at the rendered loose-ball position",{"catch_jump_m":catch_step})
	await capture("04-catch-contact")
	var gap := 0.0
	for i in 12:
		present()
		for key in ["left_hand","right_hand"]: gap = maxf(gap,world.actors[1][key].global_position.distance_to(world.ball_root.position))
	check(gap < .45 and world.ball_root.position.distance_to(sim.ball.pos)<.01,"catch gathers into physical carry with both hands attached",{"hand_center_gap_m":gap,"carry_error_m":world.ball_root.position.distance_to(sim.ball.pos)})
	await capture("05-catch-gathered")
	prepare()
	sim.action(1,"catch")
	present()
	for i in 2: present()
	before = world.ball_root.position
	sim.action(1,"throw",.5)
	present(0)
	check(world.ball_root.position.distance_to(before)<.10,"quick catch then release preserves presentation continuity",{"release_jump_m":world.ball_root.position.distance_to(before)})
	for i in 30:
		sim.step(1.0/60)
		present()
	check(world.ball_root.position.distance_to(sim.ball.pos)<.01,"released gather converges to unfiltered flight")
	prepare()
	sim.action(1,"catch")
	present()
	sim.ball.owner = 0
	sim.ball.pos = Vector3(0,2,0)
	sim.reset_time = 3
	present()
	check(world.ball_root.position.distance_to(sim.ball.pos)<.001,"kickoff clears an interrupted gather immediately")
	prepare()
	sim.players[1].pos = Vector3(12,0,0)
	sim.ball.owner = 1
	present()
	check(world.ball_root.position.distance_to(sim.ball.pos)<.01,"large owner relocation attaches without dragging a stale catch across court")
	prepare()
	sim.players[1].giant = 4
	sim.ball.pos = Vector3(-1.8,.52,0)
	for i in 45: present()
	before = world.ball_root.position
	sim.action(1,"catch")
	present(0)
	check(sim.ball.owner==1 and world.ball_root.position.distance_to(before)<.10,"Giant catch uses physical reach without bypassing the gather",{"catch_jump_m":world.ball_root.position.distance_to(before)})
	await capture("06-giant-contact")
	var giant_gap := 0.0
	for i in 12:
		present()
		for key in ["left_hand","right_hand"]: giant_gap = maxf(giant_gap,world.actors[1][key].global_position.distance_to(world.ball_root.position))
		if i == 3: await capture("07-giant-gather")
	check(giant_gap<.82 and world.ball_root.position.distance_to(sim.ball.pos)<.01,"Giant hands follow the same gathering ball",{"hand_center_gap_m":giant_gap})
	await capture("08-giant-carried")
	check(unchanged,"world feel presentation never mutates simulation snapshots")
	var report := {"fixtures":true,"checks":checks,"failures":checks.filter(func(row):return not row.pass),"captures":captures,"world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"probe_sha256":FileAccess.get_sha256(get_script().resource_path)}
	if not pack_source.is_empty():
		report["pack_sha256"] = FileAccess.get_sha256(pack_source)
		report["world_sha256"] = ""
		report["sim_sha256"] = ""
		report["source_identity_note"] = "Compiled scripts are identified by the exact pack SHA; loose res:// file hashes are not used."
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_FEEL_RESULT ",JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
