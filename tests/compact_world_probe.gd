extends SceneTree
const World=preload("res://game/world/island.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world: Node3D=World.new()
	root.add_child(world)
	for frame: int in range(3): await physics_frame
	var points: Array[Vector3]=[]
	points.assign(World.ROUTE_POINTS)
	for id: String in ["spawn","boat","jetty","terraces","repair","beacon","repair_cache","engine_cache","reel_cache"]: points.append(world.markers[id])
	for index: int in range(points.size()):
		var at: Vector3=points[index]
		var query:=PhysicsShapeQueryParameters3D.new()
		var shape:=CapsuleShape3D.new()
		shape.radius=0.5
		shape.height=3.8
		query.shape=shape
		query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*1.95)
		query.collision_mask=1
		var hits: Array[Dictionary]=world.get_world_3d().direct_space_state.intersect_shape(query)
		var names: Array[String]=[]
		for hit: Dictionary in hits: names.append(str(hit.collider.get_path()))
		var connected: Array[int]=[]
		for other: int in range(points.size()):
			if index!=other and world._route_segment(at,points[other]): connected.append(other)
		print("ROUTE_NODE ",index," ",at," floor=",world._route_ground(at)," solid=",names," connects=",connected)
	for id: String in ["repair","rod_cache","engine_cache","reel_cache"]:
		var at: Vector3=world.markers.boat
		for hop: int in range(12):
			var next: Vector3=world.route_step(at,world.markers[id])
			print("HOP ",id," ",at," -> ",next," goal=",world.markers[id])
			if next.distance_to(at)<0.1 or next.distance_to(world.markers[id])<0.1: break
			at=next
	quit(0)
