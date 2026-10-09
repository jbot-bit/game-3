extends GutTest

const HUD = preload("res://game/ui/hud.gd")
const SpeciesModel = preload("res://game/fishing/species.gd")
const Settings = preload("res://game/ui/settings_local.gd")
const Gear = preload("res://game/progression/equipment.gd")
const Recipes = preload("res://game/progression/crafting.gd")
var hud: GameHUD
var settings_path: String

func before_each() -> void:
	hud = HUD.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	settings_path = "user://tests/hud_settings_" + str(Time.get_ticks_usec()) + ".json"
	hud.configure_settings(Settings.new(settings_path))
	add_child_autofree(hud)
	await get_tree().process_frame
	hud.show_game()

func after_each() -> void:
	if FileAccess.file_exists(settings_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))

func test_journal_includes_every_catalog_species_and_habitat_hint() -> void:
	hud.update_view({}, "crew_1", "")
	for metadata: Dictionary in SpeciesModel.catalog().values():
		assert_string_contains(hud._journal.text, metadata.name)
		if metadata.has("habitat_hint"): assert_string_contains(hud._journal.text, metadata.habitat_hint)
	assert_string_contains(hud._journal.text, "BASE CHANCES")

func test_workshop_contains_entire_equipment_and_recipe_catalogs() -> void:
	hud.update_view({}, "crew_1", "")
	for id: String in Gear.rods_all(): assert_true(hud._gear_buttons.has(id), id)
	for id: String in Gear.lamps_all(): assert_true(hud._gear_buttons.has(id), id)
	assert_eq(hud._recipe_buttons.size(), Recipes.recipes_all().size())

func test_completed_campaign_does_not_reopen_ending_during_continued_island() -> void:
	hud.update_view({"is_host": true, "campaign": {"completed": true}, "escape": {"completed": false}}, "crew_1", "")
	assert_false(hud.panel_open())

func test_campaign_objective_and_requirements_come_from_server_status() -> void:
	var status: Dictionary = {"title": "Light the beacon", "objective": "Bring a lens to the north ridge", "repair_id": "beacon", "completed": false, "repairs": [{"id": "beacon", "name": "Beacon", "complete": false, "requirements": "45 coins + keeper lens", "location": "North ridge"}], "tools": {}}
	hud.update_view({"campaign": status, "escape": {"description": "Visit Moth after dark", "can_arm": false, "can_signal": false}}, "crew_1", "")
	var objective: Label = hud.get("_objective")
	assert_not_null(objective)
	if objective == null: return
	assert_string_contains(objective.text, status.objective)
	var details: Label = hud.get("_campaign_details")
	assert_string_contains(details.text, "45 coins + keeper lens")
	assert_string_contains(details.text, "North ridge")

func test_ending_continue_is_only_available_to_host_and_escape_respects_snapshot() -> void:
	hud.update_view({"is_host": false, "campaign": {"completed": true}, "escape": {"completed": true}}, "crew_2", "")
	var continue_button: Button = hud.get("_continue_island")
	assert_not_null(continue_button)
	if continue_button == null: return
	assert_true(continue_button.disabled)
	assert_eq(hud._panel_kind, "ending")
	hud.update_view({"is_host": true, "campaign": {"completed": true}, "escape": {"completed": true}}, "crew_1", "")
	assert_false(continue_button.disabled)
	watch_signals(hud)
	continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "action_requested", ["continue_island", {}])

func test_new_island_requires_explicit_confirmation() -> void:
	assert_true(hud.has_method("request_new_island"))
	if not hud.has_method("request_new_island"): return
	watch_signals(hud)
	hud.show_menu()
	hud.call("request_new_island")
	assert_signal_not_emitted(hud, "new_island_requested")
	var confirmation: ConfirmationDialog = hud.get("_new_island_confirmation")
	assert_true(confirmation.visible)
	confirmation.confirmed.emit()
	assert_signal_emitted_with_parameters(hud, "new_island_requested", ["Angler"])

func test_completed_escape_keeps_return_to_ending_available_after_browsing() -> void:
	hud.update_view({"is_host": true, "escape": {"completed": true}}, "crew_1", "")
	hud.toggle_panel("journal")
	var return_button: Button = hud.get("_return_to_ending")
	assert_not_null(return_button)
	if return_button == null: return
	assert_true(return_button.is_visible_in_tree())
	return_button.pressed.emit()
	assert_eq(hud._panel_kind, "ending")

func test_final_crossing_and_ending_do_not_promise_automatic_dawn() -> void:
	hud.update_view({"run": {"phase": "escape", "crossing_left": 7}, "escape": {"departing": true}}, "crew_1", "")
	assert_string_contains(hud._context.text, "outer channel")
	hud.update_view({"run": {"phase": "escape", "terminal": true, "run_id": "final"}, "progression": {"settled_run_ids": ["final"]}, "escape": {"completed": true}}, "crew_1", "")
	assert_string_contains(hud._context.text, "Continue Island")
	assert_false(hud._context.text.contains("Dawn"))

func test_settings_and_binding_widgets_do_not_send_network_intents() -> void:
	assert_true(hud.has_signal("settings_changed"))
	if not hud.has_signal("settings_changed"): return
	assert_true(hud._panels.has("settings"))
	watch_signals(hud)
	hud.call("_set_local_setting", "invert_y", true)
	assert_signal_emitted(hud, "settings_changed")
	assert_signal_not_emitted(hud, "action_requested")

func test_recipe_and_gear_buttons_emit_the_selected_ids() -> void:
	watch_signals(hud)
	hud._recipe_buttons.braced_reel.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "action_requested", ["craft", {"recipe_id": "braced_reel"}])
	hud._gear_buttons.drift_rod.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "action_requested", ["equip_rod", {"rod_id": "drift_rod"}])

func test_escape_actions_and_locked_alternate_tool_follow_status() -> void:
	hud.update_view({"escape": {"can_arm": true, "can_signal": false}, "campaign": {"tools": {"scout": {"name": "Trail Mark", "unlocked": false}}}}, "crew_1", "")
	assert_false(hud._arm_escape.disabled)
	assert_true(hud._signal_escape.disabled)
	assert_true(hud._alternate_tool.disabled)
	hud.update_view({"escape": {"can_arm": false, "can_signal": true}, "campaign": {"tools": {"scout": {"name": "Trail Mark", "unlocked": true}}}}, "crew_1", "")
	assert_true(hud._arm_escape.disabled)
	assert_false(hud._signal_escape.disabled)
	assert_false(hud._alternate_tool.disabled)
	watch_signals(hud)
	hud._alternate_tool.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "action_requested", ["set_tool", {"mode": "alternate"}])

func test_remapped_keys_appear_in_game_and_fishing_help() -> void:
	hud._settings.set_binding("move_right", KEY_L)
	hud._settings.set_binding("interact", KEY_Z)
	hud.update_view({"fishing": {"crew_1": {"pull": -1.0}}}, "crew_1", "")
	assert_string_contains(hud._controls.text, "Z interact")
	assert_string_contains(hud._fish_hint.text, "LEFT · hold L")

func test_switching_from_host_pause_to_settings_keeps_island_paused_until_close() -> void:
	hud.update_view({"is_host": true}, "crew_1", "")
	watch_signals(hud)
	hud.toggle_panel("pause")
	hud.toggle_panel("settings")
	assert_eq(get_signal_emit_count(hud, "action_requested"), 1)
	assert_signal_emitted_with_parameters(hud, "action_requested", ["pause", {"paused": true}])
	hud._close_panel()
	assert_signal_emitted_with_parameters(hud, "action_requested", ["pause", {"paused": false}])
