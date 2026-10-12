extends SceneTree

const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var world: Node3D
var state: Dictionary
var prefix: String
var metrics: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func record_timings(label: String, samples: Array[float]) -> void:
	if samples.is_empty(): return
	var ordered := samples.duplicate()
	ordered.sort()
	var total := 0.0
	for value in samples: total += value
	metrics[label] = {"samples": samples.size(), "average_ms": total / samples.size(), "min_ms": ordered[0], "p95_ms": ordered[floori((ordered.size() - 1) * .95)], "max_ms": ordered.back()}
	print("COURT_FRAME_INTERVAL ", label, " ", JSON.stringify(metrics[label]))

func frame_view(seat: int, yaw: float = 0.0, pitch: float = .43, frames: int = 45, label: String = "") -> void:
	var samples: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	for i in frames:
		world.present(state, seat, 1.0 / 60.0, yaw, pitch)
		await process_frame
		var tick := Time.get_ticks_usec()
		if i >= 15: samples.append((tick - previous_tick) / 1000.0)
		previous_tick = tick
	await RenderingServer.frame_post_draw
	if not label.is_empty(): record_timings(label, samples)

func capture(label: String) -> void:
	root.get_texture().get_image().save_png("res://tests/court_v2_%s_%s.png" % [prefix, label])
	if prefix == "after":
		var before_path := "res://tests/court_v2_before_%s.png" % label
		if FileAccess.file_exists(before_path):
			var before := Image.load_from_file(before_path)
			var after := root.get_texture().get_image()
			var comparison := Image.create(2560, 800, false, Image.FORMAT_RGBA8)
			before.convert(Image.FORMAT_RGBA8)
			after.convert(Image.FORMAT_RGBA8)
			comparison.blit_rect(before, Rect2i(0, 0, 1280, 800), Vector2i.ZERO)
			comparison.blit_rect(after, Rect2i(0, 0, 1280, 800), Vector2i(1280, 0))
			comparison.save_png("res://tests/court_v2_compare_%s.png" % label)

