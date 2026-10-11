extends GutTest

const HUD = preload("res://prototypes/physics_party/party_hud.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
var hud: CanvasLayer
var viewport: SubViewport

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	add_child_autofree(viewport)
	hud = HUD.new()
	viewport.add_child(hud)

func after_each() -> void:
	# Rebuilt button lists use queue_free, just as they do during a render frame.
	await get_tree().process_frame
	await get_tree().process_frame

func _state(complete: bool = false) -> Dictionary:
	return {"course_id": "crossing", "phase": "complete" if complete else "play",
		"players": {"crew_1": {"name": "Player", "power": "spring", "appearance": Cosmetics.default_style(0)}},
		"cosmetic_cards": ["paint_mint", "gear_cap", "gear_crown"],
		"reward_cards": ["paint_mint", "gear_cap", "gear_crown"] if complete else [],
		"reward_run_id": "earned-run-a" if complete else "", "next_course_name": "Counterweight"}

func _ready_feature() -> bool:
	assert_true(hud.has_method("show_cosmetics"), "The HUD exposes a customization panel")
	assert_true(hud.has_signal("appearance_chosen"), "Appearance choices leave through one gameplay signal")
	return hud.has_method("show_cosmetics") and hud.has_signal("appearance_chosen")

func _button(text: String) -> Button:
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.text == text: return button
	return null

func _choice(kind: String, value: String) -> Button:
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.get_meta("cosmetic_kind", "") == kind and button.get_meta("cosmetic_value", "") == value:
			return button
	return null

func _reward_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.has_meta("reward_card_id"): result.append(button)
	return result

func test_customization_is_available_from_pause_and_draft_and_blocks_movement() -> void:
	if not _ready_feature(): return
	hud.show_game()
	hud.update_view(_state(), "crew_1", true)
	hud.show_menu()
	assert_true(hud.get("_menu_customize").is_visible_in_tree())
	hud.get("_menu_customize").pressed.emit()
	assert_true(hud.get("_cosmetics").is_visible_in_tree())
	assert_true(hud.blocks_input())
	hud.call("hide_cosmetics")
	assert_true(hud.is_menu_open(), "Closing customization returns to its pause menu")
	var data := _state()
	data.players.crew_1.power = ""
	data.offers = {"crew_1": ["spring", "heavy", "grip"]}
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_true(hud.get("_draft_customize").is_visible_in_tree())
	hud.get("_draft_customize").pressed.emit()
	assert_true(hud.get("_cosmetics").is_visible_in_tree())
	watch_signals(hud)
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_1
	shortcut.pressed = true
	hud.call("_unhandled_key_input", shortcut)
	assert_signal_not_emitted(hud, "power_chosen", "Power shortcuts cannot activate behind the cosmetics panel")

func test_only_owned_choices_can_be_applied_and_blank_style_stays_available() -> void:
	if not _ready_feature(): return
	hud.show_game()
	hud.update_view(_state(), "crew_1", true)
	hud.call("show_cosmetics")
	watch_signals(hud)
	assert_false(_choice("color", "mint").disabled)
	assert_true(_choice("color", "prism").disabled)
	assert_true(_choice("color", "rose").disabled)
	_choice("color", "prism").pressed.emit()
	_choice("color", "mint").pressed.emit()
	hud.call("_show_cosmetic_kind", "accessory")
	assert_false(_choice("accessory", "none").disabled, "The unadorned character is always an option")
	assert_false(_choice("accessory", "crown").disabled)
	assert_true(_choice("accessory", "halo").disabled)
	assert_true(_choice("accessory", "beanie").disabled)
	assert_true(_choice("accessory", "sprout").disabled)
	_choice("accessory", "crown").pressed.emit()
	_button("Apply look").pressed.emit()
	assert_signal_emitted_with_parameters(hud, "appearance_chosen", [{"color": "mint", "accessory": "crown"}])
	assert_eq(hud.get("_confirmed_appearance"), Cosmetics.default_style(0), "The signal does not invent server confirmation")
	var confirmed := _state()
	confirmed.players.crew_1.appearance = {"color": "mint", "accessory": "crown"}
	hud.update_view(confirmed, "crew_1", true)
	assert_eq(hud.get("_cosmetic_status").text, "Your look is ready.")
	confirmed.appearance_error = "That item is still locked."
	hud.update_view(confirmed, "crew_1", true)
	assert_eq(hud.get("_cosmetic_status").text, confirmed.appearance_error)

func test_reward_bag_reveals_exact_server_cards_once_and_keeps_navigation() -> void:
	if not _ready_feature(): return
	var data := _state(true)
	data.reward_duplicates = ["gear_cap"]
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	watch_signals(hud)
	_button("Open surprise bag").pressed.emit()
	var cards := _reward_buttons()
	assert_eq(cards.size(), 3)
	for index in cards.size():
		assert_eq(cards[index].get_meta("reward_card_id"), data.reward_cards[index])
		assert_false(cards[index].get_meta("revealed", false))
		cards[index].pressed.emit()
		assert_true(cards[index].get_meta("revealed", false))
		assert_eq(cards[index].get_meta("rarity"), Cosmetics.card_info(data.reward_cards[index]).rarity)
	assert_true(cards[1].get_meta("duplicate", false))
	assert_true(hud.get("_next_course").is_visible_in_tree())
	assert_true(hud.get("_restart").is_visible_in_tree())
	hud.update_view(data, "crew_1", true)
	assert_eq(_reward_buttons()[0], cards[0], "Repeated snapshots do not replace revealed cards")
	assert_true(_reward_buttons()[0].get_meta("revealed", false))
	assert_signal_not_emitted(hud, "appearance_chosen", "Opening a bag never equips or rolls rewards")

func test_repeated_new_card_is_a_duplicate_only_after_its_first_copy() -> void:
	var data := _state(true)
	data.reward_cards = ["paint_mint", "paint_mint", "gear_cap"]
	data.reward_duplicates = ["gear_cap"]
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	_button("Open surprise bag").pressed.emit()
	var cards := _reward_buttons()
	assert_false(cards[0].get_meta("duplicate"), "The first newly earned copy is new")
	assert_true(cards[1].get_meta("duplicate"), "Another copy in this bag is already collected")
	assert_true(cards[2].get_meta("duplicate"), "Previously owned cards remain duplicates")

func test_menu_explains_three_player_requirement_and_bags_show_per_card_odds() -> void:
	var menu_text: String = ""
	for label: Node in hud.get("_menu").find_children("*", "Label", true, false):
		menu_text += label.text + "\n"
	assert_true(menu_text.contains("3 players required to clear"))
	assert_true(menu_text.contains("Solo exploration welcome"))
	hud.show_game()
	hud.update_view(_state(), "crew_1", true)
	hud.show_cosmetics()
	assert_true(hud.get("_cosmetic_status").text.contains("Per card: Common 60% · Rare 28% · Epic 10% · Legendary 2%"))
	hud.hide_cosmetics()
	hud.update_view(_state(true), "crew_1", true)
	assert_true(hud.get("_reward_note").text.contains("Per card:"))
	_button("Open surprise bag").pressed.emit()
	assert_true(hud.get("_reward_note").text.contains("Per card:"))

func test_rarity_labels_and_foil_follow_authoritative_card_rarity() -> void:
	if not _ready_feature(): return
	for card_id: String in ["paint_mint", "gear_cap", "gear_sprout", "gear_crown"]:
		var data := _state(true)
		data.reward_cards = [card_id]
		data.reward_run_id = "run-" + card_id
		hud.show_game()
		hud.update_view(data, "crew_1", true)
		_button("Open surprise bag").pressed.emit()
		var card := _reward_buttons()[0]
		card.pressed.emit()
		var rarity: String = Cosmetics.card_info(card_id).rarity
		assert_eq(card.get_meta("rarity"), rarity)
		assert_eq(card.get_meta("foil"), rarity != "common")
		assert_eq(card.get_node_or_null("FoilShine") != null, rarity != "common", "Only uncommon cards draw the animated foil overlay")

func test_unconfirmed_save_has_no_bag_and_client_never_gets_host_navigation() -> void:
	if not _ready_feature(): return
	var data := _state(true)
	data.save_failed = true
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_false(_button("Open surprise bag").is_visible_in_tree())
	assert_false(hud.get("_reward_row").is_visible_in_tree())
	data.save_failed = false
	hud.update_view(data, "crew_1", false)
	_button("Open surprise bag").pressed.emit()
	assert_false(hud.get("_next_course").is_visible_in_tree())
	assert_false(hud.get("_restart").is_visible_in_tree())
	var can_leave: bool = false
	for button: Node in hud.get("_ending").find_children("*", "Button", true, false):
		if button.text == "Leave game" and button.is_visible_in_tree(): can_leave = true
	assert_true(can_leave)

func test_cosmetics_and_open_bag_fit_small_window_and_teamwork_copy_is_authoritative() -> void:
	if not _ready_feature(): return
	var data := _state()
	data.teamwork_text = "Bring both players to the finish"
	data.teamwork_hint = "Hold the bridge for your friend."
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	assert_eq(hud.get("_objective").text, data.teamwork_text)
	assert_eq(hud.get("_note").text, data.teamwork_hint)
	hud.call("show_cosmetics")
	await get_tree().process_frame
	await get_tree().process_frame
	for key: String in ["_cosmetic_panel", "_cosmetic_scroll"]:
		var control: Control = hud.get(key)
		assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(control.get_global_rect()), key + " fits the window")
	hud.call("hide_cosmetics")
	hud.update_view(_state(true), "crew_1", true)
	_button("Open surprise bag").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	for card: Button in _reward_buttons():
		assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(card.get_global_rect()), "Reward card fits the window")
	for key: String in ["_next_course", "_restart"]:
		assert_true(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(hud.get(key).get_global_rect()), "Completion action fits with open bag")
