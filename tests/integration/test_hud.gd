extends GutTest

const HUD = preload("res://game/ui/hud.gd")
var hud: GameHUD

func before_each() -> void:
	hud = HUD.new()
	add_child_autofree(hud)
	hud.show_game()

func test_battery_choice_does_not_add_a_ballot_overlay() -> void:
	hud.update_view({"choice": {"open": true, "votes": {}}}, "crew_1", "")
	assert_false(hud._vote_notice.visible)
	assert_false(hud.panel_open())
	hud.update_view({"choice": {"open": false, "committed": "jetty"}}, "crew_1", "")
	assert_false(hud._vote_notice.visible)

func test_toggle_reel_mode_never_tells_player_to_release_a_button_to_stop() -> void:
	var data: Dictionary={"reel_toggle_mode":true,"reel_active":true,"fishing":{"crew_1":{"pull":1.0,"surging":true}}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._fish_hint.text,"Click LMB")
	assert_false(hud._fish_hint.text.contains("Release"))
	data.fishing.crew_1.surging=false
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._fish_hint.text,"Click LMB")
	assert_false(hud._fish_hint.text.contains("release"))
	data.fishing.crew_1.surging=true
	data.reel_active=false
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._fish_hint.text,"Wait")
	data.reel_toggle_mode=false
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._fish_hint.text,"Release LMB")

func test_lan_address_is_only_shown_for_host() -> void:
	hud.update_view({"is_host": true, "host_addresses": ["192.168.1.20"]}, "crew_1", "")
	assert_true(hud._host_address.visible)
	assert_string_contains(hud._host_address.text, "192.168.1.20")
	hud.update_view({"is_host": false, "host_addresses": ["192.168.1.20"]}, "crew_2", "")
	assert_false(hud._host_address.visible)

func test_audio_updates_do_not_emit_user_actions() -> void:
	watch_signals(hud)
	hud.update_view({"audio_muted": true}, "crew_1", "")
	assert_true(hud._mute.button_pressed)
	assert_signal_not_emitted(hud, "action_requested")
	hud._mute.button_pressed = false
	assert_signal_emitted_with_parameters(hud, "action_requested", ["set_audio", {"muted": false}])

func test_snapshot_does_not_overwrite_name_being_edited() -> void:
	var data: Dictionary = {"progression": {"profiles": {"crew_1": {"name": "Penny", "role_id": "rigger"}}}}
	hud.update_view(data, "crew_1", "")
	hud.toggle_panel("workshop")
	assert_eq(hud._profile_name.text, "Penny")
	hud._profile_name.text = "New name"
	hud.update_view(data, "crew_1", "")
	assert_eq(hud._profile_name.text, "New name")

func test_departure_suppresses_stale_fishing_and_cargo_instructions() -> void:
	var data: Dictionary = {"run": {"phase": "refuge", "crossing_left": 12.0}, "fishing": {"crew_1": {"pull": -1.0}}, "cargo": {"fish": {"state": "whole_held", "carrier_id": "crew_1"}}}
	hud.update_view(data, "crew_1", "LMB toss · hold P to pack")
	assert_false(hud._fish_card.visible)
	assert_false(hud._context.text.contains("LMB"))
	assert_false(hud._equipment.text.contains("pack"))
	assert_string_contains(hud._context.text, "12s")

func test_terminal_status_requires_a_saved_run_receipt() -> void:
	var data: Dictionary = {"is_host": true, "run": {"run_id": "trip-1", "terminal": true, "paused": true}}
	hud.update_view(data, "crew_1", "E bank")
	assert_string_contains(hud._context.text, "save pending")
	data.progression = {"settled_run_ids": ["trip-1"]}
	hud.update_view(data, "crew_1", "E bank")
	assert_string_contains(hud._context.text, "saved")
	assert_false(hud._context.text.contains("pending"))

func test_fishing_hint_names_the_opposite_countersteer_key() -> void:
	hud.update_view({"fishing": {"crew_1": {"pull": -1.0}}}, "crew_1", "")
	assert_string_contains(hud._fish_hint.text, "LEFT · hold D")
	hud.update_view({"fishing": {"crew_1": {"pull": 1.0}}}, "crew_1", "")
	assert_string_contains(hud._fish_hint.text, "RIGHT · hold A")
