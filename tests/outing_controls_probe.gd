extends SceneTree

const Game = preload("res://game/main.gd")
var app: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	app = Game.new()
	var stamp: String = str(Time.get_ticks_usec())
	app.save_path = "user://tests/outing_controls_"+stamp+".json"
	app.settings_path = "user://tests/outing_controls_settings_"+stamp+".json"
	app.game_port = 24969
	root.add_child(app)
	app._host("Controls probe")
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await _frames(8)
	app.set_process(false)
	await _tap(KEY_J)
	print("KEY_J_PANEL ", app.hud._panel_kind)
	await _tap(KEY_ESCAPE)
	print("KEY_ESCAPE_FROM_JOURNAL ", app.hud._panel_kind, " paused=", app.controller.run.paused)
	await _tap(KEY_ESCAPE)
	print("SECOND_ESCAPE ", app.hud._panel_kind, " paused=", app.controller.run.paused)
	await _bank_with_cell()
	await _camera_routes()
	app.session.close()
	app.queue_free()
	await _frames(2)
	quit(0)

func _bank_with_cell() -> void:
	var c: RunController = app.controller
	var actor: Angler = c.avatars.crew_1
	actor.global_position = app.world.markers.boat
	actor.last_dry = actor.global_position
	var record: Dictionary = CatchTable.roll("jetty","day",0,0.5,0.5,0.5)
	record.merge({"catch_id":"controls-bank","run_id":c.run.run_id,"profile_id":"crew_1"})
	c.progression.record_specimen(record)
	c._add_landed(record)
	c.supply_bodies.cell_1.global_position = actor.global_position+Vector3.UP
	c.supply_bodies.cell_1.freeze = true
	print("BANK_CELL_GRAB ", c.apply_intent(1,"grab_cell",{"cell_id":"cell_1"},"controls-cell"))
	c.supply_bodies.cell_1.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6)
	await physics_frame
	await physics_frame
	c._publish()
	print("BANK_WITH_CELL_CONTEXT ",app._context()," coins=",c.progression.snapshot().coins," actor=",actor.global_position," cell=",c.supply_bodies.cell_1.global_position)
	await _tap(KEY_E)
	print("BANK_AFTER_FIRST_E ",app._context()," coins=",c.progression.snapshot().coins," cell=",c.supplies.snapshot().cell_1," position=",c.supply_bodies.cell_1.global_position)
	await _tap(KEY_E)
	print("BANK_AFTER_SECOND_E ",app._context()," coins=",c.progression.snapshot().coins," cell=",c.supplies.snapshot().cell_1)
	print("BANK_DIRECT_ACTION ",c.apply_intent(1,"bank",{},"controls-bank")," coins=",c.progression.snapshot().coins)

func _camera_routes() -> void:
	var actor: Node3D = app.controller.avatars.crew_1
	var camera: CrewCamera = app.camera
	camera.target = actor
	var legs: Array = [["spawn","jetty"],["jetty","rod_cache"],["jetty","lens_cache"],["lens_cache","terraces"],["reeds","reeds_cast"],["tidepools","engine_cache"],["beacon","beacon_repair"]]
	for leg: Array in legs:
		var start: Vector3 = app.world.markers[leg[0]]
		var finish: Vector3 = app.world.markers[leg[1]]
		actor.global_position = start
		var toward: Vector3 = finish-start
		camera.yaw = atan2(-toward.x,-toward.z)
		camera.pitch = -0.45
		camera.distance = 7.5
		camera.clear_fishing_focus()
		camera.position = start+Vector3(0,5,7)
		for frame: int in range(90): camera.follow(1.0/60.0)
		var max_shift: float = 0.0
		var max_turn: float = 0.0
		var at_shift: Vector3 = start
		var at_turn: Vector3 = start
		var steps: int = ceili(start.distance_to(finish)/0.04)
		for frame: int in range(steps+1):
			actor.global_position = start.lerp(finish,float(frame)/float(steps))
			var prior_position: Vector3 = camera.global_position
			var prior_yaw: float = camera.view_yaw()
			camera.follow(1.0/60.0)
			var shift: float = prior_position.distance_to(camera.global_position)
			var turn: float = absf(angle_difference(prior_yaw,camera.view_yaw()))
			if shift > max_shift:
				max_shift = shift
				at_shift = actor.global_position
			if turn > max_turn:
				max_turn = turn
				at_turn = actor.global_position
		print("CAMERA_ROUTE ",leg," max_step=",max_shift," at=",at_shift," max_turn_deg=",rad_to_deg(max_turn)," at=",at_turn)

func _tap(code: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame
