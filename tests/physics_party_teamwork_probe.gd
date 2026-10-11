extends SceneTree
## Three real puppets. Initial positions are fixtures at each stage, not a full route run.
const World = preload("res://prototypes/physics_party/party_world.gd")
const Teamwork = preload("res://prototypes/physics_party/party_teamwork.gd")
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var team: Node3D
var actors: Dictionary = {}
var targets: Dictionary = {}
var inputs: Dictionary = {}
var failures: Array[String] = []
var checks: int = 0
var elapsed: float = 0.0
var evidence: Array = []
var cargo_evidence: Dictionary = {}

func _initialize() -> void: call_deferred("_run")
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _step(count: int = 1) -> void:
	for index in count:
		var controls: Dictionary = {}
		for id: String in actors:
			var actor: Node3D = actors[id]
			var control: Dictionary = inputs.get(id, {}).duplicate()
			if targets.has(id):
				var offset: Vector3 = targets[id] - actor.body_position()
				var velocity: Vector3 = actor.physical_bone_body.linear_velocity
				var move := (Vector2(offset.x, offset.z) * 0.8 - Vector2(velocity.x, velocity.z) * 0.16).limit_length(1)
				control.move = move
				if move.length() > 0.05 and not control.has("yaw"): control.yaw = atan2(-move.x, -move.y)
			actor.set_controls(control)
			controls[id] = control
		team.tick(actors, controls, 1.0 / 60.0)
		await physics_frame
		elapsed += 1.0 / 60.0

func _walk(target: Vector3, max_ticks: int = 1500) -> bool:
	targets.c = target
	for index in max_ticks:
		await _step()
		var position: Vector3 = actors.c.body_position()
		if not position.is_finite() or position.y < -10: return false
		if Vector2(position.x - target.x, position.z - target.z).length() < 0.55 and actors.c.is_on_floor: return true
	return false

func _deliver_cargo(stage: Dictionary) -> bool:
	var cargo: RigidBody3D = world.props.team_cargo
	targets.erase("c")
	var held: bool = false
	for tick in 240:
		var offset: Vector3 = cargo.global_position - actors.c.body_position()
		var direction := Vector2(offset.x, offset.z).normalized()
		var caught_support: bool = (actors.c.get("_left_target") != null and actors.c.get("_left_target") != cargo) or (actors.c.get("_right_target") != null and actors.c.get("_right_target") != cargo)
		inputs.c = {"move": direction * 0.25, "yaw": atan2(-direction.x, -direction.y), "pitch": -0.4, "left": not caught_support, "right": not caught_support}
		await _step()
		held = actors.c.get("_left_target") == cargo or actors.c.get("_right_target") == cargo
		if held: break
	cargo_evidence = {"grabbed": held, "pickup": cargo.global_position, "body": actors.c.body_position(), "hands": [actors.c.left_area.global_position, actors.c.right_area.global_position], "targets": [str(actors.c.get("_left_target")), str(actors.c.get("_right_target"))]}
	if not held: return false
	var arrived: bool = false
	for tick in 1800:
		if actors.c.get("_left_target") != cargo and actors.c.get("_right_target") != cargo: return false
		var offset: Vector3 = stage.receiver - cargo.global_position
		var error := Vector2(offset.x, offset.z)
		var velocity: Vector3 = cargo.linear_velocity
		var move: Vector2 = (error * 0.6 - Vector2(velocity.x, velocity.z) * 0.18).limit_length(0.6)
		inputs.c = {"move": move, "yaw": atan2(-team._forward.x, -team._forward.z), "pitch": 0.4, "left": true, "right": true}
		await _step()
		if error.length() < 0.4 and Vector2(velocity.x, velocity.z).length() < 0.8:
			arrived = true
			break
	cargo_evidence.arrived = arrived
	cargo_evidence.before_release = cargo.global_position
	inputs.c = {"interact": true}
	for tick in 120:
		await _step()
		if team._cargo_received(stage): break
	cargo_evidence.after_release = cargo.global_position
	cargo_evidence.supported = team._cargo_received(stage)
	return arrived and cargo_evidence.supported

