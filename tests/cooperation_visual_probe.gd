extends SceneTree
## Renders the actual production carry pose and supply body without loading saves.
const PlayerBody=preload("res://game/player/player.gd")
const CellBody=preload("res://game/physics/supply_cell.gd")
const Art=preload("res://game/world/block_art.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var scene:=Node3D.new()
	root.add_child(scene)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("397884")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("bad1d5")
	environment.environment.ambient_light_energy=0.65
	scene.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-25,0)
	sun.light_energy=0.55
	scene.add_child(sun)
	Art.box(scene,Vector3(0,-0.2,0),Vector3(14,0.4,10),Color("77935b"),true)
	Art.box(scene,Vector3(0,0.015,0),Vector3(14,0.03,4),Color("826347"))
	var carrier: CharacterBody3D=PlayerBody.new()
	carrier.setup("crew_1",Color("62b9db"))
	scene.add_child(carrier)
	carrier.position=Vector3(-2,0.05,0)
	carrier.rotation.y=0.2
	carrier.carrying_teammate=true
	carrier.lamp.visible=false
	var passenger: CharacterBody3D=PlayerBody.new()
	passenger.setup("crew_2",Color("e67c61"))
	scene.add_child(passenger)
	passenger.being_carried=true
	passenger.downed=true
	passenger.lamp.visible=false
	var supplier: CharacterBody3D=PlayerBody.new()
	supplier.setup("crew_3",Color("a28ad6"))
	scene.add_child(supplier)
	supplier.position=Vector3(2,0.05,0)
	supplier.rotation.y=-0.5
	supplier.carrying=true
	supplier.lamp.visible=false
	var cell: RigidBody3D=CellBody.new()
	cell.setup_cell("cell_1")
	scene.add_child(cell)
	cell.set_host_simulated(true)
	cell.set_carry_pose(supplier.carry_transform(),supplier.global_position+Vector3.UP)
	var second: RigidBody3D=CellBody.new()
	second.setup_cell("cell_2")
	scene.add_child(second)
	second.position=Vector3(0,0.38,-1.5)
	var camera:=Camera3D.new()
	scene.add_child(camera)
	camera.position=Vector3(5,5,8)
	camera.look_at(Vector3(0,1,0))
	camera.fov=56
	camera.current=true
	for frame: int in range(24):
		carrier.animate(1.0/60.0,0.4)
		passenger.global_transform=carrier.rescue_transform()
		passenger.animate(1.0/60.0,0.0)
		supplier.animate(1.0/60.0,0.0)
		await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path: String=ProjectSettings.globalize_path("res://logs/cooperation-bodies.png")
	var result: Error=root.get_texture().get_image().save_png(path)
	print("COOPERATION_RENDER_"+("OK" if result==OK else "FAILED")+": "+path)
	quit(0 if result==OK else 1)
