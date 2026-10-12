extends SceneTree

const STAGES = ["host_catch", "host_pass_client2", "client2_pass_host", "client3_tackle", "client3_catch", "client3_shoot_south", "client2_catch", "client2_jump_dunk_north", "client2_launch", "client2_extra_jump", "client2_speed_strip"]
var app
var coordinator
var role = "host"
var address = "127.0.0.1"
var elapsed = 0.0
var stage_age = 0.0
var stage_index = -1
var instruction = {}
var next_step = 0
var input_age = 0.0
var pending_checkpoint = {}
var acknowledged = {}
var local_checkpoints = []
var history = []
var submitted_actions = []
var peak_roster = 0
var pending_advance = false
var checkpoint_sent = false
var started = false
var reported = false
var released_shot = false
var shot_peak = 0.0
var shot_trace = []
var trace_age = 0.0
var airborne_dunk = false
var tackle_dropped = false
var profile_path = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
		if arg.begins_with("--address="): address = arg.substr(10)
	call_deferred("boot")

func boot() -> void:
	coordinator = load("res://tests/network_actions_coordinator.gd").new()
	coordinator.name = "NetworkActionsCoordinator"
	coordinator.driver = self
	root.add_child(coordinator)
	app = load("res://main.tscn").instantiate()
	app.name = "NetworkActionsApp"
	app.manual_input_enabled = false
	root.add_child(app)
	app.nickname = "ACTIONS " + role
	app.muted = true
	profile_path = "user://network_actions_%s_%d.json" % [role, Time.get_ticks_usec()]
	app.profile = load("res://profile.gd").new(profile_path)
	app.balance_teams = false
	if role == "host": app.host_game("teams")
	else: app.join_game(address)

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or reported: return false
	elapsed += dt
	peak_roster = maxi(peak_roster, app.seats.size())
	if role == "host" and not started and app.phase == "lobby" and app.seats.size() == 3 and elapsed > 1.5:
		app.team_choices = {1:0, 2:0, 3:1}
		app.balance_teams = false
		app.start_match()
		started = true
		pending_advance = true
	if app.phase == "match" and not app.state.is_empty():
		if role == "host" and pending_advance and app.sim.reset_time <= 0:
			pending_advance = false
			begin_stage(stage_index + 1)
		stage_age += dt
		input_age += dt
		if not instruction.is_empty():
			if input_age >= .05:
				input_age = 0.0
				var move = Vector3.ZERO
				if instruction.get("follow_ball",false) and app.state.ball.owner == 0 and app.state.players.has(app.local_seat):
					var offset: Vector3 = app.state.ball.pos - app.state.players[app.local_seat].pos
					offset.y = 0
					if offset.length() > .65: move = offset.normalized()
					app.submit_action("catch")
				app.submit_move(move, instruction.get("aim", Vector3.FORWARD))
			var steps: Array = instruction.get("steps", [])
			while next_step < steps.size() and stage_age >= float(steps[next_step].at):
				var item: Dictionary = steps[next_step]
				if item.action == "throw": app.last_aim=instruction.get("shot_aim",app.last_aim)
				app.submit_action(item.action, float(item.get("charge", .5)))
				submitted_actions.append({"stage":stage_index,"action":item.action,"age":stage_age})
				next_step += 1
		if role == "host" and stage_index >= 0:
			if stage_index == 3 and app.sim.tackles > 0 and app.sim.ball.owner == 0 and app.sim.players[1].stun > 0: tackle_dropped = true
			if stage_index == 5 and app.sim.throws >= 3 and app.sim.ball.owner == 0:
				released_shot = true
				shot_peak = maxf(shot_peak, app.sim.ball.pos.y)
				trace_age += dt
				if trace_age >= .05 and stage_age < 2.5:
					trace_age = 0
					shot_trace.append({"age":stage_age,"pos":app.sim.ball.pos,"vel":app.sim.ball.vel,"aim":app.sim.players[3].aim,"event":app.sim.event_kind,"message":app.sim.message})
			if stage_index == 7 and not app.sim.players[2].grounded and app.sim.players[2].pos.y > app.sim.floor_height(app.sim.players[2].pos.x,app.sim.players[2].pos.z)+.6: airborne_dunk = true
			if not checkpoint_sent and expected_matches(expectation(stage_index), app.state): send_checkpoint()
			if not pending_advance and stage_age > 8: fail("Stage timed out: " + STAGES[stage_index])
		if not pending_checkpoint.is_empty() and expected_matches(pending_checkpoint.expected, app.state):
			var observed: Dictionary = app.state.players.get(2,{})
			var payload = {"stage":pending_checkpoint.stage,"seat":app.local_seat,"scores":app.state.scores.duplicate(),"owner":app.state.ball.owner,"counters":counts(app.state),"snapshots":app.snapshot_count,"player2":{"pos":observed.get("pos"),"vel":observed.get("vel"),"jumps":observed.get("jump_count"),"boost_time":observed.get("boost_time")}}
			local_checkpoints.append(payload)
			pending_checkpoint = {}
			if role == "host": receive_ack(1,payload)
			else: coordinator.acknowledge.rpc_id(1,payload)
	if elapsed > 65: fail("Session timed out before all action checkpoints agreed")
	return false

