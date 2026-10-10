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


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	visual_only = "--visual-only" in OS.get_cmdline_user_args()
	world = WorldScript.new()
	world.setup(true)
	root.add_child(world)
	actor = PuppetScene.instantiate()
	actor.authoritative = true
	root.add_child(actor)
	actor.setup_color(Color("ec765e"))
	actor.reset_at(world.spawn_point(2))
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
	if not await _walk_to(Vector2(4.5, 3.5), 7.0):
		_fail("Could not walk behind the right plank")
		await _finish()
		return
	_event("approached_plank")
	# Each angle is an ordinary camera pitch. We do not place a test object at
	# the hand, edit a constraint, change a prop pose or inject an impulse.
	for pitch: float in [-0.2, -0.4, -0.05]:
		controls = {"yaw": 0.0, "pitch": pitch, "left": true, "right": true, "move": Vector2(0.0, -0.35)}
		await _ticks(40)
		if _holding_plank():
			grab_observed = true
			break
		controls = {}
		await _ticks(8)
	if not grab_observed:
		_fail("Ordinary hands did not grab the low plank")
		_event("grab_failed")
		await _finish()
		return
	_event("plank_grabbed")
	for tick in 900:
		var plank: RigidBody3D = world.props.plank_right
		var aim_pitch: float = 0.2
		controls = {"yaw": 0.0, "pitch": aim_pitch, "left": true, "right": true, "move": Vector2(0.0, -0.8)}
		await _ticks(1)
		if plank.global_position.z < -8.9:
			break
		if actor.body_position().y < -2.0:
			_fail("Fell while positioning the plank")
			await _finish()
			return
	_event("plank_positioned")
	controls = {}
	await _ticks(45)
	report.plank_translation_m = initial_plank.distance_to(world.props.plank_right.global_position)
	if float(report.plank_translation_m) < 2.0:
		_fail("Normal grab and walk did not move the free plank at least 2m")
		await _finish()
		return
	# A first lesson must not require perfect solo bridge placement. The live
	# four-metre gap also supports a run/jump/hand-help route beside the plank.
	report.bridge_placement_proven = false
	if not await _walk_to(Vector2(6.0, -6.0), 8.0):
		_fail("Could not approach the first jump after moving the plank")
		await _finish()
		return
	if not await _running_jump(Vector2(6.0, -13.8), -8.4, 6.0):
		_fail("Could not use the first crossing's run-and-jump fallback")
		await _finish()
		return
	if not await _walk_to(Vector2(6.0, -15.3), 5.0):
		_fail("Could not walk into the checkpoint after the first jump")
		await _finish()
		return
	_event("first_crossing_complete")
	report.first_crossing_s = elapsed
	if not world.checkpoint_contains(actor.body_position()):
		_fail("First crossing did not reach the live checkpoint bounds")
		await _finish()
		return
	if not await _walk_to(Vector2(5.0, -23.7), 12.0):
		_fail("Could not approach the stepping-stone route")
		await _finish()
		return
	_event("second_crossing_approach")
	if not await _jump_to(Vector2(5.0, -27.0), 5.0):
		_fail("Could not land on the stepping stone using normal jump input")
		await _finish()
		return
	_event("stepping_stone_landed")
	if not await _jump_to(Vector2(4.5, -30.5), 5.0):
		_fail("Could not jump from the stepping stone onto the final platform")
		await _finish()
		return
	controls = {}
	await _ticks(60)
	_event("finish_reached")
	report.goal_contains_actor = world.goal_contains(actor.body_position())
	if not report.goal_contains_actor:
		_fail("Actual final position is outside the live goal bounds")
	await _finish()


func _walk_to(target: Vector2, timeout: float, hop_obstacles: bool = false) -> bool:
	var started: float = elapsed
	var last_hop: float = -10.0
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		var delta := target - Vector2(at.x, at.z)
		if delta.length() < 0.38:
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
	while elapsed - started < timeout:
		var at: Vector3 = actor.body_position()
		if at.y < -2.0:
			return false
		var delta := target - Vector2(at.x, at.z)
		var jump: bool = not sent_jump and at.z < launch_z and actor.is_on_floor
		if jump:
			sent_jump = true
		if sent_jump and not actor.is_on_floor:
			left_floor = true
		if left_floor and actor.is_on_floor and delta.length() < 0.9:
			controls = {}
			await _ticks(12)
			return true
		var direction := delta.normalized()
		controls = {"move": direction * minf(1.0, delta.length() / 1.2), "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
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
	if camera != null:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/hands-full-world-look.png" if visual_only else "res://logs/hands-full-course.png")
	report.merge({"elapsed_s": elapsed, "grab_observed": grab_observed, "events": events, "failures": failures,
		"limits": "One scripted puppet with ordinary controller inputs; initial spawn only. No prop positioning, completion calls, injected forces or rewards. Wind matches main. Not a human or three-PC playtest."})
	if visual_only:
		report.limits = "Native starting view using normal player camera geometry; no course completion attempted. No performance claim."
	var file := FileAccess.open("res://logs/hands-full-world-look.json" if visual_only else "res://logs/hands-full-course.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PARTY_COURSE_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
