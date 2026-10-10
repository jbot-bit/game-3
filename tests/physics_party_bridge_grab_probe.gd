extends SceneTree
## Actual hand input against the untouched full-size ready bridge.
const WorldScript = preload("res://prototypes/physics_party/party_world.gd")
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actor: Node3D
var controls: Dictionary = {}
var elapsed: float = 0.0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = WorldScript.new()
	world.setup(true)
	root.add_child(world)
	actor = PuppetScene.instantiate()
	root.add_child(actor)
	# The only placement is this initial player spawn behind the bridge.
	actor.reset_at(Vector3(4.5, 3.0, -2.5))
	world.track_puppets([actor])
	await _ticks(90)
	var plank: RigidBody3D = world.props.plank_right
	var start: Vector3 = plank.global_position
	_event("initial_settled")
	# Approach before lowering the hands; reaching early can grip the floor.
	for tick in 120:
		controls = {"yaw": 0.0, "move": Vector2(0.0, -1.0)}
		await _ticks(1)
		if actor.body_position().z < -3.2:
			break
	controls = {}
	await _ticks(18)
	_event("approached_without_grabbing")
	for tick in 180:
		controls = {"yaw": 0.0, "pitch": -0.25, "left": true, "right": true, "move": Vector2(0.0, -1.0)}
		await _ticks(1)
		if _holding_plank():
			break
	report.real_grip = _holding_plank()
	_event("grab_attempt")
	if not report.real_grip:
		failures.append("Normal reach did not grip the unchanged full-size bridge")
		_finish()
		return
	var retained_grip_ticks: int = 0
	for tick in 360:
		controls = {"yaw": 0.0, "pitch": 0.2, "left": true, "right": true, "move": Vector2(0.0, 1.0)}
		await _ticks(1)
		if _holding_plank():
			retained_grip_ticks += 1
		if plank.global_position.z - start.z > 1.0:
			break
		if actor.body_position().y < -2.0:
			failures.append("Carrier fell while backdragging the bridge")
			break
	report.backdrag_m = plank.global_position.z - start.z
	report.held_ticks = retained_grip_ticks
	if float(report.backdrag_m) <= 1.0:
		failures.append("Ordinary held backdrag did not move the full-size bridge at least 1m")
	_event("backdrag_end")
	controls = {}
	await _ticks(20)
	report.released = actor.left_joint.node_b.is_empty() and actor.right_joint.node_b.is_empty()
	if not report.released:
		failures.append("Releasing hand buttons did not release the bridge")
	_finish()


func _holding_plank() -> bool:
	return actor._left_target == world.props.plank_right or actor._right_target == world.props.plank_right


func _ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		await physics_frame
		elapsed += 1.0 / 60.0


func _event(label: String) -> void:
	var entry := {"event": label, "elapsed_s": elapsed, "actor": str(actor.body_position()),
		"plank": str(world.props.plank_right.global_transform),
		"left": str(actor.left_joint.node_b), "right": str(actor.right_joint.node_b)}
	events.append(entry)
	print("PARTY_BRIDGE_GRAB_EVENT " + JSON.stringify(entry))


func _finish() -> void:
	actor.release_all()
	report.merge({"elapsed_s": elapsed, "failures": failures, "events": events,
		"digital_movement_only": true,
		"limits": "Digital keyboard-equivalent movement presses/releases and collision-created grabs against the unchanged full-size world plank. Initial actor spawn only; no prop teleport, injected force or joint fixture. One scripted player, not a human playtest."})
	var file := FileAccess.open("res://logs/hands-full-bridge-grab.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PARTY_BRIDGE_GRAB " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
