extends SceneTree
## Real ENet processes; positioning fixtures isolate transport and mode rules
## from the separate continuous physics playtests. No simulated hit RPC exists.
const Game = preload("res://prototypes/physics_party/main.gd")
const Match = preload("res://prototypes/physics_party/party_match.gd")
var app: Node3D
var role: String = "host"
var output: String = ""
var key: String = ""
var port: int = 24943
var checks: int = 0
var tick: int = 0
var failures: Array[String] = []
var local: String = ""
var previous_pose: Dictionary = {}

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

func send_controls(extra: Dictionary = {}) -> void:
	tick += 1
	var data: Dictionary = app._neutral()
	data.tick = tick
	data.merge(extra, true)
	app.session.controls(data)

func roster_size(count: int) -> bool:
	return app.session.connected and app.avatars.size() == count and app.state.get("players", {}).size() == count

func match_phase() -> String:
	return str(app.state.get("match", {}).get("phase", ""))

func score(id: String) -> int:
	return int(app.state.get("match", {}).get("scores", {}).get(id, 0))

func run_probe() -> void:
	app = Game.new()
	app.name = "HandsFull"
	app.scripted = true
	app.progress_path = "user://tests/hands-full-modes-" + key + ".json"
	app.game_port = port
	root.add_child(app)
	if role == "host":
		app._host("Host", "crossing", "gladiator")
		marker("ready")
	elif role == "client1":
		if not check(await until(func(): return exists("ready")), "Host starts"):
			await finish()
			return
		app._join("127.0.0.1", role)
	else:
		if not check(await until(func(): return exists("late_join")), "Live round permits late join"):
			await finish()
			return
		app._join("127.0.0.1", role)
	if role != "client2":
		if not check(await until(func(): return roster_size(2) and match_phase() == "fight"), "Two players start a real round"):
			await finish()
			return
		marker(role + "_two_fighting")
		if role == "host":
			check(await until(func(): return exists("client1_two_fighting")), "Client sees the first round")
			marker("late_join")
	if not check(await until(func(): return roster_size(3) and app.mode_id == "gladiator"), "Three processes build Gladiator"):
		await finish()
		return
	local = app.session.local_id
	check(app.state.course_id == "crossing", "Legacy course ID remains valid for a match")
	check(app.world.get_script().resource_path.ends_with("party_arena_world.gd"), "Gladiator world is constructed on every peer")
	check(app.world.authoritative == (role == "host"), "Only host owns arena physics")
	check(app.teamwork == null, "Co-op barriers are absent from Gladiator")
	check(Match.valid_snapshot(app.state.match), "Network match snapshot obeys its schema")
	check(local in ["crew_1", "crew_2", "crew_3"], "Stable profile slot assigned")
	check("crew_3" not in app.state.match.alive, "Late entrant waits until the next round")
	if role == "host":
		await physics_frame
		for bone: PhysicalBone3D in app.avatars.crew_3.physics_bones:
			check(bone.collision_layer == 0 and bone.collision_mask == 0, "Pending player cannot obstruct live fighters")
	# Capture the old ID before publishing readiness. The host may restart as
	# soon as the barrier opens, before another peer resumes its await.
	var old_run: String = app.run_id
	if not await barrier("late_joined"):
		await finish()
		return
	if role == "host": app.session.act("restart")
	if not check(await until(func(): return app.run_id != old_run and match_phase() == "fight" and app.state.match.alive.size() == 3), "Restart admits all three into the fight"):
		await finish()
		return
	check(await combat_transport_probe(), "Attack and brace transport phase finishes")
	if not failures.is_empty():
		await finish()
		return
	await restricted_controls_probe("gladiator")
	if not await barrier("combat_checked"):
		await finish()
		return
	await disconnect_probe()
	if not failures.is_empty():
		await finish()
		return
	old_run = app.run_id
	if not await barrier("scoring_restart_ready"):
		await finish()
		return
	if role == "host": app.session.act("restart")
	if not check(await until(func(): return app.run_id != old_run and match_phase() == "fight" and app.state.match.alive.size() == 3), "Fresh three-player match after rejoin"):
		await finish()
		return
	for wins in range(1, 4):
		if not check(await until(func(): return match_phase() == "fight" and app.state.match.alive.size() == 3), "All players enter scoring round %d" % wins):
			await finish()
			return
		if role != "host": app.session.act("recover")
		if not check(await until(func(): return score("crew_1") == wins), "Forfeits award host exactly round %d" % wins):
			await finish()
			return
		check(score("crew_2") == 0 and score("crew_3") == 0, "Other scores remain zero")
		check(app.state.match.alive == ["crew_1"], "Elimination state replicates")
		if not await barrier("round_" + str(wins)):
			await finish()
			return
	if not check(await until(func(): return app.state.phase == "complete"), "First to three ends the match"):
		await finish()
		return
	check(app.state.match.winner == "crew_1", "Named match winner replicates")
	await reward_probe(1)
	if role != "host" and not app.presentation._snapshots.is_empty(): previous_pose = app.presentation._snapshots.back().duplicate(true)
	old_run = app.run_id
	if not await barrier("match_complete"):
		await finish()
		return
	if role == "host":
		check(int(app.rules.complete(app.run_id).completions) == 1, "Duplicate match clear grants no second bag")
		app.session.act("restart")
	if not check(await until(func(): return app.run_id != old_run and app.state.phase == "play"), "Match replay gets a fresh run ID"):
		await finish()
		return
	check(score("crew_1") == 0 and score("crew_2") == 0 and score("crew_3") == 0, "Replay clears every score")
	check(app.state.reward_cards.is_empty() and app.state.completions == 1, "Replay preserves collection without a new bag")
	if role != "host":
		check(not previous_pose.is_empty(), "Previous run pose was received")
		await until(func(): return app.presentation._run_id == app.run_id)
		app._poses_received(previous_pose)
		check(app.presentation._run_id == app.run_id, "Old run pose cannot overwrite replay presentation")
	if not await barrier("replayed"):
		await finish()
		return
	if role == "host":
		# Explicit host-side fixture changes mode with the same ENet roster.
		# Production mode selection starts a new lobby, not a live menu swap.
		app._make_world(true, "crossing", "wipeout")
		app._new_run_state()
		app._roster_changed(app.session.players)
		for id: String in app.avatars: app.avatars[id].reset_at(app.world.spawn_point(int(app.session.players[id].slot), 0))
		app._publish()
	if not check(await until(func(): return app.mode_id == "wipeout" and app.state.get("challenge", {}).get("phase", "") == "running"), "Same course ID with new mode rebuilds every client world"):
		await finish()
		return
	await wipeout_probe()
	if not failures.is_empty():
		await finish()
		return
	if not await barrier("done"):
		await finish()
		return
	if role == "host": marker("shutdown")
	else: await until(func(): return exists("shutdown"))
	await finish()

