extends SceneTree

const Game = preload("res://prototypes/physics_party/main.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
var app: Node3D
var role = "host"
var output = ""
var key = ""
var port = 24573
var checks = 0
var tick = 0
var failures: Array[String] = []
var first_motion_msec = -1
var earned_style: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-role="): role = arg.trim_prefix("--probe-role=")
		if arg.begins_with("--probe-output="): output = arg.trim_prefix("--probe-output=")
		if arg.begins_with("--probe-key="): key = arg.trim_prefix("--probe-key=")
		if arg.begins_with("--probe-port="): port = int(arg.trim_prefix("--probe-port="))
	call_deferred("run_probe")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func until(predicate: Callable, seconds: float = 12.0) -> bool:
	var end = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if predicate.call(): return true
		await create_timer(0.05).timeout
	return predicate.call()

func marker(name: String, data: Dictionary = {}) -> void:
	var file = FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func exists(name: String) -> bool:
	return FileAccess.file_exists(output.path_join(name + ".json"))

func read_marker(name: String) -> Dictionary:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join(name + ".json")))
	return decoded if decoded is Dictionary else {}

func seed_first_bag() -> void:
	# Seed only this isolated test profile so the first real bag exercises both
	# equip paths. Production still rolls and atomically awards the actual cards.
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 300):
		rng.seed = seed_value
		var color: bool = false
		var accessory: bool = false
		for card_id: String in Cosmetics.draw_bag([], rng):
			color = color or Cosmetics.card_info(card_id).kind == "color"
			accessory = accessory or Cosmetics.card_info(card_id).kind == "accessory"
		if color and accessory:
			app.rules.reward_rng.seed = seed_value
			return
	check(false, "Could seed both earned cosmetic types")

