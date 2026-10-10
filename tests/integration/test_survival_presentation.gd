extends GutTest

const HUD = preload("res://game/ui/hud.gd")
var hud: GameHUD

func before_each() -> void:
	hud = HUD.new()
	add_child_autofree(hud)
	hud.show_game()

func test_field_light_budget_shows_usable_night_seconds_and_expiry() -> void:
	var data: Dictionary = {"run":{"elapsed_s":120}, "lights":{"station_until":{"jetty":390,"reeds":240}}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Jetty 150s")
	data.run.elapsed_s = 400
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Jetty dark")
	data.lights.station_until.reeds = 490
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Reeds 90s")

func test_downed_crewmate_shows_distance_countdown_and_revive_progress() -> void:
	var data: Dictionary = {"run":{"players":{"crew_1":{},"crew_2":{"downed":true,"down_left":18}}},"poses":{"players":{"crew_1":{"position":Vector3.ZERO},"crew_2":{"position":Vector3(3,0,4)}}},"progression":{"profiles":{"crew_2":{"name":"Moss"}}},"rescue_progress":{"crew_1":{"target":"crew_2","held_s":1.5}}}
	hud.update_view(data,"crew_1","Hold E to revive")
	assert_string_contains(hud._crew_labels[1].text,"5m")
	assert_string_contains(hud._crew_labels[1].text,"18s")
	assert_string_contains(hud._context.text,"50%")
	assert_string_contains(hud._context.text,"Moss")

func test_supplies_and_throw_charge_do_not_claim_fish_value() -> void:
	var data: Dictionary = {"supplies":{"cell_1":{"state":"held","carrier_id":"crew_1"}},"throw_charge":0.75}
	hud.update_view(data,"crew_1","E feed the light · R set down")
	assert_string_contains(hud._equipment.text,"POWER CELL")
	assert_string_contains(hud._context.text,"75%")
	assert_false(hud._equipment.text.contains("WHOLE FISH"))

func test_being_carried_replaces_stale_cast_instructions() -> void:
	var data: Dictionary = {"run":{"players":{"crew_1":{"downed":true,"carried_by":"crew_2"}}},"progression":{"profiles":{"crew_2":{"name":"Moss"}}}}
	hud.update_view(data,"crew_1","LMB cast")
	assert_string_contains(hud._context.text,"Moss")
	assert_false(hud._context.text.contains("LMB cast"))

func test_trip_recap_reports_retreat_and_saved_rewards_without_safe_claim() -> void:
	var data: Dictionary = {"run":{"run_id":"r1","terminal":true},"progression":{"settled_run_ids":["r1"]},"trip_result":{"outcome":"retreat","banked":24,"new_species":2,"records":1,"lost_count":3,"next_goal":"Find the engine part at Tide Pools"}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._context.text,"Retreat")
	assert_string_contains(hud._equipment.text,"24")
	assert_string_contains(hud._equipment.text,"2 new")
	assert_string_contains(hud._equipment.text,"3 lost")
	assert_string_contains(hud._objective.text,"engine part")
	assert_false(hud._context.text.contains("Safe"))

func test_pending_save_does_not_show_uncommitted_trip_recap() -> void:
	var data: Dictionary = {"run":{"run_id":"r1","terminal":true},"trip_result":{"outcome":"refuge","banked":999,"new_species":2,"records":1,"lost_count":0,"next_goal":"Next"}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._context.text,"save pending")
	assert_false(hud._equipment.text.contains("999"))

func test_play_controls_fit_one_line_and_bottom_panel_leaves_world_visible() -> void:
	hud.update_view({},"crew_1","E open cache")
	await get_tree().process_frame
	assert_eq(hud._controls.text.count("\n"),0)
	var card: Control = hud._context.get_parent().get_parent()
	assert_lt(card.size.y,120.0)

func test_vote_explains_temporary_power_and_physical_cell_extension() -> void:
	hud.update_view({"run":{"elapsed_s":300},"choice":{"committed":"jetty"},"lights":{"station_until":{"jetty":390,"reeds":240}}},"crew_1","")
	assert_string_contains(hud._vote_status.text,"90s")
	assert_false(hud._vote_status.text.contains("for tonight"))

func test_collection_goal_remains_available_separately_after_an_escape() -> void:
	var state: Dictionary = Progression.blank_state()
	state.campaign_flags.escaped = true
	state.discoveries = ["penny_perch"]
	var status: Dictionary = CampaignRules.status(state)
	assert_string_contains(status.collection_objective,"Pebble Dab")
	assert_string_contains(status.collection_objective,"terraces")
	assert_false(status.collection_objective.contains("Continue Island"))
	state.discoveries = Species.catalog().keys()
	state.specimen_records.penny_perch = {"largest_size":1.23}
	status = CampaignRules.status(state)
	assert_string_contains(status.collection_objective,"Penny Perch")
	assert_string_contains(status.collection_objective,"1.23")

func test_menu_keeps_full_controls_in_accessible_help() -> void:
	hud.show_menu()
	assert_false(hud._menu_controls.visible)
	hud.toggle_panel("help")
	assert_eq(hud._panel_kind,"help")
	if hud._panels.has("help"):
		var text: String = str(hud._panels.help.get_child(0).text)
		assert_string_contains(text,"Right mouse")
		assert_string_contains(text,"carry")
		assert_string_contains(text,"revive")

func test_charge_shows_one_action_and_new_context_clears_threat_colour() -> void:
	hud.update_view({"hunter":"chase","hunter_target":"crew_1"},"crew_1","")
	hud.update_view({"throw_charge":0.5},"crew_1","E drop · P pack")
	assert_eq(hud._action_key.text,"Release LMB")
	assert_eq(hud._context.text,"throw 50%")
	assert_eq(hud._context.get_theme_color("font_color"),GameHUD.AMBER)

func test_stormwatch_lantern_displays_usable_seconds_and_actual_low_light_threshold() -> void:
	var data: Dictionary = {"progression":{"profiles":{"crew_1":{"lamp_id":"flood","outfit_id":"stormwatch"}}},"lights":{"batteries":{"crew_1":90.0}}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Flood 108s")
	data.progression.profiles.crew_1.lamp_id="surveyor"
	data.lights.batteries.crew_1=45.0
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Surveyor 54s")
	data.lights.batteries.crew_1=14.0
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"17s")
	assert_false(hud._equipment.text.contains("LOW LIGHT"))
	data.lights.batteries.crew_1=12.0
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"LOW LIGHT · 15s")
	data.lamp_enabled={"crew_1":false}
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._equipment.text,"Surveyor off · 15s")

