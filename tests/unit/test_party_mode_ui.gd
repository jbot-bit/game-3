extends GutTest

const HUD = preload("res://prototypes/physics_party/party_hud.gd")
var hud: CanvasLayer
var viewport: SubViewport

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	add_child_autofree(viewport)
	hud = HUD.new()
	viewport.add_child(hud)

func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _button(text: String) -> Button:
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null

func _state(mode: String, complete: bool = false) -> Dictionary:
	return {"mode_id": mode, "course_id": "crossing", "phase": "complete" if complete else "play",
		"players": {"crew_1": {"name": "Sam", "power": ""}, "crew_2": {"name": "Alex", "power": ""}, "crew_3": {"name": "Charlie", "power": ""}},
		"offers": {"crew_1": ["spring", "heavy", "grip"]}, "unlocked_power_ids": ["spring"],
		"match": {"phase": "complete" if complete else "active", "round": 4, "remaining": 30.0, "scores": {"crew_1": 1, "crew_2": 3, "crew_3": 0}, "alive": ["crew_1", "crew_2"], "winner": "crew_2"},
		"challenge": {"elapsed": 73.25, "results": {"crew_1": {"time": 73.25, "falls": 2}, "crew_2": {"time": 68.75, "falls": 1}, "crew_3": {"time": 80.5, "falls": 3}}},
		"next_course_name": "Counterweight"}

func _assert_visible_controls_fit(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Control and child.is_visible_in_tree() and (child is BaseButton or child is LineEdit or child is Label):
			assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(child.get_global_rect()), "%s fits 960x540: %s" % [child.name, child.get_global_rect()])
		_assert_visible_controls_fit(child)

func test_host_chooses_modes_without_changing_host_signal_or_course_catalog() -> void:
	assert_true(hud.has_method("selected_mode_id"))
	if not hud.has_method("selected_mode_id"): return
	assert_eq(hud.selected_mode_id(), "coop")
	var selector: OptionButton = hud.get("_course_selector")
	selector.select(19)
	watch_signals(hud)
	hud.get("_name").text = "  Host  "
	for mode: String in ["Gladiator", "Wipeout", "Knockout"]:
		assert_not_null(_button(mode))
		if _button(mode) == null: return
		_button(mode).pressed.emit()
		assert_eq(hud.selected_mode_id(), mode.to_lower())
		assert_false(selector.is_visible_in_tree())
		assert_eq(hud.selected_course_id(), "crossing", "Modes without courses keep a valid legacy course argument")
		_button("Host game").pressed.emit()
	assert_signal_emitted_with_parameters(hud, "host_requested", ["Host"])
	_button("Co-op").pressed.emit()
	assert_true(selector.is_visible_in_tree())
	assert_eq(hud.selected_course_id(), "final_shift", "Returning to co-op preserves the chosen level")

func test_competitive_modes_do_not_offer_powers_or_grapple() -> void:
	for mode: String in ["gladiator", "wipeout", "knockout"]:
		hud.show_game()
		hud.update_view(_state(mode), "crew_1", true)
		assert_false(hud.get("_draft").is_visible_in_tree())
		assert_false(hud.get("_grapple_reticle").is_visible_in_tree())
		assert_false(hud.get("_grapple_status").is_visible_in_tree())
		assert_false(hud.blocks_input(), "The old power draft cannot block a match")
		assert_false(hud.get("_course_title").text.contains("20"))
		hud.show_menu()
		assert_true(hud.get("_menu_customize").is_visible_in_tree())
		assert_false(_button(mode.capitalize()).is_visible_in_tree(), "A running session cannot change mode")

func test_mode_objective_and_hint_use_host_state() -> void:
	var data := _state("gladiator")
	data.mode_text = "Alex wins this round · next round in 3"
	data.mode_hint = "Brace against a swing, then counter."
	hud.show_game()
	hud.update_view(data, "crew_1", false)
	assert_eq(hud.get("_objective").text, data.mode_text)
	assert_eq(hud.get("_note").text, data.mode_hint)
	assert_true(hud.get("_controls").text.contains("Swing"))
	assert_true(hud.get("_controls").text.contains("Brace"))

