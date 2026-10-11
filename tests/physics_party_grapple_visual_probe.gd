extends SceneTree
## Native game + actual controls and grapple physics, with a fixed presentation
## camera for readable screenshots. An isolated save and port are used. This is
## a controlled fixture, not human mouse aiming or a multiplayer playtest.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var actor: Node3D
var held: Dictionary = {}
var failures: Array[String] = []
var report: Dictionary = {"limit": "Scripted host controls; fixed presentation camera; no human aiming or remote client evidence."}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native rendering is required.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.gui_disable_input = true
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/grapple-visual-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24873
	root.add_child(app)
	app.rng.seed = 20261010
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app._host("Grapple test", "crossing")
	_check(app.session.hosting, "Isolated host starts")
	if not app.session.hosting:
		await _finish()
		return
	actor = app.avatars[app.session.local_id]
	app._action(app.session.local_id, "power", app.state.offers[app.session.local_id][0])
	var camera := Camera3D.new()
	camera.fov = 65.0
	root.add_child(camera)
	camera.position = Vector3(12, 10, 9)
	camera.look_at(Vector3(-0.8, 5, -4))
	camera.current = true
	held = app._neutral()
	await _ticks(75)
	app.camera.current = true
	await process_frame
	var body_screen: Vector2 = app.camera.unproject_position(actor.visual_position())
	_check(body_screen.x > 0.0 and body_screen.x < 620.0 and body_screen.y > 0.0 and body_screen.y < 720.0, "Ordinary camera keeps player visible left of reticle")
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://logs/grapple-normal.png") == OK, "Ordinary orbit image saved")
	var beam: StaticBody3D = app.world.get_node("BridgeGrapple")
	# The normal orbit camera can see the overhead beam within its pitch range.
	var toward: Vector3 = beam.global_position - (actor.visual_position() + Vector3.UP * 0.5)
	app.yaw = atan2(-toward.x, -toward.z)
	app.pitch = atan2(3.0, 10.0) + atan2(toward.y, Vector2(toward.x, toward.z).length())
	for attempt in 8:
		app._update_camera(1.0)
		toward = beam.global_position - app.camera.global_position
		app.yaw = atan2(-toward.x, -toward.z)
		app.pitch = atan2(3.0, 10.0) + atan2(toward.y, Vector2(toward.x, toward.z).length())
	_check(app.pitch >= -0.85 and app.pitch <= 1.25, "Overhead beam fits normal camera pitch range")
	app._update_camera(1.0)
	app.camera.current = true
	await process_frame
	var aimed: Vector3 = app._grapple_aim()
	var target: Dictionary = actor.grapple.target_at(aimed)
	_check(target.get("collider") == beam, "Normal camera center ray selects the overhead beam")
	_check(app.camera.global_position.y >= actor.visual_position().y + 0.95, "Upward aim keeps camera above the player torso")
	var center: Vector2 = root.get_visible_rect().size * 0.5
	var ray_from: Vector3 = app.camera.project_ray_origin(center)
	var sightline := PhysicsRayQueryParameters3D.create(ray_from, ray_from + app.camera.project_ray_normal(center) * 65.0)
	var direct_hit: Dictionary = app.world.get_world_3d().direct_space_state.intersect_ray(sightline)
	_check(direct_hit.get("collider") == beam, "Reticle sees the beam without hiding the player's body from raycasts")
	_check_help_clear("1280x720")
	report.camera_aim = {"pitch": app.pitch, "yaw": app.yaw, "hit": str(aimed), "target": str(target.get("collider"))}
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://logs/grapple-aim.png") == OK, "Normal orbit aim image saved")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await process_frame
	await RenderingServer.frame_post_draw
	_check_help_clear("960x540")
	_check(root.get_texture().get_image().save_png("res://logs/grapple-aim-960x540.png") == OK, "Minimum window orbit aim image saved")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	camera.current = true
	held.aim = aimed
	held.grapple = true
	held.grapple_mode = "pull"
	app.grapple_mode = "pull"
	await _ticks(32)
	await _capture("pull")
	held.grapple_mode = "swing"
	app.grapple_mode = "swing"
	held.move = Vector2(1, 0)
	await _ticks(30)
	held.move = Vector2.ZERO
	await _capture("swing")
	held.grapple = false
	await _ticks(2)
	_check(not actor.grapple.active, "Release detaches after captures")
	camera.queue_free()
	await _finish()

func _ticks(count: int) -> void:
	for index in count:
		app._controls(app.session.local_id, held)
		await physics_frame

func _check_help_clear(resolution: String) -> void:
	var status: Label = app.hud.get("_grapple_status")
	var plate: Control = status.get_parent().get_parent()
	var body_screen: Vector2 = app.camera.unproject_position(actor.visual_position())
	var torso := Rect2(body_screen - Vector2(24, 38), Vector2(48, 76))
	_check(not plate.get_global_rect().intersects(torso), resolution + " help panel leaves the aiming player's torso visible")

func _capture(mode: String) -> void:
	_check(actor.grapple.active and actor.grapple.mode == mode, mode + " is actually attached")
	_check(actor.grapple.get("_rope").is_visible_in_tree(), mode + " rope is rendered")
	_check(not app.hud.blocks_input(), mode + " uses gameplay HUD")
	await process_frame
	await RenderingServer.frame_post_draw
	var rope: MeshInstance3D = actor.grapple.get("_rope")
	var top: Vector3 = rope.global_transform * Vector3(0, 0.5, 0)
	var bottom: Vector3 = rope.global_transform * Vector3(0, -0.5, 0)
	var top_error: float = top.distance_to(actor.grapple.anchor)
	var bottom_error: float = bottom.distance_to(actor.visual_position() + Vector3.UP * 0.2)
	_check(top_error < 0.05, mode + " visible rope meets its hook (error %.3fm)" % top_error)
	_check(bottom_error < 0.05, mode + " visible rope meets the puppet (error %.3fm)" % bottom_error)
	var error: Error = root.get_texture().get_image().save_png("res://logs/grapple-" + mode + ".png")
	_check(error == OK, mode + " image saved")
	report[mode] = {"body": str(actor.body_position()), "anchor": str(actor.grapple.anchor), "mode": actor.grapple.mode,
		"active": actor.grapple.active, "rope_length": actor.grapple.rope_length, "velocity": str(actor.physical_bone_body.linear_velocity),
		"rendered_top_error": top_error, "rendered_bottom_error": bottom_error}

func _finish() -> void:
	report.failures = failures
	var file := FileAccess.open("res://logs/grapple-visual.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("GRAPPLE_NATIVE_VISUAL " + JSON.stringify(report))
	if is_instance_valid(app):
		app.session.close()
		app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures.append(message)
