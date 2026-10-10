extends SceneTree
## Bounded visual review using only public mouse/key input for gameplay.
const Game = preload("res://game/main.gd")
var app: Node3D
var destination: String = "res://.tools/fresh-ui-play-review"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var fixture: String = "user://tests/play_review_"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	app = Game.new()
	app.save_path = fixture+"/household.json"
	app.settings_path = fixture+"/settings.json"
	app.game_port = 24893
	root.add_child(app)
	await _frames(12)
	await _capture("01-menu")
	await _click_button("Help")
	await _capture("02-help")
	await _click_button("Close")
	await _click_button("Host a game")
	await _click_button("Start island")
	await _frames(45)
	if not app.session.is_host():
		_fail("Host button did not start a session")
		return
	await _capture("03-first-spawn")
	_key(KEY_W,true)
	var walk_started: int=Time.get_ticks_msec()
	while app.controller.avatars.crew_1.global_position.distance_to(app.world.markers.jetty)>1.4 and Time.get_ticks_msec()-walk_started<8000:
		await create_timer(0.05).timeout
	_key(KEY_W,false)
	await _frames(8)
	await _capture("04-walk-to-jetty")
	print("NORMAL_INPUT_POSITION ",app.controller.avatars.crew_1.global_position)
	print("NORMAL_INPUT_CONTEXT ",app.hud._context.text)
	await _capture("04b-jetty-edge")
	_mouse(MOUSE_BUTTON_LEFT,true,Vector2(640,360))
	await _frames(12)
	if not app._is_fishing():
		_mouse(MOUSE_BUTTON_LEFT,false,Vector2(640,360))
		_fail("Normal walk and click did not reach a fishing spot")
		return
	await _capture("05-first-cast")
	var began: float = Time.get_ticks_msec()/1000.0
	var held: bool = true
	while app._is_fishing() and Time.get_ticks_msec()/1000.0-began<50.0:
		var fish: Dictionary = app.controller.snapshot_data.fishing.crew_1
		var should_hold: bool = float(fish.get("fish_position",0.5))>float(fish.get("bar_position",0.5))
		if held!=should_hold:
			held=should_hold
			_mouse(MOUSE_BUTTON_LEFT,held,Vector2(640,360))
		await create_timer(0.15).timeout
	_mouse(MOUSE_BUTTON_LEFT,false,Vector2(640,360))
	await _frames(20)
	await _capture("06-fishing-time-limit" if app._is_fishing() else "06-catch-outcome")
	print("NORMAL_INPUT_CAST_FINISHED ",not app._is_fishing())
	print("NORMAL_INPUT_FISH_SECONDS ",Time.get_ticks_msec()/1000.0-began)
	print("NORMAL_INPUT_DISCOVERIES ",app.controller.snapshot_data.progression.discoveries)
	print("NORMAL_INPUT_CARGO ",app.controller.snapshot_data.cargo)
	var throw_tested: bool = false
	# Observe a charged throw only if this cast produces a whole fish.
	if app._held_id()!="":
		_mouse(MOUSE_BUTTON_LEFT,true,Vector2(640,360))
		await create_timer(0.55).timeout
		await _capture("07-charge-throw")
		_mouse(MOUSE_BUTTON_LEFT,false,Vector2(640,360))
		await create_timer(0.6).timeout
		await _capture("08-thrown-fish")
		throw_tested = true
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,false)
	await _frames(4)
	await _capture("09-pause")
	app.session.close()
	app.queue_free()
	await process_frame
	print("NORMAL_INPUT_REVIEW_COMPLETE: menu, Help, host, W movement to Jetty, LMB cast and hold/release fish tracking, pause; throw_tested=",throw_tested,"; isolated saves; no gameplay teleport/time changes")
	quit(0)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _mouse(button: int, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)

func _click_button(text: String) -> void:
	var button: Button = _find_button(app.hud,text)
	if button==null:
		_fail("Could not find visible button "+text)
		return
	var position: Vector2 = button.get_global_rect().get_center()
	_mouse(MOUSE_BUTTON_LEFT,true,position)
	await process_frame
	_mouse(MOUSE_BUTTON_LEFT,false,position)
	await _frames(3)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text==text and node.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child,text)
		if found!=null: return found
	return null

func _capture(label: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination+"/"+label+".png")
	print("REVIEW_FRAME ",label," | ",app.hud._context.text)

func _frames(count: int) -> void:
	for i: int in range(count): await process_frame

func _fail(message: String) -> void:
	push_error(message)
	app.session.close()
	app.queue_free()
	quit(1)