func run_probe() -> void:
	app = Game.new()
	app.name = "HandsFull"
	app.scripted = true
	app.progress_path = "user://tests/hands-full-" + key + ".json"
	app.game_port = port
	root.add_child(app)
	if role == "host":
		app._host("Host")
		seed_first_bag()
		marker("ready")
	else:
		check(await until(func(): return exists("ready")), "Host starts")
		app._join("127.0.0.1", role)
	check(await until(func(): return app.session.connected and app.avatars.size() == 3 and app.state.get("players", {}).size() == 3), "Three peers admitted with all puppets")
	if app.avatars.size() != 3:
		finish()
		return
	var local: String = app.session.local_id
	check(app.state.get("course_id", "") == "crossing", "All peers start First Crossing")
	check(local in ["crew_1", "crew_2", "crew_3"], "Assigned known stable slot")
	check(app.state.offers[local].size() == 3, "Three offered power choices arrive")
	app.session.act("appearance", "mint|crown")
	check(await until(func(): return not app.state.get("appearance_error", "").is_empty()), "Unowned appearance RPC rejected")
	check(app.state.get("cosmetic_cards", []).is_empty(), "No cosmetics granted before a clear")
	check(app.state.players[local].appearance == Cosmetics.default_style(int(app.session.players[local].slot)), "Rejected appearance keeps the player's plain default")
	marker(role + "_appearance_rejected")
	check(await until(func(): return exists("host_appearance_rejected") and exists("client1_appearance_rejected") and exists("client2_appearance_rejected")), "All peers exercised ownership rejection")
	app.session.act("power", app.state.offers[local][0])
	check(await until(func():
		for id in app.state.players:
			if str(app.state.players[id].power).is_empty(): return false
		return true), "All remote power selections accepted")
	await create_timer(1.0).timeout
	var actor = app.avatars[local]
	var before: Vector3 = actor.body_position()
	var movement_sent_msec = Time.get_ticks_msec()
	for step in range(45):
		tick += 1
		app.session.controls({"move": Vector2(0, -1), "yaw": 0.0, "pitch": 0.0, "jump": step > 12 and step < 17, "left": false, "right": false, "limp": false, "tick": tick})
		await create_timer(1.0 / 30.0).timeout
		if first_motion_msec < 0 and before.z - actor.body_position().z > 0.1:
			first_motion_msec = Time.get_ticks_msec() - movement_sent_msec
	await create_timer(0.5).timeout
	var after: Vector3 = actor.body_position()
	check(after.is_finite(), "Moved physical torso remains finite")
	check(Vector2(after.x - before.x, after.z - before.z).length() > 0.8, "Network inputs move physical puppet")
	check(first_motion_msec >= 0 and first_motion_msec < 500, "Visible input-to-motion under 500ms in this local probe")
	for id in app.avatars:
		var pose: Array = app.avatars[id].capture_pose()
		check(pose.size() == 10, "Ten physical body transforms: " + id)
		for transform: Transform3D in pose: check(transform.is_finite(), "Finite body transform: " + id)
	check(app.world.props.size() == 8 and app.world.props.has("team_cargo"), "Seven course props plus cooperative cargo replicated")
	marker(role + "_moved", {"before": str(before), "after": str(after)})
	check(await until(func(): return exists("host_moved") and exists("client1_moved") and exists("client2_moved")), "All three finished input sequence")
	await grapple_probe(local)
	if role == "host":
		# Deterministic fixture for proximity-authorized unilateral choice.
		app.avatars.crew_1.reset_at(app.world.switch_position + Vector3.UP * 2)
		await physics_frame
		app.session.act("switch")
		check(app.state.wind == -1, "Nearby player reverses crew wind")
		marker("switched")
	check(await until(func(): return app.state.get("wind", 0) == -1), "Unilateral switch reaches every peer")
	marker(role + "_wind")
	await teamwork_control_probe(local)
	if role == "host":
		check(await until(func(): return exists("client1_wind") and exists("client2_wind")), "Clients acknowledge wind state")
		# Isolate course-completion/save synchronization from traversal feel.
		fixture_course_finish()
	check(await until(func(): return app.state.get("phase", "") == "complete"), "Complete course state replicated")
	check(int(app.state.get("completions", 0)) == 1, "Completion committed exactly once")
	await reward_probe(1)
	var collection: Array = app.state.get("unlocked_power_ids", [])
	check(not collection.is_empty(), "Successful clear unlocks permanent power choices")
	for player in app.state.players.values():
		check(str(player.power) in collection, "Each crew member's used power is collected")
	await earned_appearance_probe(local)
	marker(role + "_complete")
	if role == "host":
		check(await until(func(): return exists("client1_complete") and exists("client2_complete")), "Both clients see completion")
		var saved: Dictionary = app.rules.complete(app.run_id)
		check(saved.ok and int(saved.completions) == 1, "Duplicate completion does not award twice")
		var reloaded = app.Rules.new()
		check(reloaded.load_progress(app.progress_path).ok and reloaded.progress.unlocked_power_ids == collection, "Collected powers survive a fresh save load")
		app.session.act("next_course")
		# Make the previously earned choice absent from the new random offers.
		# This isolates the permanent-choice route from luck of the next draw.
		for id in app.state.offers:
			var fresh: Array = []
			for power_id in ["spring", "heavy", "swift", "feather", "grip"]:
				if power_id != collection[0] and fresh.size() < 3: fresh.append(power_id)
			app.state.offers[id] = fresh
		app._publish()
	check(await until(func(): return app.state.get("phase", "") == "play" and app.state.get("completions", 0) == 1 and app.state.get("course_id", "") == "counterweight"), "Next course reaches every peer and retains progression")
	check(app.world.spawn_point(1, 2).x > 10.0, "Every peer actually builds Counterweight geometry")
	check(app.world.authoritative == (role == "host"), "Only the host simulates the second course")
	check(app.world.props.size() == 8 and app.world.props.has("team_cargo"), "Second course keeps its seven props plus cargo")
	await appearance_persisted_probe("next course")
	check(await until(func(): return collection[0] not in app.state.offers.get(local, [])), "Collected choice is outside this run's random offers")
	app.session.act("power", str(collection[0]))
	check(await until(func():
		for player in app.state.players.values():
			if str(player.power) != str(collection[0]): return false
		return true), "Every peer can equip a saved power outside the random draw")
	marker(role + "_rematch")
	check(await until(func(): return exists("host_rematch") and exists("client1_rematch") and exists("client2_rematch")), "All players finished saved-power selection")
	if role == "client2":
		app._leave()
		marker("left")
	else:
		check(await until(func(): return exists("left") and app.avatars.size() == 2), "Disconnect removes puppet and releases constraints")
		marker(role + "_disconnect")
	if role == "host":
		check(await until(func(): return exists("client1_disconnect")), "Remaining client sees disconnect")
		marker("can_rejoin")
	if role == "client2":
		check(await until(func(): return exists("can_rejoin")), "Host permits second-course rejoin after cleanup")
		app._join("127.0.0.1", role)
	check(await until(func(): return app.session.connected and app.avatars.size() == 3 and app.state.get("players", {}).size() == 3 and app.state.get("course_id", "") == "counterweight"), "Late rejoin reconstructs the active second course")
	local = app.session.local_id
	check(app.world.spawn_point(1, 2).x > 10.0, "Late state never leaves the client on First Crossing")
	await appearance_persisted_probe("rejoin")
	if role == "client2": app.session.act("power", str(collection[0]))
	check(await until(func():
		for player in app.state.players.values():
			if str(player.power) != str(collection[0]): return false
		return true), "Rejoined player can equip the shared saved power")
	var second_run: String = app.run_id
	marker(role + "_rejoined")
	if role == "host":
		check(await until(func(): return exists("client1_rejoined") and exists("client2_rejoined")), "Clients acknowledge reconstructed second course")
		app.session.act("restart")
	check(await until(func(): return app.run_id != second_run and app.state.get("course_id", "") == "counterweight"), "Mid-course restart repeats Counterweight with a fresh run")
	check(app.state.get("completions", 0) == 1, "Restart awards nothing and preserves existing clear")
	check(app.state.get("reward_cards", []).is_empty(), "Restart cannot replay the previous bag reveal")
	await appearance_persisted_probe("restart")
	app.session.act("power", str(collection[0]))
	check(await until(func():
		for player in app.state.players.values():
			if str(player.power) != str(collection[0]): return false
		return true), "Saved power choices still work after second-course restart")
	marker(role + "_second_ready")
	if role == "host":
		check(await until(func(): return exists("client1_second_ready") and exists("client2_second_ready")), "All peers ready for second-course completion fixture")
		fixture_course_finish()
	check(await until(func(): return app.state.get("phase", "") == "complete" and app.state.get("completions", 0) == 2), "Second course completes and saves exactly one additional clear")
	await reward_probe(2)
	for saved_power in collection: check(saved_power in app.state.unlocked_power_ids, "First course collection survives second clear")
	marker(role + "_second_complete")
	if role == "host":
		check(await until(func(): return exists("client1_second_complete") and exists("client2_second_complete")), "Both clients see second course saved")
		var reloaded = app.Rules.new()
		check(reloaded.load_progress(app.progress_path).ok and reloaded.progress.completions == 2, "Both course clears survive fresh save load")
		check(app.rules.complete(app.run_id).completions == 2, "Second clear is exact-once too")
		app.session.act("next_course")
	await level_pack_probe(local)
	check(await until(func(): return app.state.get("course_id", "") == "crossing" and app.state.get("phase", "") == "play"), "After twenty courses the whole crew returns to First Crossing")
	check(absf(app.world.spawn_point(1, 2).x) < 1.0, "Round trip restores original geometry")
	check(app.state.get("completions", 0) == 20, "Round trip keeps all twenty saved clears")
	marker(role + "_roundtrip")
	if role == "host":
		check(await until(func(): return exists("client1_roundtrip") and exists("client2_roundtrip")), "Both clients finish round trip")
		marker("shutdown")
	else: await until(func(): return exists("shutdown"))
	finish()

func level_pack_probe(local: String) -> void:
	for index in range(2, Courses.IDS.size()):
		var id: String = Courses.IDS[index]
		check(await until(func(): return app.state.get("course_id", "") == id and app.state.get("phase", "") == "play"), id + " reaches every peer")
		check(app.state.get("course_number", 0) == index + 1 and app.state.get("course_count", 0) == 20, id + " has the correct level number")
		check(app.world.authoritative == (role == "host"), id + " host owns simulation")
		check(app.world.props.size() >= 5 and app.world.props.size() <= 10 and app.world.props.has("team_cargo"), id + " has bounded course props plus cargo")
		await appearance_persisted_probe(id)
		if role != "host":
			for body in app.world.props.values(): check(body.freeze, id + " client prop is a replica")
		for slot in 3:
			check(app.world.checkpoint_contains(app.world.spawn_point(slot, 1)), id + " checkpoint fits slot " + str(slot))
			check(app.world.goal_contains(app.world.spawn_point(slot, 2)), id + " finish fits slot " + str(slot))
		app.session.act("power", str(app.state.offers[local][0]))
		check(await until(func():
			for player in app.state.players.values():
				if str(player.power).is_empty(): return false
			return true), id + " all powers selected")
		# Wait for actual pose transport after each world rebuild, independent of
		# the completion fixtures below. Clients must receive this run's stream.
		if role != "host":
			check(await until(func(): return not app.presentation.sample(float(Time.get_ticks_msec())).is_empty()), id + " receives fresh poses")
		for actor in app.avatars.values(): check(actor.body_position().is_finite(), id + " finite crew pose")
		marker(role + "_ready_" + id)
		if role == "host":
			check(await until(func(): return exists("client1_ready_" + id) and exists("client2_ready_" + id)), id + " clients ready")
			for actor_id in app.avatars: app.avatars[actor_id].reset_at(app.world.spawn_point(int(app.session.players[actor_id].slot), 1))
		check(await until(func():
			for player in app.state.players.values():
				if int(player.checkpoint) != 1: return false
			return true), id + " shared checkpoint replicates")
		marker(role + "_checkpoint_" + id)
		if role == "host":
			check(await until(func(): return exists("client1_checkpoint_" + id) and exists("client2_checkpoint_" + id)), id + " clients see checkpoint")
			fixture_course_finish()
		check(await until(func(): return app.state.get("phase", "") == "complete" and app.state.get("completions", 0) == index + 1), id + " saves one clear")
		await reward_probe(index + 1)
		marker(role + "_complete_" + id)
		if role == "host":
			check(await until(func(): return exists("client1_complete_" + id) and exists("client2_complete_" + id)), id + " clients see completion")
			app.session.act("next_course")
	if role == "host":
		var reloaded = app.Rules.new()
		check(reloaded.load_progress(app.progress_path).ok and reloaded.progress.completions == 20, "All twenty clears survive a fresh save load")

