extends SceneTree
## Ordinary controls only after initial spawn. Analog steering is a bot aid.
const WorldScript = preload("res://prototypes/physics_party/party_counterweight_world.gd")
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actors: Array[Node3D] = []
var inputs: Array[Dictionary] = []
var supports: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var elapsed := 0.0
var camera: Camera3D
var power := ""
var crew_count := 1
var mode := "route"
var report: Dictionary = {}
var minimum_loaded_tip := INF
var far_end_support_ticks := 0
var partner_holding_position := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	power = _option("--power", "")
	crew_count = int(_option("--crew", "1"))
	mode = _option("--mode", "route")
	world = WorldScript.new()
	world.setup(true)
	root.add_child(world)
	world.set_wind(int(_option("--wind", "1")))
	for slot in crew_count:
		var actor: Node3D = PuppetScene.instantiate()
		root.add_child(actor)
		actor.set_power(power)
		actor.setup_color([Color("ec765e"), Color("73c7b0"), Color("f0ba4b")][slot])
		actor.reset_at(world.spawn_point(slot, 1) if mode == "recovery" else world.spawn_point(slot))
		actors.append(actor)
		inputs.append({})
		supports.append({})
	world.track_puppets(actors)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		camera = Camera3D.new()
		root.add_child(camera)
		camera.current = true
		camera.fov = 68.0
	await _ticks(120)
	_event("start_settled")
	if mode == "look":
		await _finish()
		return
	if mode == "recovery":
		await _recover_from_checkpoint()
		await _finish()
		return
	if mode == "load":
		await _load_block(0, "block_2", Vector2(1.3, -2.6))
		await _finish()
		return
	if mode.begins_with("balance"):
		await _balance()
		await _finish()
		return
	if mode != "unweighted":
		if not await _load_block(0, "block_2", Vector2(1.3, -2.6)):
			await _finish()
			return
	for slot in crew_count:
		if not await _route(slot):
			break
	await _finish()


func _recover_from_checkpoint() -> void:
	# Setup fixture only: spawn at the public checkpoint, then walk off naturally.
	for slot in crew_count:
		if not world.checkpoint_contains(actors[slot].body_position()) or not actors[slot].is_on_floor:
			_fail("Checkpoint spawn does not settle safely for actor " + str(slot))
			return
	if not await _steady_walk(0, Vector2(-2.3, -15.5), 8.0):
		_fail("Cannot approach checkpoint edge for recovery")
		return
	var fell := false
	for tick in 600:
		inputs[0] = {"move": Vector2(-1, 0), "yaw": PI * 0.5}
		await _ticks(1)
		if actors[0].body_position().y < -12.0:
			fell = true
			break
	if not fell:
		_fail("Ordinary movement did not produce the intended recovery fall")
		return
	_event("natural_checkpoint_fall")
	# Same threshold and reset API as main.gd; no completion/checkpoint assignment.
	inputs[0] = {}
	actors[0].reset_at(world.spawn_point(0, 1))
	await _ticks(180)
	report.natural_fall_below_minus_12 = fell
	report.recovered_checkpoint = world.checkpoint_contains(actors[0].body_position()) and actors[0].is_on_floor
	if not report.recovered_checkpoint:
		_fail("Existing reset API did not settle the fallen actor on checkpoint")
	for slot in crew_count:
		if not actors[slot].body_position().is_finite() or not world.checkpoint_contains(actors[slot].body_position()):
			_fail("Checkpoint recovery disturbed crew member " + str(slot))
	_event("checkpoint_recovered")


