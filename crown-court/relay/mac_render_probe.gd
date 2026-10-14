extends SceneTree
# Diagnostic only: never modifies the exported pack or player saves.
var mode := "minimal"
var output := ""
var frames := 0
var began := 0
var app
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="): mode = arg.trim_prefix("mode=")
		if arg.begins_with("output="): output = arg.trim_prefix("output=")
	boot.call_deferred()
func boot():
	root.size = Vector2i(1280,800)
	began = Time.get_ticks_msec()
	if mode == "minimal":
		var camera = Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0,0,4)
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.CORAL
		mesh.material_override = mat
		root.add_child(mesh)
	else:
		app = load("res://main.tscn").instantiate()
		root.add_child(app)
		if mode == "no-scenery":
			var scenery = app.world.arena.get_node_or_null("StadiumScenery")
			if scenery: scenery.free()
	RenderingServer.frame_post_draw.connect(drawn)
func drawn():
	frames += 1
	if frames == 3:
		root.get_texture().get_image().save_png(output + ".png")
	if frames >= 30:
		var report = {"mode":mode,"frames":frames,"milliseconds":Time.get_ticks_msec()-began,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name()}
		FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
		print("RENDER_PROBE_PASS ",JSON.stringify(report))
		quit.call_deferred(0)