func fixture_course_finish() -> void:
	# Completion transport/save test only. The independent teamwork probe proves
	# physical operators, crossing, latch, cargo and recovery on these stages.
	for index in app.teamwork.stages.size():
		app.teamwork.stages[index].latched = true
		app.teamwork.stages[index].amount = 1.0
		app.teamwork._apply_geometry(index)
	for id in app.avatars:
		app.avatars[id].reset_at(app._goal_spawn(int(app.session.players[id].slot)))

func reward_probe(clear_count: int) -> void:
	check(app.state.get("reward_cards", []).size() == 3, "Clear %d reveals exactly three cards" % clear_count)
	check(app.state.get("reward_run_id", "") == app.run_id, "Clear %d reward is bound to its run" % clear_count)
	var cards: Array = app.state.get("reward_cards", [])
	var owned: Array = app.state.get("cosmetic_cards", [])
	for card_id: String in cards:
		check(not Cosmetics.card_info(card_id).is_empty() and card_id in owned, "Earned card is valid and permanently owned: " + card_id)
	var identity: String = "reward_" + str(clear_count)
	if role == "host":
		marker(identity, {"cards": cards, "owned": owned, "run_id": app.run_id})
		var before_rng: int = app.rules.reward_rng.state
		var before_hash: String = FileAccess.get_sha256(app.progress_path)
		check(app.rules.complete(app.run_id).completions == clear_count, "Clear %d duplicate remains exact-once" % clear_count)
		check(app.rules.reward_rng.state == before_rng, "Clear %d duplicate draws no new RNG cards" % clear_count)
		check(FileAccess.get_sha256(app.progress_path) == before_hash, "Clear %d duplicate leaves committed save unchanged" % clear_count)
	check(await until(func(): return exists(identity)), "Host reward fixture available for clear %d" % clear_count)
	var confirmed: Dictionary = read_marker(identity)
	check(cards == confirmed.get("cards", []) and owned == confirmed.get("owned", []) and app.run_id == confirmed.get("run_id", ""), "All peers see identical ordered cards and collection for clear %d" % clear_count)

