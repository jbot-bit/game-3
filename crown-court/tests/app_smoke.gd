extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ResourceLoader.exists("res://main.tscn"):
		push_error("Application scene does not exist yet")
		quit(1)
		return
	var scene: PackedScene = load("res://main.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var profile_path = "user://app_smoke_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	assert(app.phase == "menu", "Starts in the main menu")
	await capture("app_menu")
	app.show_wardrobe()
	await capture("app_wardrobe")
	app.close_wardrobe()
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "grab", "throw_ball", "tackle"]:
		assert(InputMap.has_action(action), "Missing action " + action)
	app.manual_input_enabled = false
	app.selected_power = "blast"
	app.practice_game("coop")
	await physics_frame
	assert(app.phase == "match" and app.local_seat == 1)
	assert(app.state.players.size() == 6)
	assert(app.sim.players[1].power == "blast", "Practice uses the selected Hype power")
	assert(app.sim.players[2].power == "pad", "Bots retain their default powers")
	assert(app.clean_power("invalid") == "giant", "Unknown power is sanitized")
	app.sim.players[1].pos = Vector3.ZERO
	app.sim.ball.pos = Vector3(0, 1.1, -0.5)
	app.sim.ball.owner = 0
	app.sim.ball.lock = 0.0
	app.sim.reset_time = 0.0
	app.state = app.sim.snapshot()
	app.input_armed = true
	app.manual_input_enabled = true
	Input.action_press("catch_pass")
	await create_timer(0.05).timeout
	assert(app.sim.ball.owner == 1, "Catch input takes possession")
	Input.action_release("catch_pass")
	await create_timer(0.05).timeout
	app.manual_input_enabled = false
	assert(app.sim.ball.owner == 1, "Click to grab must keep the ball on release")
	app.submit_move(Vector3.ZERO, Vector3.RIGHT)
	app.sim.players[1].aim = Vector3.FORWARD
	app.submit_action("throw", 0.4)
	assert(app.sim.ball.vel.x > 5.0, "Action carries latest submitted aim even if host aim is stale")
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	var first_match: String = app.match_id
	assert(not first_match.is_empty())
	await capture("app_gameplay")
	app.set_paused(true)
	assert(app.paused and not app.charging)
	app.set_paused(false)
	assert(not app.paused)
	app.start_match()
	await physics_frame
	assert(app.phase == "match" and app.state.winner == -1)
	assert(app.match_id != first_match, "Rematch identity changes")
	assert(app.sim.players[1].power == "blast", "Rematch preserves selected power")
	app.sim.winner = 0
	await create_timer(0.1).timeout
	assert(app.profile.data.bags == 1, "Winner earns one bag")
	assert(app.state.reward_seats == [1], "Win records participating human seats")
	assert(app.state.reward_peers == [1], "Win records participating connections")
	app.seats[77] = 2
	await create_timer(0.04).timeout
	assert(app.state.reward_seats == [1], "Joining a finished match cannot acquire a win reward")
	assert(app.state.reward_peers == [1], "Joining a finished match cannot acquire another connection's reward")
	app.seats.erase(77)
	await process_frame
	assert(app.profile.data.bags == 1, "Repeated win snapshot does not duplicate reward")
	app.open_bag()
	assert(app.profile.data.bags == 0 and app.profile.data.inventory.size() == 3)
	await capture("app_bag_reveal")
	app.close_reveal()
	app.close_session()
	await process_frame
	assert(app.phase == "menu")
	app.practice_game("versus")
	await physics_frame
	assert(app.state.players.size() == 3)
	app.close_session()
	await process_frame
	app.practice_game("teams")
	await physics_frame
	assert(app.state.players.size() == 2, "Solo custom teams balances with one bot")
	assert(app.state.scores.has(0) and app.state.scores.has(1))
	app.close_session()
	await process_frame
	app.seats = {1: 1, 2: 2, 3: 3}
	app.names = {1: "Host", 2: "Player 2", 3: "Player 3"}
	app.selected_mode = "teams"
	app.show_lobby()
	await capture("app_teams_lobby")
	var setup: Dictionary = app.build_team_setup()
	assert(setup.teams[1] == 0 and setup.teams[2] == 0 and setup.teams[3] == 1)
	assert(setup.bots[0] == 0 and setup.bots[1] == 1)
	app.balance_teams = false
	setup = app.build_team_setup()
	assert(setup.bots[0] == 0 and setup.bots[1] == 0)
	app.seats = {1: 1, 2: 2}
	setup = app.build_team_setup()
	assert(setup.teams[1] == 0 and setup.teams[2] == 1)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	print("APP SMOKE PASS: menu, controls, catch retention, action aim, selected power, all modes, pause, rematch, win reward, dedupe, wardrobe, custom 1v1 / 2v1 with optional bots, close")
	quit(0)

func capture(name: String) -> void:
	if not "--render" in OS.get_cmdline_user_args(): return
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s.png" % name)