func test_gladiator_ending_names_winner_and_scores_and_only_host_can_replay() -> void:
	var data := _state("gladiator", true)
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_true(hud.get("_ending_title").text.contains("Alex"))
	assert_true(hud.get("_ending_detail").text.contains("Alex · 3"))
	assert_true(hud.get("_ending_detail").text.contains("Sam · 1"))
	assert_false(hud.get("_next_course").is_visible_in_tree())
	assert_eq(hud.get("_restart").text, "Play again")
	hud.update_view(data, "crew_2", false)
	assert_false(hud.get("_restart").is_visible_in_tree())
	assert_false(hud.get("_next_course").is_visible_in_tree())

func test_wipeout_ending_reports_time_and_falls() -> void:
	hud.show_game()
	hud.update_view(_state("wipeout", true), "crew_1", true)
	assert_eq(hud.get("_ending_title").text, "COURSE COMPLETE")
	assert_true(hud.get("_ending_detail").text.contains("Sam · 1:13.25 · 2 falls"))
	assert_true(hud.get("_ending_detail").text.contains("Alex · 1:08.75 · 1 fall"))
	assert_false(hud.get("_next_course").is_visible_in_tree())
	assert_false(hud.get("_controls").text.contains("Grapple"))

func test_wipeout_live_clock_keeps_running_until_player_finishes_and_timeout_shows_dnf() -> void:
	var data := _state("wipeout")
	data.challenge.runners = {"crew_1": {"checkpoint": 2, "falls": 3, "finished": false, "time": 0.0}}
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_eq(hud.get("_wind").text, "TIME 1:13.25")
	assert_eq(hud.get("_progress").text, "Checkpoint 2 · 3 falls")
	data.challenge.runners.crew_1.finished = true
	data.challenge.runners.crew_1.time = 72.1
	data.challenge.elapsed = 91.0
	hud.update_view(data, "crew_1", true)
	assert_eq(hud.get("_wind").text, "TIME 1:12.10")
	data.phase = "complete"
	data.challenge.results.crew_3.finished = false
	hud.update_view(data, "crew_1", true)
	assert_string_contains(hud.get("_ending_detail").text, "Charlie · DNF · 3 falls")

func test_solo_gladiator_does_not_advertise_a_reward() -> void:
	var data := _state("gladiator")
	data.match.phase = "practice"
	data.players.erase("crew_2")
	data.players.erase("crew_3")
	data.reward_cards = ["paint_mint", "gear_cap", "gear_crown"]
	data.reward_run_id = "stale-bag"
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_false(hud.get("_bag_button").is_visible_in_tree())

func test_committed_gladiator_bag_survives_other_players_leaving() -> void:
	var data := _state("gladiator", true)
	data.run_id = "finished-match"
	data.reward_run_id = "finished-match"
	data.reward_cards = ["paint_mint", "gear_cap", "gear_crown"]
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_true(hud.get("_bag_button").is_visible_in_tree())
	data.players.erase("crew_2")
	data.players.erase("crew_3")
	hud.update_view(data, "crew_1", true)
	assert_true(hud.get("_bag_button").is_visible_in_tree(), "Leaving after a saved match cannot revoke its unopened bag")
	hud.get("_bag_button").pressed.emit()
	var row: HBoxContainer = hud.get("_reward_row")
	assert_true(row.is_visible_in_tree())
	assert_eq(row.get_child_count(), 3)
	var card: Button = row.get_child(0)
	card.pressed.emit()
	hud.update_view(data, "crew_1", true)
	assert_true(row.is_visible_in_tree(), "Later snapshots keep the saved reveal open with one player remaining")
	assert_eq(row.get_child(0), card)
	assert_true(card.get_meta("revealed", false))
	assert_eq(card.get_meta("reward_card_id"), "paint_mint")

func test_mode_menu_play_and_results_fit_small_viewport() -> void:
	for mode: String in ["Gladiator", "Wipeout", "Knockout", "Co-op"]:
		assert_not_null(_button(mode))
		if _button(mode) == null: return
		hud.reset_session()
		_button(mode).pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_visible_controls_fit(hud)
		if mode == "Co-op": continue
		var data := _state(mode.to_lower())
		hud.show_game()
		hud.update_view(data, "crew_1", true)
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_visible_controls_fit(hud)
		data.phase = "complete"
		data.reward_cards = ["paint_mint", "gear_cap", "gear_crown"]
		data.reward_run_id = "mode-complete"
		hud.update_view(data, "crew_1", true)
		hud.get("_bag_button").pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_visible_controls_fit(hud)

