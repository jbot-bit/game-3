extends Node3D
## Hands Full: compact LAN physics game. The old fishing save is separate.
const Network = preload("res://prototypes/physics_party/party_session.gd")
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
const World = preload("res://prototypes/physics_party/party_world.gd")
const HUD = preload("res://prototypes/physics_party/party_hud.gd")
const Rules = preload("res://prototypes/physics_party/party_rules.gd")
const Audio = preload("res://prototypes/physics_party/party_audio.gd")
const Presentation = preload("res://prototypes/physics_party/party_presentation.gd")
const COLORS = [Color("ef805f"), Color("58c9b6"), Color("9c9fe8")]
var session: Node
var world: Node3D
var hud: CanvasLayer
var camera: Camera3D
var avatars: Dictionary = {}
var inputs: Dictionary = {}
var actor_bones: Dictionary = {}
var rules = Rules.new()
var rng = RandomNumberGenerator.new()
var state: Dictionary = {}
var run_id = ""
var yaw = 0.0
var pitch = -0.18
var input_tick = 0
var input_clock = 0.0
var pose_clock = 0.0
var state_clock = 0.0
var switch_cooldown = 0.0
var recover_cooldowns: Dictionary = {}
var progress_path = "user://physics_party/progress.json"
var game_port = Network.PORT
var scripted = false
var show_fps = false
var diagnostics: Label
var save_error = ""
var completion_powers: Array = []
var audio: Node
var presentation = Presentation.new()
var camera_focus = Vector3.ZERO
var camera_ready = false
var quitting = false

func _ready() -> void:
	DisplayServer.window_set_title("Hands Full")
	Engine.max_fps = 120
	get_tree().auto_accept_quit = false
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	session = Network.new()
	session.name = "PartySession"
	add_child(session)
	session.players_changed.connect(_roster_changed)
	session.controls_received.connect(_controls)
	session.action_received.connect(_action)
	session.state_received.connect(_state_received)
	session.poses_received.connect(_poses_received)
	session.status_changed.connect(_status)
	hud = HUD.new()
	add_child(hud)
	hud.host_requested.connect(_host)
	hud.join_requested.connect(_join)
	hud.leave_requested.connect(_leave)
	hud.quit_requested.connect(_request_quit)
	hud.power_chosen.connect(func(id): session.act("power", id))
	hud.restart_requested.connect(func(): session.act("restart"))
	hud.resume_requested.connect(func(): hud.show_game(); hud.update_view(state, session.local_id, session.hosting))
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65
	camera.far = 160
	add_child(camera)
	_make_world(false)
	camera.position = Vector3(22, 24, 22)
	camera.look_at(Vector3(0, 0, -12))
	diagnostics = Label.new()
	diagnostics.position = Vector2(20, 160)
	diagnostics.add_theme_font_size_override("font_size", 14)
	hud.add_child(diagnostics)
	hud.show_menu()

func _make_world(authority: bool) -> void:
	camera_ready = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.authoritative = authority
	add_child(world)

func _host(player_name: String) -> void:
	var loaded: Dictionary = rules.load_progress(progress_path)
	if not loaded.get("ok", false):
		hud.show_menu("Progress file needs attention. Existing file preserved.")
		return
	_make_world(true)
	_new_run_state()
	if session.host(player_name, game_port) != OK: return
	hud.show_game()
	_publish()

func _join(address: String, player_name: String) -> void:
	_make_world(false)
	state.clear()
	run_id = ""
	session.join(address, player_name, game_port)

func _leave() -> void:
	session.close()
	audio.reset()
	presentation.reset()
	camera_ready = false
	state.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.reset_session()

func _status(message: String) -> void:
	if session.connected:
		hud.show_game()
	else:
		hud.reset_session(message)

