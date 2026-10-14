extends SceneTree

# The driver reads snapshots and presses normal controls. It never writes match
# state, positions, ownership, scores, timers, seats, or bot commands.
var app
var output_dir = "res://tests/active-play"
var join_address = ""
var room_url = ""
var room_code = ""
var selected_mode = "coop"
var limit_seconds = 420.0
var sanity = false
var settings_existed = false
var saved_settings = PackedByteArray()
var profile_path = ""
var initial_inventory_count = 0
var character = ""
var elapsed = 0.0
var ticks = 0
var actions: Array = []
var events: Array = []
var possessions: Array = []
var samples: Array = []
var discontinuities: Array = []
var actions_count: Dictionary = {}
var local_events: Dictionary = {}
var keys_down: Dictionary = {}
var mouse_down: Dictionary = {}
var key_release: Dictionary = {}
var mouse_release: Dictionary = {}
var last_decision = -1.0
var last_catch = -10.0
var last_jump = -10.0
var last_request = -10.0
var last_hype = -10.0
var last_tackle = -10.0
var possession_started = 0.0
var possessions_won = 0
var previous_owner = -1
var previous_event = -1
var previous_score: Dictionary = {}
var previous_position = Vector3.ZERO
var previous_camera = Vector3.ZERO
var previous_yaw = 0.0
var previous_reset = 0.0
var previous_celebration = 0.0
var previous_dunk = 0.0
var have_previous = false
var maximum_player_step = 0.0
var maximum_dunk_step = 0.0
var maximum_camera_step = 0.0
var maximum_dunk_camera_step = 0.0
var kickoff_resets = 0
var focus_recoveries = 0
var local_possession_seconds = 0.0
var distance_travelled = 0.0
var contested_possession_seconds = 0.0
var live_seconds = 0.0
var shot_started = -1.0
var shot_hold_seconds = .3
var intention = "dunk"
var navigation_target = Vector3.ZERO
var facing_target = Vector3.ZERO
var result_since = -1.0
var initial_bot_count = 0
var reason = ""
var capture_fps = 0.0
var capture_clock = -1.0
var capture_started = 0
var capture_frames: Array = []
var capture_last = -1.0
var peak_roster = 0
var play_nickname = ""
var play_series = false
var requested_difficulty = "easy"
var completed_rounds: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): output_dir = argument.trim_prefix("--evidence-dir=")
		elif argument.begins_with("--join="): join_address = argument.trim_prefix("--join=")
		elif argument.begins_with("--room-url="): room_url = argument.trim_prefix("--room-url=")
		elif argument.begins_with("--room-code="): room_code = argument.trim_prefix("--room-code=")
		elif argument.begins_with("--mode="): selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--capture-fps="): capture_fps = clampf(float(argument.trim_prefix("--capture-fps=")), 0, 30)
		elif argument.begins_with("--nickname="): play_nickname = argument.trim_prefix("--nickname=")
		elif argument.begins_with("--character="): character = argument.trim_prefix("--character=")
		elif argument.begins_with("--max-seconds="): limit_seconds = clampf(float(argument.trim_prefix("--max-seconds=")), 5, 900)
		elif argument == "--sanity": sanity = true
		elif argument == "--series": play_series = true
		elif argument.begins_with("--difficulty="): requested_difficulty = argument.trim_prefix("--difficulty=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed: saved_settings = FileAccess.get_file_as_bytes("user://settings.cfg")
	root.size = Vector2i(1280, 800)
	app = load("res://main.tscn").instantiate()
	profile_path = "user://active_play_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	initial_inventory_count = app.profile.data.inventory.size()
	if not character.is_empty() and not app.profile.select_character(character):
		push_error("Could not select explicit test character: " + character)
		quit(1)
		return
	root.add_child(app)
	if not is_instance_valid(app.world):
		reason = "Application did not construct"
		finish(false)
		return
	if not room_url.is_empty():
		app.room_server_url = room_url
		app.show_menu()
	if not play_nickname.is_empty(): app.name_edit.text = play_nickname
	if capture_fps > 0 and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output_dir.path_join("frames"))
		capture_started = Time.get_ticks_usec()
		RenderingServer.frame_post_draw.connect(capture_view)
	await wait_frames(4)
	if requested_difficulty != "easy":
		app.difficulty_select.grab_focus()
		await menu_key(KEY_SPACE)
		await menu_key(KEY_HOME)
		for index in {"normal":1,"hard":2}.get(requested_difficulty,0): await menu_key(KEY_DOWN)
		await menu_key(KEY_ENTER)
		if app.selected_difficulty != requested_difficulty:
			reason = "Menu did not select requested bot difficulty"
			finish(false)
			return
	if join_address.is_empty() and room_url.is_empty() and selected_mode != "coop":
		app.mode_select.grab_focus()
		await menu_key(KEY_SPACE)
		await menu_key(KEY_HOME)
		for index in {"versus":1,"teams":2}.get(selected_mode,0): await menu_key(KEY_DOWN)
		await menu_key(KEY_ENTER)
		if app.selected_mode != selected_mode:
			reason = "Mode selection did not reach requested mode"
			finish(false)
			return
	if not room_url.is_empty():
		app.room_edit.text = room_code
		await click_button("Join room")
	elif not join_address.is_empty():
		app.ip_edit.text = join_address
		await click_button("Join")
	else:
		await click_button("Practice")
	var connect_ticks = 0
	while app.phase != "match" and connect_ticks < 1800:
		await wait_frames(1)
		connect_ticks += 1
	if app.phase != "match":
		reason = "Menu start/join did not reach a match"
		finish(false)
		return
	while app.state.is_empty(): await wait_frames(1)
	initial_bot_count = app.state.players.size() - app.seats.size()
	selected_mode = app.selected_mode
	log_action("match_start", {"network_client": not join_address.is_empty() or not room_url.is_empty(), "bot_count": initial_bot_count, "human_count": app.seats.size()})
	while elapsed < limit_seconds:
		await physics_frame
		ticks += 1
		elapsed = float(ticks) / Engine.physics_ticks_per_second
		release_due()
		if app.phase != "match":
			reason = "Session ended before result"
			break
		if app.paused:
			focus_recoveries += 1
			tap_key(KEY_ESCAPE, "focus_resume")
			continue
		if app.state.is_empty() or not app.state.players.has(app.local_seat): continue
		observe()
		if int(app.state.winner) >= 0:
			release_gameplay()
			if app.result_panel.visible:
				if result_since < 0: result_since = elapsed
				if elapsed - result_since >= 2.0:
					if play_series:
						completed_rounds.append({"match_id": app.state.match_id, "scores": app.state.scores.duplicate(), "winner": app.state.winner, "won": int(app.state.players[app.local_seat].team) == int(app.state.winner), "series": app.state.get("series", {}).duplicate(true)})
						if not app.state.get("series", {}).get("finished", false):
							var power_choice = app.result_panel.find_child("NextPower", true, false)
							power_choice.grab_focus()
							await menu_key(KEY_SPACE)
							await menu_key(KEY_HOME)
							for index in completed_rounds.size() % 3: await menu_key(KEY_DOWN)
							await menu_key(KEY_ENTER)
							await click_button("Run it back · best of 3" if completed_rounds.size() == 1 else "Next round")
							result_since = -1.0
							log_action("series_next_round", {"round": completed_rounds.size() + 1, "power": app.selected_power})
							continue
					reason = "Actual result screen reached"
					finish(true)
					return
			continue
		if float(app.state.reset_time) > 0:
			release_gameplay()
			continue
		if not app.input_armed: continue
		if elapsed - last_decision >= .10:
			last_decision = elapsed
			choose_play()
		steer()
	if reason.is_empty(): reason = "Time limit reached before a result"
	finish(false)

