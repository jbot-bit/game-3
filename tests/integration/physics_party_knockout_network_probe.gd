extends SceneTree
## Three real ENet peers. Live sweeper replication is checked before host-side
## hazard collision masking isolates combat/scoring transport from random falls.
## Positions and F-forfeits are explicit fixtures, not a human survival match.
const Game = preload("res://prototypes/physics_party/main.gd")
const Match = preload("res://prototypes/physics_party/party_match.gd")
var app: Node3D
var role: String = "host"
var output: String = ""
var key: String = ""
var port: int = 24953
var checks: int = 0
var tick: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-role="): role = arg.trim_prefix("--probe-role=")
		if arg.begins_with("--probe-output="): output = arg.trim_prefix("--probe-output=")
		if arg.begins_with("--probe-key="): key = arg.trim_prefix("--probe-key=")
		if arg.begins_with("--probe-port="): port = int(arg.trim_prefix("--probe-port="))
	call_deferred("run_probe")

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(role + ": " + message)
	return condition

func until(predicate: Callable, seconds: float = 12.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await create_timer(0.025).timeout
	return predicate.call()

func marker(name: String, data: Dictionary = {}) -> void:
	var file := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func exists(name: String) -> bool:
	return FileAccess.file_exists(output.path_join(name + ".json"))

func read_marker(name: String) -> Dictionary:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join(name + ".json")))
	return decoded if decoded is Dictionary else {}

func barrier(name: String) -> bool:
	marker(role + "_" + name)
	return check(await until(func(): return exists("host_" + name) and exists("client1_" + name) and exists("client2_" + name)), "All peers acknowledge " + name)

func roster_size(count: int) -> bool:
	return app.session.connected and app.avatars.size() == count and app.state.get("players", {}).size() == count

func phase() -> String:
	return str(app.state.get("match", {}).get("phase", ""))

func score(id: String) -> int:
	return int(app.state.get("match", {}).get("scores", {}).get(id, 0))

func noncolliding(id: String) -> bool:
	for bone: PhysicalBone3D in app.avatars[id].physics_bones:
		if bone.collision_layer != 0 or bone.collision_mask != 0: return false
	return true

func send_controls(extra: Dictionary = {}) -> void:
	tick += 1
	var controls: Dictionary = app._neutral()
	controls.tick = tick
	controls.merge(extra, true)
	app.session.controls(controls)

func run_probe() -> void:
	app = Game.new()
	app.name = "HandsFull"
	app.scripted = true
	app.progress_path = "user://tests/hands-full-knockout-" + key + "-" + role + ".json"
	app.game_port = port
	root.add_child(app)
	if role == "host":
		app._host("Host", "crossing", "knockout")
		marker("ready")
	else:
		if not check(await until(func(): return exists("late_join" if role == "client2" else "ready")), "Host is ready for this entrant"):
			await finish()
			return
		app._join("127.0.0.1", role)
	if role != "client2":
		if not check(await until(func(): return roster_size(2) and phase() == "fight"), "Two peers start a Knockout round"):
			await finish()
			return
		marker(role + "_fighting")
		if role == "host":
			if not check(await until(func(): return exists("client1_fighting")), "Client receives fight state"):
				await finish()
				return
			marker("late_join")
	if not check(await until(func(): return roster_size(3) and app.mode_id == "knockout"), "All three peers select and construct Knockout"):
		await finish()
		return
	check(app.world.get_script().resource_path.ends_with("party_knockout_world.gd") and app.world.authoritative == (role == "host"), "Each peer builds the correct world with host-only authority")
	check(Match.valid_snapshot(app.state.match) and app.teamwork == null, "Knockout uses valid ring-out state without co-op barriers")
	check("crew_3" not in app.state.match.alive, "Late join spectates the live round")
	if role == "host": check(await until(func(): return noncolliding("crew_3")), "Every late-join body is non-colliding")
	if not await live_movers_probe() or not await barrier("live_movers"):
		await finish()
		return
	if role == "host":
		# Explicit deterministic fixture: live geometry/timeline was checked above.
		# The separate physical-contact probe tests hazard knockback and ring-outs.
		for body: AnimatableBody3D in app.world.movers.values():
			body.collision_layer = 0
			body.collision_mask = 0
	if not await shrinking_floor_probe():
		await finish()
		return
	if not await restart_match("combat") or not await combat_probe() or not await disconnect_probe():
		await finish()
		return
	if not await restart_match("scoring"):
		await finish()
		return
	for wins in range(1, 4):
		if not check(await until(func(): return phase() == "fight" and app.state.match.alive.size() == 3), "All entrants start scoring round %d" % wins):
			await finish()
			return
		if role == "client1": app.session.act("recover")
		if not check(await until(func(): return app.state.match.alive.size() == 2 and "crew_2" not in app.state.match.alive), "Remote forfeit eliminates only its own entrant"):
			await finish()
			return
		if wins == 1 and role == "host": check(await until(func(): return noncolliding("crew_2")), "Eliminated player's bodies cannot obstruct survivors")
		if not await barrier("one_out_" + str(wins)):
			await finish()
			return
		if role == "client2": app.session.act("recover")
		if not check(await until(func(): return score("crew_1") == wins), "Last standing receives round %d on every peer" % wins):
			await finish()
			return
		check(app.state.match.alive == ["crew_1"] and score("crew_2") == 0 and score("crew_3") == 0, "Round result names only its survivor")
		if not await barrier("scored_" + str(wins)):
			await finish()
			return
		if wins == 1 and not await round_reset_probe():
			await finish()
			return
	if not check(await until(func(): return app.state.phase == "complete" and phase() == "complete"), "First-to-three completes the match"):
		await finish()
		return
	check(app.state.match.winner == "crew_1", "Match winner replicates")
	if not await reward_and_replay_probe() or not await barrier("done"):
		await finish()
		return
	if role == "host": marker("shutdown")
	else: await until(func(): return exists("shutdown"))
	await finish()

