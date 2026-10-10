extends SceneTree

const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var role = "host"
var output = ""
var key = ""
var port = 24573
var checks = 0
var tick = 0
var failures: Array[String] = []
var first_motion_msec = -1

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

func run_probe() -> void:
	app = Game.new()
	app.name = "HandsFull"
	app.scripted = true
	app.progress_path = "user://tests/hands-full-" + key + ".json"
	app.game_port = port
	root.add_child(app)
	if role == "host":
		app._host("Host")
		marker("ready")
	else:
		check(await until(func(): return exists("ready")), "Host starts")
		app._join("127.0.0.1", role)
	check(await until(func(): return app.session.connected and app.avatars.size() == 3 and app.state.get("players", {}).size() == 3), "Three peers admitted with all puppets")
	if app.avatars.size() != 3:
		finish()
		return
	var local: String = app.session.local_id
	check(local in ["crew_1", "crew_2", "crew_3"], "Assigned known stable slot")
	check(app.state.offers[local].size() == 3, "Three offered power choices arrive")
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
	check(app.world.props.size() == 7, "Seven prop replicas")
	marker(role + "_moved", {"before": str(before), "after": str(after)})
	check(await until(func(): return exists("host_moved") and exists("client1_moved") and exists("client2_moved")), "All three finished input sequence")
	if role == "host":
		# Deterministic fixture for proximity-authorized unilateral choice.
		app.avatars.crew_1.reset_at(app.world.switch_position + Vector3.UP * 2)
		await physics_frame
		app.session.act("switch")
		check(app.state.wind == -1, "Nearby player reverses crew wind")
		marker("switched")
	check(await until(func(): return app.state.get("wind", 0) == -1), "Unilateral switch reaches every peer")
	marker(role + "_wind")
	if role == "host":
		check(await until(func(): return exists("client1_wind") and exists("client2_wind")), "Clients acknowledge wind state")
		# Isolate course-completion/save synchronization from traversal feel.
		for id in app.avatars: app.avatars[id].reset_at(app.world.spawn_point(int(app.session.players[id].slot), 2))
	check(await until(func(): return app.state.get("phase", "") == "complete"), "Complete course state replicated")
	check(int(app.state.get("completions", 0)) == 1, "Completion committed exactly once")
	var collection: Array = app.state.get("unlocked_power_ids", [])
	check(not collection.is_empty(), "Successful clear unlocks permanent power choices")
	for player in app.state.players.values():
		check(str(player.power) in collection, "Each crew member's used power is collected")
	marker(role + "_complete")
	if role == "host":
		check(await until(func(): return exists("client1_complete") and exists("client2_complete")), "Both clients see completion")
		var saved: Dictionary = app.rules.complete(app.run_id)
		check(saved.ok and int(saved.completions) == 1, "Duplicate completion does not award twice")
		var reloaded = app.Rules.new()
		check(reloaded.load_progress(app.progress_path).ok and reloaded.progress.unlocked_power_ids == collection, "Collected powers survive a fresh save load")
		app.session.act("restart")
		# Make the previously earned choice absent from the new random offers.
		# This isolates the permanent-choice route from luck of the next draw.
		for id in app.state.offers:
			var fresh: Array = []
			for power_id in ["spring", "heavy", "swift", "feather", "grip"]:
				if power_id != collection[0] and fresh.size() < 3: fresh.append(power_id)
			app.state.offers[id] = fresh
		app._publish()
	check(await until(func(): return app.state.get("phase", "") == "play" and app.state.get("completions", 0) == 1), "Rematch resets course and retains progression")
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
		marker("shutdown")
	else:
		await until(func(): return exists("shutdown"))
	finish()

func finish() -> void:
	var result = {"role": role, "checks": checks, "failures": failures, "build": app.session.BUILD,
		"first_motion_msec": first_motion_msec,
		"limit": "Real three-process loopback. Completion and lever use positioning fixtures; not a free-play course completion."}
	marker(role + ("_pass" if failures.is_empty() else "_fail"), result)
	app._leave()
	# Match the game's exit path: stop voices and let the real mixer release them.
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