func _run() -> void:
	world = World.new()
	root.add_child(world)
	team = Teamwork.new()
	team.world = world
	world.add_child(team)
	for id: String in ["a", "b", "c"]:
		var actor: Node3D = Puppet.instantiate()
		root.add_child(actor)
		actors[id] = actor
	world.track_puppets(actors.values())
	for stage_index in 3:
		var stage: Dictionary = team.stages[stage_index]
		# Separate negative fixture: even a runner already at the far latch
		# cannot bypass the crossing/ride/cargo requirement while friends power it.
		targets = {"a": stage.pads[0], "b": stage.pads[1], "c": stage.latch - team._right}
		inputs = {}
		for slot: String in actors: actors[slot].reset_at(targets[slot] + Vector3(0, 3, 0))
		await _step(150)
		inputs = {"a": {"interact": true}, "b": {"interact": true}, "c": {"interact": true}}
		await _step(400)
		_check(not stage.latched, stage.kind + ": going straight to far latch cannot bypass the physical job")
		var removed: Node3D = actors.b
		actors.erase("b")
		await _step(60)
		_check(stage.amount < 0.95, stage.kind + ": disconnect closes an unlatched obstacle")
		actors.b = removed
		inputs = {}
		await _step(400)
		var start: float = elapsed
		inputs = {}
		targets = {"a": stage.pads[0], "b": stage.pads[1]}
		actors.a.reset_at(stage.pads[0] + Vector3(0, 3, 0))
		actors.b.reset_at(stage.pads[1] + Vector3(0, 3, 0))
		var runner_start: Vector3 = stage.near + team._forward * (10 if stage_index == 1 else 0)
		actors.c.reset_at(runner_start + Vector3(0, 3, 0))
		targets.c = runner_start
		await _step(150)
		_check(actors.a.is_on_floor and actors.b.is_on_floor and actors.c.is_on_floor, stage.kind + ": three fixtures reach real support")
		if stage_index == 0:
			for index in 90:
				team.tick({"a": actors.a, "b": actors.b}, {"a": {"interact": true}, "b": {"interact": true}}, 1.0 / 60.0)
				await physics_frame
			_check(stage.amount == 0, "Two players cannot power the bridge")
		inputs = {"a": {"interact": true}, "b": {"interact": true}, "c": {"interact": true}}
		if stage_index == 1:
			for index in 480:
				await _step()
				if stage.amount >= 1.0: break
			_check(team._ride_height >= 6.5, "Lift physically carried its recorded rider upward")
		else:
			await _step(210)
		_check(stage.amount >= 0.995, stage.kind + ": distinct operators fully open actual mechanism")
		var reached: bool = false
		if stage_index == 2:
			reached = await _deliver_cargo(stage)
			_check(cargo_evidence.get("grabbed", false), "Runner actually grabs the replicated cargo")
			_check(reached, "Delivered cargo is physically supported on receiving square")
			reached = reached and await _walk(stage.latch - team._right * 1.0)
		else:
			reached = await _walk(stage.latch - team._right * 1.0)
		await _step(30)
		_check(reached, stage.kind + ": runner reaches latch through ordinary controls")
		_check(stage.latched, stage.kind + ": host accepts earned three-person latch")
		evidence.append({"kind": stage.kind, "seconds": elapsed - start, "latched": stage.latched, "amount": stage.amount, "runner": actors.c.body_position(), "operators": [actors.a.body_position(), actors.b.body_position()], "rider_height": team._ride_height, "crossers": team._crossers.keys(), "carriers": team._carriers.keys()})
		print("TEAM_STAGE " + JSON.stringify(evidence[-1]))
		if not stage.latched: break
	_check(team.completed(), "All three physical stages completed")
	_check(team.goal_contains(team.goal_spawn(1)), "Extraction becomes eligible only after all stages")
	var report := {"checks": checks, "passed": checks - failures.size(), "failures": failures, "stages": evidence, "simulated_seconds": elapsed, "limits": "Three authoritative puppets with ordinary controls and real contacts. Each stage starts with an explicit initial actor-position fixture. Not a full approach/tail route, human play, or LAN test."}
	var file := FileAccess.open("res://logs/teamwork-physics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("TEAMWORK_PHYSICS " + JSON.stringify(report))
	for actor: Node3D in actors.values(): actor.queue_free()
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
