extends "res://tests/physics_party_teamwork_probe.gd"
## Full first course: only the initial spawn is placed. Recoveries, if any, are F-equivalent.
var supports: Dictionary = {"a": {}, "b": {}, "c": {}}
var route_events: Array = []
var recoveries: Array = []
var approach_checkpoint: int = 0

func _step(count: int = 1) -> void:
	for index in count:
		for actor: Node3D in actors.values():
			var wind: Vector3 = world.wind_at(actor.body_position())
			for bone: PhysicalBone3D in actor.physics_bones: bone.linear_velocity += wind / 60.0
		await super._step(1)
		for id: String in actors:
			var actor: Node3D = actors[id]
			if actor.is_on_floor and world.checkpoint_contains(actor.body_position()): approach_checkpoint = 1
			for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
				for hit in cast.get_collision_count():
					var body: Object = cast.get_collider(hit)
					if body is Node and cast.get_collision_normal(hit).y > 0.5:
						var label: String = str(body.name)
						supports[id][label] = int(supports[id].get(label, 0)) + 1

func _event(label: String) -> void:
	var positions: Dictionary = {}
	var grounded: Dictionary = {}
	for id: String in actors:
		positions[id] = actors[id].body_position()
		grounded[id] = {"floor": actors[id].is_on_floor, "grace": actors[id]._floor_grace}
	var cargo: RigidBody3D = world.props.team_cargo
	route_events.append({"event": label, "seconds": elapsed, "positions": positions, "grounded": grounded, "stage": team.capture(), "cargo": {"position": cargo.global_position, "velocity": cargo.linear_velocity, "receiver_supported": team._cargo_received(team.stages[2])}})
	print("TEAM_ROUTE_EVENT " + JSON.stringify(route_events[-1]))

func _approach() -> bool:
	var progress := {"a": 0, "b": 0, "c": 0}
	var jumped := {"a": false, "b": false, "c": false}
	var left_floor := {"a": false, "b": false, "c": false}
	var last_jump := {"a": -10.0, "b": -10.0, "c": -10.0}
	var sides := {"a": -4.5, "b": 4.5, "c": 4.5}
	for tick in 4800:
		var finished: int = 0
		for id: String in actors:
			var actor: Node3D = actors[id]
			var at: Vector3 = actor.body_position()
			if at.y < -12:
				if recoveries.size() >= 6: return false
				actor.reset_at(world.spawn_point(["a", "b", "c"].find(id), approach_checkpoint))
				team.forget_actor(id)
				recoveries.append({"actor": id, "seconds": elapsed, "checkpoint": approach_checkpoint})
				progress[id] = 3 if approach_checkpoint > 0 else 0
				jumped[id] = false
				left_floor[id] = false
				continue
			var step: int = progress[id]
			if step >= 7:
				finished += 1
				inputs[id] = {}
				continue
			var lane: float = float(["a", "b", "c"].find(id) - 1) * 0.75
			var points: Array[Vector2] = [Vector2(sides[id], -3.5), Vector2(sides[id], -6.1), Vector2(sides[id], -15.5), Vector2(lane, -16.8), Vector2(lane, -20), Vector2(lane, -28.4), Vector2(lane * 2, -33)]
			var target: Vector2 = points[step]
			targets[id] = Vector3(target.x, 0, target.y)
			var distance: float = Vector2(at.x, at.z).distance_to(target)
			var should_jump: bool = false
			if step in [1, 4] and not jumped[id] and actor.is_on_floor: should_jump = true
			if step == 5 and at.z < -25.8 and not jumped[id] and actor.is_on_floor: should_jump = true
			if step == 6 and elapsed - float(last_jump[id]) > 1.2 and actor.is_on_floor: should_jump = true
			if should_jump:
				jumped[id] = true
				last_jump[id] = elapsed
			if jumped[id] and not actor.is_on_floor: left_floor[id] = true
			inputs[id] = {"jump": should_jump}
			var done: bool = actor.is_on_floor and distance < 0.65
			if step in [1, 4]: done = done and left_floor[id]
			if step == 5: done = actor.is_on_floor and (team._supported_by(actor, world.get_node("SteppingStone")) or team._supported_by(actor, world.get_node("Finish")))
			if step == 6: done = actor.is_on_floor and world.goal_contains(at)
			if done:
				progress[id] += 1
				jumped[id] = false
				left_floor[id] = false
				_event("approach_" + id + "_" + str(step))
		if finished == 3: return true
		await _step()
	_event("approach_timeout_" + str(progress))
	return false

