extends SceneTree

var app
var role = "host"
var mode = "coop"
var humans = 3
var address = "127.0.0.1"
var late = false
var balance = true
var elapsed = 0.0
var played = 0.0
var peak_roster = 0
var movement = 0.0
var previous = Vector3.ZERO
var snapshots = 0
var counters = {"grabs":0,"throws":0,"dunks":0,"tackles":0,"baskets":0}
var inputs = {}
var started = false
var saw_win = false
var saw_rematch = false
var first_round = ""
var win_state = {}
var rewarded = false
var rematched = false
var forced_goal = false
var shot_fixture = false
var input_tick = 0.0
var reported = false
var mind = preload("res://sim.gd").new()
var test_profile_path = ""
var roster_checked = false
var roster_ok = false
var power_ok = false
var team_counts = {}
var bot_counts = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role = argument.substr(7)
		if argument.begins_with("--mode="): mode = argument.substr(7)
		if argument.begins_with("--humans="): humans = int(argument.substr(9))
		if argument.begins_with("--address="): address = argument.substr(10)
		if argument == "--late": late = true
		if argument == "--unbalanced": balance = false
	call_deferred("boot")

func boot() -> void:
	app = load("res://main.tscn").instantiate()
	app.manual_input_enabled = false
	root.add_child(app)
	app.nickname = role.to_upper()
	app.muted = true
	app.balance_teams = balance
	app.selected_power = {"host":"blast", "client1":"giant", "client2":"pad"}[role]
	test_profile_path = "user://network_%s_%d.json" % [role, Time.get_ticks_usec()]
	app.profile = load("res://profile.gd").new(test_profile_path)
	# Exercise real cosmetic synchronization with a locally earned and equipped item.
	app.profile.award_win("setup")
	var reward = app.profile.open_bag()
	app.profile.equip(reward.id)
	if role == "host": app.host_game(mode)
	else: app.join_game(address)

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or reported: return false
	elapsed += dt
	peak_roster = maxi(peak_roster, app.seats.size())
	if role == "host" and app.phase == "lobby" and elapsed > 1.5 and (app.seats.size() == humans or late):
		app.start_match()
	if app.phase == "match" and not app.state.is_empty():
		started = true
		played += dt
		var s = app.state
		if played > 10 and app.seats.size() == humans and not roster_checked:
			roster_checked = true
			for id in s.players:
				var side = int(s.players[id].team)
				team_counts[side] = int(team_counts.get(side, 0)) + 1
				if not id in app.seats.values(): bot_counts[side] = int(bot_counts.get(side, 0)) + 1
			if mode == "coop":
				roster_ok = team_counts == {0:3, 1:3} and int(bot_counts.get(0,0)) == 3-humans and int(bot_counts.get(1,0)) == 3
			elif mode == "teams":
				var expected = {0:1, 1:1} if humans == 2 else {0:2, 1:2 if balance else 1}
				roster_ok = team_counts == expected and int(bot_counts.get(1,0)) == (1 if humans == 3 and balance else 0) and int(bot_counts.get(0,0)) == 0
			else:
				roster_ok = team_counts == {1:1, 2:1, 3:1}
			power_ok = true
			var selected_by_name = {"HOST":"blast","CLIENT1":"giant","CLIENT2":"pad"}
			# Clients can connect in either order. Verify the named player's choice,
			# not an assumed process-launch-order to seat mapping.
			for id in app.seats.values(): power_ok = power_ok and str(s.players[id].power) == str(selected_by_name.get(str(app.names.get(id,"")),"missing"))
		snapshots = maxi(snapshots, app.snapshot_count)
		for key in counters: counters[key] = maxi(counters[key], int(s.get(key, 0)))
		for id in app.remote_inputs: inputs[id] = maxi(int(inputs.get(id,0)), app.remote_inputs[id])
		if first_round.is_empty(): first_round = str(s.get("match_id", ""))
		if str(s.get("match_id", "")) != first_round and not first_round.is_empty(): saw_rematch = true
		if int(s.winner) >= 0:
			saw_win = true
			win_state = {"winner":s.winner,"scores":s.scores,"match_id":s.get("match_id", "")}
			var won = (s.players[app.local_seat].team == s.winner)
			rewarded = app.profile.data.bags == (1 if won else 0)
		elif s.players.has(app.local_seat) and (played < 17 or rematched or saw_rematch):
			var position = s.players[app.local_seat].pos
			if previous != Vector3.ZERO: movement += minf(1.0, previous.distance_to(position))
			previous = position
			mind.players = s.players.duplicate(true)
			mind.ball = s.ball.duplicate(true)
			mind.mode = s.mode
			mind.clock = s.clock
			input_tick += dt
			if input_tick >= .025:
				input_tick = 0.0
				var command = mind.bot_command(app.local_seat)
				app.submit_move(command.move, command.aim)
				if command.action != "":
					if command.action == "throw": app.last_aim=mind.players[app.local_seat].shot_aim
					app.submit_action(command.action, command.charge)
		if role == "host":
			if played > 14 and not saw_win and not shot_fixture and app.sim.reset_time<=0 and app.sim.celebration_time<=0:
				print("NETWORK_FIXTURE shot age=",played," reset=",app.sim.reset_time," celebration=",app.sim.celebration_time)
				shot_fixture = true
				# A short AI-driven 1v1 can remain contested at midfield. Exercise an
				# explicit host input shot so the lifecycle check is deterministic.
				for id in app.sim.players:
					app.sim.players[id].pos = Vector3(8,1,id)
					app.sim.players[id].vel = Vector3.ZERO
					app.sim.players[id].stun = 3.0
					app.sim.players[id].dunk = 0.0
				app.sim.players[1].pos = app.Sim.NORTH + Vector3(0,-app.Sim.HOOP_Y,9)
				app.sim.players[1].stun = 0.0
				app.sim.ball.owner = 1
				app.sim.ball.last_touch = 1
				app.sim.reset_time = 0.0
				app.submit_move(Vector3.ZERO,Vector3.FORWARD)
				var charge=preload("res://tests/shot_fixture.gd").aimed_charge(app.sim,1)
				app.last_aim=app.sim.players[1].shot_aim
				app.submit_action("throw",charge)
			if played > 17 and not saw_win and not forced_goal and app.sim.reset_time<=0 and app.sim.celebration_time<=0:
				print("NETWORK_FIXTURE final age=",played," reset=",app.sim.reset_time," celebration=",app.sim.celebration_time," ball=",app.sim.ball.pos)
				forced_goal = true
				# Controlled final basket uses the same physical scoring path as gameplay.
				app.sim.scores = {1:6,2:0,3:0} if mode == "versus" else {0:3,1:0}
				for id in app.sim.players:
					app.sim.players[id].pos = Vector3(8,1,id)
					app.sim.players[id].vel = Vector3.ZERO
					app.sim.players[id].stun = 2.0
					app.sim.players[id].dunk = 0.0
				app.sim.ball.owner = 0
				app.sim.ball.last_touch = 1
				app.sim.ball.pos = app.Sim.NORTH + Vector3.UP*.2
				app.sim.ball.vel = Vector3(0, -8, 0)
				app.sim.reset_time = 0.0
			if played > 21 and saw_win and app.sim.celebration_time<=0 and not rematched:
				rematched = true
				app.start_match()
		if played > ((38 if late else 31) if role == "host" else 27): finish()
	if elapsed > 43: finish()
	return false

