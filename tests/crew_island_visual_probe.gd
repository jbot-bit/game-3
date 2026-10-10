extends SceneTree
## Reviews front/back character readability in the real island environment.
const World=preload("res://game/world/island.gd")
const Crew=preload("res://game/player/animated_crew.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var world: Node3D=World.new()
	root.add_child(world)
	world.set_time(100.0)
	var crew: Array[Node3D]=[]
	var anchor: Vector3=world.markers.spawn
	for slot: int in range(3):
		var actor: Node3D=Crew.new()
		actor.configure([Color("62b9db"),Color("e67c61"),Color("a28ad6")][slot],["harbour","angler","deckhand"][slot],"starter")
		world.add_child(actor)
		actor.position=anchor+Vector3((slot-1)*2.0,0,0)
		crew.append(actor)
	var camera: Camera3D=Camera3D.new()
	world.add_child(camera)
	camera.current=true
	camera.fov=50
	for side: String in ["front","back"]:
		camera.position=anchor+Vector3(0,3.1,-7.8 if side=="front" else 7.8)
		camera.look_at(anchor+Vector3(0,1.1,0))
		for frame: int in range(30):
			for actor: Node3D in crew: actor.animate_motion(0.0,1.0/60.0)
			await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		var output: String="res://logs/crew-island-"+side+".png"
		var result: Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		if result!=OK:
			push_error("Unable to save "+output)
			quit(1)
			return
		print("CREW_ISLAND_RENDER "+output)
	quit(0)
