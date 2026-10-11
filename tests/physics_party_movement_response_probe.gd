extends SceneTree
## Real keyboard events -> main input polling -> Jolt -> rendered puppet.
## Flat, isolated fixture separates motor response from obstacle traversal.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var actor: Node3D
var failures: Array[String] = []
var report: Dictionary = {"trials": [], "limits": "Scripted key events in a flat physical fixture, not human input latency or Wi-Fi evidence."}
var label: String = "current"
var checks: int = 0
var frame_times: Array[float] = []
var last_frame: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	call_deferred("_run")

func _run() -> void:
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/movement-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24883
	root.add_child(app)
	app._host("Movement test")
	app._action("crew_1", "power", app.state.offers.crew_1[0])
	actor = app.avatars.crew_1
	report.renderer = DisplayServer.get_name()
	# Keep native mouse capture away from the user while preserving real input polling.
	app.set_process(false)
	app.scripted = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var floor_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(40, 1, 60)
	collision.shape = box
	floor_body.add_child(collision)
	root.add_child(floor_body)
	floor_body.position = Vector3(45, -0.5, 0)
	var floor_mesh = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = box.size
	floor_mesh.mesh = mesh
	floor_body.add_child(floor_mesh)
	process_frame.connect(_render_frame)
	for power in ["grip", "heavy", "swift"]:
		actor.set_power(power)
		actor.reset_at(Vector3(45, 3, 0))
		app.camera_ready = false
		await _ticks(120)
		_check(actor.is_on_floor, power + " begins on real ground")
		var start: Vector3 = actor.body_position()
		_key(KEY_W, true)
		_check(Input.is_physical_key_pressed(KEY_W), "scripted key reaches physical keyboard polling")
		var trial: Dictionary = {"power": power, "command_ms": -1.0, "first_0_1m_ms": -1.0, "speed_200ms": 0.0, "speed_1s": 0.0, "samples": []}
		for tick in 90:
			await physics_frame
			var elapsed: float = (tick + 1) * 1000.0 / 60.0
			var data: Dictionary = app.inputs.get("crew_1", {}).get("data", {})
			if trial.command_ms < 0 and data.get("move", Vector2.ZERO).y < -0.9: trial.command_ms = elapsed
			if trial.first_0_1m_ms < 0 and start.z - actor.body_position().z > 0.1: trial.first_0_1m_ms = elapsed
			if tick == 11: trial.speed_200ms = -actor.physical_bone_body.linear_velocity.z
			if tick == 59: trial.speed_1s = -actor.physical_bone_body.linear_velocity.z
			if tick in [0, 5, 11, 29, 59, 89]:
				trial.samples.append({"ms": elapsed, "torso_speed": -actor.physical_bone_body.linear_velocity.z, "whole_body_speed": -_body_velocity().z, "travel": start.z - actor.body_position().z})
		_key(KEY_W, false)
		_key(KEY_S, true)
		trial.reversal_ms = -1.0
		for tick in 36:
			await physics_frame
			if trial.reversal_ms < 0 and actor.physical_bone_body.linear_velocity.z > 0.3: trial.reversal_ms = (tick + 1) * 1000.0 / 60.0
		_key(KEY_S, false)
		var release: Vector3 = actor.body_position()
		trial.stop_ms = -1.0
		for tick in 45:
			await physics_frame
			if trial.stop_ms < 0 and Vector2(actor.physical_bone_body.linear_velocity.x, actor.physical_bone_body.linear_velocity.z).length() < 0.3:
				trial.stop_ms = (tick + 1) * 1000.0 / 60.0
		trial.coast_m = Vector2(actor.body_position().x - release.x, actor.body_position().z - release.z).length()
		report.trials.append(trial)
		_check(trial.first_0_1m_ms > 0 and trial.first_0_1m_ms <= 150, power + " visibly starts within 150ms")
		_check(trial.command_ms > 0 and trial.command_ms <= 1000.0 / 60.0, power + " host consumes input within one physics tick")
		_check(trial.speed_200ms >= 3.0, power + " accelerates promptly instead of dragging the ragdoll")
		_check(trial.speed_1s >= 4.5 and trial.speed_1s < 8.5, power + " reaches useful bounded running speed")
		_check(trial.reversal_ms > 0 and trial.reversal_ms <= 220, power + " reverses within 220ms")
		_check(trial.stop_ms > 0 and trial.stop_ms <= 250 and trial.coast_m < 0.65, power + " stops without a long skid")
	if not frame_times.is_empty():
		frame_times.sort()
		report.frame_ms = {"p95": frame_times[int(frame_times.size() * 0.95)], "max": frame_times[-1]}
	report.checks = checks
	report.failures = failures
	var file = FileAccess.open("res://logs/movement-response-" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MOVEMENT_RESPONSE " + JSON.stringify(report))
	app._leave()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _ticks(count: int) -> void:
	for tick in count: await physics_frame

func _key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _body_velocity() -> Vector3:
	var momentum = Vector3.ZERO
	var mass = 0.0
	for bone in actor.physics_bones:
		momentum += bone.linear_velocity * bone.mass
		mass += bone.mass
	return momentum / mass

func _render_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if is_instance_valid(app) and is_instance_valid(actor): app._update_camera((now - last_frame) / 1000000.0 if last_frame > 0 else 1.0 / 60.0)
	if last_frame > 0: frame_times.append((now - last_frame) / 1000.0)
	last_frame = now

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)
	print("PASS " if ok else "FAIL ", description)
