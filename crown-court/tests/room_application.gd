extends SceneTree

var apps: Array = []
var profile_paths: Array[String] = []
var checks: Array[Dictionary] = []
var url = "ws://127.0.0.1:30230/rooms"
var evidence = "res://tests"
var host
var first
var second

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room-url="): url = arg.trim_prefix("--room-url=")
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, name: String, details: Dictionary = {}) -> bool:
	checks.append({"check":name,"passed":ok,"details":details})
	print("PASS " if ok else "FAIL ",name," ",details)
	return ok

func until(condition: Callable, seconds: float = 5.0) -> bool:
	var start = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < seconds * 1000: await process_frame
	return condition.call()

func make_app(label: String):
	var branch = Node.new()
	branch.name = label
	root.add_child(branch)
	var api = SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app = load("res://main.gd").new()
	app.name = "App"
	app.manual_input_enabled = false
	var path = "user://room_app_%s_%d.json" % [label,Time.get_ticks_usec()]
	profile_paths.append(path)
	app.profile = load("res://profile.gd").new(path)
	branch.add_child(app)
	app.room_server_url = url
	app.nickname = label
	app.muted = true
	apps.append(app)
	return app

func run() -> void:
	host = make_app("RoomHost")
	host.room_server_url = ""
	host.host_room("coop")
	check(host.phase == "menu" and "not available" in host.status_message,"unconfigured room service leaves practice/LAN available")
	host.room_server_url = url
	host.host_room("coop")
	check(host.phase == "connecting" and host.room_host_pending,"host waits for registration before showing lobby")
	if not check(await until(func(): return host.phase == "lobby" and host.room_code.length() == 26),"host receives room code",{"phase":host.phase,"error":host.status_message}):
		await finish()
		return
	check(host.multiplayer.get_unique_id() == 1 and host.seats == {1:1},"registered room host has authoritative identity")
	first = make_app("RoomFirst")
	first.selected_power = "pad"
	var decorated_code: String = host.room_code.substr(0,13).to_lower() + " - " + host.room_code.substr(13).to_lower()
	first.join_room(decorated_code)
	check(first.phase == "connecting" and first.local_seat == 0,"joining client waits for host welcome")
	if not check(await until(func(): return first.phase == "lobby" and host.seats.size() == 2 and first.seats.size() == 2),"formatted room code joins through real application RPC",{"error":first.status_message}):
		await finish()
		return
	second = make_app("RoomSecond")
	second.selected_power = "blast"
	second.join_room(host.room_code)
	if not check(await until(func(): return second.phase == "lobby" and host.seats.size() == 3 and first.seats.size() == 3 and second.seats.size() == 3),"three humans agree on room roster"):
		await finish()
		return
	check(first.room_code == host.room_code and second.room_code == host.room_code,"room code visible to joined players")
	check(await until(func(): return host.names.values().has("RoomFirst") and host.names.values().has("RoomSecond")),"names register through room transport")
	var extra = make_app("RoomExtra")
	extra.join_room(host.room_code)
	check(await until(func(): return extra.phase == "menu"),"full room returns extra player to menu",{"error":extra.status_message})
	check(extra.status_message == "This room already has three players.","full room preserves actionable server reason",{"error":extra.status_message})
	check(host.seats.size() == 3,"full room cannot replace existing seats")
	host.start_match()
	if not check(await until(func(): return first.phase == "match" and second.phase == "match" and first.snapshot_count > 3 and second.snapshot_count > 3),"room match and compressed snapshots reach both clients"):
		await finish()
		return
	check(first.match_id == host.match_id and second.match_id == host.match_id,"all peers share match identity")
	check(host.sim.players.size() == 6 and first.state.players.size() == 6 and second.state.players.size() == 6,"three humans retain three opponent bots")
	check(host.sim.players[first.local_seat].power == "pad" and host.sim.players[second.local_seat].power == "blast","selected powers register before match")
	await until(func(): return host.sim.reset_time <= 0,4.0)
	var origin: Vector3 = host.sim.players[first.local_seat].pos
	first.submit_move(Vector3.RIGHT,Vector3.RIGHT)
	first.submit_action("jump")
	await create_timer(0.2).timeout
	check(host.sim.players[first.local_seat].pos.x > origin.x + 0.1 and int(host.remote_inputs.get(first.local_seat,0)) > 0,"remote movement reaches authoritative host")
	check(host.sim.players[first.local_seat].jump_count > 0,"remote jump action reaches authoritative host")
	# This is a reward/transition fixture, not a claim of a naturally completed match.
	host.sim.winner = 0
	host.sim.celebration_time = 0.0
	check(await until(func(): return host._winner_shown and first._winner_shown and second._winner_shown),"winner reaches all result panels")
	check(host.profile.data.bags == 1 and first.profile.data.bags == 1 and second.profile.data.bags == 1,"eligible winners each receive one disposable-profile reward")
	var round_id: String = host.match_id
	host.start_match()
	check(await until(func(): return first.match_id != round_id and second.match_id == host.match_id and first.snapshot_count > 1),"room rematch changes identity on every peer")
	await first.close_session()
	check(await until(func(): return host.seats.size() == 2 and second.seats.size() == 2),"leaving client clears roster and remaining room keeps running")
	first.join_room(host.room_code)
	check(await until(func(): return first.phase == "match" and host.seats.size() == 3 and first.snapshot_count > 2),"client rejoins live room and receives state",{"phase":first.phase,"error":first.status_message,"host_seats":host.seats.duplicate()})
	check(first.profile.data.bags == 1,"rejoin does not duplicate previous reward")
	await host.close_session()
	check(await until(func(): return first.phase == "menu" and second.phase == "menu"),"host close returns both room clients to menu")
	await finish()

func finish() -> void:
	for app in apps:
		if is_instance_valid(app): await app.close_session()
	await create_timer(0.2).timeout
	for app in apps:
		if is_instance_valid(app): app.get_parent().queue_free()
	await process_frame
	for path in profile_paths:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"transport":"real local WebSocket room relay","scope":"application handshake, input, snapshot and transition fixture; not WAN latency or a natural match"}
	DirAccess.make_dir_recursive_absolute(evidence)
	var file = FileAccess.open(evidence.path_join("room-application-result.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("ROOM_APPLICATION_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
