extends SceneTree
## Real Jolt bodies: catches pulling that does not reel, swing damping, and stale ropes.
var failures: Array[String] = []
var checks: int = 0
var actor: Node3D
var held: Dictionary = {}
var anchor_body: StaticBody3D

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	actor = load("res://prototypes/physics_party/puppet.tscn").instantiate()
	root.add_child(actor)
	actor.reset_at(Vector3(0, 5, 0))
	anchor_body = _solid(Vector3(0, 16, 0), Vector3(3, 1, 3))
	await _ticks(2)
	_check(actor.get_node_or_null("Grapple") != null, "puppet provides a grapple")
	if actor.get_node_or_null("Grapple") == null:
		_finish()
		return
	var hook = actor.get_node("Grapple")
	held = {"grapple": true, "grapple_mode": "pull", "aim": anchor_body.position}
	await _ticks(2)
	_check(hook.active, "holding grapple attaches to visible static geometry")
	var first_distance: float = actor.body_position().distance_to(hook.anchor)
	await _ticks(45)
	_check(actor.body_position().distance_to(hook.anchor) < first_distance - 3.0, "pull reels the physical puppet toward the hook")
	_check(_finite(), "pull keeps all bones finite")
	held.grapple_mode = "swing"
	await _ticks(2)
	var swing_length: float = hook.rope_length
	_check(hook.mode == "swing" and hook.active, "mode changes while attached")
	for bone in actor.physics_bones: bone.linear_velocity = Vector3(7, 0, 0)
	var start_x: float = actor.body_position().x
	await _ticks(30)
	_check(absf(hook.rope_length - swing_length) < 0.001, "swing never reels in the rope")
	_check(actor.body_position().x > start_x + 1.0, "swing preserves useful sideways momentum without held movement")
	_check(actor.body_position().distance_to(hook.anchor) < swing_length + 0.9, "swing rope limits distance from anchor")
	_check(_finite(), "swing keeps all bones finite")
	var peak_distance: float = 0.0
	for tick in 120:
		await _ticks(1)
		peak_distance = maxf(peak_distance, actor.body_position().distance_to(hook.anchor))
	_check(peak_distance < swing_length + 0.9 and _finite(), "sustained swinging stays bounded for two more seconds")
	var before_release: Vector3 = actor.physical_bone_body.linear_velocity
	held.grapple = false
	await _ticks(1)
	_check(not hook.active, "releasing grapple detaches")
	_check(actor.physical_bone_body.linear_velocity.length() > before_release.length() * 0.65, "detach does not zero launch momentum")
	var launch_speed: float = Vector2(actor.physical_bone_body.linear_velocity.x, actor.physical_bone_body.linear_velocity.z).length()
	await _ticks(15)
	var later_speed: float = Vector2(actor.physical_bone_body.linear_velocity.x, actor.physical_bone_body.linear_velocity.z).length()
	_check(later_speed > launch_speed * 0.6, "released swing carries momentum through the airborne launch")
	actor.reset_at(Vector3(0, 5, 0))
	held = {"grapple": true, "grapple_mode": "swing", "aim": anchor_body.position}
	await _ticks(3)
	_check(hook.active, "grapple can reattach after release")
	actor.release_all()
	_check(not hook.active, "release_all removes the rope for recovery and course changes")
	held = {}
	await _ticks(2)
	anchor_body.position.y = 80
	actor.reset_at(Vector3(0, 5, 0))
	await _ticks(2) # Let Jolt register the moved static fixture before firing.
	held = {"grapple": true, "grapple_mode": "pull", "aim": Vector3(0, 80, 0)}
	await _ticks(3)
	_check(not hook.active, "out of range targets cannot attach")
	anchor_body.position.y = 16
	held = {}
	await _ticks(2)
	var blocker = _solid(Vector3(0, 10, 0), Vector3(8, 1, 8))
	await _ticks(2)
	held = {"grapple": true, "grapple_mode": "pull", "aim": anchor_body.position}
	await _ticks(3)
	_check(hook.active and hook.anchor.y < 11, "host ray hits the blocking surface rather than hooking through it")
	held = {}
	await _ticks(2)
	blocker.queue_free()
	actor.reset_at(Vector3(0, 5, 0))
	await _ticks(2)
	held = {"grapple": true, "grapple_mode": "swing", "aim": anchor_body.position}
	await _ticks(3)
	_check(hook.active, "rope attaches before stale-input check")
	held = {} # Stop refreshing the puppet's input, like a lost connection.
	for index in 35: await physics_frame
	_check(not hook.active, "stale controls release the rope")
	actor.reset_at(Vector3(0, 5, 0))
	held = {"grapple": true, "grapple_mode": "swing", "aim": anchor_body.position}
	await _ticks(3)
	anchor_body.queue_free()
	await _ticks(3)
	_check(not hook.active, "removed world target releases the rope")
	var remote = load("res://prototypes/physics_party/puppet.tscn").instantiate()
	remote.authoritative = false
	root.add_child(remote)
	remote.set_controls({"grapple": true, "grapple_mode": "pull", "aim": Vector3(0, 16, 0)})
	await _ticks(2)
	_check(not remote.get_node("Grapple").active, "client inputs cannot simulate their own grapple")
	remote.get_node("Grapple").present({"active": true, "mode": "swing", "anchor": Vector3(0, 16, 0), "length": 10.0})
	_check(remote.get_node("Grapple").active, "remote can display authoritative rope state")
	remote.queue_free()
	_finish()

func _solid(point: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	root.add_child(body)
	body.position = point
	return body

func _ticks(count: int) -> void:
	for index in count:
		actor.set_controls(held)
		await physics_frame

func _finite() -> bool:
	for bone in actor.physics_bones:
		if not bone.global_position.is_finite() or not bone.linear_velocity.is_finite(): return false
	return true

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func _finish() -> void:
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