func test_knockout_shows_live_round_scores_and_match_winner() -> void:
	var data := _state("knockout")
	data.mode_text = "ROUND 4 / 2 standing / First to 3 wins"
	data.mode_hint = "Jump the low sweeper. Brace against a swing."
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_eq(hud.get("_course_title").text, "Knockout")
	assert_eq(hud.get("_objective").text, data.mode_text)
	assert_eq(hud.get("_note").text, data.mode_hint)
	assert_eq(hud.get("_wind").text, "ROUND 4 · FIRST TO 3")
	assert_string_contains(hud.get("_progress").text, "Alex · 3")
	assert_string_contains(hud.get("_controls").text, "Swing")
	assert_string_contains(hud.get("_controls").text, "Brace")
	hud.show_menu()
	assert_eq(hud.get("_course_restart").text, "Restart match")
	assert_true(hud.get("_resume").has_focus(), "Pause is keyboard-ready")
	hud.show_game()
	hud.update_view(_state("knockout", true), "crew_1", true)
	assert_eq(hud.get("_ending_title").text, "Alex WINS")
	assert_string_contains(hud.get("_ending_detail").text, "Alex · 3")
	assert_false(hud.get("_next_course").is_visible_in_tree())
	hud.update_view(_state("knockout", true), "crew_2", false)
	assert_false(hud.get("_restart").is_visible_in_tree())

func test_launcher_keyboard_submission_and_connection_errors() -> void:
	watch_signals(hud)
	_button("Host game").pressed.emit()
	assert_signal_not_emitted(hud, "host_requested")
	assert_eq(hud.get("_status").text, "Enter your name.")
	assert_true(hud.get("_name").has_focus())
	hud.get("_name").text = "  Alex  "
	hud.get("_name").text_submitted.emit("  Alex  ")
	assert_signal_emitted_with_parameters(hud, "host_requested", ["Alex"])
	_button("Join").pressed.emit()
	assert_signal_not_emitted(hud, "join_requested")
	assert_eq(hud.get("_status").text, "Enter the host's IP address.")
	assert_true(hud.get("_address").has_focus())
	hud.get("_address").text = "  192.168.1.50  "
	hud.get("_address").text_submitted.emit("  192.168.1.50  ")
	assert_signal_emitted_with_parameters(hud, "join_requested", ["192.168.1.50", "Alex"])
	var message := "Couldn't connect. Check the host address and that both PCs are on the same home network."
	hud.show_menu(message)
	assert_eq(hud.get("_status").text, message)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)

func test_host_copy_action_uses_one_usable_address_and_never_appears_for_clients() -> void:
	var data := _state("knockout")
	data.join_address = "192.168.1.50 / 172.18.80.1"
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	hud.show_menu()
	assert_true(_button("Copy address").is_visible_in_tree())
	assert_eq(hud.get("_host_address_to_copy"), "192.168.1.50", "Copy a usable host, not the combined interface list")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
	hud.update_view(data, "crew_2", false)
	assert_false(_button("Copy address").is_visible_in_tree())
	assert_eq(hud.get("_host_address_to_copy"), "")

	data.join_address = "Check this PC's network settings"
	hud.update_view(data, "crew_1", true)
	assert_false(_button("Copy address").is_visible_in_tree())
	assert_eq(hud.get("_host_address_to_copy"), "")
	data.join_address = "192.168.1.50"
	hud.update_view(data, "crew_1", true)
	hud.reset_session()
	assert_false(_button("Copy address").is_visible_in_tree())
	assert_eq(hud.get("_host_address_to_copy"), "")