func _group(destinations: Dictionary, timeout: float = 24) -> bool:
	targets = destinations.duplicate()
	var started: float = elapsed
	while elapsed - started < timeout:
		var done: bool = true
		for id: String in actors:
			var at: Vector3 = actors[id].body_position()
			if not at.is_finite() or at.y < -12: return false
			var target: Vector3 = targets[id]
			if Vector2(at.x - target.x, at.z - target.z).length() > 0.65 or not actors[id].is_on_floor: done = false
		if done: return true
		await _step()
	return false

func _lanes(center: Vector3) -> Dictionary:
	return {"a": center - team._right * 1.5, "b": center, "c": center + team._right * 1.5}

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
		actor.reset_at(world.spawn_point(["a", "b", "c"].find(id)))
	world.track_puppets(actors.values())
	await _step(100)
	_event("initial_spawn_settled")
	var ok: bool = await _approach()
	_check(ok, "All three traverse the original first-course approach")
	if ok:
		for id: String in actors:
			_check(supports[id].has("plank_left") or supports[id].has("plank_right"), id + " stood on a real loose approach bridge")
			_check(supports[id].has("seesaw"), id + " stood on the original seesaw")
		_event("approach_complete")
	for stage_index in (3 if ok else 0):
		var stage: Dictionary = team.stages[stage_index]
		inputs = {}
		ok = await _group(_lanes(stage.near - team._forward * 3))
		if not ok: _check(false, stage.kind + ": crew reaches staging without teleport"); break
		# Fan out across the broad staging deck before the runner boards. Sending
		# two ragdolls through each other can deadlock a naive waypoint controller.
		ok = await _group({"a": stage.pads[0], "b": stage.pads[1] - team._forward * 4, "c": stage.near + team._forward * (0 if stage_index == 2 else 2)})
		if not ok: _check(false, stage.kind + ": crew fans out on staging deck"); break
		ok = await _group({"a": stage.pads[0], "b": stage.pads[1], "c": stage.near + team._forward * (10 if stage_index == 1 else 0)})
		if not ok: _check(false, stage.kind + ": operators and runner reach their stations"); break
		_event(stage.kind + "_stations_ready")
		inputs = {"a": {"interact": true}, "b": {"interact": true}, "c": {"interact": true}}
		for tick in 480:
			await _step()
			if stage.amount >= 0.995: break
		_check(stage.amount >= 0.995, stage.kind + ": mechanism opens under held controls")
		if stage_index == 2:
			ok = await _deliver_cargo(stage)
			_check(cargo_evidence.get("grabbed", false), "Runner grabs actual crate after continuous route")
			_check(ok, "Cargo reaches physical receiving support")
			_event("cargo_released_" + str(cargo_evidence))
		ok = await _walk(stage.latch - team._right)
		await _step(15)
		_check(ok and stage.latched, stage.kind + ": earned latch during continuous route")
		_event(stage.kind + "_latched" if stage.latched else stage.kind + "_failed")
		if not stage.latched: break
		inputs = {}
		if stage_index == 1:
			# The two former operators use the now-unlocked physical escape ramp.
			ok = await _group({"a": stage.near + team._right * 8 - team._forward * 3, "b": stage.near + team._right * 8 - team._forward, "c": stage.far})
			if ok: ok = await _group({"a": stage.far + team._right * 8, "b": stage.far + team._right * 8 + team._forward * 2, "c": stage.far})
		else:
			# Operators return from side pads to the center before crossing the gap.
			ok = await _group({"a": stage.near - team._right * 1.3 + team._forward * 3, "b": stage.near + team._right * 1.3 + team._forward * 3, "c": stage.far + team._right * 2.0})
		if ok: ok = await _group(_lanes(stage.far))
		_check(ok, stage.kind + ": former operators physically regroup at checkpoint")
		_event(stage.kind + "_crew_regrouped")
		if not ok: break
	if ok and team.completed(): ok = await _group(_lanes(team._goal))
	_check(team.completed(), "Three mechanisms complete in continuous run")
	for id: String in actors: _check(team.goal_contains(actors[id].body_position()) and actors[id].is_on_floor, id + " actually stands at final extraction")
	_event("route_end")
	var report := {"checks": checks, "passed": checks - failures.size(), "failures": failures, "simulated_seconds": elapsed, "recoveries": recoveries, "events": route_events, "supports": supports, "limits": "Three real authoritative puppets, concurrent ordinary movement, jumps and hand grabs. Initial spawn only; any explicit F-equivalent recovery is listed. No powers or grapples. Scripted first-course traversal, not a human completion-time estimate or LAN test."}
	var file := FileAccess.open("res://logs/teamwork-full-route.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("TEAMWORK_FULL_ROUTE " + JSON.stringify(report))
	for actor: Node3D in actors.values(): actor.queue_free()
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
