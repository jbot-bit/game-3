extends SceneTree
## Inspect the real starting-area collision independently of network transport.
const World=preload("res://game/world/island.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world: Node3D=World.new()
	root.add_child(world)
	var actor:=CharacterBody3D.new()
	actor.collision_layer=2
	actor.collision_mask=1
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.38
	capsule.height=1.9
	shape.shape=capsule
	shape.position.y=0.95
	actor.add_child(shape)
	world.add_child(actor)
	for slot in range(3):
		var start: Vector3=world.markers.spawn+Vector3((slot-1)*2.5,0,0)
		actor.global_position=start
		actor.velocity=Vector3.ZERO
		await physics_frame
		var ray:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*5,start-Vector3.UP*5,1)
		var floor_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		var blockers: Dictionary={}
		for tick in range(60):
			await physics_frame
			actor.velocity.x=0
			actor.velocity.z=-5
			actor.velocity.y=actor.velocity.y-22.0/60.0 if not actor.is_on_floor() else 0.0
			actor.move_and_slide()
			for index in range(actor.get_slide_collision_count()):
				var contact: KinematicCollision3D=actor.get_slide_collision(index)
				blockers[str(contact.get_collider().get_path())]={"normal":str(contact.get_normal()),"position":str(contact.get_position())}
		print("SPAWN_COLLISION "+JSON.stringify({"slot":slot,"start":str(start),"end":str(actor.global_position),"distance":start.distance_to(actor.global_position),"floor":str(floor_hit.get("position",Vector3.INF)),"blockers":blockers}))
	world.queue_free()
	await process_frame
	quit(0)
