extends SceneTree
## Real Jolt traversal: initial spawn only. The separate impact fixture starts beside a sweeper.
const World = preload("res://prototypes/physics_party/party_wipeout_world.gd")
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actor: Node3D
var elapsed: float = 0.0
var controls: Dictionary = {}
var supports: Dictionary = {}
var checkpoints: Array[int] = []
var events: Array = []
var failures: Array[String] = []
var jump_count: int = 0
var last_jump: float = -10.0
var max_tilt: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	world = World.new()
	root.add_child(world)
	actor = Puppet.instantiate()
	root.add_child(actor)
	world.track_puppets([actor])
	actor.reset_at(world.spawn_point(1))
	await _ticks(120)
	if not actor.is_on_floor: failures.append("Initial spawn has no physical support")
	for index in world.route_points().size():
		if not await _walk(world.route_points()[index], index in world.route_jumps()):
			failures.append("Could not reach waypoint " + str(index))
			break
		events.append({"waypoint": index, "elapsed_s": elapsed, "position": str(actor.body_position())})
	controls = {}
	await _ticks(60)
	var route: Dictionary = {"elapsed_s": elapsed, "standing_goal": actor.is_on_floor and world.goal_contains(actor.body_position()), "checkpoints": checkpoints.duplicate(), "supports": supports.duplicate(), "jumps": jump_count, "beam_tilt_radians": max_tilt.duplicate(), "events": events.duplicate(true)}
	if not route.standing_goal: failures.append("Did not finish on real support")
	if checkpoints != [1, 2, 3]: failures.append("Did not physically visit checkpoints in order")
	for id: String in world.required_route_supports():
		if not supports.has(id): failures.append("Required support bypassed: " + id)
	# Independent collision fixture: a settled, idle physical puppet is hit only by a rotating bar.
	world.set_physics_process(false)
	world.reset_props()
	var fixture_center := Vector3(5.3, 7, -43)
	actor.reset_at(fixture_center)
	await _ticks(120)
	var before: Vector3 = actor.body_position()
	world.set_physics_process(true)
	var peak_speed: float = 0.0
	var displacement: float = 0.0
	var airborne_ticks: int = 0
	for tick in 620:
		await _ticks(1)
		var speed: Vector3 = actor.physical_bone_body.linear_velocity
		peak_speed = maxf(peak_speed, Vector2(speed.x, speed.z).length())
		displacement = maxf(displacement, Vector2(actor.body_position().x - before.x, actor.body_position().z - before.z).length())
		if not actor.is_on_floor: airborne_ticks += 1
	var impact := {"peak_horizontal_speed": peak_speed, "horizontal_displacement": displacement, "airborne_ticks": airborne_ticks, "initial": str(before), "final": str(actor.body_position()), "fixture": "Puppet initially placed on the sweeper deck; no artificial force, jump, movement or combat input."}
	if displacement < 0.75 or peak_speed < 1.2: failures.append("Rotating padded collision bar did not physically displace the idle puppet")
	var report := {"route": route, "sweeper_collision": impact, "failures": failures, "timing": "Simulated seconds at 60Hz. Initial spawn only for route, independent initial-position fixture for collision. This proves physical feasibility, not human difficulty or multiplayer latency."}
	var file := FileAccess.open("res://logs/wipeout-physics-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("WIPEOUT_PHYSICS_RESULT " + JSON.stringify(report))
	actor.release_all()
	actor.queue_free()
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _walk(target: Vector3, needs_jump: bool) -> bool:
	var start: float = elapsed
	var stable: int = 0
	var best: float = INF
	var progressed: float = elapsed
	while elapsed - start < 22.0:
		var at: Vector3 = actor.body_position()
		if not at.is_finite() or at.y < -2.0: return false
		var offset := Vector2(target.x - at.x, target.z - at.z)
		var distance: float = offset.length()
		if distance < best - 0.1:
			best = distance
			progressed = elapsed
		if distance < 0.65 and actor.is_on_floor and at.y > target.y + 0.6 and at.y < target.y + 3.2:
			controls = {}
			stable += 1
			if stable >= 5: return true
		else:
			stable = 0
			var velocity: Vector3 = actor.physical_bone_body.linear_velocity
			var direction: Vector2 = offset.normalized()
			var move: Vector2 = (offset * 0.85 - Vector2(velocity.x, velocity.z) * 0.16).limit_length(1.0)
			var jump: bool = actor.is_on_floor and elapsed - last_jump > 1.0 and ((needs_jump and (distance < 5.5 or not _ground_ahead(direction))) or elapsed - progressed > 0.8 or _sweeper_near())
			if jump:
				last_jump = elapsed
				jump_count += 1
			controls = {"move": move, "yaw": atan2(-direction.x, -direction.y), "jump": jump}
		await _ticks(1)
	return false

func _sweeper_near() -> bool:
	var at: Vector3 = actor.body_position()
	for id: String in world.movers:
		var body: AnimatableBody3D = world.movers[id]
		var spec: Dictionary = world.mover_specs[id]
		var next_basis := Basis(Vector3.UP, body.rotation.y + float(spec.speed) * 0.24)
		var local: Vector3 = next_basis.inverse() * (at - body.global_position)
		if absf(local.x) < float(spec.length) * 0.5 + 0.5 and absf(local.z) < 1.65 and at.y < 7.5: return true
	return false

func _ground_ahead(direction: Vector2) -> bool:
	var at: Vector3 = actor.body_position() + Vector3(direction.x, 0, direction.y) * 1.1
	var exclusions: Array[RID] = []
	for bone: PhysicalBone3D in actor.physics_bones: exclusions.append(bone.get_rid())
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.3, 1, exclusions)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		await physics_frame
		elapsed += 1.0 / 60.0
		for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
			for index in cast.get_collision_count():
				var body: Object = cast.get_collider(index)
				if body is Node and cast.get_collision_normal(index).y > 0.5 and not actor.is_ancestor_of(body):
					supports[str(body.name)] = int(supports.get(str(body.name), 0)) + 1
		if actor.is_on_floor:
			var checkpoint: int = world.checkpoint_index(actor.body_position())
			if checkpoint == checkpoints.size() + 1: checkpoints.append(checkpoint)
		for id: String in world.props:
			var tilt: float = (world.props[id] as RigidBody3D).global_basis.get_euler().length()
			max_tilt[id] = maxf(float(max_tilt.get(id, 0)), tilt)
