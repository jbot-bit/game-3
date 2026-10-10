extends SceneTree
## Actual controls through the course. Only the initial spawn is positioned.
const WorldScript = preload("res://prototypes/physics_party/party_world.gd")
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actor: Node3D
var camera: Camera3D
var elapsed: float = 0.0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var controls: Dictionary = {}
var grab_observed: bool = false
var initial_plank: Vector3
var report: Dictionary = {}
var visual_only: bool = false
var seesaw_only: bool = false
var supports: Dictionary = {}
var power_id: String = ""
var wind_direction: int = 1
var variant_output: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	visual_only = "--visual-only" in OS.get_cmdline_user_args()
	seesaw_only = "--seesaw-only" in OS.get_cmdline_user_args()
	power_id = _option("--power", "")
	wind_direction = int(_option("--wind", "1"))
	variant_output = "--power" in OS.get_cmdline_user_args() or "--wind" in OS.get_cmdline_user_args()
	if power_id not in ["", "spring", "heavy", "swift", "feather", "grip"] or wind_direction not in [-1, 1]:
		push_error("Use --power spring|heavy|swift|feather|grip and --wind -1|1")
		quit(2)
		return
	world = WorldScript.new()
	world.setup(true)
	root.add_child(world)
	world.set_wind(wind_direction)
	actor = PuppetScene.instantiate()
	actor.authoritative = true
	root.add_child(actor)
	actor.set_power(power_id)
	actor.setup_color(Color("ec765e"))
	actor.reset_at(world.spawn_point(1, 1) if seesaw_only else world.spawn_point(2))
	world.track_puppets([actor])
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		root.gui_disable_input = true
		camera = Camera3D.new()
		camera.current = true
		camera.fov = 65.0
		root.add_child(camera)
	await _ticks(100)
	initial_plank = world.props.plank_right.global_position
	_event("spawn_settled")
	if visual_only:
		report.visual_only = true
		await _finish()
		return
	if seesaw_only:
		report.seesaw_only = true
		await _traverse_seesaw()
		await _finish()
		return
	if not await _walk_to(Vector2(4.5, -3.5), 8.0):
		_fail("Could not approach the ready bridge")
		await _finish()
		return
	_event("bridge_approached")
	if not await _jump_to(Vector2(4.5, -6.1), 5.0):
		_fail("Could not step onto the movable bridge")
		await _finish()
		return
	_event("bridge_boarded")
	if not await _walk_to(Vector2(4.5, -15.5), 9.0):
		_fail("Could not cross the movable bridge")
		await _finish()
		return
	report.bridge_contact_proven = supports.has("plank_right")
	report.bridge_placement_proven = false
	report.plank_translation_m = initial_plank.distance_to(world.props.plank_right.global_position)
	if not report.bridge_contact_proven:
		_fail("First crossing skipped the actual movable bridge")
		await _finish()
		return
	_event("first_crossing_complete")
	report.first_crossing_s = elapsed
	if not world.checkpoint_contains(actor.body_position()):
		_fail("First crossing did not reach the live checkpoint bounds")
		await _finish()
		return
	await _traverse_seesaw()
	await _finish()


func _traverse_seesaw() -> void:
	if not await _walk_to(Vector2(0.0, -16.8), 5.0, false, 0.8):
		_fail("Could not approach the seesaw step")
		return
	if not await _jump_to(Vector2(0.0, -20.0), 6.0):
		_fail("Could not jump onto the seesaw")
		return
	_event("seesaw_boarded")
	if not await _running_jump(Vector2(0.0, -28.4), -25.8, 6.0):
		_fail("Could not jump from the seesaw onto its landing")
		return
	_event("seesaw_landing_reached")
	if not await _reach_goal(7.0):
		_fail("Could not jump from the seesaw landing to the finish")
		return
	report.seesaw_contact_proven = supports.has("seesaw")
	report.goal_contains_actor = world.goal_contains(actor.body_position())
	if not report.seesaw_contact_proven:
		_fail("Route did not stand on the actual movable seesaw")
	if not report.goal_contains_actor:
		_fail("Actual seesaw route endpoint is outside the goal")
	_event("seesaw_route_complete")


