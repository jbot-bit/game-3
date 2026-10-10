extends SceneTree
## Actual production models at gameplay scale, with no saves or game authority.
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
	environment.environment.background_color=Color("6392a2")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("b9d1df")
	environment.environment.ambient_light_energy=0.36
	scene.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-25,0)
	sun.light_energy=0.64
	sun.shadow_enabled=true
	scene.add_child(sun)
	Art.box(scene,Vector3(0,-0.2,0),Vector3(16,0.4,10),Color("78986d"))
	var sets: Array[String]=["harbour","angler","deckhand","stormwatch"]
	var colors: Array[Color]=[Color("62b9db"),Color("e67c61"),Color("a28ad6"),Color("62b9db")]
	for index: int in range(4):
		var actor: Node3D=Art.crew(colors[index])
		Art.set_outfit_appearance(actor,sets[index])
		actor.position=Vector3(float(index)*2.2-3.3,0,0)
		actor.rotation.y=PI+0.25
		actor.get_node("RightArm/HeldTool").visible=false
		scene.add_child(actor)
		var label: Label3D=Label3D.new()
		label.text=sets[index].capitalize()
		label.font_size=25
		label.pixel_size=0.01
		label.outline_size=6
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=actor.position+Vector3(0,2.65,0)
		scene.add_child(label)
	for index: int in range(4):
		var fish: Node3D=Art.fish(["penny_perch","bellgill","lantern_eel","crown_ray"][index],true)
		fish.position=Vector3(float(index)*2.2-3.3,0.45,1.8)
		fish.rotation.x=-0.3
		scene.add_child(fish)
	var camera: Camera3D=Camera3D.new()
	scene.add_child(camera)
	camera.position=Vector3(5.5,6.6,11)
	camera.look_at(Vector3(0,1.0,0.4))
	camera.fov=50
	camera.current=true
	for frame: int in range(16): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path: String=ProjectSettings.globalize_path("res://logs/crew-outfits.png")
	var result: Error=root.get_texture().get_image().save_png(path)
	print("CREW_OUTFITS_RENDER_"+("OK" if result==OK else "FAILED")+": "+path)
	quit(0 if result==OK else 1)
