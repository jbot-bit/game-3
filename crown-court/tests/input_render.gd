extends SceneTree

var app
var checks = 0
var failures = 0
var evidence = "C:/game-3/build/crown-court-evidence"
var test_path = ""
var settings_existed = false
var saved_settings = ""
var pause_test = false
var focus_recoveries = 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + title)

func key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse(pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)

func frames(count: int) -> void:
	for i in count:
		if is_instance_valid(app) and app.paused and not pause_test:
			# Native automation can lose OS focus. Resume through real Escape input
			# and report every recovery rather than letting a paused fixture advance.
			focus_recoveries += 1
			key(KEY_ESCAPE, true)
			key(KEY_ESCAPE, false)
			Input.flush_buffered_events()
		await physics_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(name + ".png"))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed: saved_settings = FileAccess.get_file_as_string("user://settings.cfg")
	root.size = Vector2i(1280, 800)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.muted = true
	test_path = "user://input_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(test_path)
	await frames(8)
	await capture("01-menu")
	# Enter through the actual button signal and input stack used by the shipped UI.
	var play = find_button(app.ui, "Practice")
	check(play != null, "Practice is reachable from the menu")
	play.pressed.emit()
	app.set_paused(false)
	await frames(5)
	# Reserve all seats to isolate input response from AI tackles in this fixture.
	app.seats = {1:1,2:2,3:3,4:4,5:5,6:6}
	for id in app.sim.players:
		app.sim.players[id].move = Vector3.ZERO
		app.sim.players[id].vel = Vector3.ZERO
		if id != 1: app.sim.players[id].pos = Vector3(7,0,10+id*.7)
	await frames(190)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Gameplay captures mouse for orbit camera")
	var start = app.sim.players[1].pos
	key(KEY_W, true)
	await frames(45)
	key(KEY_W, false)
	await frames(5)
	check(app.sim.players[1].pos.z < start.z - 4, "Physical W events move player forward")
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, -15)
	motion.screen_relative = motion.relative
	var yaw_before: float = app.yaw
	var pitch_before: float = app.pitch
	Input.parse_input_event(motion)
	await frames(2)
	check(angle_difference(yaw_before, app.yaw) < -0.2 and app.pitch < pitch_before, "Mouse input rotates chase camera")
	key(KEY_SPACE, true)
	await frames(2)
	key(KEY_SPACE, false)
	await frames(8)
	check(app.sim.players[1].pos.y > 0.5, "Physical Space makes player jump")
	key(KEY_SPACE, true)
	await frames(2)
	key(KEY_SPACE, false)
	check(app.sim.players[1].jump_count == 2, "Second press double jumps through input path")
	await capture("02-jump")
	await frames(75)
	# Isolate a rebound fixture while using actual E and mouse input for possession and shot.
	app.seats = {1:1,2:2,3:3,4:4,5:5,6:6}
	for id in app.sim.players:
		app.sim.players[id].move = Vector3.ZERO
		app.sim.players[id].vel = Vector3.ZERO
		app.sim.players[id].pos = Vector3(7,0,10+id*.7) if id != 1 else app.Sim.NORTH+Vector3(0,-app.Sim.HOOP_Y,14)
	app.yaw = 0
	app.sim.ball.owner = 0
	app.sim.ball.lock = 0
	app.sim.ball.pos = app.sim.players[1].pos+Vector3(0,1.2,-.8)
	app.sim.ball.vel = Vector3.ZERO
	await frames(2)
	key(KEY_E,true)
	await frames(2)
	key(KEY_E,false)
	check(app.sim.ball.owner == 1, "Physical E grabs nearby ball")
	# The test chooses a manual physical shot. Gameplay never calls this helper.
	var planned_charge: float = load("res://tests/shot_fixture.gd").aimed_charge(app.sim, 1)
	var planned_direction: Vector3 = app.sim.players[1].shot_aim
	var look = InputEventMouseMotion.new()
	var desired_yaw = atan2(-planned_direction.x, -planned_direction.z)
	var desired_pitch = .43 + deg_to_rad(48.0) - asin(planned_direction.y)
	look.relative = Vector2(-angle_difference(app.yaw, desired_yaw) / .0032, (desired_pitch - app.pitch) / .0028)
	look.screen_relative = look.relative
	Input.parse_input_event(look)
	Input.flush_buffered_events()
	var score_before_shot = int(app.sim.scores[0])
	mouse(true)
	var charge_frames = maxi(1, roundi(planned_charge * 1.15 * Engine.physics_ticks_per_second))
	# physics_frame resumes before the app's control tick; allow the press tick.
	await frames(charge_frames + 1)
	check(app.charging and app.owns_ball(), "Holding mouse charges a held ball")
	print("INPUT_SHOT_PLAN ", JSON.stringify({"planned_charge":planned_charge,"actual_charge":app.charge_time/1.15,"planned_direction":planned_direction,"control_direction":app.shot_direction(),"position":app.sim.players[1].pos,"charge_frames":charge_frames,"hand":app.sim.hand_position(1)}))
	app.set_physics_process(false)
	await capture("03-aim")
	mouse(false)
	app.set_physics_process(true)
	await frames(2)
	check(app.sim.ball.owner == 0 and app.sim.throws > 0, "Mouse release launches the held ball")
	print("INPUT_SHOT_RELEASE ", JSON.stringify({"velocity":app.sim.ball.vel,"ball":app.sim.ball.pos,"score":app.sim.scores,"paused":app.paused}))
	await capture("04-shot")
	await frames(100)
	check(int(app.sim.scores[0]) == score_before_shot + 1, "A player-input shot physically scores through hoop")
	await frames(195)
	while app.sim.reset_time > 0: await frames(1)
	app.sim.players[1].pos = Vector3(0,0,app.Sim.NORTH.z+3)
	app.sim.players[1].vel = Vector3.ZERO
	app.sim.ball.owner = 1
	app.sim.ball.last_touch = 1
	var score_before_dunk = int(app.sim.scores[0])
	await frames(2)
	key(KEY_SPACE,true)
	await frames(2)
	key(KEY_SPACE,false)
	await frames(7)
	key(KEY_F,true)
	await frames(2)
	key(KEY_F,false)
	check(app.sim.players[1].dunk > 0, "Physical F after jump starts contextual dunk")
	print("INPUT_DUNK_ATTEMPT ", JSON.stringify({"position":app.sim.players[1].pos,"dunk":app.sim.players[1].dunk,"jump_count":app.sim.players[1].jump_count,"reset":app.sim.reset_time,"paused":app.paused,"score":app.sim.scores}))
	await capture("05-dunk")
	await frames(90)
	check(int(app.sim.scores[0]) == score_before_dunk + 1, "Input-driven dunk scores once")
	pause_test = true
	key(KEY_ESCAPE,true)
	await frames(2)
	key(KEY_ESCAPE,false)
	check(app.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape pauses and releases cursor")
	await capture("06-pause")
	var at_pause = app.sim.clock
	await frames(10)
	check(is_equal_approx(app.sim.clock,at_pause), "Offline pause actually stops simulation")
	key(KEY_ESCAPE,true)
	await frames(2)
	key(KEY_ESCAPE,false)
	check(not app.paused, "Escape resumes")
	app.close_session()
	await frames(5)
	# Exercise earned-reward reveal and equip through real UI buttons.
	app.profile.award_win("input-reward")
	app.show_menu()
	await frames(3)
	var wardrobe = find_button_contains(app.ui, "WARDROBE")
	check(wardrobe != null, "Wardrobe is reachable from the menu")
	if wardrobe:
		wardrobe.pressed.emit()
		await frames(3)
		await capture("07-wardrobe")
		var open = find_button_contains(app.ui, "OPEN")
		check(open != null, "Earned blind bag has an open button")
		if open:
			open.pressed.emit()
			await frames(100)
			await capture("08-reward")
			check(app.profile.data.bags == 0 and app.profile.data.inventory.size() == 3, "UI reveals and saves exactly one earned item")
	print("INPUT_RENDER_RESULT %d checks; %d failures; final render %dfps; %d OS-focus recoveries" % [checks, failures, Engine.get_frames_per_second(), focus_recoveries])
	if settings_existed:
		var settings = FileAccess.open("user://settings.cfg",FileAccess.WRITE)
		settings.store_string(saved_settings)
		settings.close()
	elif FileAccess.file_exists("user://settings.cfg"): DirAccess.remove_absolute("user://settings.cfg")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix): DirAccess.remove_absolute(test_path + suffix)
	quit(1 if failures else 0)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text.to_upper() == text.to_upper(): return node
	for child in node.get_children():
		var found = find_button(child, text)
		if found: return found
	return null

func find_button_contains(node: Node, text: String) -> Button:
	if node is Button and text.to_upper() in node.text.to_upper(): return node
	for child in node.get_children():
		var found = find_button_contains(child, text)
		if found: return found
	return null
