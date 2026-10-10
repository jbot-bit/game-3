extends SceneTree
## Native UI render fixture. Host is opened through the HUD; edge states are authored snapshots.
const Game = preload("res://game/main.gd")
var app: Node3D
var failures: PackedStringArray = []
var destination: String = "res://.tools/fresh-hud-preview"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.content_scale_size=resolution
		root.size=resolution
		DisplayServer.window_set_size(resolution)
		app=Game.new()
		var fixture: String="user://tests/fresh_hud_"+str(Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
		app.save_path=fixture+"/household.json"
		app.settings_path=fixture+"/settings.json"
		app.game_port=24895
		root.add_child(app)
		await _frames(12)
		var hud: GameHUD=app.hud
		await _capture(str(resolution.x)+"-home")
		hud.show_menu_flow("join")
		await _capture(str(resolution.x)+"-join")
		hud.show_menu_flow("host")
		await _capture(str(resolution.x)+"-host")
		hud.host_requested.emit("Harbour")
		await _frames(45)
		await _capture(str(resolution.x)+"-spawn")
		app.set_process(false)
		app.set_physics_process(false)
		var data: Dictionary=app.controller.snapshot_data.duplicate(true)
		data.is_host=true
		data.host_addresses=["192.168.1.20"]
		data.run.paused=true
		hud.update_view(data,"crew_1","")
		hud.toggle_panel("pause")
		await _capture(str(resolution.x)+"-pause")
		if hud._panels.pause.size.y > hud._panel_scroll.size.y: failures.append("Pause requires scroll at "+str(resolution))
		hud.toggle_panel("workshop")
		await _capture(str(resolution.x)+"-workshop")
		hud.toggle_panel("journal")
		hud._journal_page(true)
		await _capture(str(resolution.x)+"-journal")
		hud._close_panel()
		data.run.paused=false
		data.run.elapsed_s=330.0
		data.run.phase="night"
		data.run.players.crew_2={"downed":true,"down_left":18.0}
		data.progression.profiles.crew_2.name="Moss"
		data.poses={"players":{"crew_1":{"position":Vector3.ZERO},"crew_2":{"position":Vector3(4,0,3)}}}
		data.lights.station_until={"jetty":390.0,"reeds":420.0}
		data.choice={"open":true,"votes":{"crew_2":"jetty"}}
		data.fishing={"crew_1":{"pull":1.0,"progress":0.6,"tension":0.5}}
		hud.update_view(data,"crew_1","Hold E · revive Moss")
		hud.toast("Moss needs a hand.")
		await _capture(str(resolution.x)+"-edge-states")
		var viewport: Rect2=Rect2(Vector2.ZERO,Vector2(resolution))
		for control: Control in [hud._stats,hud._action_card,hud._fish_card,hud._toast_card,hud._vote_notice,hud._status_strip]:
			if control.is_visible_in_tree() and not viewport.encloses(control.get_global_rect()): failures.append("%s outside %s"%[control.name,resolution])
		if hud._action_card.get_global_rect().intersects(hud._fish_card.get_global_rect()): failures.append("Fishing overlaps context at "+str(resolution))
		if hud._vote_notice.is_visible_in_tree() and hud._toast_card.get_global_rect().intersects(hud._vote_notice.get_global_rect()): failures.append("Toast overlaps battery notice at "+str(resolution))
		app.session.close()
		app.queue_free()
		await _frames(3)
	for failure: String in failures: push_error(failure)
	print("FRESH_HUD_RENDER ","PASS" if failures.is_empty() else "FAIL",": native 1280x720 + 960x540; authored edge states")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i: int in range(count): await process_frame

func _capture(label: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var result: Image=root.get_texture().get_image()
	result.save_png(destination+"/"+label+".png")
	print("FRESH_HUD_FRAME ",label," ",result.get_size())