func _new_run_state() -> void:
	run_id = Crypto.new().generate_random_bytes(12).hex_encode()
	inputs.clear()
	recover_cooldowns.clear()
	switch_cooldown = 0.0
	save_error = ""
	completion_powers.clear()
	state = {"run_id": run_id, "players": {}, "offers": {}, "phase": "play", "checkpoint": 0,
		"wind": 1, "note": "Look down to grab. Look up to lift.",
		"level": rules.progress.get("level", 1), "completions": rules.progress.get("completions", 0),
		"unlocked_power_ids": rules.progress.get("unlocked_power_ids", []).duplicate(),
		"join_address": _local_addresses()}

func _local_addresses() -> String:
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if ":" in address or address.begins_with("127.") or address.begins_with("169.254."): continue
		var private_172 = address.begins_with("172.") and int(address.get_slice(".", 1)) >= 16 and int(address.get_slice(".", 1)) <= 31
		if address.begins_with("10.") or address.begins_with("192.168.") or private_172:
			addresses.append(address)
	addresses.sort()
	# Typical home LAN addresses precede virtual-machine adapters.
	var home_first: PackedStringArray = []
	for address in addresses:
		if address.begins_with("192.168."): home_first.append(address)
	for address in addresses:
		if not address.begins_with("192.168."): home_first.append(address)
	return " / ".join(home_first) if not home_first.is_empty() else "Check this PC's network settings"

func _found_powers() -> Array:
	var powers: Array = []
	for player in state.get("players", {}).values():
		var id = str(player.get("power", ""))
		if not id.is_empty() and id not in powers: powers.append(id)
	return powers

func _roster_changed(roster: Dictionary) -> void:
	# Removing a body must also release other hands attached to it.
	for id in avatars.keys():
		if not roster.has(id):
			for actor in avatars.values(): actor.release_grabs_to(avatars[id])
			avatars[id].release_all()
			avatars[id].queue_free()
			avatars.erase(id)
			actor_bones.erase(id)
			inputs.erase(id)
	world.track_puppets(avatars.values())
	if roster.is_empty(): return
	for id in roster:
		if not avatars.has(id):
			var actor = Puppet.instantiate()
			actor.name = id
			actor.authoritative = session.hosting
			add_child(actor)
			actor.setup_color(COLORS[int(roster[id].slot)])
			actor.reset_at(world.spawn_point(int(roster[id].slot), int(state.get("checkpoint", 0))))
			avatars[id] = actor
			actor_bones[id] = actor.find_children("*", "PhysicalBone3D", true, false)
	world.track_puppets(avatars.values())
	if session.hosting:
		for id in state.players.keys():
			if not roster.has(id):
				state.players.erase(id)
				state.offers.erase(id)
		for id in roster:
			if not state.players.has(id):
				state.players[id] = {"name": roster[id].name, "power": "", "finished": false, "checkpoint": int(state.checkpoint)}
				state.offers[id] = rules.draw_offers(rng)
		_publish()

func _controls(id: String, data: Dictionary) -> void:
	if not avatars.has(id): return
	inputs[id] = {"data": data.duplicate(), "at": Time.get_ticks_msec()}

func _action(id: String, action: String, value: String) -> void:
	if not session.hosting or not state.get("players", {}).has(id): return
	match action:
		"power":
			if state.phase != "play" or not str(state.players[id].power).is_empty(): return
			if value not in state.offers.get(id, []) and value not in state.get("unlocked_power_ids", []): return
			state.players[id].power = value
			avatars[id].set_power(value)
		"switch":
			if state.phase != "play" or switch_cooldown > 0.0: return
			if avatars[id].body_position().distance_to(world.switch_position) > 4.0: return
			state.wind = -int(state.wind)
			switch_cooldown = 2.0
			world.set_wind(state.wind)
			state.note = "%s reversed the fan." % state.players[id].name
		"recover":
			if float(recover_cooldowns.get(id, 0.0)) > 0.0: return
			_recover(id)
		"restart":
			if id != "crew_1": return
			_restart()
	_publish()