func live_movers_probe() -> bool:
	if not check(app.world.movers.size() == 2, "Both sweepers exist on each peer"): return false
	var before: Dictionary = {}
	for id: String in app.world.movers: before[id] = app.world.movers[id].rotation.y
	await create_timer(0.55).timeout
	var moving: bool = true
	var authority: bool = true
	for id: String in app.world.movers:
		var body: AnimatableBody3D = app.world.movers[id]
		moving = moving and body.global_transform.is_finite() and absf(angle_difference(float(before[id]), body.rotation.y)) > 0.10
		authority = authority and ((body.collision_layer != 0) if role == "host" else (body.collision_layer == 0 and body.collision_mask == 0))
	check(moving and authority, "Live moving sweepers replicate with physical collision only on host")
	if role == "host":
		var angles: Dictionary = {}
		for id: String in app.world.movers: angles[id] = app.world.movers[id].rotation.y
		marker("live_angles", angles)
	if not check(await until(func(): return exists("live_angles")), "Host timeline sample is available"): return false
	var aligned: bool = true
	for id: String in read_marker("live_angles"):
		aligned = aligned and absf(angle_difference(float(read_marker("live_angles")[id]), app.world.movers[id].rotation.y)) < 0.55
	return check(aligned, "Sweeper presentation stays on the host timeline")

func floor_radius() -> float:
	var poses: Dictionary = app.world.capture_movers()
	var floor_pose: Variant = poses.get("ArenaFloor")
	return floor_pose.basis.x.length() * 9.0 if floor_pose is Transform3D else -1.0

func shrinking_floor_probe() -> bool:
	if not await barrier("floor_fixture_ready"): return false
	if role == "host":
		# Explicit elapsed-time fixture exercises the actual floor collider and its
		# ENet presentation without spending 45 seconds in an uncontrolled match.
		app.world._round_elapsed = 45.0
		await physics_frame
		await physics_frame
		app.world.set_physics_process(false)
		marker("floor_shrunk")
	if not check(await until(func(): return exists("floor_shrunk") and absf(floor_radius() - 7.5) < 0.04), "Host and clients receive the half-shrunk arena radius"): return false
	var floor_pose: Transform3D = app.world.capture_movers().ArenaFloor
	check(floor_pose.origin.distance_to(Vector3(0, 3.3, 0)) < 0.001 and absf(floor_pose.basis.y.length() - 1.0) < 0.001 and absf(floor_pose.basis.x.length() - floor_pose.basis.z.length()) < 0.001, "Shrinking floor preserves deck height and circular horizontal scale")
	if not await barrier("floor_shrink_seen"): return false
	if role == "host":
		app.world.reset_props()
		app.world.set_physics_process(true)
	if not check(await until(func(): return absf(floor_radius() - 9.0) < 0.001), "Reset restores the full arena radius on every peer"): return false
	return await barrier("floor_restored")

func restart_match(label: String) -> bool:
	var old_run: String = app.run_id
	if not await barrier("restart_" + label): return false
	if role == "host": app.session.act("restart")
	return check(await until(func(): return app.run_id != old_run and phase() == "fight" and app.state.match.alive.size() == 3), "Restart admits all three for " + label)