func _balance() -> void:
	if mode == "balance-block":
		if not await _load_block(0, "block_2", Vector2(1.3, -2.6)):
			return
	if mode == "balance-partner":
		if crew_count < 2 or not await _walk(1, Vector2(1.1, -4.0), 10.0, false, true):
			_fail("Partner cannot occupy the loading end")
			return
		inputs[1] = {}
		partner_holding_position = true
	if not await _walk(0, Vector2(-1.0, -0.5), 8.0):
		_fail("Cannot approach balance test")
		return
	if not await _walk(0, Vector2(-1.0, -4.0), 8.0, false, true):
		_fail("Cannot board balance test")
		return
	if not await _steady_walk(0, Vector2(-1.0, -10.8), 14.0):
		_fail("Cannot reach far end for balance test")
		return
	for tick in 180:
		_steady_input(0, Vector2(-1.0, -10.8))
		await _ticks(1)
	report.far_tip_y_after_wait = (world.props.seesaw.global_transform * Vector3(0, 0, -5.5)).y
	report.rider_position_after_wait = str(actors[0].body_position())
	report.minimum_tip_with_far_end_foot_contact = minimum_loaded_tip if is_finite(minimum_loaded_tip) else null
	report.far_end_support_ticks = far_end_support_ticks
	if mode == "balance-partner":
		report.partner_on_board_after_wait = _on_support(1, world.props.seesaw)
		if not report.partner_on_board_after_wait:
			_fail("Partner did not remain on the rear arm during the balance wait")
	_event("balance_wait_complete")
	# A stationary jump has less horizontal reach; back up for the same running
	# takeoff used by the full route. The waiting measurement is already saved.
	if not await _steady_walk(0, Vector2(-1.0, -9.3), 6.0):
		_fail("Rider cannot return to takeoff after the balance wait")
		return
	if not await _jump_to_checkpoint(0, 8.0):
		_fail("Rider cannot jump to checkpoint after waiting")


func _steady_input(slot: int, target: Vector2) -> void:
	var at: Vector3 = actors[slot].body_position()
	var velocity: Vector3 = actors[slot].physical_bone_body.linear_velocity
	var move := ((target - Vector2(at.x, at.z)) * 0.8 - Vector2(velocity.x, velocity.z) * 0.18).limit_length(0.55)
	inputs[slot] = {"move": move, "yaw": 0.0}


func _steady_walk(slot: int, target: Vector2, timeout: float) -> bool:
	var start: float = elapsed
	while elapsed - start < timeout:
		var at: Vector3 = actors[slot].body_position()
		if at.y < -2:
			return false
		_steady_input(slot, target)
		await _ticks(1)
		if Vector2(at.x, at.z).distance_to(target) < 0.25:
			return true
	return false


func _load_block(slot: int, id: String, destination: Vector2) -> bool:
	var actor: Node3D = actors[slot]
	var block: RigidBody3D = world.props[id]
	var origin: Vector3 = block.global_position
	if not await _steady_walk(slot, Vector2(origin.x, origin.z + 2.1), 12.0):
		_fail("Loader cannot approach " + id)
		return false
	inputs[slot] = {}
	await _ticks(20)
	for tick in 180:
		var delta: Vector3 = block.global_position - actor.body_position()
		var direction: Vector2 = Vector2(delta.x, delta.z).normalized()
		# Let the reaching hands arrive before the responsive motor pushes the
		# block into the loading lip. This changes bot steering, not success checks.
		inputs[slot] = {"move": direction * 0.25, "yaw": atan2(-direction.x, -direction.y), "pitch": 0.0, "left": true, "right": true}
		await _ticks(1)
		if _holding(slot, id):
			break
	_event("block_grab_attempt")
	if not _holding(slot, id):
		_fail("Collision-created block grip failed")
		return false
	report.real_block_grip = true
	# Walk sideways while facing the cargo, then onto the loading end.
	if not await _carry_to(slot, id, Vector2(destination.x, block.global_position.z), 9.0):
		_fail("Loader cannot align cargo with the board")
		return false
	if not await _carry_to(slot, id, destination, 10.0):
		_fail("Loader cannot place cargo on the long arm")
		return false
	inputs[slot] = {}
	await _ticks(90)
	report.block_displacement_m = origin.distance_to(block.global_position)
	report.loaded_block = str(block.global_position)
	_event("block_released_on_board")
	await _capture("cargo")
	if absf(block.global_position.x) > 2.6 or block.global_position.z > -1.0 or block.global_position.y < 0.8:
		_fail("Released counterweight did not remain on the board")
		return false
	var query := PhysicsRayQueryParameters3D.create(block.global_position, block.global_position + Vector3.DOWN * 3.0, 1, [block.get_rid()])
	var below: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	report.block_supported_by_board = not below.is_empty() and below.collider == world.props.seesaw
	if not report.block_supported_by_board:
		_fail("Released cargo does not have physical seesaw support underneath")
		return false
	return true


