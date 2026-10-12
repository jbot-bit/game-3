extends SceneTree

# Uses normal network submit calls. The copied Sim is a read-only decision model;
# no live player, ball, score, clock, or roster state is altered by this driver.
var app
var role = "peer"
var output_dir = "res://tests/active-network"
var address = "127.0.0.1"
var room_url = ""
var room_code = ""
var ready_written = false
var limit_seconds = 600.0
var sanity = false
var profile_path = ""
var character = ""
var wait_for_view = false
var mind = preload("res://sim.gd").new()
var elapsed = 0.0
var played = 0.0
var input_time = 0.0
var start_wait = -1.0
var result_wait = -1.0
var peak_roster = 0
var opponent_bots = 0
var local_possession = 0.0
var distance = 0.0
var previous_position = Vector3.ZERO
var previous_reset = 0.0
var previous_celebration = 0.0
var have_previous = false
var previous_owner = -1
var previous_event = -1
var last_sample = -1.0
var actions: Array = []
var samples: Array = []
var events: Array = []
var possession_changes: Array = []
var action_counts: Dictionary = {}
var final_state: Dictionary = {}
var result_written = false
var quitting = false
var reason = ""
var accepted_inputs: Dictionary = {}

func _initialize() -> void:
	boot.call_deferred()

func boot() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output_dir = argument.trim_prefix("--evidence-dir=")
		elif argument.begins_with("--address="): address = argument.trim_prefix("--address=")
		elif argument.begins_with("--room-url="): room_url = argument.trim_prefix("--room-url=")
		elif argument.begins_with("--room-code="): room_code = argument.trim_prefix("--room-code=")
		elif argument.begins_with("--max-seconds="): limit_seconds = clampf(float(argument.trim_prefix("--max-seconds=")), 8, 900)
		elif argument.begins_with("--character="): character = argument.trim_prefix("--character=")
		elif argument == "--sanity": sanity = true
		elif argument == "--wait-for-view": wait_for_view = true
	DirAccess.make_dir_recursive_absolute(output_dir)
	app = load("res://main.tscn").instantiate()
	app.manual_input_enabled = false
	profile_path = "user://active_network_%s_%d.json" % [role, Time.get_ticks_usec()]
	app.profile = load("res://profile.gd").new(profile_path)
	if not character.is_empty() and not app.profile.select_character(character):
		push_error("Could not select explicit test character: " + character)
		quit(1)
		return
	root.add_child(app)
	app.nickname = ("PLAY HOST" if role == "host" else "PLAY PEER") if character.is_empty() else character.capitalize()
	app.muted = true
	if not room_url.is_empty(): app.room_server_url = room_url
	if role == "host":
		if room_url.is_empty(): app.host_game("coop")
		else: app.host_room("coop")
	else:
		if room_url.is_empty(): app.join_game(address)
		else: app.join_room(room_code)

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or quitting: return false
	elapsed += dt
	if role == "host" and app.phase == "lobby" and not ready_written:
		ready_written = true
		write_json("host-ready.json", {"ready":true,"port":app.PORT,"transport":"enet" if room_url.is_empty() else "room","room_code":app.room_code})
	peak_roster = maxi(peak_roster, app.seats.size())
	for id in app.remote_inputs: accepted_inputs[id] = maxi(int(accepted_inputs.get(id,0)),int(app.remote_inputs[id]))
	if role == "host" and app.phase == "lobby" and app.seats.size() == 3:
		if start_wait < 0: start_wait = elapsed
		if elapsed-start_wait > 1.0: app.start_match()
	if app.phase == "match" and not app.state.is_empty() and app.state.players.has(app.local_seat):
		played += dt
		var state: Dictionary = app.state
		var p: Dictionary = state.players[app.local_seat]
		opponent_bots = 0
		for id in state.players:
			if not id in app.seats.values() and int(state.players[id].team) != int(p.team): opponent_bots += 1
		observe(dt)
		if int(state.winner) >= 0:
			if result_wait < 0: result_wait = elapsed
			app.submit_move(Vector3.ZERO, p.aim)
			if elapsed-result_wait > 2.5 and app.result_panel.visible and not result_written:
				final_state = state.duplicate(true)
				reason = "Actual authoritative result reached"
				write_report(true)
		elif float(state.reset_time) <= 0:
			input_time += dt
			if input_time >= .04:
				input_time = 0.0
				mind.players = state.players.duplicate(true)
				mind.ball = state.ball.duplicate(true)
				mind.mode = state.mode
				mind.bot_difficulty = state.get("bot_difficulty","easy")
				mind.clock = state.clock
				mind.winner = state.winner
				mind.reset_time = state.reset_time
				var command: Dictionary = mind.bot_command(app.local_seat)
				app.submit_move(command.move, command.aim)
				if str(command.action) != "":
					if command.action == "throw": app.last_aim = mind.players[app.local_seat].shot_aim
					app.submit_action(command.action, command.charge)
					action_counts[command.action] = int(action_counts.get(command.action,0))+1
					actions.append({"time":played,"action":command.action,"charge":command.charge,"move":vec(command.move),"aim":vec(command.aim)})
		else: app.submit_move(Vector3.ZERO, p.aim)
		if sanity and played >= (18.0 if role == "host" else 12.0) and not result_written:
			final_state = state.duplicate(true)
			reason = "Bounded connection and active-input smoke"
			write_report(false)
	if result_written:
		if role == "host":
			# Keep authority alive until both clients have written their final view.
			if FileAccess.file_exists(output_dir.path_join("peer.json")) and FileAccess.file_exists(output_dir.path_join("view/active-play.json")):
				shutdown()
			elif elapsed > limit_seconds+10: shutdown()
		elif not wait_for_view or FileAccess.file_exists(output_dir.path_join("view/active-play.json")):
			shutdown()
		elif elapsed-result_wait > 20.0:
			push_error("Recorded view did not finish within the bounded peer teardown wait")
			shutdown()
	elif elapsed > limit_seconds:
		reason = "Deadline reached before result"
		if not app.state.is_empty(): final_state = app.state.duplicate(true)
		write_report(false)
		shutdown()
	elif elapsed > 35 and played <= 0:
		reason = "Three-player match did not start"
		write_report(false)
		shutdown()
	return false

