extends SceneTree
## Standalone rendered acceptance scene; does not start the game or touch saves.
const Art = preload("res://game/world/block_art.gd")
const World = preload("res://game/world/island.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene: Node3D = Node3D.new()
	root.add_child(scene)
	var island: Node3D = World.new()
	scene.add_child(island)
	var colors: Array[Color] = [Color("62b9db"), Color("e67c61"), Color("a28ad6")]
	var points: Array[Vector3] = [Vector3(-64.9, 2.05, 43.0), Vector3(-63.1, 2.05, 42.0), Vector3(-61.3, 2.05, 43.1)]
	for index: int in range(3):
		var crew: Node3D = Art.crew(colors[index])
		crew.position = points[index]
		crew.rotation.y = [0.2, PI, -0.45][index]
		scene.add_child(crew)
		if index == 1:
			(crew.get_node("RightArm/HeldTool") as Node3D).visible = false
			(crew.get_node("LeftArm") as Node3D).rotation.x = -0.9
			(crew.get_node("RightArm") as Node3D).rotation.x = -0.9
			var trophy: Node3D = Art.fish("bellgill", true)
			crew.add_child(trophy)
			trophy.position = Vector3(0.0, 0.94, -0.8)
			trophy.rotation.z = -0.1
	var camera: Camera3D = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(-63.2, 5.6, 49.3)
	camera.fov = 68.0
	camera.far = 850.0
	camera.look_at(Vector3(-63.2, 3.25, 42.9))
	camera.current = true
	var caption: Label = Label.new()
	caption.position = Vector2(24, 672)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("e4d4af"))
	caption.add_theme_color_override("font_shadow_color", Color("202d3a"))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(caption)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs"))
	for mode: String in ["day", "night"]:
		island.call("set_time", 100.0 if mode == "day" else 320.0)
		caption.text = "LAST LIGHT ISLAND   /   %s   /   ENGINE ART PROBE   /   1280 x 720" % mode.to_upper()
		for frame: int in range(12):
			await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		var snapshot: Image = root.get_texture().get_image()
		var output: String = ProjectSettings.globalize_path("res://logs/art-%s.png" % mode)
		var result: Error = snapshot.save_png(output)
		if result != OK:
			push_error("Image save failed: " + error_string(result))
			quit(1)
			return
		print("ART_VISUAL_PROBE_%s_OK: %s (%sx%s)" % [mode.to_upper(), output, snapshot.get_width(), snapshot.get_height()])
	quit(0)