func wait_frames(count: int) -> void:
	for index in count: await physics_frame

func menu_key(code: int) -> void:
	set_key(code, true)
	Input.flush_buffered_events()
	await wait_frames(2)
	set_key(code, false)
	Input.flush_buffered_events()
	await wait_frames(2)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = find_button(child, text)
		if found != null: return found
	return null

func click_button(text: String) -> void:
	var button = find_button(app.ui, text)
	if button == null: return
	var center = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await wait_frames(2)
	await wait_frames(2)

func set_key(code: int, down: bool) -> void:
	if bool(keys_down.get(code, false)) == down: return
	keys_down[code] = down
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func set_mouse(button: int, down: bool) -> void:
	if bool(mouse_down.get(button, false)) == down: return
	mouse_down[button] = down
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)

func tap_key(code: int, action: String) -> void:
	if bool(keys_down.get(code, false)): return
	set_key(code, true)
	key_release[code] = elapsed + .05
	log_action(action)

func tap_mouse(button: int, action: String) -> void:
	if bool(mouse_down.get(button, false)): return
	set_mouse(button, true)
	mouse_release[button] = elapsed + .05
	log_action(action)

func release_due() -> void:
	for code in key_release.keys():
		if elapsed >= float(key_release[code]):
			set_key(code, false)
			key_release.erase(code)
	for button in mouse_release.keys():
		if elapsed >= float(mouse_release[button]):
			set_mouse(button, false)
			mouse_release.erase(button)