func combat_transport_probe() -> bool:
	if role == "host":
		app.avatars.crew_1.reset_at(Vector3(0, 7, -1))
		app.avatars.crew_2.reset_at(Vector3(0, 7, 1))
		app.avatars.crew_3.reset_at(Vector3(4, 7, 3))
		await create_timer(1.1).timeout
		check(app.avatars.crew_1.is_on_floor and app.avatars.crew_2.is_on_floor, "Real fighters stand on arena before contact test")
		marker("combat_positions")
	if not check(await until(func(): return exists("combat_positions")), "Contact fixture is settled"): return false
	var saw_swing: bool = false
	var saw_brace: bool = false
	var saw_hit: bool = false
	for step in 40:
		send_controls({"attack": role == "client1", "brace": role == "host", "yaw": PI if role == "host" else 0.0})
		await create_timer(1.0 / 30.0).timeout
		var fighters: Dictionary = app.state.get("match", {}).get("fighters", {})
		saw_swing = saw_swing or float(fighters.get("crew_2", {}).get("swing", 0.0)) > 0.0
		saw_brace = saw_brace or bool(fighters.get("crew_1", {}).get("brace", false))
		if role == "host": saw_hit = saw_hit or "crew_1" in app.contest.combat.fighters.get("crew_2", {}).get("hit", [])
	send_controls()
	check(saw_swing, "Remote LMB attack produces replicated stick swing")
	check(saw_brace, "Host RMB brace is replicated")
	if role == "host": check(saw_hit, "Real remote attack contacts the host's physical puppet")
	check(score("crew_1") == 0 and score("crew_2") == 0 and score("crew_3") == 0, "A stick hit alone does not manufacture a round win")
	return await barrier("combat_transport")

