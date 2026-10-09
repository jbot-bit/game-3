extends SceneTree
## Three separate Godot processes exercise the real scene and ENet RPCs.
## Files coordinate test stages only; all gameplay state arrives through Session.

var game: Node3D
var role: String = ""
var output: String = ""
var run_key: String = ""
var port: int = 24563
var failed: bool = false
var checks: int = 0
var request_sequence: int = 0
var fish_id: String = ""
var first_positions: Dictionary = {}
var last_poses: Dictionary = {}
var pose_packets: int = 0
var last_status_message: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-role="): role = argument.trim_prefix("--probe-role=")
		if argument.begins_with("--probe-output="): output = argument.trim_prefix("--probe-output=")
		if argument.begins_with("--probe-key="): run_key = argument.trim_prefix("--probe-key=")
		if argument.begins_with("--probe-port="): port = int(argument.trim_prefix("--probe-port="))
	if not _check(role in ["host", "client1", "client2"] and not output.is_empty() and not run_key.is_empty(), "arguments"):
		return
	var scene: PackedScene = load("res://game/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	# Prevent absent headless keyboard input from overwriting test intents.
	game.set_physics_process(false)
	game.set_process(false)
	game.game_port = port
	game.session.poses_received.connect(_observe_poses)
	game.session.status_changed.connect(func(_status: String, message: String) -> void: last_status_message = message)
	if role == "host":
		await _host_probe()
	else:
		await _client_probe()

func _host_probe() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	game.save_path = "user://tests/network_probe_" + run_key + ".json"
	game._host("Probe Host")
	if not _check(game.session.is_host() and game.controller.active, "host_started", {"port": port, "save": game.save_path}): return
	_write("listen", {"ready": true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 3, "three_real_connections"): return
	var original_roster: Dictionary = game.session.roster.snapshot()
	if not _check(original_roster.crew_1.peer_id == 1 and original_roster.crew_2.peer_id != original_roster.crew_3.peer_id, "unique_peer_ids", original_roster): return
	# Persist a distinctive reconnect fixture through the real atomic save API.
	var saved: Dictionary = game.controller.progression.set_profile("crew_2", "Probe Keeper", "keeper")
	if not _check(saved.ok, "profile_saved_before_reconnect"): return
	game.controller._publish()
	if not await _wait_ack("ready"): return
	first_positions = _positions()
	_write("move", {"ready": true})
	await _move_for_one_second()
	if not await _wait_ack("moved"): return
	await create_timer(0.5).timeout
	if not _check_movement(): return
	game.controller._publish()
	_write("settled", {"ready": true, "pose_sequence":game.session._pose_sequence})
	if not await _wait_ack("movement_checked"): return

	fish_id = str(game.controller.run.run_id) + ":network_fixture"
	var record: Dictionary = {"catch_id": fish_id, "run_id": game.controller.run.run_id, "profile_id": "crew_2", "species_id": "penny_perch", "habitat_id": "jetty", "rare_eligible": false, "trait_id": "oversized", "size": 1.4, "catch_value": 12}
	var recorded: Dictionary = game.controller.progression.record_specimen(record)
	if not _check(recorded.ok, "specimen_durably_recorded", {"catch_id": fish_id, "revision": recorded.get("revision", -1)}): return
	game.controller._add_landed(record)
	await create_timer(0.6).timeout
	game.controller._publish()
	if not _check(game.controller.fish_bodies.has(fish_id) and game.controller.cargo.snapshot()[fish_id].state == "whole_loose", "one_host_physics_fish"): return
	_write("fish", {"ready": true, "catch_id": fish_id})
	if not await _wait_ack("fish_seen"): return
	_write("grab", {"ready": true})
	if not await _wait(func() -> bool: return game.controller.cargo.held_by("crew_2") == fish_id and game.controller.fish_bodies[fish_id].held, "remote_grab_accepted"): return
	await create_timer(0.4).timeout
	if not _check(game.controller.cargo.held_by("crew_2") == fish_id and game.controller.fish_bodies.size() == 1, "stable_id_single_holder"): return
	_write("held", {"ready": true})
	if not await _wait_ack("held_seen"): return

	_write("disconnect", {"ready": true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 2 and not game.session.roster.snapshot().has("crew_2"), "client_disconnected"): return
	if not await _wait(func() -> bool: return game.controller.cargo.snapshot()[fish_id].state == "whole_loose" and not game.controller.fish_bodies[fish_id].held, "disconnect_releases_shared_fish"): return
	game.controller._publish()
	if not await _wait(func() -> bool: return _has("client2_disconnect_seen"), "remaining_client_sees_disconnect"): return
	_write("rejoin", {"ready": true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 3, "three_connections_after_rejoin"): return
	var new_roster: Dictionary = game.session.roster.snapshot()
	if not _check(new_roster.crew_2.peer_id != original_roster.crew_2.peer_id, "new_connection_same_profile", {"old_peer": original_roster.crew_2.peer_id, "new_peer": new_roster.crew_2.peer_id, "profile": "crew_2"}): return
	var state: Dictionary = game.controller.progression.snapshot()
	if not _check(state.profiles.crew_2.name == "Probe Keeper" and state.landed_catch_ids.count(fish_id) == 1 and state.coins == 0 and state.banked_catch_ids.is_empty(), "reconnect_preserves_profile_no_duplicate_or_reward"): return
	var save_script: GDScript = load("res://game/progression/save_store.gd")
	var store: RefCounted = save_script.new(game.save_path)
	var loaded: Dictionary = store.load_or_recover()
	if not _check(loaded.ok and loaded.state.profiles.crew_2.name == "Probe Keeper" and fish_id in loaded.state.landed_catch_ids, "independent_disk_reload_confirms_fixture"): return
	_write("rejoined", {"ready": true, "pose_sequence":game.session._pose_sequence})
	if not await _wait_ack("rejoined_seen"): return
	# Queue both real disconnect packets before one transport poll. This makes
	# the teardown race reproducible instead of depending on process scheduling.
	game.controller.set_physics_process(false)
	multiplayer_poll = false
	_write("simultaneous_drop", {"ready": true})
	if not await _wait_ack("batch_closed"): return
	await create_timer(0.1).timeout
	game.get_multiplayer().poll()
	multiplayer_poll = true
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 1, "both_disconnects_processed_in_batch"): return
	await process_frame
	game.controller.set_physics_process(true)
	_write("batch_reconnect", {"ready": true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 3, "host_remains_joinable_after_batch_disconnect"): return
	if not await _wait_ack("batch_rejoined"): return
	if not await _campaign_host_probe(): return
	_write("host_exit_started", {"ready": true})
	await _finish()

func _client_probe() -> void:
	if not await _wait(func() -> bool: return _has("listen"), "host_listening"): return
	game._join("127.0.0.1", 1 if role == "client1" else 2, role)
	var expected: String = "crew_2" if role == "client1" else "crew_3"
	if not await _wait(func() -> bool: return game.session.local_profile_id == expected and game.session.roster.snapshot().size() == 3 and _profile_restored(), "client_join_and_saved_profile"): return
	if not _check(game.get_multiplayer().get_unique_id() > 1 and not game.session.is_host(), "real_remote_client", {"peer_id": game.get_multiplayer().get_unique_id(), "profile": expected}): return
	_write(role + "_ready", {"ready": true})
	if not await _wait(func() -> bool: return _has("move"), "movement_stage"): return
	first_positions = _positions()
	await _move_for_one_second()
	_write(role + "_moved", {"ready": true})
	if not await _wait(func() -> bool: return _has("settled"), "movement_settled"): return
	await create_timer(0.3).timeout
	if not await _wait_player_pose_barrier("settled"): return
	if not _check_movement() or not _check_player_poses(): return
	_write(role + "_movement_checked", {"ready": true})
	if not await _wait(func() -> bool: return _has("fish"), "fish_stage"): return
	fish_id = str(_read("fish").catch_id)
	if not await _wait(func() -> bool: return game.controller.fish_bodies.has(fish_id) and last_poses.get("fish", {}).has(fish_id), "replicated_physics_fish"): return
	await create_timer(0.3).timeout
	if not _check_fish("whole_loose"): return
	_write(role + "_fish_seen", {"ready": true})
	if not await _wait(func() -> bool: return _has("grab"), "grab_stage"): return
	if role == "client1": _send("grab_fish", {"catch_id": fish_id})
	if not await _wait(func() -> bool: return _has("held") and _cargo().get("state", "") == "whole_held", "replicated_remote_grab"): return
	if not _check_fish("whole_held"): return
	if not _check(_cargo().carrier_id == "crew_2" and _cargo().catch_record.profile_id == "crew_2", "holder_and_original_angler_agree"): return
	_write(role + "_held_seen", {"ready": true})
	if not await _wait(func() -> bool: return _has("disconnect"), "disconnect_stage"): return
	if role == "client1":
		game.session.close()
		game.controller.active = false
		if not await _wait(func() -> bool: return _has("rejoin"), "rejoin_allowed"): return
		game._join("127.0.0.1", 1, role)
		if not await _wait(func() -> bool: return game.session.status == "connected" and game.session.local_profile_id == "crew_2" and _profile_restored(), "stable_profile_restored_on_new_connection"): return
	else:
		if not await _wait(func() -> bool: return game.session.roster.snapshot().size() == 2 and _cargo().get("state", "") == "whole_loose", "observer_sees_disconnect_and_release"): return
		_write(role + "_disconnect_seen", {"ready": true})
	if not await _wait(func() -> bool: return _has("rejoined") and game.session.roster.snapshot().size() == 3, "all_three_rejoined"): return
	await create_timer(0.4).timeout
	if not await _wait_player_pose_barrier("rejoined"): return
	if not _check_fish("whole_loose") or not _check_player_poses(): return
	var saved: Dictionary = game.controller.snapshot_data.progression
	if not _check(saved.profiles.crew_2.name == "Probe Keeper" and saved.landed_catch_ids.count(fish_id) == 1 and saved.coins == 0, "rejoined_snapshot_preserves_progress"): return
	_write(role + "_rejoined_seen", {"ready": true})
	if not await _wait(func() -> bool: return _has("simultaneous_drop"), "batched_disconnect_stage"): return
	game.session.close()
	game.controller.active = false
	_write(role + "_batch_closed", {"ready": true})
	if not await _wait(func() -> bool: return _has("batch_reconnect"), "batch_reconnect_stage"): return
	game._join("127.0.0.1", 1 if role == "client1" else 2, role)
	if not await _wait(func() -> bool: return game.session.status == "connected" and game.session.local_profile_id == expected and game.session.roster.snapshot().size() == 3, "same_profile_after_batched_disconnect"): return
	_write(role + "_batch_rejoined", {"ready": true})
	if not await _campaign_client_probe(expected): return
	if not await _wait(func() -> bool: return _has("host_exit_started") and game.session.status == "offline", "actual_host_departure_reported"): return
	if not _check(not game.controller.active and game.session.local_profile_id.is_empty(), "host_departure_stops_client_run"): return
	if not _check(_profile_restored() and game.controller.snapshot_data.progression.landed_catch_ids.count(fish_id) == 1, "last_confirmed_progress_survives_host_departure"): return
	await _finish()

func _campaign_host_probe() -> bool:
	# Explicit earned-progress fixture: campaign navigation/repair earning has its
	# own checks. This probe exercises real authority, RPCs and durable departure.
	game.controller.set_physics_process(false)
	var store_script: GDScript = load("res://game/progression/save_store.gd")
	var progress_script: GDScript = load("res://game/progression/progression.gd")
	var campaign_script: GDScript = load("res://game/progression/campaign_rules.gd")
	var store: RefCounted = store_script.new(game.save_path)
	var seed: Dictionary = game.controller.progression.snapshot()
	seed.coins = 200
	seed.lifetime_banked = 200
	seed.revision = int(seed.revision) + 1
	for repair: String in campaign_script.required_repairs(): seed.repairs[repair] = true
	if not _check(store.commit(seed) == OK, "explicit_earned_campaign_fixture_saved", {"coins":200,"repairs":seed.repairs}): return false
	game.controller.progression = progress_script.new(store,seed)
	game.controller.run.elapsed_s = 300.0
	game.controller.run.phase = "night"
	game.controller.hunter.global_position = Vector3(-70,2.05,-57)
	_place("crew_1",game.world.markers.boat)
	_place("crew_2",game.world.markers.boat+Vector3(-3.5,0,0))
	_place("crew_3",game.world.markers.beacon_repair)
	game.controller._publish()
	game.controller.set_physics_process(true)
	_write("campaign_fixture",{"ready":true,"run_id":game.controller.run.run_id,"coins":200})
	if not await _wait_ack("campaign_fixture_seen"): return false
	_send("arm_escape",{})
	if not await _wait(func() -> bool: return game.controller.mission.armed,"host_rpc_arms_final_escape"): return false
	if not await _wait(func() -> bool: return game.controller.mission.signalled,"client_rpc_signals_beacon_in_range"): return false
	if not await _wait_ack("beacon_signalled"): return false
	_place("crew_3",game.world.markers.boat+Vector3(-1.8,0,0))
	var body: RigidBody3D = game.controller.fish_bodies[fish_id]
	body.global_position = game.controller.avatars.crew_2.global_position+Vector3(0,1.1,-0.7)
	body.last_dry_position = body.global_position
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	game.controller._publish()
	_write("campaign_grab",{"ready":true})
	if not await _wait(func() -> bool: return game.controller.cargo.held_by("crew_2")==fish_id and body.held,"departing_client_has_original_whole_fish"): return false
	if not await _wait(func() -> bool: return _has("client1_campaign_held"),"remote_holder_confirms_departure_cargo"): return false
	_write("campaign_ready",{"ready":true})
	_send("ready",{"ready":true})
	if not await _wait(func() -> bool: return game.controller.run.phase=="escape" and game.controller.mission.departing,"all_three_rpc_ready_start_final_crossing"): return false
	var departure_run: String = game.controller.run.run_id
	_write("campaign_crossing",{"ready":true})
	if not await _wait_ack("crossing_seen"): return false
	_write("campaign_drop",{"ready":true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==2 and not game.session.roster.snapshot().has("crew_2"),"real_disconnect_during_final_crossing"): return false
	var manifest: Dictionary = game.controller.run.players.get("crew_2",{})
	var cargo_entry: Dictionary = game.controller.cargo.snapshot().get(fish_id,{})
	if not _check(bool(manifest.get("aboard",false)) and cargo_entry.get("state","")=="whole_held" and cargo_entry.get("carrier_id","")=="crew_2","departure_manifest_and_whole_cargo_survive_disconnect"): return false
	_write("campaign_rejoin_attempt",{"ready":true})
	if not await _wait(func() -> bool: return _has("client1_sailing_rejected"),"real_rejoin_rejected_while_sailing"): return false
	if not _check(game.session.roster.snapshot().size()==2,"rejected_sailing_join_does_not_claim_a_slot"): return false
	if not await _wait(func() -> bool: return game.controller.mission.completed,"final_crossing_commits_ending"): return false
	var state: Dictionary = game.controller.progression.snapshot()
	if not _check(bool(state.campaign_flags.get("escaped",false)) and state.coins==220 and state.banked_catch_ids.count(fish_id)==1 and state.settled_run_ids.count(departure_run)==1,"final_ending_and_disconnected_whole_payout_commit_once",{"coins":state.coins,"banked_count":state.banked_catch_ids.count(fish_id)}): return false
	var reloaded: Dictionary = store.load_or_recover()
	if not _check(reloaded.ok and reloaded.state.campaign_flags.get("escaped",false) and reloaded.state.coins==220 and reloaded.state.banked_catch_ids.count(fish_id)==1,"independent_reload_confirms_ending_and_whole_reward"): return false
	_write("campaign_complete",{"ready":true})
	if not await _wait(func() -> bool: return _has("client2_ending_seen"),"connected_client_receives_durable_ending"): return false
	_send("continue_island",{})
	if not await _wait(func() -> bool: return game.controller.run.run_id!=departure_run and game.controller.run.phase=="day" and not game.controller.mission.completed,"host_rpc_continues_preserving_campaign"): return false
	_write("campaign_continue",{"ready":true})
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==3,"normal_admission_resumes_after_continue"): return false
	if not await _wait_ack("campaign_continued"): return false
	state = game.controller.progression.snapshot()
	return _check(state.coins==220 and state.campaign_flags.get("escaped",false) and state.landed_catch_ids.count(fish_id)==1,"continue_does_not_duplicate_or_clear_saved_rewards")

func _campaign_client_probe(expected: String) -> bool:
	if not await _wait(func() -> bool: return _has("campaign_fixture") and game.controller.snapshot_data.get("campaign",{}).get("can_escape",false),"earned_campaign_fixture_replicated"): return false
	var before: Dictionary = game.controller.snapshot_data
	if not _check(before.progression.coins==200 and before.run.phase=="night" and before.progression.landed_catch_ids.count(fish_id)==1,"campaign_fixture_is_explicit_and_preserves_old_progress"): return false
	_write(role+"_campaign_fixture_seen",{"ready":true})
	if not await _wait(func() -> bool: return game.controller.snapshot_data.get("escape",{}).get("armed",false),"host_escape_arm_replicated"): return false
	if role=="client2": _send("signal_escape",{})
	if not await _wait(func() -> bool: return game.controller.snapshot_data.get("escape",{}).get("signalled",false),"remote_beacon_signal_replicated"): return false
	_write(role+"_beacon_signalled",{"ready":true})
	if not await _wait(func() -> bool: return _has("campaign_grab"),"whole_cargo_boarding_stage"): return false
	if role=="client1":
		_send("grab_fish",{"catch_id":fish_id})
		if not await _wait(func() -> bool: return _cargo().get("carrier_id","")=="crew_2","original_fish_regrabbed_through_rpc"): return false
		_write(role+"_campaign_held",{"ready":true})
	if not await _wait(func() -> bool: return _has("campaign_ready"),"final_ready_stage"): return false
	_send("ready",{"ready":true})
	if not await _wait(func() -> bool: return _has("campaign_crossing") and game.controller.snapshot_data.get("run",{}).get("phase","")=="escape","final_crossing_replicated"): return false
	if not _check(game.controller.snapshot_data.escape.departing and game.controller.snapshot_data.run.players[expected].aboard,"crew_aboard_actual_final_departure"): return false
	_write(role+"_crossing_seen",{"ready":true})
	if not await _wait(func() -> bool: return _has("campaign_drop"),"sailing_disconnect_stage"): return false
	if role=="client1":
		game.session.close()
		game.controller.active = false
		if not await _wait(func() -> bool: return _has("campaign_rejoin_attempt"),"sailing_rejoin_attempt_stage"): return false
		last_status_message = ""
		game._join("127.0.0.1",1,role)
		if not await _wait(func() -> bool: return game.session.status=="rejected","server_rejects_real_sailing_rejoin"): return false
		if not _check(last_status_message.contains("Moth is sailing") and game.session.local_profile_id.is_empty(),"sailing_rejection_is_actionable_and_unassigned",{"message":last_status_message}): return false
		_write(role+"_sailing_rejected",{"ready":true})
	else:
		if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==2,"observer_sees_sailing_disconnect"): return false
		if not await _wait(func() -> bool: return _has("campaign_complete") and game.controller.snapshot_data.get("escape",{}).get("completed",false),"ending_received_after_host_durable_commit"): return false
		var ending: Dictionary = game.controller.snapshot_data
		if not _check(ending.progression.campaign_flags.get("escaped",false) and ending.progression.coins==220 and ending.progression.banked_catch_ids.count(fish_id)==1,"client_ending_contains_single_whole_reward"): return false
		_write(role+"_ending_seen",{"ready":true})
	if not await _wait(func() -> bool: return _has("campaign_continue"),"host_continue_stage"): return false
	if role=="client1": game._join("127.0.0.1",1,role)
	var prior_run: String = str(_read("campaign_fixture").run_id)
	if not await _wait(func() -> bool: return game.session.status=="connected" and game.session.local_profile_id==expected and game.session.roster.snapshot().size()==3 and game.controller.snapshot_data.get("run",{}).get("run_id",prior_run)!=prior_run,"continued_island_and_normal_rejoin_replicated"): return false
	var after: Dictionary = game.controller.snapshot_data
	if not _check(after.run.phase=="day" and after.progression.campaign_flags.get("escaped",false) and after.progression.coins==220 and after.progression.banked_catch_ids.count(fish_id)==1 and _profile_restored(),"continued_snapshot_keeps_ending_gear_profile_and_reward"): return false
	_write(role+"_campaign_continued",{"ready":true})
	return true

func _place(profile: String, at: Vector3) -> void:
	game.controller.avatars[profile].global_position = at
	game.controller.avatars[profile].last_dry = at
	game.controller.avatars[profile].velocity = Vector3.ZERO

func _move_for_one_second() -> void:
	for tick: int in range(20):
		_send("move", {"direction": Vector2(0, -1), "yaw": 0.0})
		await create_timer(0.05).timeout
	_send("move", {"direction": Vector2.ZERO, "yaw": 0.0})

func _send(action: String, payload: Dictionary) -> void:
	request_sequence += 1
	game.session.submit_intent(action, payload, "probe_" + role + "_" + str(request_sequence))

func _observe_poses(data: Dictionary) -> void:
	last_poses = data
	pose_packets += 1

func _positions() -> Dictionary:
	var result: Dictionary = {}
	for profile: String in game.controller.avatars:
		result[profile] = game.controller.avatars[profile].global_position
	return result

func _check_movement() -> bool:
	var distances: Dictionary = {}
	for profile: String in ["crew_1", "crew_2", "crew_3"]:
		if not _check(first_positions.has(profile) and game.controller.avatars.has(profile), "movement_profile_" + profile): return false
		var initial: Vector3 = first_positions[profile]
		var current: Vector3 = game.controller.avatars[profile].global_position
		distances[profile] = initial.distance_to(current)
		if not _check(float(distances[profile]) > 0.75, "movement_received_" + profile, {"metres": distances[profile]}): return false
	return true

func _check_player_poses() -> bool:
	if not _check(pose_packets > 3, "unreliable_pose_packets_received", {"count": pose_packets}): return false
	for profile: String in ["crew_1", "crew_2", "crew_3"]:
		if not _check(last_poses.get("players", {}).has(profile), "pose_present_" + profile): return false
		var authoritative: Vector3 = last_poses.players[profile].position
		var difference: float = authoritative.distance_to(game.controller.avatars[profile].global_position)
		var reliable: Dictionary = game.controller.snapshot_data.get("poses",{}).get("players",{}).get(profile,{})
		if not _check(difference < 0.3, "player_pose_agrees_" + profile, {"error_m":difference,"unreliable_sequence":game.session._last_pose_sequence,"unreliable_position":authoritative,"reliable_position":reliable.get("position",Vector3.ZERO),"avatar_position":game.controller.avatars[profile].global_position}): return false
	return true

func _wait_player_pose_barrier(stage: String) -> bool:
	# File coordination carries only a sequence barrier, never player state.
	# Rejoining recreates an avatar while the unreliable observer cache can still
	# describe its departed incarnation. Wait for fresh authority after the host
	# stage, then two more packets so the production 0.85 interpolation settles.
	# This never changes received data, avatars, or the strict 0.3m assertion.
	var barrier: int = int(_read(stage).get("pose_sequence",-1))
	var first_fresh_count: int = -1
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec() <= deadline:
		if game.session._last_pose_sequence>barrier:
			var complete: bool = true
			for profile: String in ["crew_1","crew_2","crew_3"]:
				complete = complete and last_poses.get("players",{}).has(profile)
			if complete:
				if first_fresh_count<0: first_fresh_count=pose_packets
				elif pose_packets>=first_fresh_count+2: return true
		await create_timer(0.01).timeout
	return _check(false,"timeout_fresh_player_authority_"+stage,{"barrier":barrier,"received_sequence":game.session._last_pose_sequence,"packet_count":pose_packets,"first_fresh_count":first_fresh_count})

func _cargo() -> Dictionary:
	return game.controller.snapshot_data.get("cargo", {}).get(fish_id, {})

func _check_fish(state: String) -> bool:
	if not _check(game.controller.fish_bodies.size() == 1 and game.controller.fish_bodies.has(fish_id) and _cargo().get("state", "") == state, "single_stable_fish_" + state, {"catch_id": fish_id}): return false
	var body: RigidBody3D = game.controller.fish_bodies[fish_id]
	if not _check(body.freeze and body.collision_layer == 0 and body.collision_mask == 0, "client_fish_not_simulated"): return false
	if not _check(last_poses.get("fish", {}).has(fish_id), "fish_pose_received"): return false
	# Reliable world snapshots and unreliable pose packets may overtake each
	# other. Compare with the newest received authority, as PhysicalFish does.
	var newest: Dictionary = last_poses.fish[fish_id]
	var reliable: Dictionary = game.controller.snapshot_data.get("poses",{}).get("fish",{}).get(fish_id,{})
	if int(reliable.get("sequence",-1)) > int(newest.get("sequence",-1)): newest = reliable
	var pose: Transform3D = newest.transform
	return _check(body.global_position.distance_to(pose.origin) < 0.3, "fish_pose_agrees", {"error_m": body.global_position.distance_to(pose.origin), "sequence": newest.sequence})

func _profile_restored() -> bool:
	return game.controller.snapshot_data.get("progression", {}).get("profiles", {}).get("crew_2", {}).get("name", "") == "Probe Keeper"

func _wait_ack(stage: String) -> bool:
	return await _wait(func() -> bool: return _has("client1_" + stage) and _has("client2_" + stage), "both_clients_" + stage)

func _wait(condition: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 20000
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return _check(false, "timeout_" + label, {"status": game.session.status, "roster": game.session.roster.snapshot()})
		await create_timer(0.05).timeout
	return _check(true, label)

func _check(condition: bool, label: String, evidence: Dictionary = {}) -> bool:
	checks += 1
	print(JSON.stringify({"role": role, "check": label, "ok": condition, "evidence": evidence}))
	if not condition:
		failed = true
		_write(role + "_fail", {"ready": true, "check": label, "evidence": evidence})
		quit(1)
	return condition

func _write(tag: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(output.path_join(tag + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func _read(tag: String) -> Dictionary:
	var path: String = output.path_join(tag + ".json")
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data

func _has(tag: String) -> bool:
	return bool(_read(tag).get("ready", false))

func _finish() -> void:
	var result: Dictionary = {"ready": true, "role": role, "checks": checks, "pose_packets": pose_packets, "catch_id": fish_id, "scope": "three processes on loopback; not three physical PCs"}
	game.controller.active = false
	game.session.close()
	game.queue_free()
	await process_frame
	_write(role + "_pass", result)
	print("NETWORK_PROBE_PASS " + JSON.stringify(result))
	quit(0)
