extends SceneTree
const Crew=preload("res://game/player/animated_crew.gd")
const Art=preload("res://game/world/block_art.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var scene: Node3D=Node3D.new()
	root.add_child(scene)
	var environment: WorldEnvironment=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("91adb8")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c0d6e2")
	environment.environment.ambient_light_energy=0.42
	scene.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_energy=0.68
	sun.shadow_enabled=true
	scene.add_child(sun)
	Art.box(scene,Vector3(0,-0.2,0),Vector3(25,0.4,20),Color("668568"))
	Art.box(scene,Vector3(0,-0.08,1.9),Vector3(15,0.05,3.5),Color("b6a58b"))
	var actors: Array[Node3D]=[]
	var labels: Array[Label3D]=[]
	var sets: Array[String]=["harbour","angler","deckhand","stormwatch"]
	var colours: Array[Color]=[Color("62b9db"),Color("e67c61"),Color("a28ad6"),Color("62b9db")]
	for index: int in range(4):
		var actor: Node3D=Crew.new()
		actor.configure(colours[index],sets[index],"starter")
		actor.position=Vector3(float(index)*2.7-4.0,0,0)
		actor.rotation.y=PI+0.35
		scene.add_child(actor)
		actors.append(actor)
		var label: Label3D=Label3D.new()
		label.text=["Idle / Harbour","Walk / Angler","Carry / Deckhand","Fish / Stormwatch"][index]
		label.position=actor.position+Vector3(0,2.65,0)
		label.font_size=23
		label.pixel_size=0.009
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(label)
		labels.append(label)
	var fish: Node3D=Art.fish("penny_perch",true)
	actors[2].add_child(fish)
	fish.position=Vector3(0,1,-0.82)
	var camera: Camera3D=Camera3D.new()
	scene.add_child(camera)
	camera.position=Vector3(4.4,5.5,12)
	camera.look_at(Vector3(0,1.1,0.2))
	camera.fov=49
	camera.current=true
	for frame: int in range(150):
		actors[0].animate_motion(0.0,1.0/60.0)
		actors[1].animate_motion(2.4,1.0/60.0)
		actors[2].animate_motion(4.25,1.0/60.0,true)
		actors[3].animate_motion(0.0,1.0/60.0,false,false,false,false,true)
		await process_frame
		if frame in [30,45,60,75,135]:
			RenderingServer.force_draw(false)
			await RenderingServer.frame_post_draw
			var path: String=ProjectSettings.globalize_path("res://logs/animated-crew-%s.png"%frame)
			var result: Error=root.get_texture().get_image().save_png(path)
			print("ANIMATED_CREW_FRAME ",frame," result=",result," ",path)
			if result!=OK:
				quit(1)
				return
	actors[0].play_action("throw")
	actors[1].set_seated(true)
	fish.visible=false
	for index: int in range(4): labels[index].text=["Throw","Seated boat pose","Downed","Shoulder passenger"][index]
	for frame: int in range(50):
		actors[0].animate_motion(0.0,1.0/60.0)
		actors[1].animate_motion(0.0,1.0/60.0)
		actors[2].animate_motion(0.0,1.0/60.0,false,true)
		actors[3].animate_motion(0.0,1.0/60.0,false,true,true)
		await process_frame
		if frame==35:
			RenderingServer.force_draw(false)
			await RenderingServer.frame_post_draw
			var path: String=ProjectSettings.globalize_path("res://logs/animated-crew-actions.png")
			var result: Error=root.get_texture().get_image().save_png(path)
			print("ANIMATED_CREW_ACTIONS result=",result," ",path)
	print("ANIMATED_CREW_PROBE_OK draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0)
