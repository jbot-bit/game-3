extends SceneTree
## Bounded rendered layout probe; creates no household state or network session.

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var hud_script: GDScript = load("res://game/ui/hud.gd")
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	var destination: String = "res://.tools/hud-preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	await process_frame
	await _capture(destination + "/menu.png")
	var data: Dictionary = {"is_host": true, "run": {"phase": "night", "elapsed_s": 300, "players": {"crew_1": {}, "crew_2": {}, "crew_3": {}}}, "progression": {"coins": 85, "owned_rods": ["starter", "soft_tip"], "owned_lamps": ["flood"], "known_recipes": ["surveyor_lantern", "braced_reel"], "salvage": {"glass_lens": 1, "cord_spool": 1}, "profiles": {"crew_1": {"name": "Captain Penny", "role_id": "scout", "rod_id": "starter", "lamp_id": "flood"}}, "discoveries": ["penny_perch", "bellgill"], "specimen_records": {"penny_perch": {"count": 5, "largest_size": 1.45, "traits": ["oversized"]}}}, "campaign": {"title": "Raise the beacon", "objective": "Take the keeper lens to the beacon on the north ridge.", "repairs": [{"id": "workshop", "name": "Boat Workshop", "complete": true, "location": "Moth's mooring"}, {"id": "beacon", "name": "Beacon", "complete": false, "requirements": "45 coins + keeper lens · restore the workshop first", "location": "North ridge"}], "tools": {"scout": {"name": "Trail Mark", "hint": "Discover six fish species.", "unlocked": false}}}, "escape": {"description": "Restore the beacon and Moth's engine before the final crossing.", "can_arm": false, "can_signal": false, "completed": false}}
	hud.show_game()
	hud.update_view(data, "crew_1", "Follow the lamps to the next fishing pocket.")
	await _capture(destination + "/hud.png")
	for kind: String in ["journal", "workshop", "settings"]:
		hud.toggle_panel(kind)
		await _capture(destination + "/" + kind + ".png")
		var panel: Control = hud._panel_scroll.get_parent().get_parent()
		if not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()):
			push_error("Panel exceeds 1280x720 viewport: " + kind)
			quit(1)
			return
		if kind == "journal":
			hud._journal_page(true)
			await _capture(destination + "/collection.png")
			hud._panel_scroll.scroll_vertical = 99999
			await _capture(destination + "/collection_end.png")
			hud._journal_page(false)
		if kind == "workshop":
			hud._panel_scroll.scroll_vertical = 99999
			await _capture(destination + "/workshop_end.png")
	data.escape.completed = true
	data.campaign.completed = true
	hud.update_view(data, "crew_1", "")
	await _capture(destination + "/ending.png")
	print("HUD_RENDER_PASS: menu, HUD, journal, workshop, settings, ending at 1280x720")
	hud.queue_free()
	await process_frame
	quit(0)

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