func run() -> void:
	prefix = "before" if "--before" in OS.get_cmdline_user_args() else "after"
	root.size = Vector2i(1280, 800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	var sim := Sim.new()
	sim.reset("coop")
	state = sim.snapshot()
	state.names = {1: "YOU", 2: "PIP", 3: "BO", 4: "FINN", 5: "DOT", 6: "KIP"}
	state.ball.owner = 1
	state.players[1].pos = Vector3(0, 0, Sim.HALF_LENGTH * .3)
	state.players[1].pos.y = Sim.floor_height(0, state.players[1].pos.z)
	state.ball.pos = state.players[1].pos + Vector3(0, 1.95, -.7)
	state.pass_target_preview = 2
	await frame_view(0)
	capture("overview")
	await frame_view(1, 0, .43, 120, "ground")
	capture("ground")
	var foot_pixel: Vector2 = world.camera.unproject_position(state.players[1].pos)
	var head_pixel: Vector2 = world.camera.unproject_position(state.players[1].pos + Vector3.UP * 1.72)
	print("COURT_FRAME body_fraction=", (foot_pixel.y - head_pixel.y) / 800.0, " feet_fraction=", foot_pixel.y / 800.0)
	metrics.framing = {"body_fraction": (foot_pixel.y - head_pixel.y) / 800.0, "feet_fraction": foot_pixel.y / 800.0}
	if prefix == "after":
		assert(metrics.framing.body_fraction > .135 and metrics.framing.body_fraction < .16, "Avatar matches measured reference framing")
		assert(metrics.framing.feet_fraction > .65 and metrics.framing.feet_fraction < .70, "Feet stay near lower two-thirds framing")
	var launch: Vector3 = Sim.PADS[3]
	state.players[1].pos = launch
	state.players[1].pos.y = Sim.floor_height(launch.x, launch.z)
	state.ball.pos = state.players[1].pos + Vector3(0, 1.95, -.7)
	await frame_view(1, -.3)
	capture("launcher")
	state.players[1].pos += Vector3(-4, 9, -9)
	state.players[1].vel = Vector3(-6, 12, -18)
	state.players[1].grounded = false
	state.players[1].jump_count = 2
	state.players[1].boost_time = .8
	state.ball.pos = state.players[1].pos + Vector3(0, 1.95, -.7)
	state.event_id += 1
	state.event_kind = "boost"
	state.event_player = 1
	state.event_pos = launch
	await frame_view(1, -.3, .43, 120, "boost")
	capture("air")
	var attachment_offset: Vector3 = world.ball_root.position - world.actors[1]["root"].position
	assert(attachment_offset.distance_to(state.ball.pos - state.players[1].pos) < .001, "Rendered ball shares the smoothed carrier root")
	var forward: Vector3 = -world.camera.global_basis.z
	var flat := Vector3(forward.x, 0, forward.z).normalized()
	assert(flat.dot(Vector3(sin(.3), 0, -cos(.3))) > .999, "Camera yaw remains aligned with gameplay aim")
	state.players[1].pos = Vector3(0, 0, Sim.NORTH.z + 7)
	state.players[1].pos.y = Sim.floor_height(0, state.players[1].pos.z)
	state.players[1].vel = Vector3.ZERO
	state.players[1].boost_time = 0.0
	state.players[1].grounded = true
	state.players[1].catch_time = .3
	state.ball.owner = 0
	state.ball.pos = state.players[1].pos + Vector3(0, 2.5, -3)
	await frame_view(1)
	capture("basket")
	if prefix == "after":
		state.players[1].pos = Vector3.ZERO
		state.players[1].catch_time = 0.0
		state.ball.pos = Vector3(0, 18, -1)
		state.ball_camera = true
		state.camera_focus = state.ball.pos
		await frame_view(1, 0, .43, 90)
		var player_screen: Vector2 = world.camera.unproject_position(state.players[1].pos)
		var ball_screen: Vector2 = world.camera.unproject_position(state.ball.pos)
		assert(player_screen.y > 32 and player_screen.y < 768 and ball_screen.y > 32 and ball_screen.y < 768, "Ball camera frames feet and 18m ball")
		capture("ballcam")
		print("COURT_BALLCAM feet=", player_screen, " ball=", ball_screen, " distance=", world.camera_distance, " fov=", world.camera.fov)
		await dunk_sequence()
	print("COURT_V2_RENDER_PASS phase=", prefix, " field=", Sim.HALF_WIDTH * 2, "x", Sim.HALF_LENGTH * 2, " fov=", world.camera.fov, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	metrics.field = Vector2(Sim.HALF_WIDTH * 2, Sim.HALF_LENGTH * 2)
	metrics.note = "Native Godot render frame intervals, warmup excluded; screenshot readback/encoding excluded from dunk samples. One local run, not household hardware certification."
	var file := FileAccess.open("res://tests/court_v2_%s_metrics.json" % prefix, FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	quit(0)

func dunk_sequence() -> void:
	var sim := Sim.new()
	sim.reset("coop")
	sim.reset_time = 0.0
	for id in sim.players:
		sim.players[id].pos = Vector3(15 if id % 2 else -15, 1.0, 0)
	sim.players[1].pos = Sim.NORTH + Vector3(0, 1.2 - Sim.HOOP_Y, 4.3)
	sim.players[1].grounded = false
	sim.players[1].vel = Vector3(0, 6, -9.5)
	sim.players[1].aim = Vector3.FORWARD
	sim.ball.owner = 1
	sim.ball.pos = sim.hand_position(1)
	sim.action(1, "dunk")
	assert(sim.players[1].dunk > 0, "Sequence starts an actual simulated dunk")
	var duration: float = sim.players[1].get("dunk_duration", Sim.DUNK_DURATION)
	var checkpoints: Array[int] = []
	for t in [0.0, .10, .20, .30, .40, .50, .60, .70, .80, .90, 1.0, 1.15, 1.30, 1.45, 1.60, 1.80]:
		checkpoints.append(roundi(duration * t * 60))
	var sheet := Image.create(2560, 1600, false, Image.FORMAT_RGBA8)
	var index := 0
	var samples: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	var timing_cooldown := 0
	for frame in checkpoints.back() + 1:
		sim.step(1.0 / 60)
		state = sim.snapshot()
		state.names = {1: "YOU"}
		world.present(state, 1, 1.0 / 60, 0, .43)
		assert(world.actors[1]["rig"].position.length() < 2.0, "Dunk pivot cannot accumulate frame offsets")
		if state.ball.owner == 1 and state.players[1].dunk > 0:
			for hand_key in ["left_hand", "right_hand"]:
				assert(world.actors[1][hand_key].global_position.distance_to(world.ball_root.global_position) < .5, "Dunk hands stay anchored to rendered ball")
		await process_frame
		var tick := Time.get_ticks_usec()
		if frame > 10 and timing_cooldown <= 0: samples.append((tick - previous_tick) / 1000.0)
		timing_cooldown = maxi(0, timing_cooldown - 1)
		if frame in checkpoints:
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.save_png("res://tests/court_v2_dunk_%02d.png" % index)
			picture.resize(640, 400, Image.INTERPOLATE_LANCZOS)
			picture.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(picture, Rect2i(0, 0, 640, 400), Vector2i((index % 4) * 640, (index / 4) * 400))
			index += 1
			timing_cooldown = 2
		previous_tick = Time.get_ticks_usec()
	assert(sim.baskets == 1, "Animated actual dunk scores once")
	sheet.save_png("res://tests/court_v2_dunk_sequence.png")
	print("COURT_DUNK_SEQUENCE duration=", duration, " frames=", checkpoints.back() + 1, " captures=", index, " baskets=", sim.baskets)
	record_timings("dunk", samples)