func _carry_to(slot: int, id: String, target: Vector2, timeout: float) -> bool:
	var start: float = elapsed
	var block: RigidBody3D = world.props[id]
	var last_jump := -10.0
	while elapsed - start < timeout:
		if not _holding(slot, id) or actors[slot].body_position().y < -2:
			return false
		var at: Vector3 = block.global_position
		var error: Vector2 = target - Vector2(at.x, at.z)
		var velocity: Vector3 = block.linear_velocity
		var move: Vector2 = (error * 0.6 - Vector2(velocity.x, velocity.z) * 0.18).limit_length(0.6)
		var jump: bool = elapsed - last_jump > 1.3 and actors[slot].is_on_floor and at.z < -1.0
		if jump:
			last_jump = elapsed
		inputs[slot] = {"move": move, "yaw": 0.0, "pitch": 0.4, "left": true, "right": true, "jump": jump}
		await _ticks(1)
		if error.length() < 0.35:
			inputs[slot] = {"yaw": 0.0, "pitch": 0.4, "left": true, "right": true}
			await _ticks(20)
			return true
	return false


func _route(slot: int) -> bool:
	if not await _walk(slot, Vector2(-1.0, -0.5), 8.0):
		_fail("Actor %s cannot approach the long arm" % slot)
		return false
	if not await _walk(slot, Vector2(-1.0, -4.5), 8.0, false, true):
		_fail("Actor %s cannot board the seesaw" % slot)
		return false
	if not await _steady_walk(slot, Vector2(-1.0, -9.5), 12.0):
		_fail("Actor %s cannot climb the seesaw" % slot)
		return false
	_event("hinge_reached_" + str(slot))
	await _capture("seesaw")
	if not await _jump_to_checkpoint(slot, 8.0):
		_fail("Actor %s cannot reach the checkpoint" % slot)
		return false
	_event("checkpoint_reached_" + str(slot))
	await _capture("checkpoint")
	if not await _steady_walk(slot, Vector2(2.5, -15.2), 10.0):
		_fail("Actor %s cannot turn toward the crosswind bridge" % slot)
		return false
	if not await _walk(slot, Vector2(15.2, -15.2), 12.0, false, true):
		_fail("Actor %s cannot cross the movable bridge" % slot)
		return false
	if not await _steady_walk(slot, Vector2(17.0, -17.0 + float(slot - 1) * 2.3), 10.0):
		_fail("Actor %s cannot settle at shared goal" % slot)
		return false
	inputs[slot] = {}
	await _ticks(60)
	if not world.goal_contains(actors[slot].body_position()):
		_fail("Actor %s left goal" % slot)
		return false
	if not supports[slot].has("seesaw") or not supports[slot].has("plank_left"):
		_fail("Actor %s did not contact both moving obstacles" % slot)
		return false
	return true


func _capture(label: String) -> void:
	if camera == null:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/counterweight-native-" + label + ".png")


func _walk(slot: int, target: Vector2, timeout: float, holding: bool = false, hops: bool = false) -> bool:
	var start: float = elapsed
	var last_hop := -10.0
	var actor: Node3D = actors[slot]
	while elapsed - start < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		var offset: Vector2 = target - Vector2(at.x, at.z)
		if offset.length() < 0.5:
			inputs[slot] = {"left": holding, "right": holding, "pitch": 0.3}
			await _ticks(18)
			return actor.body_position().y > -1.0
		var direction: Vector2 = offset.normalized()
		var jump: bool = hops and elapsed - last_hop > 1.15 and actor.is_on_floor
		if jump:
			last_hop = elapsed
		inputs[slot] = {"move": direction * minf(1.0, offset.length() / 1.4), "yaw": 0.0 if holding else atan2(-direction.x, -direction.y), "pitch": 0.3, "left": holding, "right": holding, "jump": jump}
		await _ticks(1)
	return false