func recipe(aim: Vector3, steps: Array = []) -> Dictionary:
	return {"aim":aim,"steps":steps}

func hit(at: float, action: String, charge: float = .5) -> Dictionary:
	return {"at":at,"action":action,"charge":charge}

func begin_stage(index: int) -> void:
	if index >= STAGES.size():
		var ok = released_shot and shot_peak > app.Sim.HOOP_Y and airborne_dunk and tackle_dropped and app.sim.throws >= 3 and app.sim.dunks >= 1 and app.sim.tackles >= 1 and app.sim.baskets == 2 and app.sim.scores == {0:1,1:1}
		for seat in [2,3]: ok = ok and int(app.remote_inputs.get(seat,0)) > 10
		var report = {"ok":ok,"history":history,"accepted_inputs":app.remote_inputs.duplicate(),"physical_shot_released":released_shot,"shot_peak":shot_peak,"shot_trace":shot_trace,"physical_dunk_airborne":airborne_dunk,"tackle_dropped_ball":tackle_dropped,"final_scores":app.sim.scores.duplicate(),"counters":counts(app.state)}
		for peer in app.connected_peers(): coordinator.complete.rpc_id(peer,report)
		complete(report)
		return
	stage_index = index
	acknowledged.clear()
	checkpoint_sent = false
	var inputs = {1:recipe(Vector3.FORWARD),2:recipe(Vector3.BACK),3:recipe(Vector3.FORWARD)}
	match index:
		0:
			place(1,Vector3(0,0,0),Vector3.FORWARD)
			place(2,Vector3(0,0,-5),Vector3.BACK)
			place(3,Vector3(8,0,7),Vector3.FORWARD)
			app.sim.ball.pos = Vector3(0,1.5,-.7)
			app.sim.ball.vel = Vector3.ZERO
			app.sim.ball.owner = 0
			app.sim.ball.lock = 0
			app.sim.ball.pass_target = 0
			inputs[1] = recipe(Vector3.FORWARD,[hit(.15,"catch")])
		1:
			inputs[1] = recipe(Vector3.FORWARD,[hit(.15,"pass")])
			inputs[2] = recipe(Vector3.BACK,[hit(.25,"catch"),hit(.4,"catch")])
		2:
			inputs[2] = recipe(Vector3.BACK,[hit(.15,"pass")])
			inputs[1] = recipe(Vector3.FORWARD,[hit(.25,"catch"),hit(.4,"catch")])
		3:
			place(1,Vector3(0,0,0),Vector3.FORWARD)
			place(2,Vector3(-8,0,-7),Vector3.BACK)
			place(3,Vector3(0,0,2.3),Vector3.FORWARD)
			inputs[3] = recipe(Vector3.FORWARD,[hit(.2,"tackle")])
		4:
			var landing: Vector3 = app.sim.ball.pos
			landing.y = 0
			place(3,landing,Vector3.BACK)
			inputs[3] = recipe(Vector3.BACK,[hit(.15,"catch"),hit(.35,"catch"),hit(.55,"catch"),hit(.8,"catch"),hit(1.1,"catch")])
			inputs[3]["follow_ball"] = true
		5:
			place(1,Vector3(-8,0,0),Vector3.FORWARD)
			place(2,Vector3(8,0,0),Vector3.FORWARD)
			place(3,app.Sim.SOUTH+Vector3(0,-app.Sim.HOOP_Y,-10),Vector3.BACK)
			var charge=preload("res://tests/shot_fixture.gd").aimed_charge(app.sim,3)
			inputs[3] = recipe(Vector3.BACK,[hit(.2,"throw",charge)])
			inputs[3]["shot_aim"]=app.sim.players[3].shot_aim
		6:
			# The previous physical goal reset the ball at center; no score/possession fixture.
			place(1,Vector3(-8,0,0),Vector3.FORWARD)
			place(2,Vector3(0,0,0),Vector3.FORWARD)
			place(3,Vector3(8,0,0),Vector3.BACK)
			inputs[2] = recipe(Vector3.FORWARD,[hit(.2,"catch"),hit(.4,"catch")])
		7:
			place(1,Vector3(-8,0,0),Vector3.FORWARD)
			place(2,app.Sim.NORTH+Vector3(0,-app.Sim.HOOP_Y,2.5),Vector3.FORWARD)
			place(3,Vector3(8,0,0),Vector3.BACK)
			inputs[2] = recipe(Vector3.FORWARD,[hit(.2,"jump"),hit(.4,"dunk")])
		8:
			place(2,app.Sim.PADS[2],Vector3.FORWARD)
		9:
			inputs[2] = recipe(Vector3.FORWARD,[hit(.15,"jump")])
		10:
			place(2,app.Sim.SPEED_PADS[0],Vector3.FORWARD)
	var payload = {"stage":index,"name":STAGES[index],"inputs":inputs}
	for peer in app.connected_peers(): coordinator.stage.rpc_id(peer,payload)
	receive_stage(payload)
	print("NETWORK_ACTION_STAGE " + STAGES[index])

