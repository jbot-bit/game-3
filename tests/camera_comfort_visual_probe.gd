extends SceneTree
## Real game casts with isolated progression and fixed poses; presentation proof only.
const Game=preload("res://game/main.gd")
var app: Node3D
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	app=Game.new()
	var fixture: String="user://tests/camera-comfort-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	app.settings_path=fixture+"/settings.json"
	app.save_path=fixture+"/household.json"
	app.game_port=24754
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app._host("Harbour")
	var c: Node=app.controller
	c.set_physics_process(false)
	var state: Dictionary=c.progression.snapshot()
	for id: String in CampaignRules.required_repairs(): state.repairs[id]=true
	state.profiles.crew_1.tool_mode="alternate"
	c.progression=Progression.new(SaveStore.new(app.save_path),state)
	var actor: Node3D=c.avatars.crew_1
	for frame: int in range(90):
		app._process(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://logs/camera-comfort-overview.png"))
	for habitat: String in ["jetty","reeds","terraces","tidepools","beacon"]:
		actor.global_position=app.world.markers["reeds_cast" if habitat=="reeds" else habitat]
		if habitat=="jetty": actor.position+=Vector3(-1,0,1)
		actor.last_dry=actor.global_position
		actor.velocity=Vector3.ZERO
		app.first_game_frame=true
		await physics_frame
		var cast: Dictionary=c._cast("crew_1")
		if not cast.ok:
			push_error("CAMERA_COMFORT_CAST_FAILED "+habitat+" "+str(cast))
			quit(1)
			return
		c._publish()
		for frame: int in range(120):
			app._process(1.0/60.0)
			if frame==1:
				c.apply_intent(1,"move",{"direction":Vector2.ZERO,"yaw":app.camera.yaw},"camera-comfort-"+habitat)
				c._tick_players(0.02)
			await process_frame
		await RenderingServer.frame_post_draw
		var output: String="res://logs/camera-comfort-"+habitat+".png"
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		var aim: Vector3=app.effects.cast_focus("crew_1")
		var hit: Dictionary=app.camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(app.camera.position,aim,17))
		var viewport: Vector2=Vector2(root.size)
		var crew_height: float=absf(app.camera.unproject_position(actor.position+Vector3(0,2.65,0)).y-app.camera.unproject_position(actor.position).y)/viewport.y
		var bobber_screen: Vector2=app.camera.unproject_position(aim)/viewport
		print("CAMERA_COMFORT ",habitat," camera=",app.camera.position," focus=",aim," blocked=",str(hit.collider.name) if not hit.is_empty() else "clear"," crew_height=",snapped(crew_height,0.001)," bobber_screen=",bobber_screen)
		if not hit.is_empty() or crew_height>=0.5 or not Rect2(0.12,0.16,0.76,0.63).has_point(bobber_screen):
			push_error("CAMERA_COMFORT_FRAMING_FAILED "+habitat)
			app.session.close()
			quit(1)
			return
		c.fishing.cancel("crew_1")
		c._publish()
	app.session.close()
	app.queue_free()
	await process_frame
	quit(0)
