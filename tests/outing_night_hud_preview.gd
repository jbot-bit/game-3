extends SceneTree

var hud: GameHUD
var destination: String = "res://.tools/outing-night-hud"

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
		var data: Dictionary = {"run":{"elapsed_s":150,"phase":"day","players":{"crew_1":{},"crew_2":{},"crew_3":{}}},"progression":{"profiles":{"crew_1":{"name":"Harbour"},"crew_2":{"name":"Moss"},"crew_3":{"name":"River"}},"coins":45},"choice":{"open":true,"committed":""},"lights":{"batteries":{"crew_1":90},"station_until":{"jetty":240,"reeds":240}}}
		hud.update_view(data,"crew_1","E · Pick up power cell")
		await _capture("choice",size)
		data.run.elapsed_s = 195
		data.run.phase = "dusk"
		data.choice.committed = "jetty"
		data.lights.station_until.jetty = 390
		hud.update_view(data,"crew_1","LMB · Cast")
		hud.toast("The default switch powered Jetty. Reeds goes dark at sunset. Spare cells can relight it.")
		await _capture("dusk",size)
		data.run.elapsed_s = 400
		data.run.phase = "night"
		data.lights.batteries.crew_1 = 0
		data.lights.station_until.reeds = 460
		hud._toast_card.hide()
		hud.update_view(data,"crew_1","LMB · Cast")
		await _capture("empty-lantern",size)
		data.hunter = "chase"
		data.hunter_target = "crew_1"
		hud.update_view(data,"crew_1","")
		await _capture("threat",size)
	hud.queue_free()
	await process_frame
	print("OUTING_NIGHT_HUD_PREVIEW_PASS: 8 native layouts at 960x540 and 1280x720")
	quit(0)

func _capture(label: String, size: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO,Vector2(size))
	for control: Control in [hud._top_strip,hud._vote_notice,hud._action_card,hud._status_strip]:
		if control.is_visible_in_tree() and not bounds.encloses(control.get_global_rect()):
			push_error("Night HUD outside viewport: " + label + " " + str(control.get_global_rect()))
			quit(1)
			return
	root.get_texture().get_image().save_png(destination.path_join(label+"-"+str(size.x)+".png"))
