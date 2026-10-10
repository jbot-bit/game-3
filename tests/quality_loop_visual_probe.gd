extends SceneTree
## Native smoke: normal controller intents, real walking/cast/landing/banking,
## isolated household. Automated input is not a human playtest.
const Game = preload("res://game/main.gd")
var app: Node3D
var sequence: int = 0
var failures: PackedStringArray = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.gui_disable_input = true
	app = Game.new()
	app.game_port = 24881
	var fixture: String = "user://tests/quality-loop-" + str(Time.get_ticks_usec())
	app.settings_path = fixture + "-settings.json"
	app.save_path = fixture + "-household.json"
	root.add_child(app)
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.set_physics_process(false)
	app.hud.set_process_input(false)
	app.hud.set_process_unhandled_input(false)
	AudioServer.set_bus_mute(0, true)
	app.hud.host_requested.emit("Harbour")
	await create_timer(0.5).timeout
	check(app.controller.active, "host started")
	check(root.msaa_3d == Viewport.MSAA_2X, "smooth edges active by default")
	check(app.world._sun.shadow_enabled, "daylight shadows active by default")
	await capture("spawn")
	if not await walk_to(app.world.markers.jetty): return finish()
	check(app._context().text == "LMB · Cast", "walking reaches a usable fishing spot")
	check(send("cast", {}).ok, "normal cast accepted")
	var cast_captured: bool = false
	var reeling: bool = true
	var deadline: int = Time.get_ticks_msec() + 60000
	while app.controller.fishing.casts.has("crew_1") and Time.get_ticks_msec() < deadline:
		var cast: Dictionary = app.controller.fishing.casts.crew_1
		reeling = float(cast.fish_position) > float(cast.bar_position)
		app.held_reel = reeling
		send("reel", {"held":reeling, "pull":0.0})
		if not cast_captured and float(cast.elapsed) > 2.0:
			await capture("fishing")
			cast_captured = true
		await create_timer(0.05).timeout
	app.held_reel = false
	await create_timer(0.25).timeout
	var saved: Dictionary = app.controller.progression.snapshot()
	check(saved.landed_catch_ids.size() == 1, "real timed fishing lands exactly one saved catch")
	check(app.hud._catch_reveal.visible, "new catch reveal appears from actual saved catch")
	await capture("catch")
	if saved.landed_catch_ids.is_empty(): return finish()
	var id: String = str(saved.landed_catch_ids[0])
	if app.controller.cargo.snapshot()[id].state == "whole_loose":
		check(send("grab_fish", {"catch_id":id}).ok, "oversized catch picked up normally")
	if not await walk_to(app.world.markers.boat): return finish()
	check(send("bank", {}).ok, "caught fish banks at Moth")
	await create_timer(0.25).timeout
	saved = app.controller.progression.snapshot()
	check(id in saved.banked_catch_ids and saved.coins > 0, "bank receipt and coins persisted")
	await capture("banked")
	if not await walk_to(app.world.markers.rod_cache): return finish()
	check(send("open_cache", {"cache_id":"shore_rod_cache"}).ok, "shore upgrade is reachable")
	await create_timer(0.25).timeout
	check("soft_tip" in app.controller.progression.snapshot().owned_rods, "rod upgrade saved")
	check(app.hud._next_step_card.visible, "found rod transitions to the island repair goal")
	await capture("upgrade")
	if not await walk_to(app.world.markers.boat): return finish()
	check(send("equip_rod", {"rod_id":"soft_tip"}).ok, "earned rod equips at Moth")
	await create_timer(0.25).timeout
	check(app.hud._next_step_card.visible, "campaign guidance stays visible after equipping")
	finish()

func send(action: String, payload: Dictionary) -> Dictionary:
	sequence += 1
	return app.controller.apply_intent(1, action, payload, "quality-loop-" + str(sequence))

func walk_to(destination: Vector3) -> bool:
	var avatar: Node3D = app.controller.avatars.crew_1
	var deadline: int = Time.get_ticks_msec() + 30000
	while avatar.global_position.distance_to(destination) > 1.1 and Time.get_ticks_msec() < deadline:
		var next: Vector3 = app.world.route_step(avatar.global_position, destination)
		var toward: Vector3 = next - avatar.global_position
		var direction := Vector2(toward.x, toward.z).normalized()
		send("move", {"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		await create_timer(0.05).timeout
	send("move", {"direction":Vector2.ZERO,"yaw":app.camera.view_yaw()})
	await create_timer(0.2).timeout
	var arrived: bool = avatar.global_position.distance_to(destination) < 1.5
	check(arrived, "walked to " + str(destination))
	return arrived

func capture(label: String) -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://logs/quality-loop-" + label + ".png") == OK, "captured " + label)

func check(passed: bool, detail: String) -> void:
	print("QUALITY_LOOP ", "OK " if passed else "FAIL ", detail)
	if not passed: failures.append(detail)

func finish() -> void:
	for failure: String in failures: push_error(failure)
	print("QUALITY_LOOP_", "PASS" if failures.is_empty() else "FAIL")
	app.session.close()
	quit(0 if failures.is_empty() else 1)