func finish() -> void:
	reported = true
	var cosmetics = app.state.get("cosmetics", {})
	var cosmetic_ok = cosmetics.get(app.local_seat, {}) == app.profile.outfit()
	var ok = started and peak_roster == humans and movement > 12 and counters.grabs > 0 and counters.throws + counters.dunks > 0 and counters.baskets > 0 and saw_win and saw_rematch and rewarded and cosmetic_ok and roster_ok and power_ok
	if role != "host": ok = ok and snapshots > 200 and app.local_seat in [2, 3]
	else:
		ok = ok and app.seats.size() == 1
		for id in range(2, humans + 1): ok = ok and int(inputs.get(id,0)) > 100
	print("NETWORK_RESULT " + JSON.stringify({"ok":ok,"mode":mode,"role":role,"humans":humans,"late":late,"balanced":balance,"seat":app.local_seat,"peak_roster":peak_roster,"movement":movement,"snapshots":snapshots,"counters":counters,"accepted_inputs":inputs,"remaining_seats":app.seats.size(),"win":win_state,"rematch":saw_rematch,"rewarded":rewarded,"outfit_sync":cosmetic_ok,"team_counts":team_counts,"bot_counts":bot_counts,"roster_ok":roster_ok,"power_sync":power_ok}))
	app.close_session("")
	await create_timer(0.4).timeout
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_profile_path + suffix): DirAccess.remove_absolute(test_profile_path + suffix)
	quit(0 if ok else 1)
