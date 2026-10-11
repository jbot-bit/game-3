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

func _state(complete: bool = false) -> Dictionary:
	return {"course_id": "counterweight", "course_name": "Counterweight", "next_course_name": "First Crossing",
		"phase": "complete" if complete else "play", "players": {
			"crew_1": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "spring"},
			"crew_2": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "heavy"},
			"crew_3": {"name": "WWWWWWWWWWWWWWWWWWWWWWWW", "power": "grip"}}}

func _button(text: String) -> Button:
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null

func _assert_visible_controls_fit(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Control and child.is_visible_in_tree() and (child is BaseButton or child is LineEdit or child is Label):
			var bounds: Rect2 = child.get_global_rect()
			assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(bounds), "%s fits 960x540: %s" % [child.name, bounds])
		_assert_visible_controls_fit(child)

func test_host_selection_emits_unchanged_signal_and_stays_out_of_live_menu() -> void:
	var selectors: Array[Node] = hud.find_children("*", "OptionButton", true, false)
	assert_eq(selectors.size(), 1, "Host can choose a course")
	if selectors.is_empty(): return
	var selector: OptionButton = selectors[0]
	assert_eq(hud.call("selected_course_id"), "crossing")
	selector.select(1)
	hud.get("_name").text = "  Host  "
	watch_signals(hud)
	_button("Host game").pressed.emit()
	assert_signal_emitted_with_parameters(hud, "host_requested", ["Host"])
	assert_eq(hud.call("selected_course_id"), "counterweight", "Main receives the selected course when handling Host")
	hud.show_game()
	hud.update_view(_state(), "crew_1", true)
	hud.show_menu()
	assert_false(selector.is_visible_in_tree(), "The host cannot swap courses from a live run")
	assert_true(_button("Restart course").is_visible_in_tree())

func test_course_title_is_authoritative_for_clients_and_completion_actions_are_host_only() -> void:
	hud.show_game()
	hud.update_view(_state(), "crew_2", false)
	var title: Variant = hud.get("_course_title")
	assert_not_null(title, "Gameplay identifies the authoritative course")
	if title == null: return
	assert_eq(title.text, "02 / 20 · Counterweight")
	hud.update_view(_state(true), "crew_2", false)
	assert_false(hud.get("_restart").is_visible_in_tree())
	var next: Variant = hud.get("_next_course")
	assert_not_null(next, "A saved clear offers a next course")
	if next == null: return
	assert_false(next.is_visible_in_tree(), "Clients wait for the host")
	hud.update_view(_state(true), "crew_1", true)
	assert_true(next.is_visible_in_tree())
	assert_string_contains(next.text, "First Crossing")
	watch_signals(hud)
	next.pressed.emit()
	assert_signal_emit_count(hud, "next_course_requested", 1)
	assert_signal_not_emitted(hud, "restart_requested")
	_button("Play again").pressed.emit()
	assert_signal_emit_count(hud, "restart_requested", 1)

func test_failed_save_hides_advance_and_keeps_the_retry_action() -> void:
	var data: Dictionary = _state(true)
	data.save_failed = true
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	var next: Variant = hud.get("_next_course")
	assert_not_null(next)
	if next == null: return
	assert_false(next.is_visible_in_tree())
	watch_signals(hud)
	_button("Retry save").pressed.emit()
	assert_signal_emit_count(hud, "restart_requested", 1)
	data.save_failed = false
	data.next_course_name = ""
	hud.update_view(data, "crew_1", true)
	assert_false(next.is_visible_in_tree(), "An explicitly absent next course does not advertise advancement")

func test_full_level_selector_and_last_course_fit_small_viewport() -> void:
	var selector: OptionButton = hud.get("_course_selector")
	assert_eq(selector.item_count, 20, "All twenty courses are available without grinding unlocks")
	if selector.item_count != 20: return
	selector.select(19)
	assert_eq(hud.selected_course_id(), "final_shift")
	assert_string_contains(selector.get_item_text(19), "20")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)


func test_menu_gameplay_and_completion_fit_small_viewport_with_three_long_names() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
	hud.show_game()
	hud.update_view(_state(), "crew_1", true)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
	hud.show_menu("Game keeps running. Restart restores the course.")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
	hud.show_game()
	hud.update_view(_state(true), "crew_1", true)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visible_controls_fit(hud)
