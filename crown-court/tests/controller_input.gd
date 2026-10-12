extends SceneTree

const DEVICE = 11
const SECOND = 12
var app
var checks: Array[Dictionary] = []
var settings_path = "user://settings.cfg"
var settings_existed = false
var settings_bytes = PackedByteArray()
var profile_path = ""
var evidence_directory = "res://tests/controller"
var hardware_inventory: Array = []
var pointer_probe: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks.append({"check":label,"passed":ok})
	print("PASS " if ok else "FAIL ",label)

func button(index: int, pressed: bool, device: int = DEVICE) -> void:
	var event = InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(index: int, device: int = DEVICE) -> void:
	button(index,true,device)
	await create_timer(0.04).timeout
	button(index,false,device)
	await create_timer(0.04).timeout

func axis(index: int, value: float, device: int = DEVICE) -> void:
	var event = InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)

func key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func focus_text(value: String, scope: Node = null) -> Control:
	var container: Node = app.controller_menu_root() if scope == null else scope
	for control in app.focusable_controls(container):
		if control is Button and control.text.begins_with(value): return control
	return null

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence_directory = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	for id in Input.get_connected_joypads(): hardware_inventory.append({"device":id,"name":Input.get_joy_name(id),"guid":Input.get_joy_guid(id),"known_mapping":Input.is_joy_known(id)})
	print("CONTROLLER_HARDWARE_INVENTORY ",JSON.stringify(hardware_inventory))
	settings_existed = FileAccess.file_exists(settings_path)
	if settings_existed: settings_bytes = FileAccess.get_file_as_bytes(settings_path)
	profile_path = "user://controller_test_%d.json" % Time.get_ticks_usec()
	app = load("res://tests/controller_app.gd").new()
	# This controller-only test must not consume physical/capture-warp pointer motion.
	# Mixed input semantics are covered separately by controller_mix and feel_input.
	app.isolate_pointer_motion = true
	app.profile = load("res://profile.gd").new(profile_path)
	root.add_child(app)
	app.muted = true
	await process_frame
	app.discovered_devices.assign([DEVICE])
	Input.joy_connection_changed.emit(DEVICE,true)
	await process_frame
	expect(app.controller_device == DEVICE,"first connected controller selected")
	expect(root.gui_get_focus_owner() == focus_text("Practice"),"main menu has Practice default focus")
	app.device_label = "DualSense Wireless Controller"
	expect(app.controller_labels(" / A / B / X / Y RT RB LB Start") == " / Cross / Circle / Square / Triangle R2 R1 L1 Options","DualSense labels match its physical buttons")
	app.device_label = ""
	await capture("01-menu")
	await tap(JOY_BUTTON_DPAD_UP)
	expect(root.gui_get_focus_owner() is OptionButton,"D-pad reaches mode selector")
	# Use the real native OptionButton popup and controller accept/cancel actions.
	app.mode_select.grab_focus()
	await tap(JOY_BUTTON_A)
	expect(app.mode_select.get_popup().visible,"A opens mode popup")
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	expect(app.selected_mode == "versus","D-pad and A select a mode")
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_B)
	expect(not app.mode_select.get_popup().visible and app.phase == "menu","B closes selector without leaving menu")
	await tap(JOY_BUTTON_A)
	axis(JOY_AXIS_LEFT_Y,1.0)
	await create_timer(0.08).timeout
	axis(JOY_AXIS_LEFT_Y,0.0)
	await tap(JOY_BUTTON_A)
	expect(app.selected_mode == "teams","left stick also navigates native mode popup")
	app.name_edit.text = "Test"
	app.name_edit.grab_focus()
	await tap(JOY_BUTTON_A)
	expect(is_instance_valid(app.controller_keyboard),"A on name opens controller keyboard")
	await capture("02-keyboard")
	var old_name: String = app.name_edit.text
	focus_text("a",app.controller_keyboard).grab_focus()
	await tap(JOY_BUTTON_A)
	focus_text("Done",app.controller_keyboard).grab_focus()
	await tap(JOY_BUTTON_A)
	expect(app.name_edit.text == old_name + "a" and not is_instance_valid(app.controller_keyboard),"controller keyboard commits text")
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_B)
	expect(not is_instance_valid(app.controller_keyboard) and root.gui_get_focus_owner() == app.name_edit,"B cancels keyboard and restores field focus")
	app.show_wardrobe()
	await create_timer(0.05).timeout
	var wardrobe_controls: Array = app.focusable_controls(app.wardrobe_panel)
	expect(root.gui_get_focus_owner() in wardrobe_controls,"wardrobe focus stays in its modal")
	await tap(JOY_BUTTON_DPAD_DOWN)
	expect(root.gui_get_focus_owner() in wardrobe_controls,"wardrobe navigation cannot reach menu behind it")
	await tap(JOY_BUTTON_B)
	expect(not is_instance_valid(app.wardrobe_panel) and app.phase == "menu","B returns from wardrobe")
	# No sockets: exercise the normal lobby UI with the offline multiplayer peer.
	app.show_lobby()
	await create_timer(0.05).timeout
	expect(root.gui_get_focus_owner() == focus_text("Start"),"lobby Start gets default focus")
	await capture("03-lobby")
	await tap(JOY_BUTTON_A)
	expect(app.phase == "match","A starts the match")
	await tap(JOY_BUTTON_START)
	expect(app.paused and root.gui_get_focus_owner() == focus_text("Resume"),"Start pauses and focuses Resume")
	await capture("04-pause")
	await tap(JOY_BUTTON_B)
	expect(not app.paused,"B resumes without dunking")
	expect(not app.commands.has("dunk"),"menu B never leaks a dunk")
	app.sim.reset_time = 0.0
	app.seats = {1:1,2:2,3:3,4:4,5:5,6:6}
	app.state = app.sim.snapshot()
	await create_timer(0.05).timeout
	app.set_paused(true)
	await create_timer(0.04).timeout
	app.commands.clear()
	button(JOY_BUTTON_A,true)
	await create_timer(0.08).timeout
	expect(app.paused and app.commands.is_empty(),"holding A on Resume cannot leak a jump")
	button(JOY_BUTTON_A,false)
	await create_timer(0.04).timeout
	expect(not app.paused and app.commands.is_empty(),"releasing A resumes without jumping")
	if DisplayServer.get_name() != "headless":
		# Reproduce the competing input, then verify test isolation leaves production
		# mouse behaviour untouched and preserves the exact controller assertions below.
		var original_yaw: float = app.yaw
		app.ball_camera = true
		app.isolate_pointer_motion = false
		var motion = InputEventMouseMotion.new()
		motion.relative = Vector2(5,0)
		motion.screen_relative = Vector2(5,0)
		motion.set_meta("controller_probe",true)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		pointer_probe = {"unisolated_yaw_delta":app.yaw-original_yaw,"unisolated_ball_camera":app.ball_camera}
		app.yaw = original_yaw
		app.ball_camera = true
		app.isolate_pointer_motion = true
		Input.parse_input_event(motion.duplicate())
		Input.flush_buffered_events()
		pointer_probe["isolated_yaw_delta"] = app.yaw-original_yaw
		pointer_probe["isolated_ball_camera"] = app.ball_camera
		pointer_probe["passed"] = is_equal_approx(float(pointer_probe.unisolated_yaw_delta),-.016) and not pointer_probe.unisolated_ball_camera and is_equal_approx(float(pointer_probe.isolated_yaw_delta),0.0) and pointer_probe.isolated_ball_camera
		print("CONTROLLER_POINTER_PROBE ",JSON.stringify(pointer_probe))
		app.ball_camera = false
	axis(JOY_AXIS_LEFT_X,0.15)
	await create_timer(0.06).timeout
	expect(app.local_direction.length() < 0.001,"left-stick drift inside deadzone does not move")
	axis(JOY_AXIS_LEFT_X,0.6)
	await create_timer(0.06).timeout
	expect(absf(app.local_direction.length() - 0.5) < 0.01,"left-stick strength ramps smoothly outside deadzone")
	axis(JOY_AXIS_LEFT_X,0.0)
	var yaw_before: float = app.yaw
	axis(JOY_AXIS_RIGHT_X,0.1)
	await create_timer(0.06).timeout
	expect(is_equal_approx(app.yaw,yaw_before),"right-stick drift leaves camera still")
	axis(JOY_AXIS_RIGHT_X,1.0)
	await create_timer(0.06).timeout
	expect(app.yaw < yaw_before,"right-stick camera turn follows mouse sign")
	axis(JOY_AXIS_RIGHT_X,0.0)
	app.commands.clear()
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_X)
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_Y)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	expect(app.commands == ["jump","catch_pass","dunk","hype","request_pass"],"face buttons and RB submit exactly their gameplay commands")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	expect(app.ball_camera,"LB toggles ball camera")
	await tap(JOY_BUTTON_RIGHT_STICK)
	app.commands.clear()
	axis(JOY_AXIS_TRIGGER_RIGHT,0.5)
	await create_timer(0.05).timeout
	expect(app.commands.is_empty(),"RT below press threshold does nothing")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.7)
	await create_timer(0.05).timeout
	axis(JOY_AXIS_TRIGGER_RIGHT,0.45)
	await create_timer(0.05).timeout
	axis(JOY_AXIS_TRIGGER_RIGHT,0.6)
	await create_timer(0.05).timeout
	expect(app.commands == ["tackle"] and app.controller_trigger,"RT hysteresis prevents repeated tackle around threshold")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	await create_timer(0.05).timeout
	app.commands.clear()
	axis(JOY_AXIS_TRIGGER_RIGHT,0.8)
	await create_timer(0.1).timeout
	expect(app.charging,"RT charges when carrying")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.3)
	await create_timer(0.05).timeout
	expect(app.commands == ["throw"] and not app.charging,"RT release throws exactly once")
	app.discovered_devices.assign([SECOND,DEVICE])
	Input.joy_connection_changed.emit(SECOND,true)
	expect(app.controller_device == DEVICE,"connecting another pad preserves active controller")
	app.commands.clear()
	await tap(JOY_BUTTON_A,SECOND)
	expect(app.commands.is_empty(),"unselected controller cannot jump")
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	axis(JOY_AXIS_TRIGGER_RIGHT,0.8)
	await create_timer(0.05).timeout
	app.commands.clear()
	app.discovered_devices.assign([SECOND])
	Input.joy_connection_changed.emit(DEVICE,false)
	await create_timer(0.06).timeout
	expect(app.controller_device == SECOND and app.paused and not app.charging and not Input.is_action_pressed("controller_shoot"),"unplug cancels charge, pauses and selects remaining pad")
	expect(not app.commands.has("throw"),"unplug cannot accidentally shoot")
	app.discovered_devices.clear()
	Input.joy_connection_changed.emit(SECOND,false)
	await process_frame
	key(KEY_ESCAPE,true)
	await process_frame
	key(KEY_ESCAPE,false)
	await create_timer(0.05).timeout
	key(KEY_W,true)
	await create_timer(0.06).timeout
	expect(app.local_direction.length() > 0.9,"keyboard remains usable after all controllers disconnect")
	key(KEY_W,false)
	await app.close_session()
	await create_timer(0.1).timeout
	app.discovered_devices.assign([DEVICE])
	axis(JOY_AXIS_TRIGGER_RIGHT,0.9)
	Input.joy_connection_changed.emit(DEVICE,true)
	await process_frame
	expect(not app.controller_neutral,"new held controller waits for neutral")
	await tap(JOY_BUTTON_A)
	expect(app.phase == "menu" and not app.controller_neutral,"A cannot activate menu while a newly connected controller is held")
	app.show_lobby()
	await create_timer(0.04).timeout
	await tap(JOY_BUTTON_B)
	expect(app.phase == "lobby" and not app.controller_neutral,"B cannot leave lobby before new controller returns to neutral")
	app.show_menu()
	axis(JOY_AXIS_TRIGGER_RIGHT,0)
	await create_timer(0.05).timeout
	expect(app.controller_neutral,"returning controls to neutral rearms selected controller")
	await create_timer(0.04).timeout
	button(JOY_BUTTON_A,true)
	await create_timer(0.04).timeout
	app.discovered_devices.clear()
	Input.joy_connection_changed.emit(DEVICE,false)
	await create_timer(0.05).timeout
	expect(app.phase == "menu","unplug while holding menu confirm cannot activate Practice")
	app.discovered_devices.assign([DEVICE])
	Input.joy_connection_changed.emit(DEVICE,true)
	await create_timer(0.04).timeout
	button(JOY_BUTTON_DPAD_DOWN,true)
	await create_timer(0.04).timeout
	expect(Input.is_action_pressed("ui_down"),"held D-pad registers UI direction")
	app.discovered_devices.clear()
	Input.joy_connection_changed.emit(DEVICE,false)
	expect(not Input.is_action_pressed("ui_down"),"unplug releases held D-pad UI action")
	app.discovered_devices.assign([DEVICE])
	Input.joy_connection_changed.emit(DEVICE,true)
	await create_timer(0.04).timeout
	app.profile.award_win("controller-reveal-fixture")
	app.show_wardrobe()
	app.open_bag()
	await create_timer(0.05).timeout
	expect(root.gui_get_focus_owner() == focus_text("Equip"),"reward reveal focuses Equip")
	await tap(JOY_BUTTON_B)
	expect(not is_instance_valid(app.reveal_panel) and is_instance_valid(app.wardrobe_panel),"B closes reveal to wardrobe")
	app.close_wardrobe()
	app.manual_input_enabled = false
	app.practice_game("coop")
	app.sim.winner = 1
	app.sim.celebration_time = 0
	await create_timer(0.08).timeout
	expect(app._winner_shown and root.gui_get_focus_owner() == focus_text("Rematch"),"results focus Rematch")
	await tap(JOY_BUTTON_A)
	expect(not app._winner_shown and app.state.winner < 0,"A starts rematch")
	await app.close_session()
	await create_timer(0.05).timeout
	app.status_message = "No answer. Check the room code or LAN address, and keep the host open."
	app.show_menu()
	await create_timer(0.06).timeout
	await capture("05-long-message-menu")
	for control in app.focusable_controls(app.panel):
		expect(control.get_global_rect().end.y < 720,"menu control above footer: " + (control.text if control is Button else control.get_class()))
	app.selected_mode = "teams"
	app.seats = {1:1,2:2,3:3}
	app.names = {1:"Player one",2:"Player two",3:"Player three"}
	app.show_lobby()
	await create_timer(0.06).timeout
	await capture("06-teams-lobby")
	for control in app.focusable_controls(app.panel):
		expect(control.get_global_rect().end.y < 720,"lobby control above footer: " + (control.text if control is Button else control.get_class()))
	await finish()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence_directory.path_join(label + ".png"))

