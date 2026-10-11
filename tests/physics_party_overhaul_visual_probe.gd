extends SceneTree
## Native presentation review of the real game. Only crew staging is a fixture.
const Game = preload("res://prototypes/physics_party/main.gd")
var app: Node3D

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app = Game.new()
	app.scripted = true
	app.progress_path = "user://tests/overhaul-" + str(Time.get_ticks_usec()) + ".json"
	app.game_port = 24961
	root.add_child(app)
	await create_timer(0.5).timeout
	await _capture("menu")
	app._host("Rook")
	app.session.players.crew_2 = {"peer": 22, "slot": 1, "name": "Nova"}
	app.session.players.crew_3 = {"peer": 33, "slot": 2, "name": "Patch"}
	app._roster_changed(app.session.players)
	await create_timer(0.2).timeout
	await _capture("powers")
	for id in app.state.players: app._action(id, "power", app.state.offers[id][0])
	await create_timer(2.0).timeout
	await _capture("play")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(7.5, 5.0, -7.0)
	camera.look_at(Vector3(0, 1.9, 3.5))
	camera.fov = 46.0
	camera.current = true
	app.hud.hide()
	await _capture("crew")
	app.hud.show()
	app.camera.current = true
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await _capture("play-small")
	app._leave()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	print("OVERHAUL_VISUAL_PASS")
	quit()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://logs/overhaul-" + label + ".png")
	if error != OK: push_error("Cannot save " + label); quit(1)
