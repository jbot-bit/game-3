extends SceneTree
## Two real ENet processes; files coordinate stages, never fishing input/state.
## The host seeds an ordinary catch and places the remote player at the Jetty.
## All catch progress, landing, movement home, and banking use normal remote intents.
var game: Node3D
var role: String = ""
var output: String = ""
var run_key: String = ""
var port: int = 24930
var checks: int = 0
var sequence: int = 0
var fish_id: String = ""
var trace: Array[Dictionary] = []
var right_samples: int = 0
var left_samples: int = 0
var previous_bar: float = 0.5
var rejected: Dictionary = {}
var catch_seconds: float = 0.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-role="): role = argument.trim_prefix("--probe-role=")
		if argument.begins_with("--probe-output="): output = argument.trim_prefix("--probe-output=")
		if argument.begins_with("--probe-key="): run_key = argument.trim_prefix("--probe-key=")
		if argument.begins_with("--probe-port="): port = int(argument.trim_prefix("--probe-port="))
	if not _check(role in ["host", "client"] and not output.is_empty() and not run_key.is_empty(), "arguments"): return
	game = load("res://game/main.tscn").instantiate()
	game.settings_path = "user://tests/fishing-network-" + run_key + "-" + role + "-settings.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.game_port = port
	game.session.snapshot_received.connect(_observe_snapshot)
	game.session.intent_rejected.connect(func(request: String, code: String) -> void: rejected[request] = code)
	if role == "host": await _host()
	else: await _client()

