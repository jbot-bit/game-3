extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var unique = str(Time.get_ticks_usec())
	var saved_path = "user://reward_test_%s.json" % unique
	var blocked_path = "user://reward_missing_%s/closet.json" % unique
	app.profile = load("res://profile.gd").new(blocked_path)
	app.manual_input_enabled = false
	app.practice_game("coop")
	await physics_frame
	app.set_physics_process(false)
	app.set_process(false)
	app.state = app.sim.snapshot()
	app.state.winner = 0
	app.state.match_id = "reward-test-" + unique
	app.state.reward_seats = [1]
	app.state.reward_peers = [9999]
	assert(not app.eligible_for_reward(), "A reused winning seat cannot inherit another peer's reward")
	assert(not app.queue_current_win_reward())
	assert(app.pending_rewards.is_empty() and app.profile.data.bags == 0)
	app.state.reward_peers = [1]
	assert(app.eligible_for_reward(), "The participating winning peer is eligible")
	assert(not app.queue_current_win_reward(), "Failed persistence cannot report an earned bag")
	assert(app.profile.data.bags == 0 and app.profile.data.redeemed.is_empty(), "Failed save rolls back the profile")
	assert(app.pending_rewards.size() == 1, "Authorized reward stays pending")
	assert(app.reward_error == app.REWARD_SAVE_ERROR, "Failure tells the player to retry before closing")
	app.close_session()
	assert(app.phase == "menu" and app.pending_rewards.size() == 1, "Leaving retains the pending reward")
	assert(app.menu_note.text == app.REWARD_SAVE_ERROR, "Menu keeps the save failure visible")
	app.profile.path = saved_path
	app.set_process(true)
	await create_timer(1.2).timeout
	assert(app.profile.data.bags == 1 and app.pending_rewards.is_empty(), "The timed menu retry saves exactly one bag")
	assert(app.profile.data.redeemed.size() == 1 and app.reward_error.is_empty())
	assert(app.retry_pending_rewards() == 0 and app.profile.data.bags == 1, "Retry is idempotent after success")
	var reloaded = load("res://profile.gd").new(saved_path)
	assert(reloaded.data.bags == 1 and reloaded.data.redeemed.size() == 1, "Recovered reward survives reload")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(saved_path + suffix): DirAccess.remove_absolute(saved_path + suffix)
	print("REWARD TEST PASS: connection eligibility, failed save rollback, retry after leaving, persistent exactly-once recovery")
	quit(0)
