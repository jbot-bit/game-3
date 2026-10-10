extends SceneTree
## Read-only product investigation; isolated temporary save and authored clock/position fixtures.
## No render or assertion of family fun: captures the real HUD plus host return transitions.
var app: Node3D
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = load("res://game/main.gd").new()
	app.game_port = 24661
	app.save_path = "user://tests/outing-night-" + str(Time.get_ticks_usec()) + ".json"
	app.settings_path = "user://tests/outing-night-settings-" + str(Time.get_ticks_usec()) + ".json"
	root.add_child(app)
	app._host("Night probe")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await physics_frame
	var c: Node = app.controller
	_check(c.active, "isolated host active")
	c.avatars.crew_1.global_position = app.world.markers.boat
	c.avatars.crew_1.last_dry = app.world.markers.boat
	c.run.elapsed_s = 149.9
	c.run.phase = "day"
	c._physics_process(0.2)
	c._publish()
	app._process(0.1)
	print("OUTING_NIGHT " + JSON.stringify({"case":"automatic choice invitation", "time":c.run.elapsed_s,"choice":c.choice.snapshot(),"vote_notice_visible":app.hud._vote_notice.is_visible_in_tree(),"visible_ui":_visible_text(app.hud._game)}))

	c.run.elapsed_s = 179.9
	var note_before: int = c.note_sequence
	c._physics_process(0.2)
	c._publish()
	app._process(0.1)
	var new_notes: Array = []
	for note: Dictionary in c.notes:
		if note.id > note_before: new_notes.append(note.text)
	print("OUTING_NIGHT " + JSON.stringify({"case":"default dusk warning", "notes_in_order":new_notes,"displayed_toast":app.hud._toast_label.text,"field_status":app.hud._field_status.text}))

	c.run.elapsed_s = 400.0
	c.run.phase = "night"
	c.avatars.crew_1.global_position = app.world.markers.reeds + Vector3(0,0,10)
	c.avatars.crew_1.last_dry = c.avatars.crew_1.global_position
	c.lights.batteries.crew_1 = 0.0
	c._publish()
	app._process(0.1)
	print("OUTING_NIGHT " + JSON.stringify({"case":"empty lantern", "visible_status":app.hud._lamp_status.text,"equipment_text":app.hud._equipment.text,"equipment_visible":app.hud._equipment.is_visible_in_tree(),"visible_ui":_visible_text(app.hud._game)}))

	c.avatars.crew_1.global_position = app.world.markers.boat
	c.avatars.crew_1.last_dry = app.world.markers.boat
	c._publish()
	var initial_context: Dictionary = app._context()
	var ready: Dictionary = c.apply_intent(1,"ready",{"ready":true},"probe-ready")
	c._physics_process(0.1)
	_check(ready.ok and c.run.phase == "refuge", "refuge works before engine repair")
	print("OUTING_NIGHT " + JSON.stringify({"case":"first outing refuge", "engine_repaired":c.progression.snapshot().repairs.get("moth_engine",false),"context_before_ready":initial_context,"ready_result":ready,"phase_after_ready":c.run.phase,"crossing_s":c.run.crossing_left}))
	c._physics_process(20.0)
	_check(c.run.terminal and c.trip_result.get("outcome","") == "refuge", "refuge settles")
	print("OUTING_NIGHT " + JSON.stringify({"case":"settlement", "recap":c.trip_result,"next_day_s":c.next_day_at,"saved_run":c.run.run_id in c.progression.snapshot().settled_run_ids}))
	c.active = false
	app.session.close()
	app.queue_free()
	await process_frame
	print("OUTING_NIGHT checks=" + str(checks))
	quit(0)

func _visible_text(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child: Node in node.find_children("*","Label",true,false):
		if child.is_visible_in_tree() and not child.text.is_empty(): result.append(child.text)
	return result

func _check(ok: bool, label: String) -> void:
	checks += 1
	print("OUTING_NIGHT_CHECK " + JSON.stringify({"ok":ok,"label":label}))
	if not ok: quit(1)
