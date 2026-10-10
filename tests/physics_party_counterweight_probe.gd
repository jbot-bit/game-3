extends SceneTree
## Course contract and physical controls. Bot steering is analog, not a human test.
const COURSE_PATH := "res://prototypes/physics_party/party_counterweight_world.gd"
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(COURSE_PATH):
		print("COUNTERWEIGHT_FAIL Missing second course world")
		quit(1)
		return
	var world: Node3D = load(COURSE_PATH).new()
	world.setup(true)
	root.add_child(world)
	await physics_frame
	_check(world.props.size() == 7, "Seven existing movable props")
	for slot in 3:
		_check(not world.goal_contains(world.spawn_point(slot)), "Start is outside goal")
		_check(world.checkpoint_contains(world.spawn_point(slot, 1)), "Checkpoint respawn is in checkpoint")
		_check(world.goal_contains(world.spawn_point(slot, 2)), "Finish respawn is in goal")
	_check(world.wind_at(Vector3(9, 6, -17)).length() > 0.0, "Plank crossing has crosswind")
	var initial: Dictionary = world.capture_prop_poses()
	world.set_wind(-1)
	world.reset_props()
	_check(world.wind_direction == 1, "Restart restores wind")
	_check(world.capture_prop_poses().size() == initial.size(), "Props retain replication identities")
	print("COUNTERWEIGHT_CONTRACT " + JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)
