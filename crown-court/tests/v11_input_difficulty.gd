extends SceneTree

var app
var checks = 0
var failures = 0
var settings_existed = false
var settings_bytes = PackedByteArray()
var profile_path = ""

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	root.size = Vector2i(1280, 800)
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed: settings_bytes = FileAccess.get_file_as_bytes("user://settings.cfg")
	var cfg = ConfigFile.new()
	cfg.set_value("game", "bot_difficulty", "normal")
	cfg.save("user://settings.cfg")
	app = load("res://main.gd").new()
	expect(app.selected_difficulty == "easy" and app.clean_difficulty("invalid") == "easy", "fresh and invalid bot preferences default to Easy")
	profile_path = "user://v11_input_profile_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	await process_frame
	expect(app.selected_difficulty == "normal" and app.sim.bot_difficulty == "normal", "saved local preference loads into menu simulation")
	expect(app.difficulty_select.get_parent() == app.mode_select.get_parent() and app.difficulty_select.item_count == 3, "compact options row contains all three bot levels")
	var card = app.mode_select.get_parent().get_parent().get_parent()
	print("V11 MENU WIDTH ", JSON.stringify({"card":card.size.x, "mode_min":app.mode_select.get_combined_minimum_size().x, "power_min":app.power_select.get_combined_minimum_size().x, "difficulty_min":app.difficulty_select.get_combined_minimum_size().x}))
	expect(card.size.x <= 440.01, "third selector stays within original menu card width")
	expect(app.difficulty_select.focus_mode == Control.FOCUS_ALL and app.difficulty_select.has_theme_stylebox_override("focus"), "difficulty selector is controller navigable with visible focus")
	app.difficulty_select.select(2)
	app.difficulty_select.item_selected.emit(2)
	cfg.load("user://settings.cfg")
	expect(app.selected_difficulty == "hard" and cfg.get_value("game", "bot_difficulty") == "hard", "host preference changes and saves through real selector")
	app.show_lobby()
	expect(app.sim.bot_difficulty == "hard" and app.build_team_setup().bot_difficulty == "hard", "lobby preview and roster advertise host difficulty")
	for mode in ["coop", "versus", "teams"]:
		app.selected_mode = mode
		app.start_match()
		expect(app.state.bot_difficulty == "hard" and app.sim.bot_difficulty == "hard", "%s match reset preserves host difficulty" % mode)
		app.start_match()
		expect(app.state.bot_difficulty == "hard", "%s rematch preserves host difficulty" % mode)
	app.selected_difficulty = "normal"
	var client = ENetMultiplayerPeer.new()
	var connected = client.create_client("127.0.0.1", 29879, app.NETWORK_CHANNELS)
	expect(connected == OK, "isolated client authority fixture initializes")
	app.multiplayer.multiplayer_peer = client
	app.lobby_setup = {"bot_difficulty": "easy"}
	app.show_lobby()
	expect(app.difficulty_select == null and app.difficulty_label.text == "Easy bots", "joining client sees host level without an editable selector")
	app.roster({1: 1, 2: 2}, {1: "HOST", 2: "CLIENT"}, {}, {"bot_difficulty": "hard"})
	expect(app.difficulty_label.text == "Hard bots" and app.sim.bot_difficulty == "hard" and app.selected_difficulty == "normal", "late roster updates effective difficulty without replacing local preference")
	app.save_settings()
	cfg.load("user://settings.cfg")
	expect(cfg.get_value("game", "bot_difficulty") == "normal", "client saving stores own preferred level after remote updates")
	app.phase = "match"
	app.match_id = "v11-input-round"
	var remote: Dictionary = app.sim.snapshot()
	remote.bot_difficulty = "easy"
	remote.match_id = app.match_id
	remote._snapshot_seq = 1
	app.apply_snapshot(remote)
	expect(app.effective_difficulty() == "easy" and app.selected_difficulty == "normal", "live snapshot owns displayed difficulty independently of local preference")
	app.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	client.close()
	app.show_menu()
	expect(app.sim.bot_difficulty == "normal" and app.difficulty_select.selected == 1, "leaving restores local preference for next hosted game")
	app.queue_free()
	await process_frame
	if settings_existed:
		var output = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		output.store_buffer(settings_bytes)
		output.close()
	else: DirAccess.remove_absolute("user://settings.cfg")
	if FileAccess.file_exists(profile_path): DirAccess.remove_absolute(profile_path)
	print("V11 INPUT DIFFICULTY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