func earned_appearance_probe(local: String) -> void:
	earned_style = Cosmetics.default_style(int(app.session.players[local].slot))
	for card_id: String in app.state.reward_cards:
		var card: Dictionary = Cosmetics.card_info(card_id)
		earned_style[card.kind] = card.value
	check(earned_style.accessory != "none" and earned_style.color not in Cosmetics.BASE_COLORS, "Seeded real first bag provides earned paint and gear")
	app.session.act("appearance", str(earned_style.color) + "|" + str(earned_style.accessory))
	check(await until(func(): return app.state.players.get(local, {}).get("appearance", {}) == earned_style), "Earned appearance RPC accepted for local player")
	marker(role + "_equipped")
	check(await until(func(): return exists("host_equipped") and exists("client1_equipped") and exists("client2_equipped")), "All three peers equip earned cosmetics")
	await appearance_persisted_probe("first earned equip")
	if role == "host":
		var restored = app.Rules.new()
		check(restored.load_progress(app.progress_path).ok, "Customized save reloads")
		for slot in 3:
			check(restored.appearance_for(slot) == earned_style, "Earned appearance persisted for slot " + str(slot))

func appearance_persisted_probe(context: String) -> void:
	check(await until(func():
		if app.avatars.size() != 3: return false
		for id in app.avatars:
			if app.state.get("players", {}).get(id, {}).get("appearance", {}) != earned_style: return false
			if app.avatars[id]._appearance != earned_style: return false
		return true), context + " keeps all three host/remote puppet appearances")
	for id in app.avatars:
		check(is_instance_valid(app.avatars[id]._accessory), context + " renders earned head accessory for " + id)

