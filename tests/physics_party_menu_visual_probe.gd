extends SceneTree
## Native menu screenshots, including connection feedback and session controls.
const HUD = preload("res://prototypes/physics_party/party_hud.gd")
var hud: CanvasLayer
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://logs/hands-full-menu-" + label + ".png")
	failed = failed or result != OK
	print("HANDS_FULL_MENU_CAPTURE ", label, " ", result)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the native renderer for menu screenshots.")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	hud = HUD.new()
	root.add_child(hud)
	await _capture("960-coop")
	hud._select_mode("knockout")
	await _capture("960-knockout")
	hud.get("_name").text = "Alex"
	hud.get("_address").text = "192.168.1.50"
	hud.show_menu("Couldn't connect. Check the host address and that both PCs are on the same home network.")
	await _capture("960-connection-error")
	hud.show_game()
	hud.update_view({"mode_id": "knockout", "join_address": "192.168.1.50", "players": {"crew_1": {"name": "Alex"}}, "match": {"round": 1}}, "crew_1", true)
	hud.show_menu("Game keeps running while this menu is open.")
	await _capture("960-session")
	hud.show_credits()
	await _capture("960-credits")
	var credit_scroll: VScrollBar = hud.get("_credits_text").get_v_scroll_bar()
	credit_scroll.value = credit_scroll.max_value
	await _capture("960-credits-end")
	hud._close_credits()
	var watching := {"mode_id": "knockout", "phase": "play", "mode_text": "ROUND 2 / 2 standing / 45s / First to 3 wins",
		"mode_hint": "Jump the low sweeper. Avoid the high arm. LMB swing / RMB brace.",
		"players": {"crew_1": {"name": "Alex"}, "crew_2": {"name": "Sam"}, "crew_3": {"name": "Josh"}},
		"match": {"round": 2, "phase": "fight", "alive": ["crew_1", "crew_2"], "entrants": ["crew_1", "crew_2"], "scores": {"crew_1": 1, "crew_2": 0, "crew_3": 0}}}
	hud.show_game()
	hud.update_view(watching, "crew_3", false)
	await _capture("960-late-join-watching")
	watching.match.alive = ["crew_1"]
	watching.match.phase = "intermission"
	watching.match.round_winner = "crew_1"
	watching.mode_text = "Alex wins the round / Next in 3"
	hud.update_view(watching, "crew_2", false)
	await _capture("960-eliminated-watching")
	hud.reset_session()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await _capture("1280-knockout")
	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)