func _recover(id: String) -> void:
	for actor in avatars.values(): actor.release_grabs_to(avatars[id])
	avatars[id].release_all()
	avatars[id].reset_at(world.spawn_point(int(session.players[id].slot), int(state.players[id].checkpoint)))
	if id == session.local_id: camera_ready = false
	recover_cooldowns[id] = 1.0

func _restart() -> void:
	if not save_error.is_empty():
		var retried: Dictionary = rules.complete(run_id, completion_powers)
		if not retried.get("ok", false):
			state.note = "Progress could not be saved. Free some disk space, then retry."
			_publish()
			return
		save_error = ""
	for actor in avatars.values(): actor.release_all()
	_new_run_state()
	camera_ready = false
	world.reset_props()
	world.set_wind(1)
	for id in avatars:
		avatars[id].set_power("")
		avatars[id].reset_at(world.spawn_point(int(session.players[id].slot), 0))
	_roster_changed(session.players)

func _publish() -> void:
	if session.hosting and not state.is_empty(): session.publish_state(state)

func _state_received(data: Dictionary) -> void:
	audio.update_state(data, session.local_id)
	if not session.hosting:
		var changed = str(data.get("run_id", "")) != run_id
		state = data.duplicate(true)
		run_id = str(data.get("run_id", ""))
		if changed:
			presentation.reset()
			camera_ready = false
			world.reset_props()
		world.set_wind(int(state.get("wind", 1)))
		for id in avatars:
			avatars[id].set_power(str(state.get("players", {}).get(id, {}).get("power", "")))
	if session.connected: hud.update_view(state, session.local_id, session.hosting)

func _poses_received(data: Dictionary) -> void:
	if session.hosting or data.get("run_id", "") != run_id: return
	presentation.push(data, float(Time.get_ticks_msec()))

func _neutral() -> Dictionary:
	return {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "jump": false, "left": false, "right": false, "limp": false, "tick": input_tick}

func _local_controls() -> Dictionary:
	var data = _neutral()
	if scripted or hud.blocks_input() or state.get("phase", "") != "play": return data
	var keys = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length(1.0)
	var direction = Basis(Vector3.UP, yaw) * Vector3(keys.x, 0, keys.y)
	data.move = Vector2(direction.x, direction.z)
	data.yaw = yaw
	data.pitch = pitch
	data.jump = Input.is_physical_key_pressed(KEY_SPACE)
	data.left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	data.right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	data.limp = Input.is_physical_key_pressed(KEY_R)
	return data

func _physics_process(delta: float) -> void:
	if not session.connected: return
	input_clock += delta
	if not scripted and input_clock >= 1.0 / 30.0:
		input_clock = 0.0
		input_tick += 1
		session.controls(_local_controls())
	if not session.hosting: return
	switch_cooldown = maxf(0.0, switch_cooldown - delta)
	for id in recover_cooldowns: recover_cooldowns[id] = maxf(0.0, float(recover_cooldowns[id]) - delta)
	for id in avatars:
		var control: Dictionary = inputs.get(id, {}).get("data", _neutral())
		if Time.get_ticks_msec() - int(inputs.get(id, {}).get("at", -1000)) > 350: control = _neutral()
		if state.phase != "play" or str(state.players[id].power).is_empty(): control = _neutral()
		avatars[id].set_controls(control)
		var body_position: Vector3 = avatars[id].body_position()
		if not body_position.is_finite() or body_position.y < -12.0 or body_position.length() > 150.0:
			_recover(id)
		elif state.phase == "play":
			var wind: Vector3 = world.wind_at(body_position)
			for bone in actor_bones[id]: bone.linear_velocity += wind * delta
			if world.checkpoint_contains(body_position): state.players[id].checkpoint = 1
			if world.goal_contains(body_position): state.players[id].finished = true
	var all_crossed = not avatars.is_empty()
	var all_finished = not avatars.is_empty()
	for id in avatars:
		all_crossed = all_crossed and int(state.players[id].checkpoint) > 0
		all_finished = all_finished and bool(state.players[id].finished)
	if all_crossed: state.checkpoint = 1
	if all_finished and state.phase == "play":
		completion_powers = _found_powers()
		var result: Dictionary = rules.complete(run_id, completion_powers)
		state.phase = "complete"
		state.level = rules.progress.get("level", 1)
		state.completions = rules.progress.get("completions", 0)
		state.unlocked_power_ids = rules.progress.get("unlocked_power_ids", []).duplicate()
		state.save_failed = not result.get("ok", false)
		save_error = "save_failed" if state.save_failed else ""
		state.note = "Everyone made it." if result.get("ok", false) else "Course complete. Progress could not be saved."
		_publish()
	pose_clock += delta
	state_clock += delta
	if pose_clock >= 1.0 / 30.0:
		pose_clock = 0.0
		var poses: Dictionary = {}
		for id in avatars: poses[id] = avatars[id].capture_pose()
		session.publish_poses({"run_id": run_id, "pose_msec": Engine.get_physics_frames() * (1000.0 / 60.0), "puppets": poses, "props": world.capture_prop_poses()})
	if state_clock >= 0.2:
		state_clock = 0.0
		_publish()

