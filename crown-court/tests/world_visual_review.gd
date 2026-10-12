extends SceneTree

const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var world: Node3D
var sim: RefCounted
var findings: Dictionary = {}
var output_phase := "baseline" if "--baseline" in OS.get_cmdline_user_args() else "after"
var evidence_dir := "res://tests"

func argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="): return argument.substr(prefix.length() + 1)
	return ""

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := "world_visual_%s_%s.png" % [output_phase, label]
	var destination := evidence_dir.path_join(filename)
	root.get_texture().get_image().save_png(destination)
	if not findings.has("raw_capture_hashes"): findings.raw_capture_hashes = {}
	findings.raw_capture_hashes[filename] = FileAccess.get_sha256(destination)

func _initialize() -> void:
	run.call_deferred()

func present(yaw: float = 0, pitch: float = .43) -> void:
	if sim.ball.owner == 1: sim.ball.pos = sim.hand_position(1)
	var state: Dictionary = sim.snapshot()
	state.players = {1: state.players[1]}
	world.present(state, 1, 1.0 / 60, yaw, pitch)

func reset_actor(at: Vector3 = Vector3.ZERO) -> void:
	sim.reset("coop")
	sim.reset_time = 0.0
	sim.players[1].pos = Vector3(at.x, Sim.floor_height(at.x, at.z), at.z)
	sim.players[1].grounded = true
	sim.ball.owner = 1
	world.camera_ready = false
	if world.actors.has(1): world.actors[1].initialized = false
	for frame in 90: present()

func hand_gap() -> float:
	var gap := 0.0
	for key in ["left_hand", "right_hand"]:
		gap = maxf(gap, world.actors[1][key].global_position.distance_to(world.ball_root.global_position))
	return gap

