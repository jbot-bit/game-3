extends SceneTree

class TestPeer extends MultiplayerPeerExtension:
	var connected = true
	var identity_queries = 0
	func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
		return MultiplayerPeer.CONNECTION_CONNECTED if connected else MultiplayerPeer.CONNECTION_DISCONNECTED
	func _get_unique_id() -> int:
		identity_queries += 1
		return 2
	func _is_server() -> bool:
		return false
	func _poll() -> void:
		pass
	func _close() -> void:
		connected = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.selected_mode = "teams"
	app.seats = {1: 1, 2: 2}
	app.names = {1: "Host", 2: "Guest"}
	app.start_match()
	assert(app.sim.team(1) == 0 and app.sim.team(2) == 1)
	assert(app.team_choices == {1: 0, 2: 1}, "Start freezes the actual sides")
	assert(app.add_match_human(3), "Third player can join the match")
	app.seats[3] = 3
	assert(app.sim.team(2) == 1 and app.team_choices[2] == 1, "Late join preserves the second player's team")
	assert(app.sim.players.size() == 4, "Balancing adds the missing fourth player")
	var counts = {0: 0, 1: 0}
	for id in app.sim.players: counts[app.sim.team(id)] += 1
	assert(counts == {0: 2, 1: 2}, "Three human late join becomes balanced 2v2")
	var setup: Dictionary = app.build_team_setup()
	assert(setup.teams == {1: 0, 2: 1, 3: 0}, "Next match setup keeps the live assignments")
	app.start_match()
	assert(app.sim.team(2) == 1 and app.sim.players.size() == 4, "Rematch retains sides and balance")
	app.close_session()
	app.selected_mode = "teams"
	app.team_choices.clear()
	app.seats = {1: 1, 2: 2}
	app.balance_teams = false
	app.start_match()
	assert(app.add_match_human(3))
	app.seats[3] = 3
	assert(app.sim.players.size() == 3, "Disabled balancing keeps custom 2v1")
	var peer = TestPeer.new()
	app.multiplayer.multiplayer_peer = peer
	var previous_queries: int = peer.identity_queries
	app._closing = true
	app.presentation_state()
	app._process(0.016)
	assert(peer.identity_queries == previous_queries, "Closing does not query connection identity")
	app._closing = false
	peer.connected = false
	assert(not app.multiplayer_active())
	app.presentation_state()
	app._physics_process(0.016)
	app.submit_move(Vector3.FORWARD, Vector3.FORWARD)
	app.submit_action("jump")
	app.eligible_for_reward()
	assert(peer.identity_queries == previous_queries, "Inactive peer is guarded in presentation, input, physics, and rewards")
	app._process(0.016)
	assert(app.phase == "menu", "Inactive match returns to menu without a peer identity query")
	assert(peer.identity_queries == previous_queries)
	print("SESSION TEST PASS: late-join balance, fixed team assignments, rematch, optional bots, closing and disconnected peer guards")
	quit(0)
