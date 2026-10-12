extends SceneTree

var app
var checks: Array[Dictionary] = []
var profile_path = ""

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, name: String, value = null) -> void:
	checks.append({"check":name,"passed":ok,"observed":value.duplicate(true) if value is Array or value is Dictionary else value})
	print("PASS " if ok else "FAIL ",name," ",value if value != null else "")

func joy_button(index: int, pressed: bool) -> void:
	var event = InputEventJoypadButton.new()
	event.device = 11
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func trigger(value: float) -> void:
	var event = InputEventJoypadMotion.new()
	event.device = 11
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func space(pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	profile_path = "user://controller_mix_%d.json" % Time.get_ticks_usec()
	app = load("res://tests/controller_app.gd").new()
	app.profile = load("res://profile.gd").new(profile_path)
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.practice_game("coop")
	app.sim.reset_time = 0.0
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.discovered_devices.assign([11])
	Input.joy_connection_changed.emit(11,true)
	app.controller_neutral = true
	app.input_armed = true
	await process_frame
	var tokens = " / A / B / X / Y RT RB LB Start"
	for layout in [
		["Xbox Wireless Controller", " / A / B / X / Y RT RB LB Start"],
		["DualSense Wireless Controller", " / Cross / Circle / Square / Triangle R2 R1 L1 Options"],
		["Nintendo Switch Pro Controller", " / B / A / Y / X ZR R L +"],
		["Unidentified USB Gamepad", " / Bottom / Right / Left / Top R trigger R shoulder L shoulder Menu"]
	]:
		app.device_label = layout[0]
		expect(app.controller_labels(tokens) == layout[1], "physical labels: " + layout[0], app.controller_labels(tokens))
	# Shared keyboard/pad actions must retain a keyboard hold on pad release/removal.
	space(true)
	joy_button(JOY_BUTTON_A,true)
	joy_button(JOY_BUTTON_A,false)
	expect(Input.is_action_pressed("jump"),"controller release preserves held Space",Input.is_action_pressed("jump"))
	app.discovered_devices.clear()
	Input.joy_connection_changed.emit(11,false)
	expect(Input.is_action_pressed("jump"),"disconnect preserves held Space",Input.is_action_pressed("jump"))
	space(false)
	expect(not Input.is_action_pressed("jump"),"restored keyboard hold releases normally")
	app.discovered_devices.assign([11])
	Input.joy_connection_changed.emit(11,true)
	app.controller_neutral = true
	app.input_armed = true
	await process_frame
	app.commands.clear()
	# A second device's press must not reset a shot already charging.
	mouse(true)
	app.read_controls(0.3)
	var before: float = app.charge_time
	expect(app.charging and before > 0.0,"mouse starts charge",{"charging":app.charging,"owner":app.state.ball.owner,"reset_time":app.state.reset_time,"pressed":Input.is_action_pressed("throw_ball"),"armed":app.input_armed})
	trigger(0.8)
	app.read_controls(0.03)
	expect(app.charge_time >= before,"RT press preserves mouse charge",{"before":before,"after":app.charge_time})
	mouse(false)
	app.read_controls(0.03)
	expect(app.charging and not app.commands.has("throw"),"one release keeps charge while other device holds")
	trigger(0.0)
	app.read_controls(0.03)
	expect(app.commands.count("throw") == 1,"last release shoots exactly once",app.commands)
	# Camera movement uses the selected controller only, with consistent yaw axes.
	app.commands.clear()
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.input_armed = true
	var motion = InputEventJoypadMotion.new()
	motion.device = 12
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var initial_yaw: float = app.yaw
	app.read_controls(0.03)
	expect(is_equal_approx(app.yaw,initial_yaw),"unselected pad cannot turn camera")
	for direction in [0.0,PI * 0.5,PI,-PI * 0.5]:
		app.yaw = direction
		motion.device = 11
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = -1.0
		Input.parse_input_event(motion.duplicate())
		Input.flush_buffered_events()
		app.read_controls(0.03)
		expect(app.local_direction.dot(app.camera_forward()) > 0.999,"forward stick follows camera yaw %.2f" % direction,app.local_direction)
	motion.axis_value = 0.0
	Input.parse_input_event(motion.duplicate())
	Input.flush_buffered_events()
	mouse(false)
	trigger(0.0)
	space(false)
	app.discovered_devices.clear()
	Input.joy_connection_changed.emit(11,false)
	await app.close_session()
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		var path: String = profile_path + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"input_source":"parsed events and injected device discovery; no physical hardware claim"}
	var output = "res://tests/controller-mix-result.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			var directory = arg.trim_prefix("--evidence-dir=")
			DirAccess.make_dir_recursive_absolute(directory)
			output = directory.path_join("controller-mix-result.json")
	var file = FileAccess.open(output,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("CONTROLLER_MIX_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