func teamwork_control_probe(local: String) -> void:
	if role == "host":
		var stage: Dictionary = app.teamwork.stages[0]
		for id in app.avatars:
			var slot: int = int(app.session.players[id].slot)
			var at: Vector3 = stage.pads[slot] if slot < 2 else stage.near
			app.avatars[id].reset_at(at + Vector3.UP * 3.0)
		await create_timer(1.2).timeout
		marker("teamwork_controls_ready")
	check(await until(func(): return exists("teamwork_controls_ready")), "Physical pressure-pad input fixture ready")
	var peak: float = 0.0
	for step in 90:
		tick += 1
		var controls: Dictionary = app._neutral()
		controls.tick = tick
		controls.interact = int(app.session.players[local].slot) < 2
		app.session.controls(controls)
		await create_timer(1.0 / 30.0).timeout
		var amounts: Array = app.state.get("teamwork", {}).get("amounts", [])
		if not amounts.is_empty(): peak = maxf(peak, float(amounts[0]))
	check(peak > 0.25, "Two distinct held-E inputs operate the physical stage on host and replicas")
	marker(role + "_interact_held")
	check(await until(func(): return exists("host_interact_held") and exists("client1_interact_held") and exists("client2_interact_held")), "All peers observed the cooperative mover")
	if role == "host":
		for id in app.session.players:
			check(bool(app.inputs.get(id, {}).get("data", {}).get("interact", false)) == (int(app.session.players[id].slot) < 2), "Held-E transport preserved for " + id)
		marker("teamwork_inputs_checked")
	# A client can reach the all-held barrier before the host resumes. Keep its
	# held packet intact until the host has inspected it, then release together.
	check(await until(func(): return exists("teamwork_inputs_checked")), "Host inspects held controls before any peer releases E")
	for step in 12:
		tick += 1
		var controls: Dictionary = app._neutral()
		controls.tick = tick
		app.session.controls(controls)
		await create_timer(1.0 / 30.0).timeout
	check(not bool(app.state.get("teamwork", {}).get("latched", [true])[0]), "Operating controls alone cannot complete the relay")
	marker(role + "_interact_done")
	check(await until(func(): return exists("host_interact_done") and exists("client1_interact_done") and exists("client2_interact_done")), "All peers release E before completion fixtures")

func grapple_probe(local: String) -> void:
	if role == "host":
		for id in app.avatars: app.avatars[id].reset_at(app.world.spawn_point(int(app.session.players[id].slot), 0))
		await create_timer(0.3).timeout
		marker("grapple_ready")
	check(await until(func(): return exists("grapple_ready")), "Grapple fixture ready")
	var aim: Vector3 = app.world.get_node("BridgeGrapple").global_position
	for mode in ["pull", "swing"]:
		app.grapple_mode = mode
		for step in 30:
			tick += 1
			var controls: Dictionary = app._neutral()
			controls.tick = tick
			controls.grapple = true
			controls.grapple_mode = mode
			controls.aim = aim
			app.session.controls(controls)
			await create_timer(1.0 / 30.0).timeout
		check(app.avatars[local].grapple.active, "Local " + mode + " grapple attaches through network controls")
		check(app.avatars[local].grapple.mode == mode, "Local " + mode + " mode reaches host and returns")
		for id in app.avatars:
			check(app.avatars[id].grapple.active and app.avatars[id].grapple.mode == mode, "Every peer sees " + mode + " rope for " + id)
		marker(role + "_grapple_" + mode)
		check(await until(func(): return exists("host_grapple_" + mode) and exists("client1_grapple_" + mode) and exists("client2_grapple_" + mode)), "All peers acknowledge " + mode + " ropes")
	for step in 12:
		tick += 1
		var controls: Dictionary = app._neutral()
		controls.tick = tick
		app.session.controls(controls)
		await create_timer(1.0 / 30.0).timeout
	for id in app.avatars: check(not app.avatars[id].grapple.active, "Grapple release replicates for " + id)
	marker(role + "_grapple_done")
	check(await until(func(): return exists("host_grapple_done") and exists("client1_grapple_done") and exists("client2_grapple_done")), "All peers complete grapple sequence")

func finish() -> void:
	var result = {"role": role, "checks": checks, "failures": failures, "build": app.session.BUILD,
		"first_motion_msec": first_motion_msec,
		"limit": "Real three-process loopback across twenty courses, restart/rejoin, appearance RPCs, earned RNG cards and held-E cooperation. Checkpoints/lever/pad positioning and solved team stages are explicit fixtures; physical traversal and puzzle solving are tested separately."}
	marker(role + ("_pass" if failures.is_empty() else "_fail"), result)
	app._leave()
	# Match the game's exit path: stop voices and let the real mixer release them.
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