func _jump_to_checkpoint(slot: int, timeout: float) -> bool:
	var start: float = elapsed
	var last_jump := -10.0
	var actor: Node3D = actors[slot]
	while elapsed - start < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2:
			return false
		if world.checkpoint_contains(at) and actor.is_on_floor:
			inputs[slot] = {}
			await _ticks(30)
			return world.checkpoint_contains(actor.body_position())
		var offset := Vector2(-1.0, -16.5) - Vector2(at.x, at.z)
		var direction: Vector2 = offset.normalized()
		var jump: bool = at.z < -10.2 and actor.is_on_floor and elapsed - last_jump > 1.1
		if jump:
			last_jump = elapsed
			_event("exit_jump_" + str(slot))
		inputs[slot] = {"move": direction * minf(1.0, offset.length() / 1.2), "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false


func _holding(slot: int, id: String) -> bool:
	return actors[slot]._left_target == world.props[id] or actors[slot]._right_target == world.props[id]


func _on_support(slot: int, target: Node) -> bool:
	for cast: ShapeCast3D in [actors[slot].left_floor, actors[slot].right_floor]:
		for index in cast.get_collision_count():
			if cast.get_collider(index) == target and cast.get_collision_normal(index).y > 0.5:
				return true
	return false


func _ticks(count: int) -> void:
	for tick in count:
		if partner_holding_position:
			_steady_input(1, Vector2(1.1, -4.0))
		for slot in crew_count:
			var actor: Node3D = actors[slot]
			actor.set_controls(inputs[slot])
			var wind: Vector3 = world.wind_at(actor.body_position())
			for bone: PhysicalBone3D in actor.physics_bones:
				bone.linear_velocity += wind / 60.0
		await physics_frame
		elapsed += 1.0 / 60.0
		for slot in crew_count:
			for cast: ShapeCast3D in [actors[slot].left_floor, actors[slot].right_floor]:
				for index in cast.get_collision_count():
					var body: Object = cast.get_collider(index)
					if body is Node and cast.get_collision_normal(index).y > 0.5:
						supports[slot][str(body.name)] = int(supports[slot].get(str(body.name), 0)) + 1
						if slot == 0 and mode.begins_with("balance") and body == world.props.seesaw and actors[slot].body_position().z < -10.0:
							minimum_loaded_tip = minf(minimum_loaded_tip, (world.props.seesaw.global_transform * Vector3(0, 0, -5.5)).y)
							far_end_support_ticks += 1
		if camera != null:
			var at: Vector3 = actors[0].visual_position()
			camera.position = at + Vector3(9, 10, 14)
			camera.look_at(at + Vector3(1, 0, -3))


func _event(label: String) -> void:
	var positions: Array[String] = []
	for actor: Node3D in actors:
		positions.append(str(actor.body_position()))
	var board: RigidBody3D = world.props.seesaw
	var event := {"event": label, "elapsed_s": elapsed, "actors": positions, "board": str(board.global_transform), "far_tip_y": (board.global_transform * Vector3(0, 0, -5.5)).y, "block_2": str(world.props.block_2.global_position), "supports": supports.duplicate(true), "left": str(actors[0].left_joint.node_b), "right": str(actors[0].right_joint.node_b)}
	events.append(event)
	print("COUNTERWEIGHT_EVENT " + JSON.stringify(event))


func _fail(message: String) -> void:
	failures.append(message)
	print("COUNTERWEIGHT_FAIL " + message)


func _finish() -> void:
	_event("probe_end")
	var goal: Array[bool] = []
	for actor: Node3D in actors:
		goal.append(world.goal_contains(actor.body_position()))
		actor.release_all()
	var output: String = "res://logs/counterweight-" + mode + "-" + str(crew_count) + "-" + (power if power else "base") + "-wind-" + str(world.wind_direction)
	if not _option("--tag", "").is_empty():
		output += "-" + _option("--tag", "")
	if camera != null:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + ".png")
	report.merge({"crew": crew_count, "power": power, "wind": world.wind_direction, "mode": mode, "elapsed_s": elapsed, "failures": failures, "all_goal": not false in goal, "goal": goal, "events": events, "supports": supports, "limits": "Physical analog waypoint bot using ordinary controls and collision-created joints. Initial spawns only. No prop positioning or fabricated completion; not keyboard-only or human fun evidence."})
	if mode == "recovery":
		report.limits = "Initial checkpoint-spawn setup fixture; ordinary controls walk an actor below the actual -12m recovery plane, then the same reset_at public API as main restores it. No prop poses or completion assignment. Component recovery evidence, not full session automation."
	var file := FileAccess.open(output + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COUNTERWEIGHT_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _option(key: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