func restricted_controls_probe(mode: String) -> void:
	app.session.act("power", "spring")
	for step in 14:
		send_controls({"grapple": true, "aim": Vector3(0, 5, 0), "left": true, "right": true, "interact": true})
		await create_timer(1.0 / 30.0).timeout
	check(str(app.state.players[local].power).is_empty(), mode + " rejects power selection RPC")
	for id: String in app.avatars:
		check(not app.avatars[id].grapple.active, mode + " prevents grapple activation")
		if role == "host":
			for field: String in ["grapple", "left", "right", "interact"]:
				check(not bool(app.avatars[id]._controls.get(field, false)), mode + " host filters " + field)
	send_controls()

func disconnect_probe() -> void:
	if role == "client2":
		app._leave()
		marker("departed")
	else:
		check(await until(func(): return exists("departed") and roster_size(2) and match_phase() == "intermission"), "Leaving invalidates the round")
		check(score("crew_1") == 0 and score("crew_2") == 0, "Disconnect gives nobody a free win")
		check(app.state.completions == 0 and app.state.reward_cards.is_empty(), "Disconnect awards no bag")
		marker(role + "_saw_departure")
	if role == "host":
		check(await until(func(): return exists("client1_saw_departure")), "Remaining client sees canceled round")
		marker("rejoin_allowed")
	elif role == "client2":
		check(await until(func(): return exists("rejoin_allowed")), "Disconnect cleanup finishes")
		app._join("127.0.0.1", role)
	check(await until(func(): return roster_size(3) and app.mode_id == "gladiator"), "Rejoin reconstructs Gladiator")
	local = app.session.local_id
	await barrier("rejoined")

func reward_probe(expected: int) -> void:
	check(int(app.state.completions) == expected, "Completed mode saves exactly one new clear")
	check(app.state.reward_cards.size() == 3, "Earned bag contains three cards")
	check(app.state.reward_run_id == app.run_id, "Bag belongs to this completed run")
	if role == "host": marker("reward_" + str(expected), {"cards": app.state.reward_cards, "collection": app.state.cosmetic_cards})
	check(await until(func(): return exists("reward_" + str(expected))), "Host bag evidence is available")
	var expected_bag: Dictionary = read_marker("reward_" + str(expected))
	check(app.state.reward_cards == expected_bag.cards, "All peers receive the same ordered RNG cards")
	check(app.state.cosmetic_cards == expected_bag.collection, "All peers receive the same saved cosmetic collection")
	for id: String in app.state.reward_cards: check(id in app.state.cosmetic_cards, "Reward becomes owned: " + id)
	if role == "host":
		var saved = app.Rules.new()
		check(saved.load_progress(app.progress_path).ok and int(saved.progress.completions) == expected, "Mode result survives fresh save load")
		check(saved.last_reward().cards == app.state.reward_cards, "Saved bag cards match the network reward")

