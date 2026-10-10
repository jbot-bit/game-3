extends SceneTree
## Earn a real catch using the displayed fishing rail, then follow normal keys.
## Only starting location and catch-table RNG are fixtures; no landed fish injection.
var app: Node3D
var catch_id: String = ""
var failures: PackedStringArray = []
var destination: String = "res://.tools/big-fish-guidance-preview"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://game/main.gd").new()
	var fixture: String = "user://tests/big-fish-controls-" + str(Time.get_ticks_usec())
	app.save_path = fixture + "-household.json"
	app.settings_path = fixture + "-settings.json"
	app.game_port = 24941
	root.add_child(app)
	await process_frame
	app._host("Angler")
	await create_timer(0.1).timeout
	var actor: Angler = app.controller.avatars.crew_1
	actor.global_position = app.world.markers.jetty
	actor.last_dry = actor.global_position
	actor.velocity = Vector3.ZERO
	for seed_value in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var roll: Dictionary = CatchTable.roll("jetty","day",0,rng.randf(),rng.randf(),rng.randf())
		if roll.species_id == "penny_perch" and roll.trait_id == "oversized":
			app.controller.rng.seed = seed_value
			break
	_mouse(true)
	await create_timer(0.15).timeout
	if not app._is_fishing():
		failures.append("Normal LMB did not start the cast")
		await _finish()
		return
	var started: int = Time.get_ticks_msec()
	var held: bool = true
	while app._is_fishing() and Time.get_ticks_msec()-started < 18000:
		var rail = app.hud._fish_pull
		var next: bool = float(rail._shown_fish) > float(rail._shown_bar)
		if held != next:
			held = next
			_mouse(held)
		await create_timer(0.05).timeout
	_mouse(false)
	await create_timer(0.2).timeout
	var landed: Array = app.controller.progression.snapshot().landed_catch_ids
	if landed.size() != 1:
		failures.append("Displayed-bar normal input did not land exactly one catch")
		await _finish()
		return
	catch_id = landed[0]
	_check(app.controller.cargo.snapshot()[catch_id].state == "whole_loose","Earned oversized catch remains loose for ordinary pickup")
	_key(KEY_E,true)
	await create_timer(0.06).timeout
	_key(KEY_E,false)
	await create_timer(0.2).timeout
	_check(app.controller.cargo.held_by("crew_1") == catch_id,"E picks up the earned whole fish")
	for resolution: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = resolution
		root.content_scale_size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		await _capture(str(resolution.x) + "-picked-up")
		_check_visible_action("P",resolution)
	app.settings.set_binding("pack",KEY_O)
	app.settings.set_binding("interact",KEY_I)
	await create_timer(0.2).timeout
	await _capture("1280-remapped")
	_check_visible_action("O",Vector2i(1280,720))
	_key(KEY_O,true)
	await create_timer(0.8).timeout
	_key(KEY_O,false)
	await create_timer(0.2).timeout
	_check(app.controller.cargo.snapshot()[catch_id].state == "packed","Holding remapped O packs through the real input loop")
	_check(app.controller.cargo.held_by("crew_1").is_empty(),"Packing frees the player's hands")
	await _capture("1280-packed")
	_check(_visible_action().contains("Cast"),"Visible context restores casting")
	_mouse(true)
	await create_timer(0.1).timeout
	_mouse(false)
	_check(app._is_fishing(),"Normal LMB starts another cast after packing")
	_key(app.settings.action_key("cancel_cast"),true)
	_key(app.settings.action_key("cancel_cast"),false)
	await _finish()

func _check_visible_action(pack_key: String,resolution: Vector2i) -> void:
	var action: String = _visible_action()
	_check(app.hud._action_card.is_visible_in_tree(),"Action card is visible after pickup")
	for token: String in ["Hold " + pack_key,"Pack","Drop","Hold LMB","Throw"]:
		_check(action.contains(token),"Visible action includes " + token)
	_check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(app.hud._action_card.get_global_rect()),"Action card is within " + str(resolution))
	var font: Font = app.hud._context.get_theme_font("font")
	_check(font.get_string_size(app.hud._context.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x <= app.hud._context.size.x,"Three actions fit without ellipsis")

func _visible_action() -> String:
	return (app.hud._action_key.text + " · " if app.hud._keycap.is_visible_in_tree() else "") + app.hud._context.text

func _capture(label: String) -> void:
	for frame in range(3): await process_frame
	print("BIG_FISH_SAMPLE " + JSON.stringify({"label":label,"context":_visible_action(),"cargo":app.controller.cargo.snapshot().get(catch_id,{})}))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(destination + "/" + label + ".png") == OK,"Saved " + label)

func _check(condition: bool,message: String) -> void:
	print("BIG_FISH_CHECK ", "PASS " if condition else "FAIL ",message)
	if not condition: failures.append(message)

func _mouse(held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(root.size.x * 0.5,root.size.y * 0.5)
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key(code: int,held: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _finish() -> void:
	print("BIG_FISH_GUIDANCE ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures))
	app.controller.active = false
	app.session.close()
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
