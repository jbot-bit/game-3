extends SceneTree

var hud: GameHUD
var destination: String = "res://.tools/survival-preview"

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	hud = GameHUD.new()
	root.add_child(hud)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	hud.show_game()
	var data: Dictionary = {"run":{"phase":"night","elapsed_s":365.0,"players":{"crew_1":{},"crew_2":{"downed":true,"down_left":19.0},"crew_3":{}}},"progression":{"profiles":{"crew_1":{"name":"Harbour","role_id":"scout","lamp_id":"flood"},"crew_2":{"name":"Moss","role_id":"keeper"},"crew_3":{"name":"River","role_id":"rigger"}},"coins":85},"poses":{"players":{"crew_1":{"position":Vector3.ZERO},"crew_2":{"position":Vector3(3,0,4)}}},"lights":{"batteries":{"crew_1":12},"station_until":{"jetty":390,"reeds":460}},"campaign":{"objective":"Restore the beacon · 100 coins and the coil from Beacon Ridge."}}
	hud.update_view(data,"crew_1","R carry Moss · hold E to revive")
	await _capture("night-rescue")
	data.rescue_progress = {"crew_1":{"target":"crew_2","held_s":1.5}}
	hud.update_view(data,"crew_1","")
	await _capture("reviving")
	data.erase("rescue_progress")
	data.supplies = {"cell":{"state":"held","carrier_id":"crew_1"}}
	data.throw_charge = 0.7
	hud.update_view(data,"crew_1","R set down · E feed shelter")
	await _capture("charged-cell")
	data.erase("supplies")
	data.erase("throw_charge")
	data.fishing = {"crew_1":{"progress":0.7,"tension":0.75,"pull":1.0,"behavior":"surge","surge_in":0.5}}
	hud.update_view(data,"crew_1","LMB reel · release before the line turns red")
	await _capture("fishing")
	data.run.terminal = true
	data.run.run_id = "r1"
	data.progression.settled_run_ids = ["r1"]
	data.trip_result = {"outcome":"retreat","banked":45,"new_species":2,"records":1,"lost_count":3,"next_goal":"Next: bring the engine part home from Tide Pools."}
	hud.update_view(data,"crew_1","")
	await _capture("retreat-result")
	print("SURVIVAL_HUD_RENDER_PASS: night, revival, cell throw, fishing, retreat recap at1280x720")
	hud.queue_free()
	await process_frame
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport: Rect2 = Rect2(Vector2.ZERO,Vector2(1280,720))
	var bottom: Control = hud._context.get_parent().get_parent()
	if not viewport.encloses(bottom.get_global_rect()) or bottom.size.y>=120.0:
		push_error("Compact HUD does not fit: "+label)
		quit(1)
		return
	root.get_texture().get_image().save_png(destination+"/"+label+".png")