func wipeout_probe() -> void:
	check(app.world.get_script().resource_path.ends_with("party_wipeout_world.gd"), "Wipeout physical course built on every peer")
	check(app.world.props.size() == 2 and app.world.movers.size() == 2, "Two real tipping boards and two sweepers")
	check(app.teamwork == null and app.contest == null, "Race excludes co-op and fighting rules")
	for prop: RigidBody3D in app.world.props.values(): check(prop.freeze == (role != "host"), "Only host simulates tipping boards")
	var rotations: Dictionary = {}
	for id: String in app.world.movers: rotations[id] = app.world.movers[id].rotation.y
	await create_timer(0.55).timeout
	for id: String in app.world.movers:
		var body: AnimatableBody3D = app.world.movers[id]
		check(body.global_transform.is_finite(), "Finite replicated mover: " + id)
		check(absf(angle_difference(float(rotations[id]), body.rotation.y)) > 0.12, "Replicated sweeper is rotating: " + id)
		if role != "host": check(body.collision_layer == 0 and body.collision_mask == 0, "Remote mover is render only")
	if role == "host":
		var angles: Dictionary = {}
		for id: String in app.world.movers: angles[id] = app.world.movers[id].rotation.y
		marker("mover_angles", angles)
	check(await until(func(): return exists("mover_angles")), "Host sweeper angles sampled")
	var angles: Dictionary = read_marker("mover_angles")
	for id: String in angles: check(absf(angle_difference(float(angles[id]), app.world.movers[id].rotation.y)) < 0.45, "Mover stays on shared host timeline: " + id)
	await restricted_controls_probe("wipeout")
	if not await barrier("wipeout_geometry"): return
	if role == "host":
		for id: String in app.avatars: app.avatars[id].reset_at(app.world.goal_spawn(int(app.session.players[id].slot)))
		check(await until(func():
			for actor in app.avatars.values():
				if not actor.is_on_floor or not app.world.goal_contains(actor.body_position()): return false
			return true), "Bypass fixture actually stands on finish pad")
		marker("direct_finish")
	check(await until(func(): return exists("direct_finish")), "Direct-finish fixture is grounded")
	check(app.state.phase == "play" and int(app.state.completions) == 1, "Jumping straight to finish grants no clear")
	for runner: Dictionary in app.state.challenge.runners.values(): check(not runner.finished and int(runner.checkpoint) == 0, "Finish needs sequential checkpoints")
	if not await barrier("bypass_rejected"): return
	for index in range(1, 4):
		if role == "host":
			for id: String in app.avatars: app.avatars[id].reset_at(app.world.spawn_point(int(app.session.players[id].slot), index))
		check(await until(func():
			for runner: Dictionary in app.state.get("challenge", {}).get("runners", {}).values():
				if int(runner.checkpoint) != index: return false
			return app.state.get("challenge", {}).get("runners", {}).size() == 3), "Grounded checkpoint %d is replicated" % index)
		if not await barrier("checkpoint_" + str(index)): return
	if role == "client1": app.session.act("recover")
	check(await until(func(): return int(app.state.challenge.runners.get("crew_2", {}).get("falls", 0)) == 1), "Real client recover increments fall count")
	check(int(app.state.challenge.runners.crew_2.checkpoint) == 3, "Recover retains reached checkpoint")
	if not await barrier("fall_counted"): return
	if role == "host":
		for id: String in app.avatars: app.avatars[id].reset_at(app.world.goal_spawn(int(app.session.players[id].slot)))
	check(await until(func(): return app.state.phase == "complete" and app.state.challenge.phase == "complete"), "Sequential course completion reaches all peers")
	for runner: Dictionary in app.state.challenge.results.values(): check(runner.finished and float(runner.time) > 0.0, "Authoritative finish times are populated")
	check(not str(app.state.challenge.winner).is_empty(), "Race records its first finisher")
	await reward_probe(2)
	var old_run: String = app.run_id
	if not await barrier("race_complete"): return
	if role == "host": app.session.act("restart")
	check(await until(func(): return app.run_id != old_run and app.state.phase == "play"), "Race replay resets run ID")
	check(app.mode_id == "wipeout" and app.state.completions == 2 and app.state.reward_cards.is_empty(), "Replay retains mode and collection without duplicating reward")
	for runner: Dictionary in app.state.challenge.runners.values(): check(not runner.finished and int(runner.checkpoint) == 0 and int(runner.falls) == 0, "Race replay resets progress and falls")

func finish() -> void:
	var result: Dictionary = {"role": role, "checks": checks, "failures": failures, "build": app.session.BUILD,
		"limit": "Real three-process loopback Gladiator/Wipeout, actual attack/brace controls and physics contact, late join/disconnect, replicated round wins, exact-once bags, replay, stale poses, sweeper motion and checkpoint transport. Fighter/course positions are explicit fixtures; this does not claim continuous human traversal or Internet latency."}
	marker(role + ("_pass" if failures.is_empty() else "_fail"), result)
	app._leave()
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