func combat_probe() -> bool:
	if role == "host":
		app.avatars.crew_1.reset_at(Vector3(-6, 7, 0))
		app.avatars.crew_2.reset_at(Vector3(6, 7, 1))
		app.avatars.crew_3.reset_at(Vector3(6, 7, -1))
		await create_timer(1.1).timeout
		check(app.avatars.crew_2.is_on_floor and app.avatars.crew_3.is_on_floor, "Combat fixture settles on the circular pad")
		marker("combat_ready")
	if not check(await until(func(): return exists("combat_ready")), "Combat fixture is ready"): return false
	var swing: bool = false
	var brace: bool = false
	var hit: bool = false
	for step in 36:
		send_controls({"attack": role == "client1", "brace": role == "client2", "yaw": PI if role == "client2" else 0.0})
		await create_timer(1.0 / 30.0).timeout
		var fighters: Dictionary = app.state.match.fighters
		swing = swing or float(fighters.get("crew_2", {}).get("swing", 0.0)) > 0.0
		brace = brace or bool(fighters.get("crew_3", {}).get("brace", false))
		if role == "host": hit = hit or "crew_3" in app.contest.combat.fighters.get("crew_2", {}).get("hit", [])
	send_controls()
	check(swing and brace, "Both remote attack and remote brace arrive and replicate")
	if role == "host": check(hit, "Remote attack makes real padded-stick contact with the braced opponent")
	check(score("crew_1") == 0 and score("crew_2") == 0 and score("crew_3") == 0, "Contact does not manufacture a round win")
	return await barrier("combat_done") and failures.is_empty()

func disconnect_probe() -> bool:
	if role == "client2":
		app._leave()
		marker("departed")
	else:
		if not check(await until(func(): return exists("departed") and roster_size(2) and phase() == "intermission"), "Departing entrant cancels the round"): return false
		check(score("crew_1") == 0 and score("crew_2") == 0 and app.state.completions == 0 and app.state.reward_cards.is_empty(), "Disconnect creates neither a free win nor a reward")
		marker(role + "_departure_seen")
	if role == "host":
		if not check(await until(func(): return exists("client1_departure_seen")), "Remaining client sees cancellation"): return false
		marker("rejoin")
	elif role == "client2":
		if not check(await until(func(): return exists("rejoin")), "Rejoin waits for cancellation"): return false
		app._join("127.0.0.1", role)
	if not check(await until(func(): return roster_size(3) and app.mode_id == "knockout"), "Rejoin reconstructs the same Knockout session"): return false
	return await barrier("rejoined")

func round_reset_probe() -> bool:
	if not check(await until(func(): return phase() == "countdown" and int(app.state.match.round) == 2), "Next round enters countdown"): return false
	# Allow the shared remote physics timeline to reach the newly published round.
	await create_timer(0.25).timeout
	var reset: bool = absf(angle_difference(app.world.movers.SweepLow.rotation.y, 0.0)) < 0.05 and absf(angle_difference(app.world.movers.SweepHigh.rotation.y, 0.0)) < 0.05
	await create_timer(0.25).timeout
	reset = reset and absf(angle_difference(app.world.movers.SweepLow.rotation.y, 0.0)) < 0.05 and absf(angle_difference(app.world.movers.SweepHigh.rotation.y, 0.0)) < 0.05
	check(reset and absf(floor_radius() - 9.0) < 0.001 and app.state.match.alive.size() == 3, "New round resets sweepers and arena size while all entrants return")
	if role == "host": check(not noncolliding("crew_2") and not noncolliding("crew_3"), "Round reset restores eliminated players' collisions")
	return await barrier("round_reset")

func reward_and_replay_probe() -> bool:
	check(app.state.completions == 1 and app.state.reward_cards.size() == 3 and app.state.reward_run_id == app.run_id, "Finished match grants one three-card bag for this run")
	if role == "host": marker("reward", {"cards": app.state.reward_cards, "collection": app.state.cosmetic_cards})
	if not check(await until(func(): return exists("reward")), "Saved reward evidence is available"): return false
	var reward: Dictionary = read_marker("reward")
	check(app.state.reward_cards == reward.cards and app.state.cosmetic_cards == reward.collection, "Every peer receives identical ordered cards and ownership")
	if role == "host":
		var saved = app.Rules.new()
		check(saved.load_progress(app.progress_path).ok and saved.progress.completions == 1 and saved.last_reward().cards == reward.cards, "A fresh save load retains the single awarded bag")
		check(app.rules.complete(app.run_id).completions == 1, "Duplicate completion cannot grant another bag")
	if not await restart_match("rematch"): return false
	check(score("crew_1") == 0 and score("crew_2") == 0 and score("crew_3") == 0 and app.state.completions == 1 and app.state.reward_cards.is_empty() and app.state.cosmetic_cards == reward.collection, "Rematch resets scores and preserves ownership without a second bag")
	return failures.is_empty()

func finish() -> void:
	var result: Dictionary = {"role": role, "checks": checks, "failures": failures, "build": app.session.BUILD,
		"limit": "Real three-process loopback Knockout: live sweepers/timeline before collision masking, shrinking-floor replication/reset, remote attack/brace and real stick contact, late-join and eliminated collision exclusion, disconnect/rejoin, round reset, last-standing scoring, saved bag and rematch. Combat positions, F eliminations and 45-second floor elapsed time are fixtures; sweeper collisions are masked after the live replication check to isolate scoring. Not a human match, three-PC Wi-Fi test or Internet readiness proof."}
	marker(role + ("_pass" if failures.is_empty() else "_fail"), result)
	app._leave()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
