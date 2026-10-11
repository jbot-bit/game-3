extends Node3D
## Hands Full: compact LAN physics game. The old fishing save is separate.
const Network = preload("res://prototypes/physics_party/party_session.gd")
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
const World = preload("res://prototypes/physics_party/party_world.gd")
const CounterweightWorld = preload("res://prototypes/physics_party/party_counterweight_world.gd")
const LevelWorld = preload("res://prototypes/physics_party/party_level_world.gd")
const Teamwork = preload("res://prototypes/physics_party/party_teamwork.gd")
const Modes = preload("res://prototypes/physics_party/party_modes.gd")
const ArenaWorld = preload("res://prototypes/physics_party/party_arena_world.gd")
const WipeoutWorld = preload("res://prototypes/physics_party/party_wipeout_world.gd")
const KnockoutWorld = preload("res://prototypes/physics_party/party_knockout_world.gd")
const Match = preload("res://prototypes/physics_party/party_match.gd")
const Race = preload("res://prototypes/physics_party/party_race.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const HUD = preload("res://prototypes/physics_party/party_hud.gd")
const Rules = preload("res://prototypes/physics_party/party_rules.gd")
const Audio = preload("res://prototypes/physics_party/party_audio.gd")
const Presentation = preload("res://prototypes/physics_party/party_presentation.gd")
const COLORS = [Color("ff9c44"), Color("4dabf7"), Color("b591ff")]
var session: Node
var world: Node3D
var teamwork: Node3D
var contest: RefCounted
var race: RefCounted
var mode_id: String = "coop"
# Dedicated physics/save probes can isolate the original approach course.
# The shipped scene always includes the three-player stages.
var teamwork_enabled: bool = true
var hud: CanvasLayer
var camera: Camera3D
var avatars: Dictionary = {}
var inputs: Dictionary = {}
var actor_bones: Dictionary = {}
var spectators: Dictionary = {}
var rules = Rules.new()
var rng = RandomNumberGenerator.new()
var state: Dictionary = {}
var run_id = ""
var course_id = "crossing"
var yaw = 0.0
var pitch = -0.18
var input_tick = 0
var input_clock = 0.0
var jump_pending = false
var attack_pending: bool = false
var grapple_mode = "pull"
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
var completion_cosmetics: Array = []
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
	hud.next_course_requested.connect(func(): session.act("next_course"))
	hud.appearance_chosen.connect(func(style: Dictionary):
		session.act("appearance", str(style.get("color", "")) + "|" + str(style.get("accessory", ""))))
	hud.resume_requested.connect(func(): hud.show_game(); hud.update_view(state, session.local_id, session.hosting))
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65
	camera.far = 400
	add_child(camera)
	_make_world(false)
	camera.position = Vector3(22, 24, 22)
	camera.look_at(Vector3(0, 0, -12))
	diagnostics = Label.new()
	diagnostics.position = Vector2(20, 160)
	diagnostics.add_theme_font_size_override("font_size", 14)
	hud.add_child(diagnostics)
	hud.show_menu()

func _make_world(authority: bool, selected_course: String = "crossing", selected_mode: String = "") -> void:
	assert(Courses.valid(selected_course))
	if not selected_mode.is_empty(): mode_id = selected_mode
	assert(Modes.valid(mode_id))
	camera_ready = false
	presentation.reset()
	for id in avatars:
		_set_spectator(id, false)
		avatars[id].release_all()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	teamwork = null
	contest = null
	race = null
	course_id = selected_course
	# Fixed paths only: replicated IDs never become resource paths.
	if mode_id == "gladiator":
		world = ArenaWorld.new()
	elif mode_id == "knockout":
		world = KnockoutWorld.new()
	elif mode_id == "wipeout":
		world = WipeoutWorld.new()
	elif course_id == "crossing":
		world = World.new()
	elif course_id == "counterweight":
		world = CounterweightWorld.new()
	else:
		world = LevelWorld.new()
		world.course_id = course_id
	world.authoritative = authority
	add_child(world)
	if teamwork_enabled and mode_id == "coop":
		teamwork = Teamwork.new()
		teamwork.world = world
		teamwork.course_id = course_id
		world.add_child(teamwork)
	if Modes.is_ring_match(mode_id):
		contest = Match.new()
		contest.configure(world)
	elif mode_id == "wipeout":
		race = Race.new()
		race.configure(world)
	for actor in avatars.values(): actor.set_combat_visual(Modes.is_ring_match(mode_id), 0.0, false, 0.0)
	world.track_puppets(avatars.values())

func _host(player_name: String, selected_course: String = "", selected_mode: String = "") -> void:
	var requested: String = hud.selected_course_id() if selected_course.is_empty() else selected_course
	var requested_mode: String = hud.selected_mode_id() if selected_mode.is_empty() else selected_mode
	if not Courses.valid(requested) or not Modes.valid(requested_mode):
		hud.show_menu("Unknown course.")
		return
	var loaded: Dictionary = rules.load_progress(progress_path)
	if not loaded.get("ok", false):
		hud.show_menu("Progress file needs attention. Existing file preserved.")
		return
	_make_world(true, requested, requested_mode)
	_new_run_state()
	if session.host(player_name, game_port) != OK: return
	hud.show_game()
	_publish()

func _join(address: String, player_name: String) -> void:
	_make_world(false, "crossing", "coop")
	state.clear()
	run_id = ""
	session.join(address, player_name, game_port)

func _leave() -> void:
	jump_pending = false
	attack_pending = false
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
	jump_pending = false
	attack_pending = false
	run_id = Crypto.new().generate_random_bytes(12).hex_encode()
	inputs.clear()
	recover_cooldowns.clear()
	switch_cooldown = 0.0
	save_error = ""
	completion_powers.clear()
	completion_cosmetics.clear()
	state = {"run_id": run_id, "players": {}, "offers": {}, "phase": "play", "checkpoint": 0,
		"mode_id": mode_id,
		"course_id": course_id, "course_name": Courses.course_name(course_id),
		"course_number": Courses.number(course_id), "course_count": Courses.IDS.size(),
		"next_course_name": Courses.course_name(Courses.next_id(course_id)),
		"wind": 1, "note": world.intro_text() if world.has_method("intro_text") else "Look down to grab. Look up to lift.",
		"level": rules.progress.get("level", 1), "completions": rules.progress.get("completions", 0),
		"unlocked_power_ids": rules.progress.get("unlocked_power_ids", []).duplicate(),
		"cosmetic_cards": _cosmetic_collection(), "reward_cards": [], "reward_run_id": "", "reward_duplicates": [],
		"join_address": _local_addresses()}
	_update_teamwork_state()
	_update_mode_state()

func _update_mode_state() -> void:
	if contest != null:
		state.match = contest.capture()
		state.mode_text = contest.status_text()
		for id in state.get("players", {}): state.mode_text = state.mode_text.replace(str(id), str(state.players[id].name))
		state.mode_hint = contest.hint_text()
	elif race != null:
		state.challenge = race.capture()
		state.mode_text = race.status_text()
		state.mode_hint = race.hint_text()
		for id in state.get("players", {}):
			var runner: Dictionary = state.challenge.runners.get(id, {})
			state.players[id].checkpoint = int(runner.get("checkpoint", 0))
			state.players[id].finished = bool(runner.get("finished", false))
			state.players[id].falls = int(runner.get("falls", 0))

func _cosmetic_collection() -> Array:
	return rules.cosmetic_collection() if rules.has_method("cosmetic_collection") else []

func _saved_appearance(slot: int) -> Dictionary:
	return rules.appearance_for(slot) if rules.has_method("appearance_for") else Cosmetics.default_style(slot)

func _refresh_rewards() -> void:
	state.cosmetic_cards = _cosmetic_collection()
	state.reward_cards = []
	state.reward_run_id = ""
	state.reward_duplicates = []
	if not rules.has_method("last_reward") or not save_error.is_empty(): return
	var reward: Dictionary = rules.last_reward()
	if reward.get("run_id", "") != run_id: return
	state.reward_cards = reward.get("cards", []).duplicate()
	state.reward_run_id = run_id
	for card in state.reward_cards:
		if card in completion_cosmetics: state.reward_duplicates.append(card)

func _update_teamwork_state() -> void:
	if not is_instance_valid(teamwork): return
	state.teamwork = teamwork.capture()
	state.teamwork_text = teamwork.status_text(avatars.size())
	state.teamwork_hint = teamwork.hint_text()

func _spawn_point(slot: int, checkpoint: int = 0) -> Vector3:
	if checkpoint >= 2 and is_instance_valid(teamwork): return teamwork.checkpoint_spawn(slot)
	return world.spawn_point(slot, checkpoint)

func _goal_spawn(slot: int) -> Vector3:
	if mode_id == "wipeout": return world.goal_spawn(slot)
	return teamwork.goal_spawn(slot) if is_instance_valid(teamwork) else world.spawn_point(slot, 2)

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
			spectators.erase(id)
			inputs.erase(id)
	world.track_puppets(avatars.values())
	if roster.is_empty(): return
	for id in roster:
		if not avatars.has(id):
			var actor = Puppet.instantiate()
			actor.name = id
			actor.authoritative = session.hosting
			add_child(actor)
			actor.visible = session.hosting
			actor.setup_color(COLORS[int(roster[id].slot)])
			actor.reset_at(_spawn_point(int(roster[id].slot), int(state.get("checkpoint", 0))))
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
				state.players[id] = {"name": roster[id].name, "power": "", "finished": false, "checkpoint": int(state.checkpoint), "appearance": _saved_appearance(int(roster[id].slot))}
				state.offers[id] = rules.draw_offers(rng)
			avatars[id].set_appearance(state.players[id].appearance)
			if mode_id != "coop": avatars[id].set_power("")
		_update_teamwork_state()
		_update_mode_state()
		_sync_spectators()
		_publish()

func _controls(id: String, data: Dictionary) -> void:
	if not avatars.has(id): return
	inputs[id] = {"data": data.duplicate(), "at": Time.get_ticks_msec()}

func _action(id: String, action: String, value: String) -> void:
	if not session.hosting or not state.get("players", {}).has(id): return
	match action:
		"appearance":
			if not rules.has_method("set_appearance"): return
			var parts: PackedStringArray = value.split("|")
			if parts.size() != 2: return
			var style: Dictionary = {"color": parts[0], "accessory": parts[1]}
			var result: Dictionary = rules.set_appearance(int(session.players[id].slot), style)
			state.appearance_error = "" if result.get("ok", false) else "That look is locked, or could not be saved."
			if result.get("ok", false):
				state.players[id].appearance = style
				avatars[id].set_appearance(style)
		"power":
			if mode_id != "coop": return
			if state.phase != "play" or not str(state.players[id].power).is_empty(): return
			if value not in state.offers.get(id, []) and value not in state.get("unlocked_power_ids", []): return
			state.players[id].power = value
			avatars[id].set_power(value)
		"switch":
			if mode_id != "coop": return
			if state.phase != "play" or switch_cooldown > 0.0: return
			if avatars[id].body_position().distance_to(world.switch_position) > 4.0: return
			state.wind = -int(state.wind)
			switch_cooldown = 2.0
			world.set_wind(state.wind)
			state.note = "%s reversed the fan." % state.players[id].name
		"recover":
			if state.phase != "play": return
			if float(recover_cooldowns.get(id, 0.0)) > 0.0: return
			if contest != null:
				contest.forfeit(id)
				recover_cooldowns[id] = 1.0
			elif race != null:
				if not race.controls_allowed(id): return
				race.recover(id)
				_update_mode_state()
				_recover(id)
			else: _recover(id)
		"restart":
			if id != "crew_1": return
			_restart()
		"next_course":
			if mode_id != "coop": return
			if id != "crew_1" or state.phase != "complete": return
			_restart(Courses.next_id(course_id))
	_publish()

func _recover(id: String) -> void:
	if is_instance_valid(teamwork): teamwork.forget_actor(id)
	for actor in avatars.values(): actor.release_grabs_to(avatars[id])
	avatars[id].release_all()
	avatars[id].reset_at(_spawn_point(int(session.players[id].slot), int(state.players[id].checkpoint)))
	if id == session.local_id: camera_ready = false
	recover_cooldowns[id] = 1.0

func _restart(target_course: String = "") -> void:
	var next_id: String = course_id if target_course.is_empty() else target_course
	if not Courses.valid(next_id): return
	if not save_error.is_empty():
		var retried: Dictionary = rules.complete(run_id, completion_powers)
		if not retried.get("ok", false):
			state.note = "Progress could not be saved. Free some disk space, then retry."
			_publish()
			return
		save_error = ""
		state.save_failed = false
		state.completions = rules.progress.get("completions", 0)
		state.level = rules.progress.get("level", 1)
		state.unlocked_power_ids = rules.progress.get("unlocked_power_ids", []).duplicate()
		_refresh_rewards()
		if target_course.is_empty():
			state.note = "Saved. Your surprise bag is ready."
			_publish()
			return
	for actor in avatars.values(): actor.release_all()
	if next_id != course_id: _make_world(true, next_id)
	if contest != null: contest.reset()
	if race != null: race.reset()
	_new_run_state()
	camera_ready = false
	world.reset_props()
	if is_instance_valid(teamwork): teamwork.reset()
	_update_teamwork_state()
	world.set_wind(1)
	for id in avatars:
		_set_spectator(id, false)
		avatars[id].set_power("")
		avatars[id].reset_at(world.spawn_point(int(session.players[id].slot), 0))
	if hud.is_menu_open(): hud.show_game()
	_roster_changed(session.players)

func _publish() -> void:
	if session.hosting and not state.is_empty(): session.publish_state(state)

func _state_received(data: Dictionary) -> void:
	var received_course: String = str(data.get("course_id", "crossing"))
	var received_mode: String = str(data.get("mode_id", "coop"))
	if not Courses.valid(received_course) or not Modes.valid(received_mode): return
	audio.update_state(data, session.local_id)
	if not session.hosting:
		var changed = str(data.get("run_id", "")) != run_id
		var changed_course = course_id != received_course or mode_id != received_mode
		if changed_course: _make_world(false, received_course, received_mode)
		state = data.duplicate(true)
		run_id = str(data.get("run_id", ""))
		if changed:
			presentation.reset()
			camera_ready = false
			world.reset_props()
			# Hide old poses until the first snapshot for this run arrives.
			for actor in avatars.values():
				actor.release_all()
				actor.visible = false
		world.set_wind(int(state.get("wind", 1)))
		# The reliable state initializes a run; later geometry shares the bodies'
		# render timeline so low-rate HUD updates cannot snap a moving lift back.
		if (changed or changed_course) and is_instance_valid(teamwork): teamwork.present(state.get("teamwork", {}))
		if (changed or changed_course) and contest != null: contest.present(state.get("match", {}), avatars)
		for id in avatars:
			avatars[id].set_power(str(state.get("players", {}).get(id, {}).get("power", "")))
			var slot: int = int(session.players.get(id, {}).get("slot", 0))
			var style: Variant = state.get("players", {}).get(id, {}).get("appearance", Cosmetics.default_style(slot))
			if style is Dictionary: avatars[id].set_appearance(Cosmetics.sanitize(style, state.get("cosmetic_cards", []), slot))
	if session.connected: hud.update_view(state, session.local_id, session.hosting)

func _poses_received(data: Dictionary) -> void:
	if session.hosting or data.get("run_id", "") != run_id: return
	presentation.push(data, float(Time.get_ticks_msec()))

func _neutral() -> Dictionary:
	return {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "jump": false, "left": false, "right": false, "limp": false, "tick": input_tick,
		"grapple": false, "grapple_mode": grapple_mode, "aim": Vector3.ZERO, "interact": false, "attack": false, "brace": false}

func _grapple_aim() -> Vector3:
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var origin: Vector3 = camera.project_ray_origin(center)
	var end: Vector3 = origin + camera.project_ray_normal(center) * 65.0
	var ray = PhysicsRayQueryParameters3D.create(origin, end)
	var exclusions: Array[RID] = []
	for bone in actor_bones.get(session.local_id, []): exclusions.append(bone.get_rid())
	ray.exclude = exclusions
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if not hit.is_empty() else end

func _local_controls() -> Dictionary:
	var data = _neutral()
	data.yaw = yaw
	data.pitch = pitch
	# A short tap can begin and end between the 30 Hz network samples.
	var tapped_jump = jump_pending
	var tapped_attack: bool = attack_pending
	jump_pending = false
	attack_pending = false
	if scripted or hud.blocks_input() or state.get("phase", "") != "play": return data
	var keys = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length(1.0)
	var direction = Basis(Vector3.UP, yaw) * Vector3(keys.x, 0, keys.y)
	data.move = Vector2(direction.x, direction.z)
	data.jump = tapped_jump or Input.is_physical_key_pressed(KEY_SPACE)
	data.left = mode_id == "coop" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	data.right = mode_id == "coop" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	data.attack = Modes.is_ring_match(mode_id) and (tapped_attack or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	data.brace = Modes.is_ring_match(mode_id) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	data.limp = Input.is_physical_key_pressed(KEY_R)
	data.grapple = mode_id == "coop" and Input.is_physical_key_pressed(KEY_Q)
	data.interact = mode_id == "coop" and Input.is_physical_key_pressed(KEY_E)
	if mode_id == "coop": data.aim = _grapple_aim()
	return data

func _physics_process(delta: float) -> void:
	if not session.connected: return
	input_clock += delta
	# The host can consume local input every simulation tick. Network clients
	# retain the existing packet rate independently of local host responsiveness.
	if not scripted and (session.hosting or input_clock >= 1.0 / 30.0):
		input_clock = 0.0
		input_tick += 1
		session.controls(_local_controls())
	if not session.hosting: return
	switch_cooldown = maxf(0.0, switch_cooldown - delta)
	for id in recover_cooldowns: recover_cooldowns[id] = maxf(0.0, float(recover_cooldowns[id]) - delta)
	if mode_id != "coop":
		_tick_mode(delta)
		_send_frames(delta)
		return
	var active_controls: Dictionary = {}
	for id in avatars:
		var control: Dictionary = inputs.get(id, {}).get("data", _neutral())
		if Time.get_ticks_msec() - int(inputs.get(id, {}).get("at", -1000)) > 350: control = _neutral()
		if state.phase != "play" or str(state.players[id].power).is_empty(): control = _neutral()
		avatars[id].set_controls(control)
		active_controls[id] = control
		var body_position: Vector3 = avatars[id].body_position()
		if not body_position.is_finite() or body_position.y < -12.0 or body_position.length() > 600.0:
			_recover(id)
		elif state.phase == "play":
			var wind: Vector3 = world.wind_at(body_position)
			for bone in actor_bones[id]: bone.linear_velocity += wind * delta
			if world.checkpoint_contains(body_position): state.players[id].checkpoint = maxi(1, int(state.players[id].checkpoint))
			if is_instance_valid(teamwork):
				if world.goal_contains(body_position) and int(state.players[id].checkpoint) >= 1:
					state.players[id].checkpoint = maxi(2, int(state.players[id].checkpoint))
				if teamwork.goal_contains(body_position): state.players[id].finished = true
			elif world.goal_contains(body_position): state.players[id].finished = true
	if is_instance_valid(teamwork) and state.phase == "play":
		teamwork.tick(avatars, active_controls, delta)
		var checkpoint: int = teamwork.checkpoint_number()
		if checkpoint > 0:
			for id in state.players: state.players[id].checkpoint = maxi(checkpoint, int(state.players[id].checkpoint))
		_update_teamwork_state()
	var all_crossed = not avatars.is_empty()
	var all_finished = not avatars.is_empty()
	for id in avatars:
		all_crossed = all_crossed and int(state.players[id].checkpoint) > 0
		all_finished = all_finished and bool(state.players[id].finished)
	if all_crossed:
		var shared_checkpoint: int = 5
		for player in state.players.values(): shared_checkpoint = mini(shared_checkpoint, int(player.checkpoint))
		state.checkpoint = maxi(int(state.checkpoint), shared_checkpoint)
	if is_instance_valid(teamwork): all_finished = all_finished and avatars.size() == 3 and teamwork.completed()
	if all_finished and state.phase == "play":
		_finish_run(true)
	_send_frames(delta)

func _tick_mode(delta: float) -> void:
	var controls: Dictionary = {}
	for id in avatars:
		var data: Dictionary = inputs.get(id, {}).get("data", _neutral()).duplicate()
		if Time.get_ticks_msec() - int(inputs.get(id, {}).get("at", -1000)) > 350: data = _neutral()
		var allowed: bool = contest.controls_allowed(id) if contest != null else race.controls_allowed(id)
		if state.phase != "play" or not allowed: data = _neutral()
		# Enforce the mode rules on the host too; custom clients cannot grapple,
		# grab a rival or bring an earned power into a competitive round.
		data.grapple = false
		data.left = false
		data.right = false
		data.interact = false
		if contest == null:
			data.attack = false
			data.brace = false
		elif data.get("brace", false):
			data.move *= 0.45
		avatars[id].set_controls(data)
		controls[id] = data
	if state.phase != "play": return
	var event: Dictionary = contest.tick(avatars, controls, delta) if contest != null else race.tick(avatars, delta)
	_update_mode_state()
	_sync_spectators()
	for id in event.get("reset_ids", []):
		if not avatars.has(id): continue
		_recover(id)
	for id in event.get("reset_goal_ids", []):
		if avatars.has(id): avatars[id].reset_at(_goal_spawn(int(session.players[id].slot)))
	if event.get("completed", false):
		_finish_run(bool(event.get("reward", true)))

func _sync_spectators() -> void:
	if not session.hosting: return
	var current: Dictionary = contest.capture() if contest != null else {}
	for id in avatars:
		var excluded: bool = current.get("phase", "") in ["fight", "intermission", "complete"] and not id in current.get("alive", [])
		_set_spectator(id, excluded)

func _set_spectator(id: String, enabled: bool) -> void:
	if not avatars.has(id) or enabled == spectators.has(id): return
	var actor = avatars[id]
	if enabled:
		var collisions: Array[Vector2i] = []
		actor.release_all()
		actor.set_controls(_neutral())
		actor.set_physics_process(false)
		actor.physical_skel.physical_bones_stop_simulation()
		for bone in actor_bones.get(id, []):
			collisions.append(Vector2i(bone.collision_layer, bone.collision_mask))
			bone.collision_layer = 0
			bone.collision_mask = 0
		spectators[id] = collisions
		actor.visible = false
	else:
		var collisions: Array = spectators[id]
		var bones: Array = actor_bones.get(id, [])
		for index in bones.size():
			bones[index].collision_layer = collisions[index].x
			bones[index].collision_mask = collisions[index].y
		spectators.erase(id)
		actor.physical_skel.physical_bones_start_simulation()
		actor.set_physics_process(true)
		actor.visible = true

func _finish_run(reward: bool) -> void:
	if state.phase != "play": return
	state.phase = "complete"
	if not reward:
		state.note = "No finisher this time. Try again."
		_publish()
		return
	completion_powers = _found_powers() if mode_id == "coop" else []
	completion_cosmetics = _cosmetic_collection()
	var result: Dictionary = rules.complete(run_id, completion_powers)
	state.level = rules.progress.get("level", 1)
	state.completions = rules.progress.get("completions", 0)
	state.unlocked_power_ids = rules.progress.get("unlocked_power_ids", []).duplicate()
	state.save_failed = not result.get("ok", false)
	save_error = "save_failed" if state.save_failed else ""
	_refresh_rewards()
	state.note = "Your surprise bag is ready." if result.get("ok", false) else "Finished. Progress could not be saved."
	_publish()

func _send_frames(delta: float) -> void:
	pose_clock += delta
	state_clock += delta
	if pose_clock >= 1.0 / 30.0:
		pose_clock = 0.0
		var poses: Dictionary = {}
		var grapples: Dictionary = {}
		for id in avatars:
			poses[id] = avatars[id].capture_pose()
			grapples[id] = avatars[id].grapple.capture()
		session.publish_poses({"run_id": run_id, "pose_msec": Engine.get_physics_frames() * (1000.0 / 60.0), "puppets": poses, "props": world.capture_prop_poses(), "grapples": grapples, "teamwork": teamwork.capture() if is_instance_valid(teamwork) else {}, "match": contest.capture() if contest != null else {}, "movers": world.capture_movers() if world.has_method("capture_movers") else {}})
	if state_clock >= 0.2:
		state_clock = 0.0
		_publish()

func _process(delta: float) -> void:
	if not is_instance_valid(hud): return
	if session.connected and not session.hosting:
		var frame: Dictionary = presentation.sample(float(Time.get_ticks_msec()))
		for id in frame.get("puppets", {}):
			if avatars.has(id):
				avatars[id].present_pose(frame.puppets[id])
				avatars[id].grapple.present(frame.get("grapples", {}).get(id, {}))
				var fight: Dictionary = frame.get("match", {})
				avatars[id].visible = not (Modes.is_ring_match(mode_id) and fight.get("phase", "") in ["fight", "intermission", "complete"] and not id in fight.get("alive", []))
		world.present_prop_poses(frame.get("props", {}))
		if is_instance_valid(teamwork) and frame.has("teamwork"): teamwork.present(frame.teamwork)
		if contest != null and frame.has("match"): contest.present(frame.match, avatars)
		if world.has_method("apply_presented_movers"): world.apply_presented_movers(frame.get("movers", {}))
	if not scripted:
		var capture = session.connected and not hud.blocks_input() and state.get("phase", "") == "play"
		var desired = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != desired: Input.mouse_mode = desired
	_update_camera(delta)
	if mode_id == "coop" and hud.has_method("update_grapple"):
		var local_actor = avatars.get(session.local_id)
		var attached: bool = local_actor != null and local_actor.grapple.active
		var target_ready: bool = false
		if local_actor != null and not hud.blocks_input():
			target_ready = not local_actor.grapple.target_at(_grapple_aim()).is_empty()
		hud.update_grapple(grapple_mode, attached, target_ready)
	diagnostics.visible = show_fps
	if show_fps: diagnostics.text = "%d FPS · %d physical players · %d props" % [Engine.get_frames_per_second(), avatars.size(), world.props.size()]

func _update_camera(delta: float) -> void:
	if Modes.is_ring_match(mode_id) and session.connected:
		var match_state: Dictionary = state.get("match", {})
		if match_state.get("phase", "") in ["fight", "intermission", "complete"] and not session.local_id in match_state.get("alive", []):
			camera.position = Vector3(16, 19, 20)
			camera.look_at(Vector3(0, 4, 0))
			camera_ready = false
			return
	if avatars.has(session.local_id) and avatars[session.local_id].visible:
		var target: Vector3 = avatars[session.local_id].visual_position() + Vector3.UP * 0.5
		if not camera_ready or camera_focus.distance_squared_to(target) > 144.0:
			camera_focus = target
			camera_ready = true
		else:
			camera_focus = camera_focus.lerp(target, 1.0 - exp(-14.0 * delta))
		var arm = Basis(Vector3.UP, yaw) * (Basis(Vector3.RIGHT, pitch) * Vector3(0, 3.0, 10.0))
		var shoulder: Vector3 = Basis(Vector3.UP, yaw) * Vector3(1.35, 0, 0)
		var desired: Vector3 = camera_focus + arm + shoulder
		# Aim overhead from above the deck, with the puppet beside the reticle.
		# Looking up must not orbit the camera underneath the player's platform.
		desired.y = maxf(desired.y, camera_focus.y + 1.0)
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
		camera.look_at(camera.global_position - arm.normalized() * 20.0)

func _unhandled_input(event: InputEvent) -> void:
	if scripted: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Modes.is_ring_match(mode_id) and session.connected and not hud.blocks_input() and state.get("phase", "") == "play": attack_pending = true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				if session.connected and not hud.blocks_input() and state.get("phase", "") == "play": jump_pending = true
			KEY_ESCAPE:
				jump_pending = false
				attack_pending = false
				if session.connected:
					if hud.is_menu_open(): hud.show_game(); hud.update_view(state, session.local_id, session.hosting)
					else: hud.show_menu("Game stays live · Esc to return")
			KEY_F3: show_fps = not show_fps
			KEY_M:
				if session.connected and not hud.is_menu_open(): audio.toggle_mute()
			KEY_F:
				if not hud.blocks_input(): session.act("recover")
			KEY_E:
				if not hud.blocks_input(): session.act("switch")
			KEY_G:
				if mode_id == "coop" and session.connected and not hud.blocks_input() and state.get("phase", "") == "play":
					grapple_mode = "swing" if grapple_mode == "pull" else "pull"
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.relative.x * 0.003, -PI, PI)
		pitch = clampf(pitch - event.relative.y * 0.002, -0.85, 1.25)

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