func place(seat: int, location: Vector3, aim: Vector3) -> void:
	# Host-only deterministic starting positions. Never grants possession or a score.
	var p: Dictionary = app.sim.players[seat]
	location.y = app.sim.floor_height(location.x,location.z)
	p.pos = location
	p.vel = Vector3.ZERO
	p.move = Vector3.ZERO
	p.aim = aim
	p.facing = aim
	p.grounded = true
	p.jump_count = 0
	p.stun = 0
	p.guard = 0
	p.cooldown = 0
	p.pad_cooldown = 0
	p.dive = 0
	p.dunk = 0
	p.catch_time = 0
	app.sim.reset_movement_state(p)

func receive_stage(payload: Dictionary) -> void:
	stage_index = int(payload.stage)
	stage_age = 0.0
	input_age = 1.0
	next_step = 0
	pending_checkpoint = {}
	instruction = payload.inputs.get(app.local_seat,{}).duplicate(true)

func expectation(index: int) -> Dictionary:
	match index:
		0: return {"owner":1,"grabs":1,"throws":0,"scores":{0:0,1:0}}
		1: return {"owner":2,"grabs":2,"throws":1,"scores":{0:0,1:0}}
		2: return {"owner":1,"grabs":3,"throws":2,"scores":{0:0,1:0}}
		3: return {"owner":0,"tackles":1,"scores":{0:0,1:0}}
		4: return {"owner":3,"grabs":4,"tackles":1,"scores":{0:0,1:0}}
		5: return {"owner":0,"throws":3,"baskets":1,"scores":{0:0,1:1}}
		6: return {"owner":2,"grabs":5,"scores":{0:0,1:1}}
		7: return {"owner":0,"dunks":1,"baskets":2,"scores":{0:1,1:1}}
		8: return {"air_player":2,"min_height":6.0,"min_speed":15.0,"jump_count":1,"launch_pad":app.Sim.PADS[2]}
		9: return {"air_player":2,"min_height":10.0,"min_speed":15.0,"jump_count":2}
		10: return {"boost_player":2,"min_speed":15.0,"near_pad":app.Sim.SPEED_PADS[0]}
	return {}