func _host() -> void:
	game.save_path = "user://tests/fishing-network-" + run_key + ".json"
	game._host("Fishing Host")
	if not _check(game.session.is_host(), "host_started", {"port":port,"save":game.save_path}): return
	_write("listen", {"ready":true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().has("crew_2"), "remote_connected"): return
	var old_peer: int = game.session.roster.snapshot().crew_2.peer_id
	if not _check(old_peer > 1, "remote_peer_is_real", {"peer_id":old_peer}): return
	var actor = game.controller.avatars.crew_2
	actor.global_position = game.world.markers.jetty
	actor.last_dry = actor.global_position
	actor.velocity = Vector3.ZERO
	for candidate in range(1000):
		var random = RandomNumberGenerator.new()
		random.seed = candidate
		var rolled: Dictionary = CatchTable.roll("jetty","day",0,random.randf(),random.randf(),random.randf())
		if rolled.species_id == "penny_perch" and rolled.trait_id == "none":
			game.controller.rng.seed = candidate
			break
	game.controller._publish()
	_write("spawned", {"ready":true})
	if not await _wait(func() -> bool: return not game.controller.progression.snapshot().landed_catch_ids.is_empty(), "remote_normal_input_landed", 16.0): return
	var saved: Dictionary = game.controller.progression.snapshot()
	fish_id = saved.landed_catch_ids[0]
	var cargo: Dictionary = game.controller.cargo.snapshot()[fish_id]
	if not _check(saved.landed_catch_ids.size() == 1 and saved.coins == 0 and cargo.state == "packed" and cargo.catch_record.profile_id == "crew_2", "one_remote_catch_not_yet_paid"): return
	if not _check(right_samples > 0 and left_samples > 0, "remote_hold_and_release_move_host_bar_both_directions", {"right_samples":right_samples,"left_samples":left_samples}): return
	_write("landed", {"ready":true})
	if not await _wait(func() -> bool: return fish_id in game.controller.progression.snapshot().banked_catch_ids, "remote_return_and_bank", 18.0): return
	saved = game.controller.progression.snapshot()
	if not _check(saved.coins == 10 and saved.lifetime_banked == 10 and saved.banked_catch_ids.count(fish_id) == 1, "normal_catch_banked_exactly_once", {"coins":saved.coins,"catch_id":fish_id}): return
	if not await _wait(func() -> bool: return _has("client_replay_checked"), "client_duplicate_bank_rejected"): return
	if not await _wait(func() -> bool: return not game.session.roster.snapshot().has("crew_2"), "client_disconnected"): return
	_write("rejoin", {"ready":true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().has("crew_2") and game.session.roster.snapshot().crew_2.peer_id != old_peer, "same_profile_new_enet_peer"): return
	if not await _wait(func() -> bool: return _has("client_done"), "client_rejoin_verified"): return
	_write("host_trace", {"ready":true,"trace":trace})
	var client_trace: Array = _read("client_done").trace
	var matched: int = 0
	for remote: Dictionary in client_trace:
		for authoritative: Dictionary in trace:
			if remote.get("state_sha256", "") == authoritative.get("state_sha256", "missing"):
				matched += 1
				break
	if not _check(client_trace.size() >= 10 and matched == client_trace.size(), "every_replicated_control_sample_matches_host", {"samples":client_trace.size(),"matched":matched}): return
	var loaded: Dictionary = SaveStore.new(game.save_path).load_or_recover()
	if not _check(loaded.ok and loaded.state.landed_catch_ids.count(fish_id) == 1 and loaded.state.banked_catch_ids.count(fish_id) == 1 and loaded.state.coins == 10 and loaded.state.lifetime_banked == 10, "independent_disk_reload_has_single_earned_reward"): return
	_write("host_complete", {"ready":true})
	if not await _wait(func() -> bool: return _has("client_pass"), "client_finished"): return
	await _finish()

func _client() -> void:
	if not await _wait(func() -> bool: return _has("listen"), "host_listening"): return
	game._join("127.0.0.1",1,"Fishing Client")
	if not await _wait(func() -> bool: return game.session.status == "connected" and game.session.local_profile_id == "crew_2" and game.controller.avatars.has("crew_2"), "client_joined"): return
	if not await _wait(func() -> bool: return _has("spawned") and game.controller.avatars.crew_2.global_position.distance_to(game.world.markers.jetty) < 1.0, "jetty_fixture_replicated"): return
	_send("cast", {})
	if not await _wait(func() -> bool: return not _cast().is_empty(), "remote_cast_state_replicated"): return
	fish_id = str(_cast().catch_id)
	var started: int = Time.get_ticks_msec()
	var started_elapsed: float = float(_cast().elapsed)
	while not _cast().is_empty() and Time.get_ticks_msec() - started < 14000:
		var cast: Dictionary = _cast()
		_send("reel", {"held":float(cast.fish_position) > float(cast.bar_position),"pull":0.0})
		await create_timer(0.05).timeout
	_send("reel", {"held":false,"pull":0.0})
	catch_seconds = (Time.get_ticks_msec() - started) / 1000.0 + started_elapsed
	if not await _wait(func() -> bool: return fish_id in _saved().get("landed_catch_ids", []), "earned_catch_replicated"): return
	if not _check(catch_seconds <= 10.0 and catch_seconds >= 5.0, "normal_remote_catch_finishes_promptly", {"seconds":catch_seconds,"snapshot_samples":trace.size()}): return
	if not _check(_saved().landed_catch_ids.count(fish_id) == 1 and _saved().coins == 0, "client_sees_one_unbanked_landing"): return
	if not await _walk_to_boat(): return
	var bank_request: String = _send("bank", {})
	if not await _wait(func() -> bool: return fish_id in _saved().get("banked_catch_ids", []), "bank_reward_replicated"): return
	game.session.submit_intent("bank", {}, bank_request)
	if not await _wait(func() -> bool: return rejected.get(bank_request, "") == "duplicate", "same_bank_request_rejected"): return
	if not _check(_saved().coins == 10 and _saved().banked_catch_ids.count(fish_id) == 1, "bank_replay_cannot_duplicate_reward"): return
	_write("client_replay_checked", {"ready":true})
	game.session.close()
	game.controller.active = false
	if not await _wait(func() -> bool: return _has("rejoin"), "host_ready_for_rejoin"): return
	game._join("127.0.0.1",1,"Fishing Client")
	if not await _wait(func() -> bool: return game.session.status == "connected" and game.session.local_profile_id == "crew_2" and _saved().get("banked_catch_ids", []).count(fish_id) == 1, "earned_reward_survives_rejoin"): return
	if not _check(_saved().coins == 10 and _saved().landed_catch_ids.count(fish_id) == 1 and _cast().is_empty(), "rejoin_has_no_resumed_or_duplicated_catch"): return
	_write("client_done", {"ready":true,"trace":trace,"catch_seconds":catch_seconds})
	if not await _wait(func() -> bool: return _has("host_complete"), "host_disk_and_replication_verified"): return
	await _finish()

func _walk_to_boat() -> bool:
	var goal: Vector3 = game.world.markers.boat
	var deadline: int = Time.get_ticks_msec() + 15000
	while game.controller.avatars.crew_2.global_position.distance_to(goal) > 1.8:
		if Time.get_ticks_msec() > deadline: return _check(false,"remote_walk_home_timeout")
		var at: Vector3 = game.controller.avatars.crew_2.global_position
		var waypoint: Vector3 = game.world.route_step(at,goal)
		var direction: Vector2 = Vector2(waypoint.x-at.x,waypoint.z-at.z).normalized()
		_send("move", {"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		await create_timer(0.05).timeout
	_send("move", {"direction":Vector2.ZERO,"yaw":0.0})
	return _check(true,"remote_player_walked_home_normally")

func _observe_snapshot(data: Dictionary) -> void:
	var cast: Dictionary = data.get("fishing", {}).get("crew_2", {})
	if cast.is_empty(): return
	var sample: Dictionary = {}
	for key: String in ["catch_id","elapsed","bar_position","bar_width","fish_position","tracking","progress"]: sample[key] = cast[key]
	# Hash the original network values before JSON rounds floating-point evidence.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(sample))
	sample.state_sha256 = digest.finish().hex_encode()
	trace.append(sample)
	if role == "host" and float(cast.elapsed) > 0.8:
		var held: bool = bool(game.controller.inputs.get("crew_2", {}).get("reel",false))
		if held and float(cast.bar_position) > previous_bar + 0.001: right_samples += 1
		if not held and float(cast.bar_position) < previous_bar - 0.001: left_samples += 1
	previous_bar = float(cast.bar_position)

func _cast() -> Dictionary: return game.controller.snapshot_data.get("fishing", {}).get("crew_2", {})
func _saved() -> Dictionary: return game.controller.snapshot_data.get("progression", {})
func _send(action: String, payload: Dictionary) -> String:
	sequence += 1
	var request: String = "fishing_" + role + "_" + str(sequence)
	game.session.submit_intent(action,payload,request)
	return request

func _wait(condition: Callable, label: String, seconds: float = 8.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline: return _check(false,"timeout_"+label,{"session":game.session.status})
		await create_timer(0.05).timeout
	return _check(true,label)

func _check(condition: bool, label: String, evidence: Dictionary = {}) -> bool:
	checks += 1
	print(JSON.stringify({"role":role,"check":label,"ok":condition,"evidence":evidence}))
	if not condition:
		_write(role+"_fail",{"ready":true,"check":label,"evidence":evidence})
		if is_instance_valid(game): game.session.close()
		quit(1)
	return condition

func _write(tag: String, data: Dictionary) -> void:
	var file = FileAccess.open(output.path_join(tag+".json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data))
func _read(tag: String) -> Dictionary:
	var path: String = output.path_join(tag+".json")
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
func _has(tag: String) -> bool: return bool(_read(tag).get("ready",false))
func _finish() -> void:
	var result: Dictionary = {"ready":true,"role":role,"checks":checks,"catch_id":fish_id,"catch_seconds":catch_seconds,"replicated_samples":trace.size(),"scope":"Two real ENet processes on loopback; Jetty spawn and ordinary RNG fixture only; remote cast/reel/move/bank intents, earned save and reconnect; not two physical PCs."}
	game.controller.active = false
	game.session.close()
	game.queue_free()
	await process_frame
	_write(role+"_pass",result)
	print("FISHING_NETWORK_PASS "+JSON.stringify(result))
	quit()
