extends SceneTree
const Art=preload("res://game/world/block_art.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var scene: Node3D=Node3D.new()
	root.add_child(scene)
	var env: WorldEnvironment=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("6392a2")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("b9d1df")
	env.environment.ambient_light_energy=0.36
	scene.add_child(env)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-25,0)
	sun.light_energy=0.64
	sun.shadow_enabled=true
	scene.add_child(sun)
	Art.box(scene,Vector3(0,-0.2,0),Vector3(22,0.4,20),Color("78986d"))
	var beacon: Node3D=Art.lighthouse()
	beacon.position=Vector3(4,0,-3)
	scene.add_child(beacon)
	for index: int in range(2):
		var crate: Node3D=Art.cache_crate(Art.AMBER if index==0 else Art.WATER)
		crate.position=Vector3(-1.2-float(index)*2.7,0,2)
		if index==1: crate.get_node("Lid").rotation.x=-1.25
		scene.add_child(crate)
	var crew: Node3D=Art.crew(Color("62b9db"))
	crew.rotation.y=PI+0.3
	crew.position=Vector3(1.2,0,1.8)
	crew.get_node("RightArm/HeldTool").visible=false
	scene.add_child(crew)
	Art.beam(scene,Vector3(-5.4,0,-1),Vector3(-5.4,3.3,-1),0.22,Art.WOOD)
	Art.lantern(scene,Vector3(-5.4,3.5,-1))
	var camera: Camera3D=Camera3D.new()
	scene.add_child(camera)
	camera.position=Vector3(10,8,16)
	camera.look_at(Vector3(0,3,0))
	camera.fov=53
	camera.current=true
	for frame: int in range(16): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var result: Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://logs/faceted-props.png"))
	camera.position=Vector3(2.6,3.8,7.4)
	camera.look_at(Vector3(-1.2,0.65,2))
	for frame: int in range(4): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var detail_result: Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://logs/cache-detail.png"))
	if result==OK: result=detail_result
	print("PROPS_RENDER_"+("OK" if result==OK else "FAILED"))
	quit(0 if result==OK else 1)