func finish() -> void:
	var pointer_events: Array = app.pointer_events.duplicate(true)
	for index in range(22): button(index,false)
	for index in range(6): axis(index,0)
	await app.close_session()
	app.queue_free()
	await process_frame
	if settings_existed:
		var restored = FileAccess.open(settings_path,FileAccess.WRITE)
		restored.store_buffer(settings_bytes)
		restored.close()
	elif FileAccess.file_exists(settings_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	for suffix in ["",".bak",".tmp"]:
		var target: String = profile_path + suffix
		if FileAccess.file_exists(target): DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	var passed = checks.all(func(row): return row.passed)
	if not pointer_probe.is_empty(): passed = passed and bool(pointer_probe.passed)
	var report = {"passed":passed,"checks":checks,"pointer_probe":pointer_probe,"pointer_events":pointer_events,"hardware_inventory":hardware_inventory,"display_server":DisplayServer.get_name(),"input_source":"parsed joypad events with injected discovery list; competing pointer motion isolated; no physical controller claim"}
	print("CONTROLLER_RESULT ",JSON.stringify(report))
	var path = "res://tests/controller-result.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			var directory = arg.trim_prefix("--evidence-dir=")
			DirAccess.make_dir_recursive_absolute(directory)
			path = directory.path_join("controller-result.json")
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	quit(0 if passed else 1)
