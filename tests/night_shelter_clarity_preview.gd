extends SceneTree

var hud: GameHUD
var destination: String = "res://.tools/night-shelter-clarity"
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	hud = GameHUD.new()
	root.add_child(hud)
	hud.show_game()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.content_scale_size = size
		root.size = size
		DisplayServer.window_set_size(size)
		var data: Dictionary = {
			"run":{"run_id":str(size.x),"elapsed_s":365.0,"phase":"night","players":{"crew_1":{}}},
			"progression":Progression.blank_state(),
			"lights":{"batteries":{"crew_1":90},"station_until":{"jetty":240,"reeds":390}},
			"safety":{"crew_1":{"shelter_id":"reeds","protected":true,"field_protected":true,"station_remaining":25.0,"shelter_distance":2.0,"moth_distance":59.1}},
			"cargo":{}}
		hud.update_view(data,"crew_1","LMB · Cast")
		data.progression.landed_catch_ids.append("preview:1")
		data.cargo["preview:1"] = {"state":"packed","pouch_profile_id":"crew_1","catch_record":{"catch_id":"preview:1","profile_id":"crew_1","species_id":"bellgill","size":1.0,"catch_value":20}}
		hud.update_view(data,"crew_1","LMB · Cast")
		hud.toast("Bellgill packed. Bank it at Moth.")
		await _capture("catch-warning",size)
		data.hunter = "chase"
		data.hunter_target = "crew_1"
		hud.update_view(data,"crew_1","")
		await _capture("protected-chase",size)
		data.run.elapsed_s = 390.0
		data.safety.crew_1.protected = false
		data.safety.crew_1.field_protected = false
		data.safety.crew_1.station_remaining = 0.0
		hud.update_view(data,"crew_1","")
		await _capture("expired-chase",size)
		data.hunter = "recover"
		data.safety.crew_1 = {"shelter_id":"boat","protected":true}
		data.progression.banked_catch_ids = ["banked"]
		data.progression.repairs = {"moth_engine":true,"beacon":true}
		data.escape = {"can_arm":true}
		data.cargo = {}
		data.next_step = preload("res://game/ui/outing_guide.gd").next_step(data,"crew_1",{"position":Vector3.ZERO,"markers":{"boat":Vector3.ZERO},"interact":"E"})
		hud.update_view(data,"crew_1","E · Prepare the night escape")
		await _capture("moth-escape",size)
	hud.queue_free()
	await process_frame
	print("NIGHT_SHELTER_CLARITY_PREVIEW_PASS: 8 native layouts at 960x540 and 1280x720" if not failed else "NIGHT_SHELTER_CLARITY_PREVIEW_FAIL")
	quit(1 if failed else 0)

func _capture(label: String, size: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO,Vector2(size))
	for control: Control in [hud._top_strip,hud._vote_notice,hud._next_step_card,hud._catch_reveal,hud._toast_card,hud._action_card,hud._status_strip]:
		if control.is_visible_in_tree() and not bounds.encloses(control.get_global_rect()):
			push_error("Night HUD outside viewport: " + label + " " + str(control.get_global_rect()))
			failed = true
	if hud._vote_notice.visible:
		for control: Control in [hud._catch_reveal,hud._toast_card,hud._next_step_card]:
			if control.is_visible_in_tree() and control.get_global_rect().intersects(hud._vote_notice.get_global_rect()):
				push_error("Night shelter warning overlap: " + label)
				failed = true
	root.get_texture().get_image().save_png(destination.path_join(label+"-"+str(size.x)+".png"))
