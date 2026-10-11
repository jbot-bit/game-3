extends SceneTree
## Native artwork/layout inspection using explicit display fixtures, not clears.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://logs/coop-native-" + label + ".png")
	failed = failed or result != OK
	print("COOP_NATIVE_CAPTURE ", label, " ", result)

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.gui_disable_input = true
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/coop-native-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24891
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	await create_timer(0.4).timeout
	await _capture("menu")
	app._host("Player 1")
	for slot in [1, 2]: app.session.players["crew_%d" % (slot + 1)] = {"peer": slot + 21, "slot": slot, "name": "Player %d" % (slot + 1)}
	app._roster_changed(app.session.players)
	for id in app.state.players:
		app._action(id, "power", app.state.offers[id][0])
		var slot: int = app.session.players[id].slot
		var style: Dictionary = [{"color": "mint", "accessory": "cap"}, {"color": "rose", "accessory": "beanie"}, {"color": "lilac", "accessory": "halo"}][slot]
		app.state.players[id].appearance = style
		app.avatars[id].set_appearance(style)
		app.avatars[id].reset_at(Vector3(float(slot - 1) * 2.5, 3, 0))
	app.state.cosmetic_cards = ["paint_mint", "paint_rose", "gear_cap", "gear_beanie", "gear_halo"]
	app.camera.position = Vector3(4, 4, 10)
	app.camera.look_at(Vector3(0, 1.6, 0))
	await create_timer(0.8).timeout
	app.hud.update_view(app.state, "crew_1", true)
	await _capture("crew")
	app.hud.show_cosmetics()
	await create_timer(0.15).timeout
	await _capture("customize")
	app.hud.show_game()
	app.state.phase = "complete"
	app.state.completions = 1
	app.state.reward_run_id = app.run_id
	app.state.reward_cards = ["paint_mint", "gear_sprout", "gear_halo"]
	app.state.reward_duplicates = ["paint_mint"]
	app.hud.update_view(app.state, "crew_1", true)
	await _capture("bag")
	app.hud._open_reward_bag()
	for card in app.hud._reward_row.get_children(): card.pressed.emit()
	await create_timer(0.35).timeout
	await _capture("foil-cards")
	app.state.phase = "play"
	app.hud.update_view(app.state, "crew_1", true)
	var middle: Vector3 = (app.teamwork.stages[0].near + app.teamwork.stages[2].far) * 0.5
	app.camera.position = middle + app.teamwork._right * 85 + Vector3(0, 75, 20)
	app.camera.look_at(middle)
	await _capture("stages")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app.camera.position = app.teamwork.stages[0].near + app.teamwork._right * 15 + Vector3(0, 13, 18)
	app.camera.look_at(app.teamwork.stages[0].near + app.teamwork._forward * 10)
	for id in app.avatars:
		var slot: int = app.session.players[id].slot
		app.avatars[id].reset_at(app.teamwork.stages[0].near + app.teamwork._right * float(slot - 1) * 2.8 + Vector3(0, 3, 0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await create_timer(2.0).timeout
	var times: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var start: int = previous
	while Time.get_ticks_usec() - start < 5000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	var slow: int = 0
	for value in times:
		if value > 16.667: slow += 1
	await _capture("bridge")
	var report: Dictionary = {"gpu": RenderingServer.get_video_adapter_name(), "frame_p95_ms": times[int(times.size() * 0.95)], "frame_max_ms": times[-1], "over_16_7": slow, "frames": times.size(), "seconds": 5, "physical_puppets": 3, "resolution": "1280x720", "limits": "Native rendered appearance/layout fixtures and standing puppets; not human gameplay, route traversal, or remote PC performance."}
	var file := FileAccess.open("res://logs/coop-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COOP_NATIVE ", JSON.stringify(report))
	app.session.close()
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)
