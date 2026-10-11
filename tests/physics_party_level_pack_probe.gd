extends SceneTree
## Real Jolt traversal with ordinary controls. Initial spawn is the only teleport.
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
const LEVEL_WORLD_PATH := "res://prototypes/physics_party/party_level_world.gd"
const NEW_IDS: Array[String] = ["dogleg", "stepping_stones", "high_walk", "cargo_maze", "twin_bridges", "switchback", "crosswind", "rooftop_hop", "balance_beam", "freight_spiral", "split_decision", "zigzag", "crane_yard", "windy_steps", "narrow_escape", "round_trip", "skybridge", "final_shift"]
var world: Node3D
var actor: Node3D
var camera: Camera3D
var controls: Dictionary = {}
var elapsed: float = 0.0
var supports: Dictionary = {}
var events: Array[Dictionary] = []
var failures: Array[String] = []
var checkpoint_standing: bool = false
var checkpoint_ticks: int = 0
var goal_ticks: int = 0
var jump_count: int = 0
var reports: Array[Dictionary] = []
var active_id: String = ""
var output_tag: String = "current"
var wall_started_msec: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	wall_started_msec = Time.get_ticks_msec()
	if not ResourceLoader.exists(LEVEL_WORLD_PATH):
		push_error("Missing new level world: " + LEVEL_WORLD_PATH)
		quit(2)
		return
	output_tag = _option("--tag", "current").validate_filename()
	var requested: String = _option("--course", "all")
	var ids: Array[String] = []
	if requested == "all": ids.assign(NEW_IDS)
	else: ids.append(requested)
	for id: String in ids:
		if id not in NEW_IDS:
			push_error("Unknown new course: " + id)
			quit(2)
			return
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		root.gui_disable_input = true
		camera = Camera3D.new()
		camera.fov = 65.0
		root.add_child(camera)
		camera.current = true
	for id: String in ids:
		await _course(id)
	var failed_ids: Array[String] = []
	for result: Dictionary in reports:
		if not result.failures.is_empty(): failed_ids.append(result.course)
	var summary := {"courses": reports, "tested": reports.size(), "passed": reports.size() - failed_ids.size(), "failed_courses": failed_ids, "wall_elapsed_s": (Time.get_ticks_msec() - wall_started_msec) / 1000.0, "timing": "Course and event elapsed_s are simulated seconds at 60 physics ticks per second; --fixed-fps 60 may run faster than wall time.", "limits": "One unpowered physical puppet, ordinary analog waypoint input and game wind. Initial spawn only; no prop repositioning, joint fixtures, completion assignment or invented rewards. Scripted feasibility, not human fun, keyboard-only play or LAN latency."}
	_save("res://logs/level-pack-" + output_tag + ".json", summary)
	print("LEVEL_PACK_RESULT " + JSON.stringify(summary))
	if is_instance_valid(camera): camera.queue_free()
	await process_frame
	quit(0 if failed_ids.is_empty() else 1)

func _course(id: String) -> void:
	active_id = id
	controls = {}
	elapsed = 0.0
	supports = {}
	events = []
	failures = []
	checkpoint_standing = false
	checkpoint_ticks = 0
	goal_ticks = 0
	jump_count = 0
	world = load(LEVEL_WORLD_PATH).new()
	world.course_id = id
	world.setup(true)
	root.add_child(world)
	actor = PuppetScene.instantiate()
	actor.authoritative = true
	root.add_child(actor)
	actor.set_power("")
	actor.setup_color(Color("ff9c44"))
	actor.reset_at(world.spawn_point(1))
	world.track_puppets([actor])
	await _ticks(120)
	_event("spawn_settled")
	if not actor.is_on_floor: failures.append("Initial spawn did not settle on actual support")
	var points: Array = world.route_points()
	var jump_indices: Array = world.route_jumps()
	if points.size() < 2: failures.append("Course lacks a traversable route")
	for point: Variant in points:
		if not point is Vector3 or not point.is_finite():
			failures.append("Course route contains a non-finite waypoint")
			break
	if failures.is_empty():
		for index in points.size():
			if not await _walk_to(points[index], index in jump_indices, index):
				failures.append("Could not stand at waypoint " + str(index) + " " + str(points[index]))
				break
	controls = {}
	if failures.is_empty():
		# A ragdoll can bounce briefly after reaching the deck. Await the same
		# sustained-standing condition instead of sampling one arbitrary frame.
		for tick in 180:
			await _ticks(1)
			if tick >= 59 and goal_ticks >= 12: break
	var goal_standing: bool = world.goal_contains(actor.body_position()) and actor.is_on_floor and goal_ticks >= 12
	if not checkpoint_standing: failures.append("No sustained standing contact inside the live checkpoint")
	if not goal_standing: failures.append("Did not remain standing inside the live goal")
	var required_supports: Array = world.required_route_supports()
	for support: String in required_supports:
		if not supports.has(support): failures.append("Route bypassed required moving support: " + support)
	_event("course_end")
	var result := {"course": id, "elapsed_s": elapsed, "power": "base", "checkpoint_standing": checkpoint_standing, "goal_standing": goal_standing, "goal_standing_ticks": goal_ticks, "jump_count": jump_count, "supports": supports.duplicate(), "required_supports": required_supports, "events": events.duplicate(true), "failures": failures.duplicate(), "final_position": str(actor.body_position()), "prop_count": world.props.size()}
	reports.append(result)
	_save("res://logs/level-pack-" + id + "-" + output_tag + ".json", result)
	print("LEVEL_COURSE_RESULT " + JSON.stringify(result))
	if is_instance_valid(camera):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/level-pack-" + id + "-" + output_tag + ".png")
	actor.release_all()
	actor.queue_free()
	world.queue_free()
	await process_frame
	await physics_frame
	actor = null
	world = null

