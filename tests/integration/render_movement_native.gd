extends SceneTree
## Native ordinary-input sampling. FPS caps are test conditions, not a benchmark claim.
const Game=preload("res://game/main.gd")
var app: Node3D
var failures: PackedStringArray=[]
var destination: String="res://.tools/movement-native"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for cap: int in [30,120]:
		Engine.max_fps=cap
		var fixture: String="user://tests/movement_native_"+str(Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
		app=Game.new()
		app.save_path=fixture+"/household.json"
		app.settings_path=fixture+"/settings.json"
		app.game_port=24901
		root.add_child(app)
		await _frames(8)
		await _click("Host a game")
		await _click("Start island")
		await create_timer(0.5).timeout
		var actor: Angler=app.controller.avatars.crew_1
		var start: Vector3=actor.global_position
		var body_stalls: int=0
		var visual_stalls: int=0
		var measured: int=0
		var maximum_offset: float=0.0
		var deltas: Array[float]=[]
		var before_body: Vector3=actor.global_position
		var before_visual: Vector3=actor.visual.global_position
		_key(KEY_W,true)
		var began: int=Time.get_ticks_usec()
		var last: int=began
		var walk_captured: bool=false
		while Time.get_ticks_usec()-began<1800000:
			await RenderingServer.frame_post_draw
			var now: int=Time.get_ticks_usec()
			var elapsed: float=float(now-began)/1000000.0
			if elapsed>0.35:
				deltas.append(float(now-last)/1000.0)
				measured+=1
				if actor.global_position.distance_to(before_body)<0.00001: body_stalls+=1
				if actor.visual.global_position.distance_to(before_visual)<0.00001: visual_stalls+=1
				maximum_offset=maxf(maximum_offset,actor.visual.global_position.distance_to(actor.global_position))
			before_body=actor.global_position
			before_visual=actor.visual.global_position
			last=now
			if elapsed>0.9 and not walk_captured:
				walk_captured=true
				root.get_texture().get_image().save_png(destination+"/%d-walk.png"%cap)
		_key(KEY_W,false)
		await create_timer(0.35).timeout
		var traveled: float=Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z).length()
		var idle_yaw: float=actor.rotation.y
		_mouse(MOUSE_BUTTON_RIGHT,true)
		var motion:=InputEventMouseMotion.new()
		motion.relative=Vector2(160,-20)
		motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(motion)
		_mouse(MOUSE_BUTTON_RIGHT,false)
		await create_timer(0.35).timeout
		var turned: float=absf(angle_difference(idle_yaw,actor.rotation.y))
		_mouse(MOUSE_BUTTON_WHEEL_UP,true)
		_mouse(MOUSE_BUTTON_WHEEL_UP,false)
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination+"/%d-idle-orbit-zoom.png"%cap)
		deltas.sort()
		var result: Dictionary={"fps_cap":cap,"frames":measured,"frame_ms_p50":deltas[deltas.size()/2],"frame_ms_p95":deltas[mini(deltas.size()-1,int(deltas.size()*0.95))],"distance_after_1_8s_input":traveled,"idle_turn_radians":turned,"physics_still_frames":body_stalls,"visual_still_frames":visual_stalls,"maximum_visual_body_offset_m":maximum_offset,"zoom_distance":app.camera.distance,"idle_animation":actor.visual.animation_state}
		print("NATIVE_MOVEMENT ",JSON.stringify(result))
		if traveled<6.0: failures.append("Movement obstructed at cap "+str(cap))
		if turned>0.001: failures.append("Idle camera orbit turned avatar")
		if absf(app.camera.distance-6.9)>0.01: failures.append("Wheel input did not zoom")
		if maximum_offset>0.25: failures.append("Render interpolation lag exceeds bounded physics interval")
		if cap==120 and measured>50 and visual_stalls>=body_stalls: failures.append("Render interpolation did not reduce repeated body poses at 120fps")
		app.session.close()
		app.queue_free()
		await _frames(3)
	Engine.max_fps=0
	for failure: String in failures: push_error(failure)
	print("NATIVE_MOVEMENT_REVIEW ","PASS" if failures.is_empty() else "FAIL",": actual GUI Host, W movement, right-drag orbit, wheel zoom; isolated saves; no teleports")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i: int in range(count): await process_frame

func _key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)

func _mouse(button: int,pressed: bool,position: Vector2=Vector2(640,360)) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=button
	event.pressed=pressed
	event.position=position
	event.global_position=position
	event.button_mask=(MOUSE_BUTTON_MASK_RIGHT if button==MOUSE_BUTTON_RIGHT else (MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else 0)) if pressed else 0
	Input.parse_input_event(event)

func _click(text: String) -> void:
	var button: Button=_find(app.hud,text)
	if button==null:
		failures.append("Missing button "+text)
		return
	_mouse(MOUSE_BUTTON_LEFT,true,button.get_global_rect().get_center())
	await process_frame
	_mouse(MOUSE_BUTTON_LEFT,false,button.get_global_rect().get_center())
	await _frames(3)

func _find(node: Node,text: String) -> Button:
	if node is Button and node.text==text and node.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var match_button: Button=_find(child,text)
		if match_button!=null: return match_button
	return null