func release_gameplay() -> void:
	for code in keys_down.keys(): set_key(code, false)
	for button in mouse_down.keys(): set_mouse(button, false)
	key_release.clear()
	mouse_release.clear()
	shot_started = -1.0

func log_action(action: String, details: Dictionary = {}) -> void:
	actions_count[action] = int(actions_count.get(action, 0)) + 1
	var row = {"time": elapsed, "action": action}
	row.merge(details)
	actions.append(row)

func own_team(player_id: int) -> bool:
	if app.selected_mode == "versus": return player_id == app.local_seat
	return int(app.state.players[player_id].team) == int(app.state.players[app.local_seat].team)

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x, a.z-b.z).length()

func choose_play() -> void:
	var id: int = app.local_seat
	var p: Dictionary = app.state.players[id]
	var owner = int(app.state.ball.owner)
	var hoop: Vector3 = app.attack_hoop()
	var hoop_distance = flat_distance(p.pos, hoop)
	var nearest_enemy = INF
	for other in app.state.players:
		if not own_team(other): nearest_enemy = minf(nearest_enemy, flat_distance(p.pos, app.state.players[other].pos))
	if float(p.stun) > 0 or float(p.dunk) > 0:
		set_key(KEY_W, false)
		set_key(KEY_A, false)
		set_key(KEY_D, false)
		return
	if float(p.hype) >= 100 and elapsed-last_hype > 2:
		tap_key(KEY_Q, "hype")
		last_hype = elapsed
	if owner == id:
		facing_target = hoop
		navigation_target = hoop
		if shot_started >= 0:
			set_key(KEY_W, false)
			if elapsed-shot_started >= shot_hold_seconds:
				set_mouse(MOUSE_BUTTON_RIGHT, false)
				log_action("shot_release", {"charge_seconds": elapsed-shot_started, "distance": hoop_distance})
				shot_started = -1.0
			return
		if intention == "pass" and elapsed-possession_started > .45:
			var teammate = best_teammate()
			if teammate > 0:
				set_key(KEY_W, false)
				facing_target = app.state.players[teammate].pos
				if aligned(facing_target):
					tap_mouse(MOUSE_BUTTON_LEFT, "pass")
					intention = "dunk"
				return
			if elapsed-possession_started > 2: intention = "shot"
		if intention == "shot" and hoop_distance < 18 and hoop_distance > 5 and aligned(hoop):
			set_key(KEY_W, false)
			# Choose charge from visible range/elevation, then use ordinary mouse
			# look and press/release; this never changes authoritative ball state.
			var release = p.pos+Vector3.UP*1.6+app.camera_forward()*.7
			var offset:Vector3=hoop-release
			var distance=Vector2(offset.x,offset.z).length()
			var loft=deg_to_rad(58.0)
			var speed=sqrt(app.Sim.BALL_GRAVITY*distance*distance/maxf(.1,2*cos(loft)*cos(loft)*(distance*tan(loft)-offset.y)))
			shot_hold_seconds=clampf((speed-12)/34*1.15,.05,1.15)
			set_mouse(MOUSE_BUTTON_RIGHT, true)
			shot_started = elapsed
			log_action("shot_charge", {"distance": hoop_distance})
			return
		if hoop_distance < app.Sim.DUNK_RANGE-.2:
			if bool(p.grounded) and elapsed-last_jump > .5:
				tap_key(KEY_SPACE, "jump_dunk")
				last_jump = elapsed
			elif not bool(p.grounded): tap_key(KEY_F, "dunk")
		elif nearest_enemy < 4.0 and bool(p.grounded) and elapsed-last_jump > 1.3:
			tap_key(KEY_SPACE, "evade_jump")
			last_jump = elapsed
		elif not bool(p.grounded) and int(p.jump_count) == 1 and float(p.vel.y) < 4 and nearest_enemy < 6 and elapsed-last_jump > .3:
			tap_key(KEY_SPACE, "double_jump")
			last_jump = elapsed
		navigation_target = route_target(p, navigation_target)
	elif owner == 0:
		cancel_charge()
		var ball: Dictionary = app.state.ball
		var intercept = .2
		if float(ball.pos.y) > 4 and float(ball.vel.y) < 0:
			intercept = clampf((sqrt(float(ball.vel.y)*float(ball.vel.y)+2*app.Sim.BALL_GRAVITY*maxf(0,ball.pos.y-1.5))+ball.vel.y)/app.Sim.BALL_GRAVITY, .15, 1.0)
		navigation_target = ball.pos + ball.vel * intercept
		navigation_target.x = clampf(navigation_target.x, -app.Sim.HALF_WIDTH+1, app.Sim.HALF_WIDTH-1)
		navigation_target.z = clampf(navigation_target.z, -app.Sim.HALF_LENGTH+1, app.Sim.HALF_LENGTH-1)
		facing_target = navigation_target
		if p.pos.distance_to(ball.pos) < 4.5 and elapsed-last_catch > .22:
			if int(actions_count.get("catch", 0)) % 2 == 0: tap_key(KEY_E, "catch")
			else: tap_mouse(MOUSE_BUTTON_LEFT, "catch")
			last_catch = elapsed
		if flat_distance(p.pos, ball.pos) < 2.4 and ball.pos.y-p.pos.y > 2.5 and ball.vel.y < 2 and elapsed-last_jump > .5 and int(p.jump_count) < 2:
			tap_key(KEY_SPACE, "jump_catch")
			last_jump = elapsed
	elif own_team(owner):
		cancel_charge()
		var carrier: Dictionary = app.state.players[owner]
		var side = -1.0 if int(id) % 2 == 0 else 1.0
		navigation_target = carrier.pos.lerp(hoop, .35) + Vector3(side*5, 0, 0)
		facing_target = navigation_target
		if flat_distance(p.pos, carrier.pos) < 23 and elapsed-last_request > 5.0:
			tap_mouse(MOUSE_BUTTON_MIDDLE, "request_pass")
			last_request = elapsed
	else:
		cancel_charge()
		var opponent: Dictionary = app.state.players[owner]
		navigation_target = opponent.pos + opponent.vel * .15
		facing_target = navigation_target
		if flat_distance(p.pos, opponent.pos) < 2.4 and absf(p.pos.y-opponent.pos.y) < 2.0 and float(p.cooldown) <= 0 and elapsed-last_tackle > .9:
			tap_mouse(MOUSE_BUTTON_RIGHT, "tackle")
			last_tackle = elapsed
	set_key(KEY_W, flat_distance(p.pos, navigation_target) > .65)
	set_key(KEY_A, false)
	set_key(KEY_D, false)