func _walk_to(target: Vector3, needs_jump: bool, waypoint: int) -> bool:
	var started: float = elapsed
	var last_jump: float = -10.0
	var best_distance: float = INF
	var last_progress: float = elapsed
	var stable_ticks: int = 0
	while elapsed - started < 18.0:
		var at: Vector3 = actor.body_position()
		if not at.is_finite() or at.y < -12.0 or elapsed > 180.0: return false
		var offset := Vector2(target.x - at.x, target.z - at.z)
		var distance: float = offset.length()
		if distance < best_distance - 0.12:
			best_distance = distance
			last_progress = elapsed
		# The waypoint is a deck-top position; the torso normally rests 1.6m above.
		var at_height: bool = at.y > target.y + 0.7 and at.y < target.y + 3.1
		if distance < 0.62 and actor.is_on_floor and at_height:
			controls = {}
			stable_ticks += 1
			if stable_ticks >= 6:
				_event("waypoint_" + str(waypoint))
				return true
		else:
			stable_ticks = 0
			var direction: Vector2 = offset.normalized()
			var planar_velocity := Vector2(actor.physical_bone_body.linear_velocity.x, actor.physical_bone_body.linear_velocity.z)
			var move: Vector2 = (offset * 0.85 - planar_velocity * 0.16).limit_length(1.0)
			var at_jump_edge: bool = distance < 5.5 or not _ground_ahead(direction)
			var stuck_on_step: bool = elapsed - last_progress > 0.85 and distance > 0.7
			var jump: bool = actor.is_on_floor and elapsed - last_jump > 1.1 and ((needs_jump and at_jump_edge) or stuck_on_step)
			if jump:
				last_jump = elapsed
				jump_count += 1
				_event("jump_toward_" + str(waypoint))
			controls = {"move": move, "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false

func _ground_ahead(direction: Vector2) -> bool:
	var origin: Vector3 = actor.body_position() + Vector3(direction.x, 0, direction.y) * 1.0 + Vector3.UP * 0.2
	var exclusions: Array[RID] = []
	for bone: PhysicalBone3D in actor.physics_bones: exclusions.append(bone.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 3.3, 1, exclusions)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.y > 0.5

func _ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		var wind: Vector3 = world.wind_at(actor.body_position())
		for bone: PhysicalBone3D in actor.physics_bones: bone.linear_velocity += wind / 60.0
		await physics_frame
		elapsed += 1.0 / 60.0
		for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
			for index in cast.get_collision_count():
				var body: Object = cast.get_collider(index)
				if body is Node and cast.get_collision_normal(index).y > 0.5 and not actor.is_ancestor_of(body):
					supports[str(body.name)] = int(supports.get(str(body.name), 0)) + 1
		if actor.is_on_floor and world.checkpoint_contains(actor.body_position()):
			checkpoint_ticks += 1
			if checkpoint_ticks >= 6: checkpoint_standing = true
		else: checkpoint_ticks = 0
		goal_ticks = goal_ticks + 1 if actor.is_on_floor and world.goal_contains(actor.body_position()) else 0
		if is_instance_valid(camera):
			var at: Vector3 = actor.visual_position() + Vector3.UP * 0.5
			camera.position = at + Vector3(8, 8, 12)
			camera.look_at(at)

func _event(label: String) -> void:
	events.append({"event": label, "elapsed_s": elapsed, "position": str(actor.body_position()), "on_floor": actor.is_on_floor})

func _save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write evidence: " + path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

func _option(key: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