func run() -> void:
	var requested_dir := argument_value("--evidence-dir")
	if not requested_dir.is_empty(): evidence_dir = requested_dir
	if DirAccess.make_dir_recursive_absolute(evidence_dir) != OK:
		push_error("Cannot create world review evidence directory: " + evidence_dir)
		quit(2)
		return
	findings.source_hashes = {}
	for relative in ["world.gd", "sim.gd", "tests/world_visual_review.gd"]:
		if FileAccess.file_exists("res://" + relative): findings.source_hashes[relative] = FileAccess.get_sha256("res://" + relative)
	var artifact := argument_value("--pack-source")
	if not artifact.is_empty():
		if not FileAccess.file_exists(artifact):
			push_error("Requested pack identity file is missing: " + artifact)
			quit(2)
			return
		findings.pack_provenance = {"path": artifact, "sha256": FileAccess.get_sha256(artifact), "note": "Packed executable identity; compiled script source is not reconstructed or claimed readable."}
	if not findings.source_hashes.has("world.gd") and artifact.is_empty():
		push_error("Packed source unavailable: pass --pack-source=<exact executable or pack> to record its actual SHA-256.")
		quit(2)
		return
	root.size = Vector2i(1280, 800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	sim = Sim.new()
	for radians_per_frame in [.08, .16, .32]:
		reset_actor()
		var worst := 0.0
		var separated := 0
		for frame in 30:
			var yaw: float = radians_per_frame * frame
			sim.players[1].aim = Vector3(-sin(yaw), 0, -cos(yaw))
			sim.players[1].facing = sim.players[1].aim
			present(yaw)
			var gap := hand_gap()
			worst = maxf(worst, gap)
			if gap > .70: separated += 1
		findings["carry_turn_%.2f" % radians_per_frame] = {"max_hand_center_gap_m": worst, "frames_beyond_ball_and_hand_radius": separated, "frames": 30}
	reset_actor()
	await capture("giant_before")
	var giant_gap := 0.0
	var giant_separated := 0
	var giant_arm_ratio := 0.0
	sim.players[1].giant = 5.0
	for frame in 30:
		present()
		giant_gap = maxf(giant_gap, hand_gap())
		if hand_gap() > .82: giant_separated += 1
		var shoulder: Vector3 = world.actors[1].rig.to_global(Vector3(-.4, 1.03, 0))
		giant_arm_ratio = maxf(giant_arm_ratio, world.actors[1].left_hand.global_position.distance_to(shoulder) / float(world.actors[1].get("visual_size", 1.0)))
		if frame == 0: await capture("giant_onset")
	findings.giant_onset = {"max_hand_center_gap_m": giant_gap, "separated_frames": giant_separated, "max_arm_span_per_body_scale": giant_arm_ratio}
	for frame in 90: present()
	sim.players[1].giant = 0.0
	var expiry_gap := 0.0
	for frame in 30:
		present()
		expiry_gap = maxf(expiry_gap, hand_gap())
	findings.giant_expiry = {"max_hand_center_gap_m": expiry_gap}
	reset_actor(Vector3(0, 0, 10))
	sim.players[1].vel = Vector3(0, 0, -18)
	for frame in 30:
		sim.players[1].pos.z -= .3
		present()
	var before_release: Vector3 = world.ball_root.global_position
	var physics_before_release: Vector3 = sim.ball.pos
	await capture("release_before")
	sim.action(1, "throw", .5)
	present()
	await capture("release_after")
	var release_jump: float = world.ball_root.global_position.distance_to(before_release)
	findings.boost_throw_transition = {"rendered_release_jump_without_sim_time_m": release_jump, "physics_release_jump_m": sim.ball.pos.distance_to(physics_before_release)}
	for frame in 20:
		sim.step(1.0/60)
		present()
	var release_residual: float = world.ball_root.global_position.distance_to(sim.ball.pos)
	findings.boost_throw_transition.residual_after_third_second_m = release_residual
	sim.ball.owner = 1
	present()
	var caught_offset: Vector3 = world.ball_root.global_position - world.actors[1].root.global_position
	findings.boost_throw_transition.recatch_attachment_error_m = caught_offset.distance_to(sim.ball.pos - sim.players[1].pos)
	sim.players[1].pos.z -= .3
	present()
	sim.action(1, "throw", .5)
	present()
	sim.reset_time = 3.0
	sim.ball.pos = Vector3(0, Sim.BALL_RADIUS, 0)
	present()
	findings.boost_throw_transition.kickoff_ball_error_m = world.ball_root.global_position.distance_to(sim.ball.pos)
	var terrain_worst := 0.0
	var terrain_case: Dictionary = {}
	var camera_yaw_error := 0.0
	for at in [Vector3(0,0,Sim.CROSS_LANE_Z),Sim.PADS[3],Vector3(Sim.HALF_WIDTH-2,0,Sim.CROSS_LANE_Z),Vector3(0,0,Sim.HALF_LENGTH-3),Vector3(Sim.HALF_WIDTH-3,0,Sim.HALF_LENGTH-3)]:
		reset_actor(at)
		for step in 72:
			var yaw := step * TAU / 72
			present(yaw, .15)
			var target: Vector3 = world.actors[1].root.global_position + Vector3.UP * .9
			var camera_forward: Vector3 = -world.camera.global_basis.z
			camera_yaw_error = maxf(camera_yaw_error, Vector3(camera_forward.x, 0, camera_forward.z).normalized().angle_to(Vector3(-sin(yaw), 0, -cos(yaw))))
			for sample in range(2, 39):
				var point: Vector3 = world.camera.global_position.lerp(target, sample / 40.0)
				var intrusion := Sim.floor_height(point.x, point.z) - point.y
				if intrusion > terrain_worst:
					terrain_worst = intrusion
					terrain_case = {"player": at, "yaw": yaw, "point": point, "camera": world.camera.global_position}
	findings.camera_terrain = {"max_intrusion_m": terrain_worst, "case": terrain_case, "max_horizontal_aim_error_radians": camera_yaw_error}
	var board_hidden: Array = []
	for at in [Sim.NORTH+Vector3(0,-Sim.HOOP_Y,4),Sim.NORTH-Vector3.UP*Sim.HOOP_Y,Vector3(0,0,-Sim.KICKOFF_Z),Sim.NORTH+Vector3(3,-Sim.HOOP_Y,0)]:
		reset_actor(at)
		for yaw in [0.0, PI / 2, PI, -PI / 2]:
			for frame in 60: present(yaw)
			if not world.occluders[0].node.visible: board_hidden.append({"player": at, "yaw": yaw})
	findings.whole_north_hoop_hidden = board_hidden
	findings.failing_regressions = []
	if giant_gap > .82: findings.failing_regressions.append("Giant onset hands detach from held ball")
	if giant_arm_ratio > 1.5: findings.failing_regressions.append("Giant growth stretches arms ahead of body")
	if expiry_gap > .82: findings.failing_regressions.append("Giant expiry hands detach from held ball")
	if release_jump > .1: findings.failing_regressions.append("Boosted throw adds a visual ball jump with no simulated movement")
	if release_residual > .01: findings.failing_regressions.append("Release presentation fails to converge to physical flight")
	if findings.boost_throw_transition.recatch_attachment_error_m > .001: findings.failing_regressions.append("Recatch retains stale release correction")
	if findings.boost_throw_transition.kickoff_ball_error_m > .001: findings.failing_regressions.append("Kickoff retains stale release correction")
	print("WORLD_VISUAL_REVIEW ", JSON.stringify(findings))
	var file := FileAccess.open(evidence_dir.path_join("world_visual_review_%s.json" % output_phase), FileAccess.WRITE)
	if file == null:
		push_error("Could not write world review results")
		quit(2)
		return
	file.store_string(JSON.stringify(findings, "  "))
	file.close()
	quit(0 if findings.failing_regressions.is_empty() else 1)
