extends SceneTree
## Render the actual main scene through two back-to-back casts on isolated data.
const Game = preload("res://game/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var destination: String = "res://.tools/hud-preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var fixture: String = "user://tests/render_recast_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	var app: Node3D = Game.new()
	app.settings_path = fixture + "/settings.json"
	app.save_path = fixture + "/household.json"
	app.game_port = 24741
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	app._host("Camera probe")
	if not app.session.is_host():
		push_error("Recast render could not host isolated fixture")
		quit(1)
		return
	await physics_frame
	for habitat: String in ["jetty", "terraces"]:
		app.controller.fishing.cancel("crew_1")
		var actor: Node3D = app.controller.avatars.crew_1
		actor.global_position = app.world.markers[habitat]
		if not app.controller._cast("crew_1").ok:
			push_error("Recast fixture could not cast at " + habitat)
			quit(1)
			return
		app.controller._publish()
		for frame: int in range(20):
			app._process(1.0 / 30.0)
			await process_frame
		var toward: Vector3 = app.world.fishing_focus(habitat) - actor.global_position
		if absf(angle_difference(app.camera.yaw, atan2(-toward.x, -toward.z))) > 0.0001:
			push_error("Fresh catch camera did not align at " + habitat)
			quit(1)
			return
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination + "/recast_" + habitat + ".png")
	app.session.close()
	app.queue_free()
	await process_frame
	print("RENDER_RECAST_PASS: actual main, new catch IDs, jetty then terraces, isolated household/settings")
	quit(0)
