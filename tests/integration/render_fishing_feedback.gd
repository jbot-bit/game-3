extends SceneTree
## Real engine render with explicit HUD/catch fixtures. Not a human playtest.
const Game = preload("res://game/main.gd")
var app: Node3D
var failures: PackedStringArray = []
var destination: String = "res://.tools/fishing-feedback-preview"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	app = Game.new()
	app.game_port = 24876
	var fixture: String = "user://tests/fishing-feedback-" + str(Time.get_ticks_usec())
	app.save_path = fixture + "/household.json"
	app.settings_path = fixture + "/settings.json"
	root.add_child(app)
	app._host("Harbour")
	app.set_physics_process(false)
	var controller: Node = app.controller
	controller.avatars.crew_1.global_position = app.world.markers.jetty + Vector3(-1, 0, 1)
	controller.avatars.crew_1.last_dry = controller.avatars.crew_1.global_position
	app.camera.yaw = PI / 2
	for frame: int in range(45): await process_frame
	app.set_process(false)
	controller.set_physics_process(false)
	var hud: GameHUD = app.hud
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.content_scale_size = resolution
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		var data: Dictionary = controller.snapshot_data.duplicate(true)
		data.next_step = {"title":"Your first catch", "detail":"Walk onto the Jetty and cast into the water."}
		hud.update_view(data, "crew_1", "LMB · Cast into the Jetty")
		await _capture(str(resolution.x) + "-guidance")
		data.fishing = {"crew_1":{"elapsed":2.0,"progress":0.64,"bar_position":0.58,"bar_width":0.34,"fish_position":0.62,"tracking":true}}
		data.reel_active = true
		hud.update_view(data, "crew_1", "")
		await _capture(str(resolution.x) + "-tracking")
		_check_bounds(hud._fish_card, resolution)
		data.fishing.crew_1.fish_position = 0.9
		data.fishing.crew_1.tracking = false
		data.reel_toggle_mode = true
		hud.update_view(data, "crew_1", "Hold E · revive Moss")
		await _capture(str(resolution.x) + "-outside")
		if hud._fish_card.get_global_rect().intersects(hud._action_card.get_global_rect()):
			failures.append("Fishing covers the rescue action at " + str(resolution))
		data.fishing.clear()
		hud.update_view(data, "crew_1", "")
		var record: Dictionary = {"catch_id":"feedback:" + str(resolution.x), "run_id":controller.run.run_id,"profile_id":"crew_1","species_id":"bellgill","trait_id":"moonlit","size":1.37,"catch_value":30,"habitat_id":"jetty","rare_eligible":false}
		if not controller.progression.record_specimen(record).ok:
			failures.append("Saved fixture failed")
		else:
			controller._add_landed(record)
			data.progression = controller.progression.snapshot()
			data.cargo = controller.cargo.snapshot()
			hud.update_view(data, "crew_1", "")
			await _capture(str(resolution.x) + "-landed")
			_check_bounds(hud._catch_reveal, resolution)
			if not hud._catch_reveal.visible: failures.append("Saved catch did not reveal")
			if hud._next_step_card.visible: failures.append("Guidance competes with catch reveal")
			if hud._toast_card.visible and hud._toast_card.get_global_rect().intersects(hud._catch_reveal.get_global_rect()):
				failures.append("Toast overlaps catch reveal at " + str(resolution))
			for child: Node in hud._catch_reveal.find_children("*", "Control", true, false):
				if child.is_visible_in_tree() and not hud._catch_reveal.get_global_rect().encloses(child.get_global_rect()):
					failures.append("Catch content exceeds card: " + str(child.name))
	app.session.close()
	for failure: String in failures: push_error(failure)
	print("FISHING_FEEDBACK_RENDER ", "PASS" if failures.is_empty() else "FAIL", " at 1280x720 and 960x540; explicit HUD/catch fixtures in the real game")
	quit(0 if failures.is_empty() else 1)

func _check_bounds(control: Control, resolution: Vector2i) -> void:
	if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(control.get_global_rect()):
		failures.append("Panel outside viewport at " + str(resolution))

func _capture(label: String) -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination + "/" + label + ".png")
	print("FISHING_FEEDBACK_FRAME ", label)
