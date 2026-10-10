extends SceneTree
## Real CharacterBody3D traversal using the production island and hunter shape.
## Faster wall time keeps the production 1/60 s physics step: 600 Hz * time scale 10.
const World=preload("res://game/world/island.gd")
var results: Array[Dictionary]=[]

func _initialize() -> void:
	Engine.physics_ticks_per_second=600
	Engine.time_scale=10.0
	call_deferred("_run")

func _run() -> void:
	var scene:=Node3D.new()
	root.add_child(scene)
	var world: Node3D=World.new()
	scene.add_child(world)
	var hunter:=CharacterBody3D.new()
	hunter.collision_layer=8
	hunter.collision_mask=1
	var collider:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.height=3.8
	capsule.radius=0.48
	collider.shape=capsule
	collider.position.y=1.9
	hunter.add_child(collider)
	scene.add_child(hunter)
	var controller: RunController
	var cached: bool="--cached-controller" in OS.get_cmdline_user_args()
	if cached:
		controller=RunController.new()
		controller.world=world
		controller.hunter=hunter
		scene.add_child(controller)
		controller.set_physics_process(false)
	if "--blockers" in OS.get_cmdline_user_args():
		await _inspect_blockers(scene,world,hunter)
		quit(0)
		return
	for repaired: bool in [false,true]:
		world.set_repaired(repaired)
		world.set_campaign({"ridge_steps":repaired})
		hunter.position=world.markers.reeds
		hunter.velocity=Vector3.ZERO
		for frame: int in range(3): await physics_frame
		for marker: String in ["beacon","terraces","jetty","spawn","jetty","terraces","beacon","reeds"]:
			var goal: Vector3=world.markers[marker]
			var start: Vector3=hunter.global_position
			var sample: Vector3=start
			var elapsed: float=0.0
			var sample_elapsed: float=0.0
			var reached: bool=false
			var reason: String="timeout"
			var waypoint: Vector3=start
			var dt: float=0.0
			for frame: int in range(12000):
				await physics_frame
				dt=scene.get_physics_process_delta_time()
				elapsed+=dt
				sample_elapsed+=dt
				waypoint=controller._hunter_route_to(goal,"patrol",dt) if cached else world.route_step(hunter.global_position,goal)
				var direction: Vector3=waypoint-hunter.global_position
				direction.y=0
				direction=direction.normalized()
				hunter.velocity.x=direction.x*2.6
				hunter.velocity.z=direction.z*2.6
				hunter.velocity.y=hunter.velocity.y-22.0*dt if not hunter.is_on_floor() else 0.0
				hunter.move_and_slide()
				if hunter.global_position.y<0:
					reason="fell_in_water"
					break
				if hunter.global_position.distance_to(goal)<=3.0:
					reached=true
					reason="reached"
					break
				if sample_elapsed>=3.0:
					if hunter.global_position.distance_to(sample)<0.35:
						reason="stalled"
						break
					sample=hunter.global_position
					sample_elapsed=0.0
			var item: Dictionary={"repaired":repaired,"goal":marker,"start":str(start),"end":str(hunter.global_position),"waypoint":str(waypoint),"reached":reached,"reason":reason,"elapsed_s":elapsed,"physics_delta":dt,"distance_left":hunter.global_position.distance_to(goal),"collisions":_collisions(hunter)}
			results.append(item)
			print(JSON.stringify(item))
			# Independently test the next route even when this leg found a defect.
			if not reached:
				hunter.global_position=goal
				hunter.velocity=Vector3.ZERO
	var all_passed: bool=true
	for item: Dictionary in results: all_passed=all_passed and item.reached
	var report: Dictionary={"passed":all_passed,"cached_controller":cached,"legs":results}
	var path: String=ProjectSettings.globalize_path("res://logs/hunter-traversal-cached.json" if cached else "res://logs/hunter-traversal.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("HUNTER_TRAVERSAL_"+("PASS" if all_passed else "FAIL")+": "+path)
	quit(0 if all_passed else 1)

func _collisions(hunter: CharacterBody3D) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	for index: int in range(hunter.get_slide_collision_count()):
		var contact: KinematicCollision3D=hunter.get_slide_collision(index)
		var body: Node3D=contact.get_collider() as Node3D
		if body!=null: found.append({"path":str(body.get_path()),"body_position":str(body.global_position),"normal":str(contact.get_normal())})
	return found

func _inspect_blockers(scene: Node3D,world: Node3D,hunter: CharacterBody3D) -> void:
	var cases: Array[Dictionary]=[
		{"repaired":false,"at":Vector3(38.08099,2.001,-51.03613),"goal":"terraces"},
		{"repaired":false,"at":Vector3(-59.42256,2.001,-33.67992),"goal":"jetty"},
		{"repaired":true,"at":Vector3(63.31133,2.001,-45.83823),"goal":"terraces"},
		{"repaired":true,"at":Vector3(57.39687,2.031,-40.07405),"goal":"reeds"}]
	for entry: Dictionary in cases:
		world.set_repaired(entry.repaired)
		world.set_campaign({"ridge_steps":entry.repaired})
		hunter.global_position=entry.at
		hunter.velocity=Vector3.ZERO
		for frame: int in range(120):
			await physics_frame
			var dt: float=scene.get_physics_process_delta_time()
			var direction: Vector3=world.route_step(hunter.global_position,world.markers[entry.goal])-hunter.global_position
			direction.y=0
			direction=direction.normalized()
			hunter.velocity.x=direction.x*2.6
			hunter.velocity.z=direction.z*2.6
			hunter.velocity.y=hunter.velocity.y-22.0*dt if not hunter.is_on_floor() else 0.0
			hunter.move_and_slide()
		print(JSON.stringify({"goal":entry.goal,"start":str(entry.at),"end":str(hunter.global_position),"collisions":_collisions(hunter)}))