func _process(delta: float) -> void:
	if not is_instance_valid(hud): return
	if session.connected and not session.hosting:
		var frame: Dictionary = presentation.sample(float(Time.get_ticks_msec()))
		for id in frame.get("puppets", {}):
			if avatars.has(id): avatars[id].present_pose(frame.puppets[id])
		world.present_prop_poses(frame.get("props", {}))
	if not scripted:
		var capture = session.connected and not hud.blocks_input() and state.get("phase", "") == "play"
		var desired = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != desired: Input.mouse_mode = desired
	_update_camera(delta)
	diagnostics.visible = show_fps
	if show_fps: diagnostics.text = "%d FPS · %d physical players · %d props" % [Engine.get_frames_per_second(), avatars.size(), world.props.size()]

func _update_camera(delta: float) -> void:
	if avatars.has(session.local_id):
		var target: Vector3 = avatars[session.local_id].visual_position() + Vector3.UP * 0.5
		if not camera_ready or camera_focus.distance_squared_to(target) > 144.0:
			camera_focus = target
			camera_ready = true
		else:
			camera_focus = camera_focus.lerp(target, 1.0 - exp(-14.0 * delta))
		var arm = Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, pitch) * Vector3(0, 3.0, 10.0))
		var desired: Vector3 = camera_focus + arm
		# Only solid course geometry can pull the camera inward. A teammate or
		# held plank passing behind us must not cause an unwanted zoom.
		var query = PhysicsRayQueryParameters3D.create(camera_focus, desired)
		var exclusions: Array[RID] = []
		for bones in actor_bones.values():
			for bone in bones: exclusions.append(bone.get_rid())
		for prop in world.props.values(): exclusions.append(prop.get_rid())
		query.exclude = exclusions
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position + hit.normal * 0.25
		# Smooth the follow point, not mouse orbit: turning is immediate.
		camera.global_position = desired
		if camera.global_position.distance_to(camera_focus) > 0.1: camera.look_at(camera_focus)

func _unhandled_input(event: InputEvent) -> void:
	if scripted: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if session.connected:
					if hud.is_menu_open(): hud.show_game(); hud.update_view(state, session.local_id, session.hosting)
					else: hud.show_menu("Connected — Esc to return")
			KEY_F3: show_fps = not show_fps
			KEY_M:
				if session.connected and not hud.is_menu_open(): audio.toggle_mute()
			KEY_F:
				if not hud.blocks_input(): session.act("recover")
			KEY_E:
				if not hud.blocks_input(): session.act("switch")
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.relative.x * 0.003, -PI, PI)
		pitch = clampf(pitch - event.relative.y * 0.002, -0.65, 0.4)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _request_quit()

func _request_quit() -> void:
	if quitting: return
	quitting = true
	_leave()
	# Let the audio mixer release active voices before process teardown.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_inside_tree(): get_tree().auto_accept_quit = true
