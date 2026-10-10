extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	var scene: Node3D=Node3D.new()
	root.add_child(scene)
	var environment: WorldEnvironment=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("9ec5d0")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d4e0e6")
	environment.environment.ambient_light_energy=0.5
	scene.add_child(environment)
	var sun: DirectionalLight3D=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-25,0)
	sun.light_energy=0.8
	sun.shadow_enabled=true
	scene.add_child(sun)
	var plane: MeshInstance3D=MeshInstance3D.new()
	var mesh: PlaneMesh=PlaneMesh.new()
	mesh.size=Vector2(20,14)
	plane.mesh=mesh
	var material: StandardMaterial3D=StandardMaterial3D.new()
	material.albedo_color=Color("77935b")
	plane.material_override=material
	scene.add_child(plane)
	var animations: Array[String]=["Idle","Walking_A","Running_A","2H_Ranged_Aiming"]
	for index: int in range(4):
		var document: GLTFDocument=GLTFDocument.new()
		var state: GLTFState=GLTFState.new()
		document.append_from_file(ProjectSettings.globalize_path("res://.tools/art-sources/kaykit-adventurers/Rogue.glb"),state)
		var rig: Node3D=document.generate_scene(state)
		for node: Node in rig.find_children("*","MeshInstance3D",true,false):
			if node.name in ["Knife_Offhand","1H_Crossbow","2H_Crossbow","Knife","Throwable","Rogue_Cape"]:
				node.get_parent().remove_child(node)
				node.free()
		scene.add_child(rig)
		rig.position.x=float(index)*2.2-3.3
		rig.rotation.y=-0.3
		var animation: AnimationPlayer=rig.get_node("AnimationPlayer")
		animation.play(animations[index])
		animation.seek(0.3,true)
		animation.pause()
		var label: Label3D=Label3D.new()
		label.text=animations[index]
		label.font_size=24
		label.pixel_size=0.009
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=rig.position+Vector3(0,2.6,0)
		scene.add_child(label)
	var camera: Camera3D=Camera3D.new()
	scene.add_child(camera)
	camera.position=Vector3(4,5,11)
	camera.look_at(Vector3(0,1,0))
	camera.fov=48
	camera.current=true
	for frame: int in range(16): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path: String=ProjectSettings.globalize_path("res://logs/kaykit-source.png")
	var result: Error=root.get_texture().get_image().save_png(path)
	print("KAYKIT_SOURCE_RENDER ",result," ",path)
	quit(0 if result==OK else 1)
