extends SceneTree
## Native rendering/layout check at two actual viewport sizes; no gameplay state changes.
var hud: GameHUD
var failures: PackedStringArray = []
var destination: String = "res://.tools/polished-hud-preview"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.content_scale_size = resolution
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		hud=GameHUD.new()
		root.add_child(hud)
		await _capture(str(resolution.x)+"-menu")
		var saved: Dictionary = Progression.blank_state()
		saved.discoveries=["penny_perch","bellgill"]
		saved.profiles.crew_1.name="Harbour"
		saved.profiles.crew_2.name="Moss"
		saved.profiles.crew_3.name="River"
		var data: Dictionary = {"is_host":true,"host_addresses":["192.168.1.20"],"run":{"phase":"night","elapsed_s":330,"players":{"crew_1":{},"crew_2":{"downed":true,"down_left":18},"crew_3":{}}},"progression":saved,"poses":{"players":{"crew_1":{"position":Vector3.ZERO},"crew_2":{"position":Vector3(4,0,3)}}},"lights":{"station_until":{"jetty":390,"reeds":420}},"choice":{"open":true,"votes":{"crew_2":"jetty"}},"fishing":{"crew_1":{"pull":1.0,"progress":0.6,"tension":0.5}},"campaign":{"objective":"Bring the keeper lens to Beacon Ridge, then restore the signal light."}}
		hud.show_game()
		hud.update_view(data,"crew_1","Hold E · revive Moss")
		hud.toast("Moss needs a hand. Reach the light together.")
		await _capture(str(resolution.x)+"-gameplay")
		var viewport: Rect2=Rect2(Vector2.ZERO,Vector2(resolution))
		for control: Control in [hud._stats.get_parent().get_parent(),hud._context.get_parent().get_parent(),hud._fish_card,hud._toast_card,hud._objective,hud._vote_notice]:
			if not viewport.encloses(control.get_global_rect()): failures.append("%s outside %s" % [control.name,resolution])
		if hud._toast_card.get_global_rect().intersects(hud._objective.get_global_rect()) or hud._toast_card.get_global_rect().intersects(hud._vote_notice.get_global_rect()): failures.append("Toast covers objective or ballot at "+str(resolution))
		if hud._context.get_parent().get_parent().get_global_rect().intersects(hud._fish_card.get_global_rect()): failures.append("Fishing overlaps action at "+str(resolution))
		data.run.paused = true
		hud.update_view(data,"crew_1","")
		hud.toggle_panel("pause")
		await _capture(str(resolution.x)+"-pause")
		if hud._panels.pause.size.y > hud._panel_scroll.size.y: failures.append("Pause actions require scrolling at "+str(resolution))
		var panel: Control=hud._panel_scroll.get_parent().get_parent()
		if not viewport.encloses(panel.get_global_rect()): failures.append("Pause panel outside "+str(resolution))
		hud.toggle_panel("workshop")
		await process_frame
		hud._panel_scroll.ensure_control_visible(hud._outfit_grid)
		await _capture(str(resolution.x)+"-outfits")
		if not viewport.encloses(panel.get_global_rect()): failures.append("Workshop panel outside "+str(resolution))
		hud.queue_free()
		await process_frame
	for message: String in failures: push_error(message)
	print("POLISHED_HUD_RENDER ","PASS" if failures.is_empty() else "FAIL",": 1280x720 and960x540; menu, crew/downed/power/ballot/fishing, pause LAN, outfit choices")
	quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image=root.get_texture().get_image()
	result.save_png(destination+"/"+label+".png")
	print("HUD_FRAME ",label," ",result.get_size())
