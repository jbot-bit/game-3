extends SceneTree
## Native HUD screenshots at the minimum supported layout. Uses state fixtures,
## not a simulated course clear or multiplayer gameplay evidence.
const HUD = preload("res://prototypes/physics_party/party_hud.gd")
var hud: CanvasLayer
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://logs/counterweight-ui-" + label + ".png")
	failed = failed or error != OK
	print("COURSE_UI_CAPTURE ", label, " ", error)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This probe requires the native renderer.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.gui_embed_subwindows = true
	root.gui_disable_input = true
	Engine.max_fps = 60
	hud = HUD.new()
	root.add_child(hud)
	await _capture("menu")
	hud.get("_course_selector").show_popup()
	await _capture("chooser")
	hud.get("_course_selector").get_popup().hide()
	hud.get("_course_selector").select(19)
	hud.get("_course_selector").show_popup()
	await _capture("chooser-last-level")
	failed = failed or hud.selected_course_id() != "final_shift" or hud.get("_course_selector").get_popup().size.y > 360
	hud.get("_course_selector").get_popup().hide()
	hud.get("_course_selector").select(1)
	var data: Dictionary = {"course_id": "counterweight", "course_name": "Counterweight", "next_course_name": "First Crossing",
		"phase": "play", "players": {
			"crew_1": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "spring"},
			"crew_2": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "heavy"},
			"crew_3": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "grip"}},
		"join_address": "192.168.1.123", "unlocked_power_ids": ["spring", "heavy", "grip"], "completions": 3,
		"note": "Load the tray. Cross while the bridge is lowered."}
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	await _capture("play")
	hud.show_menu("Game keeps running · Esc to return")
	await _capture("pause")
	hud.show_game()
	data.phase = "complete"
	hud.update_view(data, "crew_1", true)
	await _capture("complete")
	data.save_failed = true
	hud.update_view(data, "crew_1", true)
	await _capture("retry")
	hud.update_view(data, "crew_2", false)
	await _capture("client-retry")
	print("COURSE_UI_NATIVE ", "FAIL" if failed else "PASS", " 960x540, state fixtures only")
	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)