func test_ring_spectators_get_automatic_return_feedback_and_only_available_controls() -> void:
	for mode: String in ["gladiator", "knockout"]:
		var data := _state(mode)
		data.mode_text = "ROUND 4 / 2 standing / 30s / First to 3 wins"
		data.mode_hint = "Jump the low sweeper. Avoid the high arm."
		data.match.phase = "fight"
		data.match.entrants = ["crew_1", "crew_2"]
		hud.show_game()
		hud.update_view(data, "crew_3", false)
		assert_string_contains(hud.get("_note").text, "Watching — back next round")
		assert_eq(hud.get("_controls").text, "M Mute   ESC Menu")
		assert_eq(hud.get("_objective").text, data.mode_text, "Spectators can still follow the live round")
		data.match.alive = ["crew_1"]
		data.match.phase = "intermission"
		data.match.round_winner = "crew_1"
		hud.update_view(data, "crew_2", false)
		assert_string_contains(hud.get("_note").text, "Watching — back next round")
		assert_eq(hud.get("_controls").text, "M Mute   ESC Menu")
		hud.update_view(data, "crew_1", true)
		assert_string_contains(hud.get("_note").text, "Round won")
		assert_eq(hud.get("_controls").text, "M Mute   ESC Menu")
		data.match.phase = "fight"
		data.match.alive = ["crew_1", "crew_2", "crew_3"]
		hud.update_view(data, "crew_3", false)
		assert_eq(hud.get("_note").text, data.mode_hint, "Next round restores active-player hints")
		assert_string_contains(hud.get("_controls").text, "Swing")
		assert_eq(hud.get("_objective").text, data.mode_text)
		data.phase = "complete"
		data.match.alive = ["crew_1"]
		hud.update_view(data, "crew_3", false)
		assert_false(hud.get("_note").text.contains("back next round"), "Completed matches cannot promise another round")

func test_credits_show_complete_notice_and_scroll_inside_small_viewport() -> void:
	assert_true(FileAccess.file_exists(HUD.CREDITS_PATH), "Single executable includes the complete license notice")
	_button("Credits").pressed.emit()
	assert_true(hud.get("_credits").is_visible_in_tree())
	assert_false(hud.get("_menu").is_visible_in_tree())
	assert_true(hud.blocks_input())
	assert_true(hud.is_menu_open())
	var notice: RichTextLabel = hud.get("_credits_text")
	assert_eq(notice.text, FileAccess.get_file_as_string(HUD.CREDITS_PATH))
	assert_gt(notice.text.length(), 10000, "Full third-party notices are available, not just a short attribution")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
	assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(notice.get_global_rect()))
	var scroll := notice.get_v_scroll_bar()
	assert_gt(scroll.max_value, scroll.page)
	var event := InputEventKey.new()
	event.keycode = KEY_PAGEDOWN
	event.physical_keycode = KEY_PAGEDOWN
	event.pressed = true
	viewport.push_input(event)
	assert_gt(scroll.value, 0.0, "Keyboard Page Down scrolls the notice with Back focused")
	event = InputEventKey.new()
	event.keycode = KEY_END
	event.physical_keycode = KEY_END
	event.pressed = true
	viewport.push_input(event)
	assert_almost_eq(scroll.value, scroll.max_value - scroll.page, 1.0, "The end of the full notice is reachable")
	_button("Back to menu").pressed.emit()
	assert_false(hud.get("_credits").is_visible_in_tree())
	assert_true(hud.get("_menu").is_visible_in_tree())
	assert_true(_button("Credits").has_focus())

func test_credits_escape_returns_to_menu_without_host_join_or_resume() -> void:
	hud.get("_name").text = "Alex"
	hud.get("_address").text = "192.168.1.50"
	hud._select_mode("knockout")
	hud.show_game()
	hud.update_view(_state("knockout"), "crew_1", true)
	hud.show_menu("Keep this connection feedback.")
	watch_signals(hud)
	_button("Credits").pressed.emit()
	assert_true(_button("Back to menu").has_focus())
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	viewport.push_input(event)
	assert_true(viewport.is_input_handled(), "Esc is consumed before the game can resume")
	assert_false(hud.get("_credits").is_visible_in_tree())
	assert_true(hud.get("_menu").is_visible_in_tree())
	assert_eq(hud.get("_status").text, "Keep this connection feedback.")
	assert_eq(hud.get("_name").text, "Alex")
	assert_eq(hud.get("_address").text, "192.168.1.50")
	assert_eq(hud.selected_mode_id(), "knockout")
	assert_true(hud.blocks_input())
	assert_signal_not_emitted(hud, "host_requested")
	assert_signal_not_emitted(hud, "join_requested")
	assert_signal_not_emitted(hud, "resume_requested")