func _reach_goal(timeout: float) -> bool:
	var started: float = elapsed
	var last_hop: float = -10.0
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		# Completion uses the same live volume as the game, not a precise bot stop.
		if world.goal_contains(at):
			controls = {}
			await _ticks(90)
			return world.goal_contains(actor.body_position()) and actor.is_on_floor
		var delta := Vector2(0.0, -32.0) - Vector2(at.x, at.z)
		var direction := delta.normalized()
		var jump: bool = elapsed - last_hop > 1.2 and actor.is_on_floor
		if jump:
			last_hop = elapsed
		controls = {"move": direction, "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false


func _walk_to(target: Vector2, timeout: float, hop_obstacles: bool = false, tolerance: float = 0.38) -> bool:
	var started: float = elapsed
	var last_hop: float = -10.0
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		var delta := target - Vector2(at.x, at.z)
		if delta.length() < tolerance:
			controls = {}
			await _ticks(12)
			return actor.body_position().y > -1.0
		var direction := delta.normalized()
		var jump: bool = hop_obstacles and elapsed - last_hop > 1.2 and actor.is_on_floor
		if jump:
			last_hop = elapsed
		controls = {"move": direction * minf(1.0, delta.length() / 1.4), "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false


func _jump_to(target: Vector2, timeout: float) -> bool:
	var started: float = elapsed
	var sent_jump: bool = false
	var left_floor: bool = false
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		var delta := target - Vector2(at.x, at.z)
		var jump: bool = not sent_jump and actor.is_on_floor
		if jump:
			sent_jump = true
		if sent_jump and not actor.is_on_floor:
			left_floor = true
		if left_floor and actor.is_on_floor and delta.length() < 0.9:
			controls = {}
			await _ticks(20)
			return actor.body_position().y > 0.0
		var direction := delta.normalized()
		controls = {"move": direction * minf(1.0, delta.length() / 1.2), "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false


func _running_jump(target: Vector2, launch_z: float, timeout: float) -> bool:
	var started: float = elapsed
	var sent_jump: bool = false
	var left_floor: bool = false
	var recorded_support_loss: bool = false
	report.seesaw_exit_jump_pressed = false
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		if not sent_jump and not actor.is_on_floor and not recorded_support_loss and at.z < -21.0:
			recorded_support_loss = true
			_event("seesaw_support_lost_before_launch")
		var delta := target - Vector2(at.x, at.z)
		var jump: bool = not sent_jump and at.z < launch_z and actor.is_on_floor
		if jump:
			sent_jump = true
			report.seesaw_exit_jump_pressed = true
			_event("seesaw_exit_jump_pressed")
		if sent_jump and not actor.is_on_floor:
			left_floor = true
		# A high/floaty jump may reach Finish directly. Do not steer a successful
		# landing backward to an exact bot waypoint beside the platform edge.
		if left_floor and actor.is_on_floor and (_on_support("SteppingStone") or _on_support("Finish")):
			controls = {}
			await _ticks(12)
			return true
		var direction := delta.normalized()
		controls = {"move": direction * minf(1.0, delta.length() / 1.2), "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false


func _on_support(body_name: String) -> bool:
	for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
		for index in cast.get_collision_count():
			var body: Object = cast.get_collider(index)
			if body is Node and str(body.name) == body_name and cast.get_collision_normal(index).y > 0.5:
				return true
	return false


func _holding_plank() -> bool:
	return actor.get("_left_target") == world.props.plank_right or actor.get("_right_target") == world.props.plank_right


func _ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		var wind: Vector3 = world.wind_at(actor.body_position())
		for bone: PhysicalBone3D in actor.physics_bones:
			bone.linear_velocity += wind / 60.0
		await physics_frame
		elapsed += 1.0 / 60.0
		for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
			for index in cast.get_collision_count():
				var body: Object = cast.get_collider(index)
				if body is Node and cast.get_collision_normal(index).y > 0.5:
					supports[str(body.name)] = int(supports.get(str(body.name), 0)) + 1
		if camera != null:
			# The same resting view used by main's player camera.
			var at: Vector3 = actor.visual_position() if actor.has_method("visual_position") else actor.body_position()
			var target := at + Vector3.UP * 0.5
			camera.position = target + Basis(Vector3.RIGHT, -0.18) * Vector3(0.0, 3.0, 10.0)
			camera.look_at(target)


func _event(name: String) -> void:
	var event: Dictionary = {"event": name, "elapsed_s": elapsed, "actor": str(actor.body_position()),
		"plank": str(world.props.plank_right.global_position), "plank_basis": str(world.props.plank_right.global_basis),
		"left_hand": str(actor.left_area.global_position), "right_hand": str(actor.right_area.global_position),
		"seesaw": str(world.props.seesaw.global_transform), "supports": supports.duplicate(),
		"left_target": str(actor.left_joint.node_b), "right_target": str(actor.right_joint.node_b)}
	events.append(event)
	print("PARTY_COURSE_EVENT " + JSON.stringify(event))


func _fail(message: String) -> void:
	failures.append(message)
	print("PARTY_COURSE_FAIL " + message)


func _finish() -> void:
	_event("probe_end")
	controls = {}
	actor.set_controls({})
	# Preserve observed obstacle contacts even when a later bot maneuver fails.
	report.bridge_contact_proven = supports.has("plank_right")
	report.seesaw_contact_proven = supports.has("seesaw")
	report.goal_contains_actor = world.goal_contains(actor.body_position())
	if camera != null:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_output_base()+".png")
	report.merge({"elapsed_s": elapsed, "power": power_id if not power_id.is_empty() else "base", "wind": wind_direction, "grab_observed": grab_observed, "events": events, "failures": failures,
		"limits": "One scripted puppet with ordinary controller inputs; initial spawn only. No prop positioning, completion calls, injected forces or rewards. Wind matches main. Not a human or three-PC playtest."})
	if visual_only:
		report.limits = "Native starting view using normal player camera geometry; no course completion attempted. No performance claim."
	var file := FileAccess.open(_output_base()+".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PARTY_COURSE_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _option(key: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index+1] if index >= 0 and index+1 < args.size() else fallback


func _output_base() -> String:
	var base: String = "res://logs/hands-full-world-look" if visual_only else ("res://logs/hands-full-seesaw" if seesaw_only else "res://logs/hands-full-course")
	if variant_output:
		base += "-"+(power_id if not power_id.is_empty() else "base")+"-wind-"+("left" if wind_direction<0 else "right")
	return base
