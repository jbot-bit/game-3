extends SceneTree

var app
var result: Dictionary = {}
var failures: Array = []
var baseline = false
var evidence = "res://tests/feel"
var evidence_base = "res://tests/feel"
var route_samples: Array = []
var route_mode = false
var focus_recoveries = 0
var pending_captures: Dictionary = {}
var camera_samples: Array = []
var settings_existed = false
var saved_settings = PackedByteArray()

func _initialize() -> void:
	_run.call_deferred()

func key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse(button: int, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func motion(relative: Vector2) -> void:
	var event = InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	Input.parse_input_event(event)

func frames(count: int) -> void:
	if route_mode and is_instance_valid(app) and app.paused:
		focus_recoveries += 1
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
		Input.flush_buffered_events()
	for index in count: await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	pending_captures[evidence + "-" + suffix + ".png"] = root.get_texture().get_image()

func save_captures() -> void:
	for path in pending_captures: pending_captures[path].save_png(path)

func restore_settings() -> void:
	if settings_existed:
		var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		file.store_buffer(saved_settings)
		file.close()
	elif FileAccess.file_exists("user://settings.cfg"):
		DirAccess.remove_absolute("user://settings.cfg")

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func fixture(at: Vector3 = Vector3.ZERO) -> void:
	var player: Dictionary = app.sim.players[1]
	player.pos = at
	player.vel = Vector3.ZERO
	player.move = Vector3.ZERO
	player.aim = Vector3.FORWARD
	player.facing = Vector3.FORWARD
	player.grounded = true
	player.jump_count = 0
	player.stun = 0.0
	player.dive = 0.0
	player.dunk = 0.0
	player.cooldown = 0.0
	player.catch_time = 0.0
	app.sim.reset_time = 0.0
	app.sim.ball.owner = 0
	app.sim.ball.pos = Vector3(7, 1, 8)
	app.sim.ball.vel = Vector3.ZERO
	app.sim.ball.lock = 0.0
	app.state = app.sim.snapshot()
	app.yaw = 0.0
	app.pitch = 0.43
	app.ball_camera = false
	app.charging = false
	app.charge_time = 0.0
	app.input_armed = true
	app.set_paused(false)
	app.input_armed = true

func _run() -> void:
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed: saved_settings = FileAccess.get_file_as_bytes("user://settings.cfg")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			var folder = argument.trim_prefix("--evidence-dir=")
			DirAccess.make_dir_recursive_absolute(folder)
			evidence_base = folder.path_join("feel")
	baseline = "--baseline" in OS.get_cmdline_user_args()
	evidence = evidence_base + ("-baseline" if baseline else "-after")
	root.size = Vector2i(1280, 800)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if not is_instance_valid(app.world):
		printerr("FEEL_INPUT could not construct the application")
		restore_settings()
		quit(1)
		return
	app.profile = load("res://profile.gd").new("user://feel_unsaved_%d.json" % Time.get_ticks_usec())
	app.muted = true
	app.practice_game("coop")
	app.seats = {1:1, 2:2, 3:3, 4:4, 5:5, 6:6}
	if "--route" in OS.get_cmdline_user_args():
		await play_route()
		return
	for id in app.sim.players:
		if id != 1: app.sim.players[id].pos = Vector3(8, 0, 12 + id * .5)
	await frames(3)
	fixture()
	await frames(3)
	motion(Vector2(120, -40))
	await frames(3)
	result.mouse_yaw = app.yaw
	result.mouse_pitch = app.pitch
	var forward: Vector3 = app.camera_forward()
	var at: Vector3 = app.sim.players[1].pos
	var movement_clock: float = app.sim.clock
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	await frames(2)
	var displacement: Vector3 = app.sim.players[1].pos - at
	result.forward_alignment = displacement.normalized().dot(forward)
	result.half_second_distance = displacement.length()
	result.movement_sim_seconds = app.sim.clock - movement_clock
	await capture("camera-forward")
	expect(result.mouse_yaw < 0 and result.mouse_pitch < .43, "Mouse turns right and looks up with expected signs")
	expect(result.forward_alignment > .97, "W follows camera heading")
	fixture()
	app.sim.ball.pos = Vector3(8, 1, 0)
	key(KEY_CTRL, true)
	await frames(2)
	key(KEY_CTRL, false)
	await frames(30)
	var before_yaw: float = app.yaw
	motion(Vector2(100, 0))
	await frames(3)
	result.ball_camera_manual_yaw = absf(angle_difference(before_yaw, app.yaw))
	result.ball_camera_after_manual_look = app.ball_camera
	if not baseline: expect(not app.ball_camera and result.ball_camera_manual_yaw > .2, "Manual look releases ball camera")
	fixture()
	await frames(2)
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await frames(1)
	result.quick_tap_jump_count = app.sim.players[1].jump_count
	result.first_frame_jump_height = app.sim.players[1].pos.y
	expect(result.quick_tap_jump_count == 1, "A press/release in one frame still jumps")
	await frames(12)
	key(KEY_SPACE, true)
	await frames(1)
	key(KEY_SPACE, false)
	var peak = 0.0
	var camera_peak = 0.0
	for index in 100:
		await frames(1)
		peak = maxf(peak, app.sim.players[1].pos.y)
		camera_peak = maxf(camera_peak, app.world.camera.position.y)
	result.double_jump_peak = peak
	result.double_jump_camera_peak = camera_peak
	fixture()
	app.sim.ball.pos = Vector3(3.4, 1, 0)
	app.sim.ball.vel = Vector3(-9, 0, 0)
	key(KEY_E, true)
	await frames(1)
	key(KEY_E, false)
	await frames(14)
	result.early_e_catch_owner = app.sim.ball.owner
	if not baseline: expect(result.early_e_catch_owner == 1, "E catches a ball arriving shortly after the press")
	fixture()
	app.sim.players[2].pos = Vector3(0, 0, -1.5)
	app.sim.ball.owner = 2
	await frames(3)
	result.teammate_ball_prompt = app.prompt_label.text
	await capture("teammate-ball")
	if not baseline: expect("Call for ball" in result.teammate_ball_prompt, "Nearby teammate holding the ball offers a pass request")
	app.sim.players[2].pos = Vector3(8, 0, 13)
	app.sim.players[4].pos = Vector3(0, 0, -1.5)
	app.sim.ball.owner = 4
	await frames(3)
	result.opponent_ball_prompt = app.prompt_label.text
	await capture("opponent-ball")
	if not baseline: expect("Tackle" in result.opponent_ball_prompt, "Nearby opponent holding the ball offers a tackle")
	app.sim.players[4].pos = Vector3(8, 0, 14)
	fixture()
	app.sim.ball.owner = 1
	await frames(2)
	var throws_before: int = app.sim.throws
	mouse(MOUSE_BUTTON_RIGHT, true)
	mouse(MOUSE_BUTTON_RIGHT, false)
	await frames(2)
	result.quick_shot_launched = app.sim.throws > throws_before
	if not baseline: expect(result.quick_shot_launched, "RMB press/release within one frame still shoots")
	fixture()
	app.sim.ball.owner = 1
	await frames(3)
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(20)
	# Capture the renderer between input and the next authoritative physics update.
	app.set_physics_process(false)
	app.set_process(false)
	motion(Vector2(350, -55))
	Input.flush_buffered_events()
	var preview_started = Time.get_ticks_usec()
	var points: PackedVector3Array = app.trajectory_preview()
	result.preview_call_ms = float(Time.get_ticks_usec()-preview_started)/1000
	var authoritative_aim: Vector3 = app.state.players[1].aim
	var predictor = app.Sim.new()
	predictor.players = app.state.players.duplicate(true)
	predictor.players[1].aim = app.camera_forward()
	predictor.set_shot_aim(1, app.shot_direction())
	predictor.mode = app.selected_mode
	var preview_origin: Vector3 = predictor.hand_position(1)
	var preview_velocity: Vector3 = predictor.throw_velocity(1, app.charge_time / 1.15)
	var horizontal = Vector3(preview_velocity.x,0,preview_velocity.z)
	var preview_time = (points[0]-preview_origin).dot(horizontal)/horizontal.length_squared() if not points.is_empty() else 0.0
	# The adaptive preview samples the host's discrete1/180s ball path. Infer
	# this point's time from horizontal travel rather than assuming an old.06s dot.
	var expected = preview_origin+preview_velocity*preview_time-Vector3.UP*.5*app.Sim.BALL_GRAVITY*preview_time*(preview_time+1.0/180)
	result.preview_first_point_error = points[0].distance_to(expected) if not points.is_empty() else -1
	if not baseline: expect(result.preview_first_point_error < .01, "Shot preview follows current camera aim before next snapshot")
	expect(app.state.players[1].aim == authoritative_aim, "Preview leaves authoritative state untouched")
	mouse(MOUSE_BUTTON_RIGHT, false)
	app.set_physics_process(true)
	app.set_process(true)
	await frames(2)
	fixture(Vector3(0, 0, app.Sim.NORTH.z + 3))
	app.sim.ball.owner = 1
	await frames(2)
	key(KEY_SPACE, true)
	await frames(1)
	key(KEY_SPACE, false)
	key(KEY_F, true)
	await frames(1)
	key(KEY_F, false)
	await frames(12)
	result.quick_jump_dunk_started = app.sim.dunks > 0
	result.quick_jump_dunk_prompt = app.prompt_label.text
	if not baseline: expect(result.quick_jump_dunk_started, "Quick jump then F activates once airborne")
	await capture("quick-dunk")
	if not baseline:
		measure_prediction()
		measure_render_ball()
		measure_celebration()
	result.failures = failures
	var file = FileAccess.open(evidence + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("FEEL_INPUT " + JSON.stringify(result))
	save_captures()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(app.profile.path + suffix): DirAccess.remove_absolute(app.profile.path + suffix)
	restore_settings()
	quit(1 if not failures.is_empty() else 0)

func measure_prediction() -> void:
	app.set_process(false)
	app.set_physics_process(false)
	var player: Dictionary = app.sim.players[1].duplicate(true)
	player.pos = Vector3.ZERO
	player.vel = Vector3.ZERO
	player.jump_count = 0
	player.grounded = true
	player.stun = 0.0
	player.dunk = 0.0
	app.state.reset_time = 0.0
	app.local_render_clock = -1.0
	app.visual_jump_started = -1.0
	app.begin_jump_prediction(player)
	var first_height = 0.0
	for index in 3:
		app.ui_clock += 1.0 / 60.0
		first_height = app.local_visual_height(player, 0.0)
	app.begin_jump_prediction(player)
	result.predicted_second_jump_count = app.visual_jump_count
	result.predicted_second_jump_speed = app.visual_jump_speed
	expect(app.visual_jump_count == 2 and app.visual_jump_speed >= app.Sim.DOUBLE_JUMP_SPEED, "Second jump responds before the first packet arrives")
	var packet_state: Dictionary = app.state.duplicate(true)
	packet_state.match_id = app.match_id
	packet_state["_snapshot_seq"] = app.snapshot_received_sequence + 1
	packet_state.players[1] = player.duplicate(true)
	packet_state.players[1].grounded = false
	packet_state.players[1].jump_count = 1
	var accepted_before: int = app.snapshot_count
	app.receive_state(var_to_bytes(packet_state).compress(FileAccess.COMPRESSION_DEFLATE))
	expect(app.snapshot_count == accepted_before+1,"The stale-airborne packet reaches the snapshot acceptance path")
	result.pending_jump_survives_stale_packet = app.visual_jump_started >= 0 and app.visual_jump_count == 2
	expect(result.pending_jump_survives_stale_packet, "A stale airborne snapshot does not cancel the pending extra jump")
	var last_height = first_height
	for index in 3:
		app.ui_clock += 1.0 / 60.0
		last_height = app.local_visual_height(player, 0.0)
	player.jump_count = 2
	player.grounded = false
	player.pos.y = last_height - .2
	player.vel.y = app.visual_jump_speed - app.Sim.PLAYER_GRAVITY * .05
	var worst_backward = 0.0
	for index in 12:
		app.ui_clock += 1.0 / 60.0
		player.pos.y += player.vel.y / 60.0
		player.vel.y -= app.Sim.PLAYER_GRAVITY / 60.0
		var displayed: float = app.local_visual_height(player, player.pos.y)
		worst_backward = minf(worst_backward, displayed - last_height)
		last_height = displayed
	result.prediction_ack_worst_backward_step = worst_backward
	result.prediction_final_correction = absf(last_height - player.pos.y)
	expect(worst_backward >= -.01, "Delayed jump acknowledgement does not rebound downward during ascent")
	expect(result.prediction_final_correction < .02, "Prediction correction converges back to authority")
	# A rejected jump reconciles after a real packet reports a collision/stun.
	player.pos = Vector3(0, 4, 0)
	player.vel = Vector3(0, -1, 0)
	player.jump_count = 1
	app.local_render_y = 4.0
	app.begin_jump_prediction(player)
	app.ui_clock += .04
	app.local_visual_height(player, 3.96)
	player.stun = .5
	player.pos.y = 3.9
	app.ui_clock += .016
	app.local_visual_height(player, player.pos.y)
	expect(app.visual_jump_started < 0, "An authoritative stun ends unacknowledged jump prediction")
	for index in 20:
		app.ui_clock += 1.0 / 60.0
		player.pos.y -= .03
		app.local_visual_height(player, player.pos.y)
	result.rejected_jump_final_correction = absf(app.local_render_y - player.pos.y)
	expect(result.rejected_jump_final_correction < .02, "Rejected jump correction settles without persistent floating")

func measure_render_ball() -> void:
	app.state = app.sim.snapshot()
	app.state.winner = -1
	app.state.reset_time = 0.0
	app.state.celebration_time = 0.0
	app.manual_input_enabled = false
	app.last_aim = Vector3.FORWARD
	var player: Dictionary = app.state.players[1]
	player.pos = Vector3(0, 8, 0)
	player.vel = Vector3(18, 20, 0)
	player.grounded = false
	player.boost_time = 1.0
	player.stun = 0.0
	player.dunk = 0.0
	player.giant = 0.0
	player.aim = Vector3.FORWARD
	app.visual_jump_started = -1.0
	app.visual_y_correction = 0.0
	app.local_render_clock = -1.0
	app.state.ball.owner = 1
	var helper = app.Sim.new()
	helper.players = app.state.players
	app.state.ball.pos = helper.hand_position(1)
	var original: PackedByteArray = var_to_bytes(app.state)
	var shown: Dictionary = app.predict_render_state(.08)
	helper.players = shown.players
	result.held_ball_prediction_error = shown.ball.pos.distance_to(helper.hand_position(1))
	result.previous_raw_ball_hand_error = app.state.ball.pos.distance_to(helper.hand_position(1))
	expect(result.held_ball_prediction_error < .0001, "Carried ball uses the exact predicted carrier hand during boost")
	expect(var_to_bytes(app.state) == original, "Render prediction never changes authoritative state")
	player.giant = 5.0
	player.dunk = .65
	player.dunk_duration = 1.25
	player.dunk_reach = 1.4
	shown = app.predict_render_state(.08)
	helper.players = shown.players
	result.giant_dunk_ball_prediction_error = shown.ball.pos.distance_to(helper.hand_position(1))
	expect(result.giant_dunk_ball_prediction_error < .0001, "Giant dunk uses the shared hand placement")
	app.state.ball.owner = 0
	var launch = Vector3(0, 10, 0)
	var velocity = Vector3(12, 5, -8)
	var worst = 0.0
	var smallest_step = INF
	var last_position = launch
	for index in range(0, 10):
		var time = index / 60.0
		var packet_time = floorf(time / .05) * .05
		app.state.ball.pos = launch + velocity * packet_time + Vector3.DOWN * .5 * app.Sim.BALL_GRAVITY * packet_time * packet_time
		app.state.ball.vel = velocity + Vector3.DOWN * app.Sim.BALL_GRAVITY * packet_time
		shown = app.predict_render_state(time - packet_time)
		var expected = launch + velocity * time + Vector3.DOWN * .5 * app.Sim.BALL_GRAVITY * time * time
		worst = maxf(worst, shown.ball.pos.distance_to(expected))
		if index > 0: smallest_step = minf(smallest_step, shown.ball.pos.distance_to(last_position))
		last_position = shown.ball.pos
	result.loose_ball_20hz_max_error = worst
	result.loose_ball_smallest_60hz_step = smallest_step
	expect(worst < .0001 and smallest_step > .2, "Loose ball moves every frame across synthetic 20 Hz packet boundaries")
	player.dunk = 0.0
	player.giant = 0.0
	app.local_render_clock = -1.0
	app.visual_y_correction = 0.0
	var apex_error = 0.0
	var apex_reversals = 0
	var previous_y = 18.0
	for index in range(0, 19):
		var time = index / 60.0
		var packet_time = floorf(time / .05) * .05
		player.pos = Vector3(0, 18.0 + packet_time - .5 * app.Sim.PLAYER_GRAVITY * packet_time * packet_time, 0)
		player.vel = Vector3(0, 1.0 - app.Sim.PLAYER_GRAVITY * packet_time, 0)
		app.ui_clock += 1.0 / 60.0
		shown = app.predict_render_state(time - packet_time)
		var expected_y = 18.0 + time - .5 * app.Sim.PLAYER_GRAVITY * time * time
		var current_y: float = shown.players[1].pos.y
		apex_error = maxf(apex_error, absf(current_y - expected_y))
		if time > .067 and current_y > previous_y + .0001: apex_reversals += 1
		previous_y = current_y
	result.client_apex_20hz_max_error = apex_error
	result.client_apex_descent_reversals = apex_reversals
	expect(apex_error < .0001 and apex_reversals == 0, "Snapshot prediction passes through the jump apex without a false upward rebound")
	app.state.reset_time = 3.0
	shown = app.predict_render_state(.08)
	expect(shown.ball.pos == app.state.ball.pos, "Kickoff ball remains frozen between snapshots")
	app.manual_input_enabled = true

func measure_celebration() -> void:
	# A real basket updates scores as well as the event. HUD score feedback now
	# survives a later action replacing that event in the same snapshot interval.
	app.state.scores[0] = int(app.state.scores.get(0, 0)) + 1
	app.state.winner = 0
	app.state.match_id = "feel-celebration-%d" % Time.get_ticks_usec()
	app.state.reward_peers = [1]
	app.state.celebration_time = .5
	app.state.reset_time = 3.0
	app.state.event_id = int(app.state.event_id) + 1
	app.state.event_kind = "score"
	app.update_hud(.016)
	result.celebration_reward_queued = app.profile.data.bags == 1
	result.celebration_overlay_hidden = not app.result_panel.visible
	result.celebration_event = app.event_label.text
	expect(result.celebration_reward_queued and result.celebration_overlay_hidden, "A win saves its reward immediately while preserving the follow-through")
	expect(app.event_label.text == "Your team +1\nWinning basket!", "Celebration shows the scorer, score and winning basket before the kickoff countdown")
	app.state.celebration_time = 0.0
	app.update_hud(.016)
	expect(app.result_panel.visible and app.profile.data.bags == 1, "The result menu follows celebration without duplicating the reward")

func steer_toward(target: Vector3) -> void:
	var delta: Vector3 = target - app.sim.players[1].pos
	if Vector2(delta.x, delta.z).length() < .05: return
	var desired = atan2(-delta.x, -delta.z)
	motion(Vector2(-angle_difference(app.yaw, desired) / .0032, 0))
	Input.flush_buffered_events()

func sample_route() -> void:
	var physics_tick = Engine.get_physics_frames()
	if not route_samples.is_empty() and int(route_samples.back().tick) == physics_tick: return
	var player: Dictionary = app.sim.players[1]
	route_samples.append({"tick": physics_tick, "time": float(physics_tick) / Engine.physics_ticks_per_second, "sim_clock": app.sim.clock, "pos": [player.pos.x, player.pos.y, player.pos.z],
		"vel": [player.vel.x, player.vel.y, player.vel.z], "camera": [app.world.camera.position.x, app.world.camera.position.y, app.world.camera.position.z],
		"fov": app.world.camera.fov, "owner": app.sim.ball.owner, "dunk": player.dunk,
		"celebration": float(app.sim.snapshot().get("celebration_time", 0)), "reset": app.sim.reset_time})

func sample_camera() -> void:
	if not route_mode: return
	var position: Vector3 = app.world.camera.position
	camera_samples.append({"time": app.ui_clock, "pos": [position.x, position.y, position.z], "yaw": app.yaw,
		"dunk": float(app.sim.players[1].dunk) > 0,
		"active": app.sim.reset_time <= 0 or float(app.sim.snapshot().get("celebration_time", 0)) > 0})

func route_on_launcher_arc(pad: Vector3) -> bool:
	var p: Dictionary = app.sim.players[1]
	return p.pad_cooldown > 0 and p.jump_count == 1 and p.vel.y > 20 and app.sim.flat_distance(p.pos, pad) < 3.5

func play_route() -> void:
	route_mode = true
	physics_frame.connect(sample_route)
	RenderingServer.frame_post_draw.connect(sample_camera)
	evidence = evidence_base + "-route"
	app.set_paused(false)
	while app.sim.reset_time > 0:
		await frames(1)
	await frames(2)
	var spawn: Vector3 = app.sim.players[1].pos
	result.spawn = [spawn.x, spawn.y, spawn.z]
	var started = Time.get_ticks_msec()
	var tick = 0
	key(KEY_W, true)
	while app.sim.ball.owner != 1 and Time.get_ticks_msec() - started < 10000:
		steer_toward(app.sim.ball.pos)
		key(KEY_E, tick % 10 == 0)
		await frames(1)
		sample_route()
		tick += 1
	key(KEY_E, false)
	key(KEY_W, false)
	result.route_caught = app.sim.ball.owner == 1
	expect(result.route_caught, "Spawn-to-ball route catches using movement and E")
	await capture("pickup")
	var pad: Vector3 = app.Sim.PADS[0]
	var best = INF
	for candidate in app.Sim.PADS:
		if candidate.z >= 0: continue
		var distance: float = app.sim.players[1].pos.distance_to(candidate)
		if distance < best:
			best = distance
			pad = candidate
	result.pad = [pad.x, pad.y, pad.z]
	# Reach the side lane through the clear middle crossing. The old diagonal
	# route walks straight through a new sweeper and then attempts an empty-hand
	# dunk. Keep hazards live and use ordinary movement to take the clear route.
	var lane_entry := Vector3(pad.x, 0, 0)
	started = Time.get_ticks_msec()
	key(KEY_W, true)
	while app.sim.flat_distance(app.sim.players[1].pos, lane_entry) > 1.6 and Time.get_ticks_msec() - started < 8000:
		steer_toward(lane_entry)
		await frames(1)
		sample_route()
	result.lane_entry_reached = app.sim.flat_distance(app.sim.players[1].pos, lane_entry) <= 1.6
	expect(result.lane_entry_reached, "Route reaches clear side lane using movement")
	result.lane_possession_retained = app.sim.ball.owner == 1
	expect(result.lane_possession_retained, "Clear lane route retains possession with hazards active")
	started = Time.get_ticks_msec()
	key(KEY_W, true)
	while not route_on_launcher_arc(pad) and Time.get_ticks_msec() - started < 12000:
		steer_toward(pad)
		await frames(1)
		sample_route()
	result.launch_velocity = app.sim.players[1].vel.y
	result.route_launched = route_on_launcher_arc(pad)
	expect(result.route_launched, "Route reaches and activates a launcher without teleporting")
	await frames(4)
	var velocity_before: float = app.sim.players[1].vel.y
	key(KEY_SPACE, true)
	await frames(1)
	key(KEY_SPACE, false)
	result.extra_jump_velocity_before = velocity_before
	result.extra_jump_velocity_after = app.sim.players[1].vel.y
	result.extra_jump_count = app.sim.players[1].jump_count
	expect(int(result.extra_jump_count) == 2, "Actual Space adds the midair jump after launch")
	await capture("boosted-arc")
	started = Time.get_ticks_msec()
	tick = 0
	var target: Vector3 = app.sim.hoop(1)
	var highest = app.sim.players[1].pos.y
	var score_before = int(app.sim.scores[0])
	while app.sim.dunks == 0 and Time.get_ticks_msec() - started < 15000:
		steer_toward(target)
		var at: Vector3 = app.sim.players[1].pos
		var distance = Vector2(at.x - target.x, at.z - target.z).length()
		if distance < app.Sim.DUNK_RANGE + .5:
			key(KEY_SPACE, bool(app.sim.players[1].grounded) and tick % 8 == 0)
			key(KEY_F, tick % 6 == 0)
		await frames(1)
		sample_route()
		highest = maxf(highest, app.sim.players[1].pos.y)
		tick += 1
	key(KEY_W, false)
	key(KEY_F, false)
	key(KEY_SPACE, false)
	result.route_peak_height = highest
	result.route_dunk_started = app.sim.dunks > 0
	expect(result.route_dunk_started, "Route reaches hoop and starts dunk through F")
	await capture("dunk")
	started = Time.get_ticks_msec()
	while int(app.sim.scores[0]) <= score_before and Time.get_ticks_msec() - started < 4500:
		await frames(1)
		sample_route()
	result.route_scored = int(app.sim.scores[0]) > score_before
	expect(result.route_scored, "The input-driven route scores through the hoop")
	await capture("score")
	var captured_follow_through = false
	while float(app.sim.snapshot().get("celebration_time", 0)) > 0:
		if not captured_follow_through and float(app.sim.snapshot().get("celebration_time", 0)) < .3:
			await capture("follow-through")
			captured_follow_through = true
		await frames(1)
	await frames(2)
	await capture("kickoff")
	measure_continuity()
	result.sim_seconds = app.sim.clock
	result.focus_recoveries = focus_recoveries
	result.failures = failures
	result.samples = route_samples
	result.camera_samples = camera_samples
	var file = FileAccess.open(evidence + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	var summary = result.duplicate()
	summary.erase("samples")
	summary.erase("camera_samples")
	print("FEEL_ROUTE " + JSON.stringify(summary))
	save_captures()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(app.profile.path + suffix): DirAccess.remove_absolute(app.profile.path + suffix)
	restore_settings()
	quit(1 if not failures.is_empty() else 0)

func point(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func measure_continuity() -> void:
	var max_player_step = 0.0
	var max_dunk_step = 0.0
	var reset_jumps = 0
	for index in range(1, route_samples.size()):
		var before: Dictionary = route_samples[index - 1]
		var after: Dictionary = route_samples[index]
		var step = point(before.pos).distance_to(point(after.pos))
		if float(before.celebration) > 0 and float(after.celebration) <= 0 and float(after.reset) > 0:
			reset_jumps += 1
			continue
		max_player_step = maxf(max_player_step, step)
		if float(before.dunk) > 0 or float(after.dunk) > 0: max_dunk_step = maxf(max_dunk_step, step)
	var camera_turn_step = 0.0
	var max_camera_step = 0.0
	var max_dunk_camera_step = 0.0
	var max_dunk_camera_turn = 0.0
	var max_camera_without_turn = 0.0
	for index in range(1, camera_samples.size()):
		var before: Dictionary = camera_samples[index - 1]
		var after: Dictionary = camera_samples[index]
		if not bool(before.active) or not bool(after.active): continue
		max_camera_step = maxf(max_camera_step, point(before.pos).distance_to(point(after.pos)))
		camera_turn_step = maxf(camera_turn_step, absf(angle_difference(float(before.yaw), float(after.yaw))))
		if absf(angle_difference(float(before.yaw), float(after.yaw))) < .0001:
			max_camera_without_turn = maxf(max_camera_without_turn, point(before.pos).distance_to(point(after.pos)))
		if bool(before.dunk) and bool(after.dunk):
			max_dunk_camera_step = maxf(max_dunk_camera_step, point(before.pos).distance_to(point(after.pos)))
			max_dunk_camera_turn = maxf(max_dunk_camera_turn, absf(angle_difference(float(before.yaw), float(after.yaw))))
	result.maximum_physics_step_m = max_player_step
	result.maximum_dunk_step_m = max_dunk_step
	result.maximum_camera_render_step_m = max_camera_step
	result.maximum_camera_yaw_step_rad = camera_turn_step
	result.maximum_dunk_camera_render_step_m = max_dunk_camera_step
	result.maximum_dunk_camera_yaw_step_rad = max_dunk_camera_turn
	result.maximum_camera_without_turn_step_m = max_camera_without_turn
	result.kickoff_respawns = reset_jumps
