extends SceneTree
## Native rendered compact-map acceptance; never loads or mutates a save.
const World=preload("res://game/world/island.gd")
const Crew=preload("res://game/player/animated_crew.gd")
const Game=preload("res://game/main.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var world: Node3D=World.new()
	root.add_child(world)
	var crew: Array[Node3D]=[]
	for slot: int in range(3):
		var actor: Node3D=Crew.new()
		actor.configure([Color("62b9db"),Color("e67c61"),Color("a28ad6")][slot],"harbour","starter")
		world.add_child(actor)
		actor.position=world.markers.spawn+Vector3((slot-1)*2.5,0,0)
		actor.animate_motion(0,0.5,false,false,false,false,false)
		crew.append(actor)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.current=true
	camera.fov=68
	var shots: Array[Dictionary]=[
		{"id":"home","time":100.0,"look":world.markers.spawn+Vector3(0,1.2,0),"offset":Vector3(0,4.8,8.2)},
		{"id":"overview","time":100.0,"look":Vector3(0,0,0),"offset":Vector3(52,77,88)},
		{"id":"reeds-night","time":330.0,"look":world.markers.reeds_cast+Vector3(0,1.7,0),"offset":Vector3(0,3.262,6.753)}
	]
	for shot: Dictionary in shots:
		world.set_time(shot.time)
		if shot.id=="reeds-night":
			world.set_station("reeds",true)
			for slot: int in range(3): crew[slot].position=world.markers.reeds_cast+Vector3(0,0,(slot-1)*1.6)
		camera.position=shot.look+shot.offset
		camera.look_at(shot.look)
		for frame: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var output: String="res://logs/compact-"+str(shot.id)+".png"
		var result: Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		if result!=OK:
			push_error("Unable to save "+output)
			quit(1)
			return
		print("COMPACT_RENDER "+output)
	world.queue_free()
	await process_frame
	var app: Node3D=Game.new()
	root.add_child(app)
	app.game_port=24647
	app.save_path="user://tests/compact-render-"+str(Time.get_ticks_usec())+".json"
	app._host("Harbour")
	app.set_physics_process(false)
	var c: RunController=app.controller
	c.avatars.crew_1.global_position=app.world.markers.reeds_cast
	c.avatars.crew_1.last_dry=c.avatars.crew_1.global_position
	c.run.elapsed_s=330
	c.run.phase="night"
	c.lights.set_reserve("reeds")
	c.hunter.global_position=app.world.markers.beacon
	app.camera.yaw=0
	c._publish()
	for frame: int in range(70): await process_frame
	await RenderingServer.frame_post_draw
	var actual_output: String="res://logs/compact-main-reeds-night.png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(actual_output))
	print("COMPACT_RENDER "+actual_output)
	app.session.close()
	quit(0)
