extends SceneTree

var app
var checks: Array[Dictionary] = []
var evidence = "res://tests/room-ui"
var profile_path = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"check":label,"passed":ok})
	print("PASS " if ok else "FAIL ",label)

func find_button(text: String) -> Button:
	for node in app.panel.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func tap(index: int) -> void:
	for pressed in [true,false]:
		var event = InputEventJoypadButton.new()
		event.device = 11
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await create_timer(.04).timeout

func capture(name: String) -> void:
	await create_timer(.06).timeout
	for control in app.focusable_controls(app.controller_menu_root()):
		check(control.get_global_rect().end.y < 721 and control.get_global_rect().end.x < 1260,name+" bounds: "+(control.text if control is Button else control.get_class()))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join(name+".png"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	app = load("res://tests/controller_app.gd").new()
	profile_path = "user://room_ui_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	root.add_child(app)
	app.muted = true
	app.discovered_devices.assign([11])
	Input.joy_connection_changed.emit(11,true)
	app.room_server_url = ""
	app.show_menu()
	await create_timer(.06).timeout
	check(find_button("Host online game").disabled and find_button("Find online game").disabled,"unconfigured room controls disabled")
	check(root.gui_get_focus_owner() == find_button("Practice"),"unconfigured menu retains Practice focus")
	await capture("01-unconfigured")
	app.room_server_url = "ws://127.0.0.1:30230/rooms"
	app.show_menu()
	await process_frame
	check(not find_button("Host online game").disabled and not find_button("Find online game").disabled,"configured room controls available")
	await capture("02-configured")
	app.name_edit.text = "ABCDEFGHJKLMNPQRSTUVWXYZ234"
	app.name_edit.grab_focus()
	await tap(JOY_BUTTON_A)
	check(is_instance_valid(app.controller_keyboard),"controller confirm opens name keyboard")
	await capture("03-room-keyboard")
	await tap(JOY_BUTTON_B)
	check(not is_instance_valid(app.controller_keyboard) and root.gui_get_focus_owner() == app.name_edit,"keyboard cancel returns focus to player name")
	app.join_room("bad")
	check(app.phase == "menu" and "room code" in app.status_message,"invalid room code stays in menu")
	app.selected_mode = "teams"
	app.room_code = "ABCDEFGHJKLMNPQRSTUVWXYZ234"
	app.seats = {1:1,2:2,3:3}
	app.names = {1:"Player one",2:"Player two",3:"Player three"}
	app.show_lobby()
	await capture("04-room-teams")
	check(root.gui_get_focus_owner() == find_button("Start"),"room lobby Start receives focus")
	await app.close_session()
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path+suffix))
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"scope":"rendered UI and parsed controller events; no hardware or WAN claim"}
	var file = FileAccess.open(evidence.path_join("room-ui-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ROOM_UI_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