func cancel_charge() -> void:
	if shot_started < 0: return
	set_mouse(MOUSE_BUTTON_RIGHT, false)
	log_action("charge_interrupted")
	shot_started = -1.0

func best_teammate() -> int:
	var p: Dictionary = app.state.players[app.local_seat]
	var best = 0
	var distance = INF
	for id in app.state.players:
		if id == app.local_seat or not own_team(id): continue
		var candidate: Dictionary = app.state.players[id]
		var gap = flat_distance(p.pos, candidate.pos)
		if gap > 3 and gap < 24 and float(candidate.stun) <= 0 and gap < distance:
			best = id
			distance = gap
	return best

func route_target(player: Dictionary, target: Vector3) -> Vector3:
	if not bool(player.grounded) or flat_distance(player.pos, target) < 22: return target
	for pad in app.Sim.PADS:
		var gap = flat_distance(player.pos, pad)
		if gap < 8 and gap + flat_distance(pad, target) < flat_distance(player.pos, target) + 3: return pad
	return target

func aligned(target: Vector3) -> bool:
	var p: Dictionary = app.state.players[app.local_seat]
	var direction = Vector3(target.x-p.pos.x, 0, target.z-p.pos.z).normalized()
	return app.camera_forward().dot(direction) > .98

func steer() -> void:
	var p: Dictionary = app.state.players[app.local_seat]
	if float(p.dunk) > 0 or float(p.stun) > 0: return
	var target = facing_target if shot_started >= 0 or (intention == "pass" and int(app.state.ball.owner) == app.local_seat) else navigation_target
	var direction: Vector3 = target-p.pos
	if Vector2(direction.x,direction.z).length() < .1: return
	var desired = atan2(-direction.x, -direction.z)
	# Bounded real mouse input avoids the earlier route's instantaneous 76° turn.
	var turn = clampf(angle_difference(app.yaw, desired), -3.6/Engine.physics_ticks_per_second, 3.6/Engine.physics_ticks_per_second)
	var event = InputEventMouseMotion.new()
	var desired_pitch=.43-deg_to_rad(10) if shot_started>=0 else .43
	var pitch_turn=clampf(desired_pitch-app.pitch,-3.6/Engine.physics_ticks_per_second,3.6/Engine.physics_ticks_per_second)
	event.relative = Vector2(-turn/.0032,pitch_turn/.0028)
	event.screen_relative = event.relative
	Input.parse_input_event(event)