func expected_matches(expected: Dictionary, state: Dictionary) -> bool:
	if state.is_empty() or not state.has("ball"): return false
	if state.ball.owner != expected.get("owner",state.ball.owner): return false
	if state.scores != expected.get("scores",state.scores): return false
	for key in ["grabs","throws","tackles","dunks","baskets"]:
		if int(state.get(key,0)) < int(expected.get(key,0)): return false
	var seat = int(expected.get("air_player",expected.get("boost_player",0)))
	if seat:
		var p: Dictionary = state.players.get(seat,{})
		if p.is_empty() or Vector2(p.vel.x,p.vel.z).length()<expected.min_speed: return false
		if expected.has("air_player") and (p.grounded or p.pos.y<expected.min_height or p.jump_count!=expected.jump_count): return false
		# A fresh post-score kickoff also has one airborne jump and boost speed.
		# Reject that stale snapshot: this checkpoint must observe the side pad.
		if expected.has("launch_pad") and Vector2(p.pos.x-expected.launch_pad.x,p.pos.z-expected.launch_pad.z).length()>12: return false
		if expected.has("boost_player") and p.get("boost_time",0)<.2: return false
		if expected.has("near_pad"):
			if Vector2(p.pos.x-expected.near_pad.x,p.pos.z-expected.near_pad.z).length()>4: return false
			if not p.grounded or absf(p.pos.y-app.Sim.floor_height(p.pos.x,p.pos.z))>.15: return false
	return true

func counts(state: Dictionary) -> Dictionary:
	var result = {}
	for key in ["grabs","throws","tackles","dunks","baskets"]: result[key] = state.get(key,0)
	return result

func send_checkpoint() -> void:
	checkpoint_sent = true
	var payload = {"stage":stage_index,"expected":expectation(stage_index)}
	for peer in app.connected_peers(): coordinator.checkpoint.rpc_id(peer,payload)
	receive_checkpoint(payload)

func receive_checkpoint(payload: Dictionary) -> void:
	pending_checkpoint = payload

func receive_ack(peer: int, payload: Dictionary) -> void:
	if reported or not app.seats.has(peer) or int(payload.stage) != stage_index: return
	if int(app.seats[peer]) != int(payload.seat):
		fail("Checkpoint sender/seat mismatch")
		return
	acknowledged[int(payload.seat)] = payload
	if acknowledged.size() == 3:
		history.append({"stage":STAGES[stage_index],"peers":acknowledged.duplicate(true)})
		instruction = {}
		pending_advance = true

func fail(reason: String) -> void:
	if reported: return
	var report = {"ok":false,"failure":reason,"stage":STAGES[stage_index] if stage_index >= 0 else "connect","state":counts(app.state),"scores":app.state.get("scores",{}),"owner":app.state.get("ball",{}).get("owner",-1),"shot_trace":shot_trace,"history":history}
	if role == "host":
		for peer in app.connected_peers(): coordinator.complete.rpc_id(peer,report)
	complete(report)

func complete(report: Dictionary) -> void:
	if reported: return
	reported = true
	instruction = {}
	var ok = bool(report.get("ok",false)) and local_checkpoints.size() == STAGES.size() and peak_roster == 3
	if role != "host": ok = ok and app.snapshot_count > 20 and app.local_seat in [2,3]
	var output = report.duplicate(true)
	output["ok"] = ok
	output["role"] = role
	output["seat"] = app.local_seat
	output["checkpoints"] = local_checkpoints
	output["submitted_actions"] = submitted_actions
	output["snapshots"] = app.snapshot_count
	print("NETWORK_ACTIONS_RESULT " + JSON.stringify(output))
	await create_timer(1.0 if role == "host" else .6).timeout
	app.close_session("")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	quit(0 if ok else 1)


