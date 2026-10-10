extends SceneTree
## Focused recovery fixture: actual overlap-created grabs, controlled fall pose.
const WorldScript = preload("res://prototypes/physics_party/party_world.gd")
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actor: Node3D
var checks: int = 0
var failures: Array[String] = []
var controls: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = WorldScript.new()
	world.setup(true)
	root.add_child(world)
	# Recovery is stepped explicitly after the contacts are established.
	world.set_physics_process(false)
	actor = PuppetScene.instantiate()
	root.add_child(actor)
	actor.reset_at(world.spawn_point(1))
	world.track_puppets([actor])
	await _ticks(90)
	controls = {"left": true, "right": true, "pitch": 0.1}
	await _ticks(20)
	actor.release_all()
	var returning: RigidBody3D = world.props.block_1
	var retained: RigidBody3D = world.props.block_2
	returning.freeze = true
	retained.freeze = true
	returning.global_position = actor.left_area.global_position
	retained.global_position = actor.right_area.global_position
	for tick in 20:
		await _ticks(1)
		if actor._left_target == returning and actor._right_target == retained:
			break
	_check(actor._left_target == returning and not actor.left_joint.node_b.is_empty(), "real left overlap creates a joint to the returning prop")
	_check(actor._right_target == retained and not actor.right_joint.node_b.is_empty(), "real right overlap creates an independent retained joint")
	if not failures.is_empty():
		_finish()
		return
	var retained_path: NodePath = actor.right_joint.node_b
	var torso_before: Vector3 = actor.body_position()
	# Deliberately position only the fixture prop below the live recovery plane.
	# This isolates recovery ordering, not the probability of a natural fall.
	returning.global_position.y = -15.0
	world._physics_process(1.0 / 60.0)
	_check(returning.global_position.y > -1.0, "world automatically restores the below-floor prop")
	_check(actor.left_joint.node_b.is_empty() and actor._left_target == null, "recovery releases the attached hand before the prop returns")
	_check(actor.right_joint.node_b == retained_path and actor._right_target == retained, "recovery preserves the other hand's unrelated grip")
	_check(actor.body_position().distance_to(torso_before) < 0.001, "prop recovery does not teleport the carrier")
	controls = {}
	actor.set_controls({})
	actor.release_all()
	await _ticks(3)
	_finish()


func _ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		await physics_frame


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures.append(message)
	print(("PASS " if passed else "FAIL ") + message)


func _finish() -> void:
	var result := {"checks": checks, "failures": failures,
		"limits": "Real collision-overlap-created hand joints; controlled below-floor prop position triggers the actual world recovery path. Component regression, not a natural fall or human playtest."}
	var file := FileAccess.open("res://logs/hands-full-prop-recovery.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("PARTY_PROP_RECOVERY " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