func observe(dt: float) -> void:
	var s: Dictionary = app.state
	var p: Dictionary = s.players[app.local_seat]
	var owner = int(s.ball.owner)
	if float(s.reset_time) <= 0 and owner == app.local_seat: local_possession += dt
	if have_previous and not (previous_celebration > 0 and float(s.celebration_time) <= 0 and float(s.reset_time) > 0):
		distance += p.pos.distance_to(previous_position)
	previous_position = p.pos
	previous_reset = float(s.reset_time)
	previous_celebration = float(s.celebration_time)
	have_previous = true
	if owner != previous_owner:
		possession_changes.append({"time":played,"from":previous_owner,"to":owner})
		previous_owner = owner
	if int(s.event_id) != previous_event:
		previous_event = int(s.event_id)
		events.append({"time":played,"kind":s.event_kind,"player":s.event_player,"position":vec(s.event_pos)})
	if played-last_sample >= .1:
		last_sample = played
		samples.append({"time":played,"clock":s.clock,"owner":owner,"position":vec(p.pos),"velocity":vec(p.vel),"scores":s.scores.duplicate(),"snapshots":app.snapshot_count,"humans":app.seats.size()})

func write_report(completed: bool) -> void:
	if result_written: return
	result_written = true
	var state = final_state if not final_state.is_empty() else app.state
	var winner = int(state.get("winner",-1))
	var won = winner >= 0 and state.has("players") and int(state.players[app.local_seat].team) == winner
	var peer_id = app.multiplayer.get_unique_id() if app.multiplayer_active() else -1
	var eligible = peer_id in state.get("reward_peers",[])
	var summary = {"role":role,"completed":completed,"reason":reason,"sanity_only":sanity,"fixture_mutations":false,"elapsed":elapsed,"played":played,"seat":app.local_seat,"peer_id":peer_id,"peak_roster":peak_roster,"opponent_bots":opponent_bots,"distance_m":distance,"local_possession_seconds":local_possession,"actions":action_counts,"snapshots":app.snapshot_count,"remote_inputs":accepted_inputs.duplicate(),"match_id":state.get("match_id",""),"scores":state.get("scores",{}),"winner":winner,"won":won,"reward_eligible_at_finish":eligible,"reward_bags":int(app.profile.data.bags),"reward_correct":int(app.profile.data.bags)==(1 if won else 0)}
	summary["application_version"] = ProjectSettings.get_setting("application/config/version", "unknown")
	summary["character"] = app.profile.outfit().get("character", "blank")
	summary["cosmetics"] = state.get("cosmetics", {}).duplicate(true)
	summary["transport"] = "enet" if room_url.is_empty() else "room"
	summary["snapshot_transport"] = app.snapshot_transport.duplicate()
	write_json(role+".json", {"summary":summary,"actions":actions,"events":events,"possessions":possession_changes,"samples":samples})
	print("ACTIVE_NETWORK_RESULT " + JSON.stringify(summary))

func write_json(name: String, value: Dictionary) -> void:
	var file = FileAccess.open(output_dir.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"))
	file.close()

func vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func shutdown() -> void:
	if quitting: return
	quitting = true
	var success = sanity or (not final_state.is_empty() and int(final_state.get("winner",-1)) >= 0)
	app.close_session("")
	await create_timer(.35).timeout
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if success else 1)
