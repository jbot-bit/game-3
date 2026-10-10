extends SceneTree
## Real physical-bone/ShapeCast contacts. Controlled fixture, not a course run.
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor = Puppet.instantiate()
	root.add_child(actor)
	actor.reset_at(Vector3(-5, 4, 0))
	var friend = Puppet.instantiate()
	root.add_child(friend)
	friend.reset_at(Vector3(5, 4, 0))
	# Keep fixtures near the cast while using genuine registered bone colliders.
	for puppet in [actor, friend]:
		for bone: PhysicalBone3D in puppet.physics_bones:
			bone.gravity_scale = 0.0
	var floor_body := StaticBody3D.new()
	floor_body.name = "RealFloor"
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 0.2, 3)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.position = Vector3(12, 0, 0)
	await physics_frame
	await physics_frame
	var own_leg: PhysicalBone3D = actor.left_floor.get_parent()
	var friend_leg: PhysicalBone3D = friend.left_floor.get_parent()
	var own_cast := _cast(own_leg.global_position + Vector3.UP * 0.8)
	var friend_cast := _cast(friend_leg.global_position + Vector3.UP * 0.8)
	var floor_cast := _cast(Vector3(12, 0.8, 0))
	for bone: PhysicalBone3D in actor.physics_bones:
		if bone != own_leg: own_cast.add_exception(bone)
	for bone: PhysicalBone3D in friend.physics_bones:
		if bone != friend_leg: friend_cast.add_exception(bone)
	own_cast.force_shapecast_update()
	friend_cast.force_shapecast_update()
	floor_cast.force_shapecast_update()
	_check(_upward_hit(own_cast, own_leg), "own-leg fixture contains a real upward bone contact")
	_check(not actor._floor_contact(own_cast), "own physical bone cannot grant ground contact")
	_check(_upward_hit(friend_cast, friend_leg), "friend fixture contains a real upward bone contact")
	_check(actor._floor_contact(friend_cast), "another player's physical bone remains valid support")
	_check(_upward_hit(floor_cast, floor_body), "floor fixture contains a real upward static contact")
	_check(actor._floor_contact(floor_cast), "ordinary floor contact still grants ground contact")
	print("FLOOR_CONTACT_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "limits": "Two gravity-disabled puppet fixtures and real ShapeCast contacts against their physical leg colliders plus a static floor. No natural airborne exploit or family play claim."}))
	quit(0 if failures.is_empty() else 1)

func _cast(at: Vector3) -> ShapeCast3D:
	var cast := ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.06
	cast.shape = sphere
	cast.target_position = Vector3.DOWN * 2.0
	cast.max_results = 16
	root.add_child(cast)
	cast.global_position = at
	return cast

func _upward_hit(cast: ShapeCast3D, body: PhysicsBody3D) -> bool:
	for index in cast.get_collision_count():
		if cast.get_collider(index) == body and cast.get_collision_normal(index).y > 0.5:
			return true
	return false

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed: failures.append(message)
	print(("PASS " if passed else "FAIL ") + message)