func observe() -> void:
	var state: Dictionary = app.state
	peak_roster = maxi(peak_roster, app.seats.size())
	var p: Dictionary = state.players[app.local_seat]
	var owner = int(state.ball.owner)
	var dt = 1.0/Engine.physics_ticks_per_second
	if float(state.reset_time) <= 0:
		live_seconds += dt
		if owner == app.local_seat: local_possession_seconds += dt
		if owner > 0 and not own_team(owner): contested_possession_seconds += dt
	if owner != previous_owner:
		possessions.append({"time":elapsed,"from":previous_owner,"to":owner,"position":vec(p.pos)})
		if owner == app.local_seat:
			possessions_won += 1
			possession_started = elapsed
			intention = ["pass", "shot", "dunk"][(possessions_won-1)%3]
		previous_owner = owner
	if int(state.event_id) != previous_event:
		var delivered: Array = state.get("recent_events", [[int(state.event_id),str(state.event_kind),state.get("event_pos",Vector3.ZERO),int(state.get("event_player",0)),0.0]])
		for event in delivered:
			if int(event[0]) <= previous_event: continue
			var actor = int(event[3])
			var kind = str(event[1])
			events.append({"time":elapsed,"kind":kind,"player":actor,"position":vec(event[2]),"event_id":int(event[0])})
			if actor == app.local_seat: local_events[kind] = int(local_events.get(kind,0))+1
		previous_event = int(state.event_id)
	if state.scores != previous_score:
		log_action("scoreboard", {"scores": state.scores.duplicate()})
		previous_score = state.scores.duplicate()
	var camera: Vector3 = app.world.camera.position
	if have_previous:
		var player_step = p.pos.distance_to(previous_position)
		var camera_step = camera.distance_to(previous_camera)
		var kickoff = previous_celebration > 0 and float(state.celebration_time) <= 0 and float(state.reset_time) > 0
		if kickoff: kickoff_resets += 1
		else:
			distance_travelled += player_step
			maximum_player_step = maxf(maximum_player_step, player_step)
			maximum_camera_step = maxf(maximum_camera_step, camera_step)
			if previous_dunk > 0 and float(p.dunk) > 0:
				maximum_dunk_step = maxf(maximum_dunk_step, player_step)
				maximum_dunk_camera_step = maxf(maximum_dunk_camera_step, camera_step)
			if player_step > .9 or camera_step > 2:
				discontinuities.append({"time":elapsed,"player_step":player_step,"camera_step":camera_step,"yaw_change":angle_difference(previous_yaw,app.yaw),"dunk":p.dunk,"stun":p.stun,"reset":state.reset_time})
	previous_position = p.pos
	previous_camera = camera
	previous_yaw = app.yaw
	previous_reset = float(state.reset_time)
	previous_celebration = float(state.celebration_time)
	previous_dunk = float(p.dunk)
	have_previous = true
	if ticks%6 == 0:
		samples.append({"time":elapsed,"clock":state.clock,"remaining":state.time_left,"owner":owner,"position":vec(p.pos),"velocity":vec(p.vel),"camera":vec(camera),"yaw":app.yaw,"grounded":p.grounded,"jump_count":p.jump_count,"dunk":p.dunk,"stun":p.stun,"intention":intention,"scores":state.scores.duplicate(),"ball_position":vec(state.ball.pos),"rendered_ball":vec(app.world.ball_root.position) if is_instance_valid(app.world.ball_root) else vec(state.ball.pos),"rendered_player":vec(app.world.actors[app.local_seat].root.position) if app.world.actors.has(app.local_seat) else vec(p.pos),"snapshot_age":maxf(0,app.ui_clock-app.snapshot_received_at) if not app.multiplayer.is_server() else 0.0,"sounds_played":app.sounds.played_count})

func vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func capture_view() -> void:
	var now = float(Time.get_ticks_usec()-capture_started)/1000000.0
	if capture_last >= 0 and now-capture_last < 1.0/capture_fps: return
	capture_last = now
	var name = "frames/%06d.jpg" % capture_frames.size()
	var frame = root.get_texture().get_image()
	frame.save_jpg(output_dir.path_join(name), .88)
	capture_frames.append({"file":name,"time":now,"camera_kind":app.world.cinematic_kind,"match_id":app.state.get("match_id", ""),"winner":app.state.get("winner", -1),"scores":app.state.get("scores", {}).duplicate()})

func finish(completed: bool) -> void:
	release_gameplay()
	if RenderingServer.frame_post_draw.is_connected(capture_view): RenderingServer.frame_post_draw.disconnect(capture_view)
	var summary = {"completed":completed,"reason":reason,"seconds":elapsed,"live_seconds":live_seconds,"local_possession_seconds":local_possession_seconds,"opponent_possession_seconds":contested_possession_seconds,"possessions_won":possessions_won,"actions":actions_count,"local_events":local_events,"initial_bots":initial_bot_count,"focus_recoveries":focus_recoveries,"kickoff_resets":kickoff_resets,"maximum_player_step_m":maximum_player_step,"maximum_dunk_step_m":maximum_dunk_step,"maximum_camera_step_m":maximum_camera_step,"maximum_dunk_camera_step_m":maximum_dunk_camera_step,"fixture_mutations":false,"network_client":not join_address.is_empty(),"sanity_only":sanity}
	summary["display_driver"] = DisplayServer.get_name()
	summary["application_version"] = ProjectSettings.get_setting("application/config/version", "unknown")
	summary["character"] = app.profile.outfit().get("character", "blank")
	summary["cosmetics"] = app.state.get("cosmetics", {}).duplicate(true)
	summary["network_client"] = not join_address.is_empty() or not room_url.is_empty()
	summary["transport"] = "room" if not room_url.is_empty() else ("enet" if not join_address.is_empty() else "offline")
	summary["snapshot_transport"] = app.snapshot_transport.duplicate()
	summary["mouse_mode"] = Input.mouse_mode
	summary["mode"] = selected_mode
	summary["peak_roster"] = peak_roster
	summary["capture_frames"] = capture_frames.size()
	summary["full_presentation"] = not app.scripted_session()
	summary["series_rounds"] = completed_rounds
	summary["distance_travelled_m"] = distance_travelled
	summary["coverage"] = {"move":distance_travelled > 5,"catch":int(local_events.get("grab",0)) > 0,"pass":int(local_events.get("pass",0)) > 0,"jump":int(local_events.get("jump",0)) > 0,"dunk":int(local_events.get("dunk",0)) > 0,"shot":int(local_events.get("throw",0)) > 0,"tackle":int(local_events.get("dive",0)) > 0}
	if is_instance_valid(app) and not app.state.is_empty():
		summary["scores"] = app.state.scores
		summary["winner"] = app.state.winner
		summary["sim_totals"] = {"grabs":app.state.grabs,"throws":app.state.throws,"dunks":app.state.dunks,"tackles":app.state.tackles,"baskets":app.state.baskets}
		summary["match_id"] = app.state.get("match_id", "")
		var peer_id = app.multiplayer.get_unique_id() if app.multiplayer_active() else -1
		var won = completed and int(app.state.players[app.local_seat].team) == int(app.state.winner)
		summary["peer_id"] = peer_id
		summary["seat"] = app.local_seat
		summary["snapshots"] = app.snapshot_count
		summary["reward_eligible_at_finish"] = peer_id in app.state.get("reward_peers", [])
		summary["reward_bags"] = int(app.profile.data.bags)
		var saved_profile = load("res://profile.gd").new(profile_path)
		var inventory_gain: int = saved_profile.data.inventory.size() - initial_inventory_count
		var redeemed: bool = str(app.state.get("match_id", "")) in saved_profile.data.redeemed
		summary["reward_inventory_gain"] = inventory_gain
		summary["reward_redeemed"] = redeemed
		summary["reward_saved_bags"] = int(saved_profile.data.bags)
		# A normal result-screen interaction can open the awarded bag. Verify
		# persistent entitlement and conservation, not only unopened bag count.
		var expected_rewards = completed_rounds.filter(func(round): return round.won).size() if play_series else (1 if won else 0)
		summary["reward_correct"] = redeemed == won and int(saved_profile.data.bags) + inventory_gain == expected_rewards and saved_profile.data.redeemed.size() == expected_rewards
		if completed and not summary.reward_correct:
			completed = false
			summary.completed = false
			summary.reason = "Result reached but saved reward invariant failed"
	var file = FileAccess.open(output_dir.path_join("active-play.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary":summary,"actions":actions,"events":events,"possessions":possessions,"samples":samples,"discontinuities":discontinuities}, "\t"))
		file.close()
	print("ACTIVE_PLAY " + JSON.stringify(summary))
	if not capture_frames.is_empty():
		var capture_file = FileAccess.open(output_dir.path_join("capture-timestamps.json"),FileAccess.WRITE)
		capture_file.store_string(JSON.stringify({"clock":"monotonic real time","requested_fps":capture_fps,"frames":capture_frames},"\t"))
		capture_file.close()
	for suffix in ["", ".bak", ".tmp"]:
		if not profile_path.is_empty() and FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	if settings_existed:
		var settings = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		settings.store_buffer(saved_settings)
		settings.close()
	elif FileAccess.file_exists("user://settings.cfg"):
		DirAccess.remove_absolute("user://settings.cfg")
	quit(0 if completed or sanity else 1)
