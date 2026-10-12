extends SceneTree

class NetworkApp:
	extends "res://main.gd"
	var throws: Dictionary = {}
	var conclusion: Dictionary = {}
	func host_action(slot: int, command: String, charge: float, aim: Vector3 = Vector3.ZERO, movement: Vector3 = Vector3.INF) -> void:
		var possessed = int(sim.ball.owner) == slot
		super.host_action(slot, command, charge, aim, movement)
		if command == "throw" and possessed and int(sim.ball.owner) == 0:
			throws[slot] = {"aim":aim, "velocity":sim.ball.vel, "charge":charge, "movement":sim.players[slot].move}
	@rpc("authority", "call_remote", "reliable", 0)
	func finish_probe(receipt: Dictionary) -> void:
		conclusion = receipt

var role = "coordinator"
var humans = 2
var port = 29880
var directory = ""
var app
var started = 0
var stage = 0
var stage_time = 0.0
var first_round = ""
var sent = false
var saw_host_difficulty = false
var local_aim = Vector3.ZERO
var finished = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--humans="): humans = int(arg.trim_prefix("--humans="))
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--directory="): directory = arg.trim_prefix("--directory=")
	run.call_deferred()

func run() -> void:
	if role == "coordinator":
		await coordinate()
		return
	started = Time.get_ticks_msec()
	if role == "late": await create_timer(5).timeout
	app = NetworkApp.new()
	app.name = "Main"
	app.manual_input_enabled = false
	app.profile = load("res://profile.gd").new(directory.path_join(role + "-profile.json"))
	root.add_child(app)
	app.muted = true
	app.selected_difficulty = "hard" if role == "host" else "normal"
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2, app.NETWORK_CHANNELS) if role == "host" else peer.create_client("127.0.0.1", port, app.NETWORK_CHANNELS)
	if error != OK:
		write_result({"passed":false, "error":error})
		return
	app.multiplayer.multiplayer_peer = peer
	if role == "host": app.show_lobby()
	else: app.phase = "connecting"

func aim_for(slot: int) -> Vector3:
	return Vector3(.31, .73, -.45).normalized() if slot == 2 else Vector3(-.17, .66, -.74).normalized()

func give_ball(slot: int) -> void:
	app.sim.reset_time = 0
	app.sim.ball.owner = slot
	app.sim.ball.lock = 0
	app.sim.players[slot].stun = 0
	app.sim.players[slot].dunk = 0
	app.sim.players[slot].pos = Vector3(0, 8, 0)
	app.sim.players[slot].vel = Vector3.ZERO

func _process(_dt: float) -> bool:
	if not finished: tick()
	return false

func tick() -> void:
	if role == "coordinator" or app == null: return
	var elapsed = float(Time.get_ticks_msec() - started) / 1000.0
	if elapsed > 30:
		write_result({"passed":false, "timeout":true, "phase":app.phase, "stage":stage})
		return
	if role != "host":
		if app.phase == "match" and not app.state.is_empty():
			saw_host_difficulty = saw_host_difficulty or app.state.get("bot_difficulty", "") == "hard"
			if first_round.is_empty(): first_round = app.match_id
			if not sent and int(app.state.ball.owner) == app.local_seat:
				local_aim = aim_for(app.local_seat)
				app.submit_move(Vector3.RIGHT, Vector3.FORWARD)
				app.last_aim = local_aim
				app.submit_action("throw", .63)
				sent = true
		if not app.conclusion.is_empty():
			write_result({"passed":sent and saw_host_difficulty and app.selected_difficulty == "normal" and app.match_id != first_round and app.effective_difficulty() == "hard", "sent_3d_throw":sent, "difficulty":"hard" if saw_host_difficulty else "unknown", "preferred":app.selected_difficulty, "rematched":app.match_id != first_round, "snapshots":app.snapshot_count, "host":app.conclusion})
		return
	if stage == 0 and app.seats.size() >= 2:
		app.start_match()
		first_round = app.match_id
		give_ball(2)
		stage = 1
	elif stage == 1 and app.throws.has(2):
		stage = 2 if humans == 3 else 3
	elif stage == 2 and app.seats.size() == 3:
		give_ball(3)
		stage = 4
	elif stage == 4 and app.throws.has(3): stage = 3
	if stage == 3:
		app.start_match()
		stage_time = elapsed
		stage = 5
	elif stage == 5 and elapsed - stage_time > 1.0:
		var passed = app.sim.bot_difficulty == "hard" and app.match_id != first_round
		var receipts: Dictionary = {}
		for slot in app.throws:
			var receipt: Dictionary = app.throws[slot]
			var aim_error = receipt.aim.distance_to(aim_for(slot))
			var velocity_error = receipt.velocity.normalized().distance_to(aim_for(slot))
			passed = passed and aim_error < .00001 and velocity_error < .00001 and absf(receipt.charge - .63) < .00001 and receipt.movement == Vector3.RIGHT
			receipts[str(slot)] = {"aim_error":aim_error, "velocity_direction_error":velocity_error, "charge":receipt.charge, "speed":receipt.velocity.length()}
		var conclusion = {"passed":passed, "humans":humans, "difficulty":app.sim.bot_difficulty, "rematched":true, "late_join":humans == 3, "throws":receipts}
		for peer_id in app.connected_peers(): app.finish_probe.rpc_id(peer_id, conclusion)
		app.conclusion = conclusion
		stage_time = elapsed
		stage = 6
	elif stage == 6 and elapsed - stage_time > 1.0: write_result(app.conclusion)

func write_result(receipt: Dictionary) -> void:
	finished = true
	var output = FileAccess.open(directory.path_join(role + ".json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(receipt, "\t"))
	output.close()
	print("V11 INPUT NETWORK ", role, " ", JSON.stringify(receipt))
	quit(0 if receipt.get("passed", false) else 1)

func coordinate() -> void:
	var passed = true
	var base = "C:/game-3/build/crown-court-evidence/v11-input-network-%d" % Time.get_ticks_msec()
	for count in [2, 3]:
		var target = base.path_join(str(count) + "-human")
		DirAccess.make_dir_recursive_absolute(target)
		var processes: Array[int] = []
		var roles = ["host", "client"] if count == 2 else ["host", "client", "late"]
		for actor in roles:
			processes.append(OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/v11_input_network.gd", "--", "--role=" + actor, "--humans=" + str(count), "--port=" + str(29880 + count), "--directory=" + target], false))
			if actor == "host": await create_timer(1.2).timeout
		var limit = Time.get_ticks_msec() + 35000
		while processes.any(func(pid): return OS.is_process_running(pid)) and Time.get_ticks_msec() < limit:
			await create_timer(.25).timeout
		for pid in processes:
			if OS.is_process_running(pid): OS.kill(pid)
		for actor in roles:
			var path = target.path_join(actor + ".json")
			var receipt = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
			var ok = receipt is Dictionary and receipt.get("passed", false)
			passed = passed and ok
			print("PASS " if ok else "FAIL ", count, "-human ", actor, " ", JSON.stringify(receipt))
	print("V11 INPUT NETWORK EVIDENCE ", base)
	quit(0 if passed else 1)
