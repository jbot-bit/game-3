extends GutTest

const HUD = preload("res://game/ui/hud.gd")
var hud: GameHUD

func before_each() -> void:
	hud = HUD.new()
	add_child_autofree(hud)
	hud.show_game()

func _snapshot() -> Dictionary:
	return {"run":{"run_id":"fishing-feedback","players":{"crew_1":{}}},"progression":Progression.blank_state(),"cargo":{}}

func _land(data: Dictionary, id: String = "fishing-feedback:1", profile: String = "crew_1") -> void:
	data.progression.landed_catch_ids.append(id)
	data.progression.discoveries = ["bellgill"]
	data.progression.specimen_records.bellgill = {"count":1,"largest_size":1.37,"largest_catch_id":id}
	data.cargo[id] = {"state":"packed","pouch_profile_id":profile,"catch_record":{"catch_id":id,"profile_id":profile,"run_id":"fishing-feedback","species_id":"bellgill","trait_id":"moonlit","size":1.37,"catch_value":30}}

func test_fishing_shows_authoritative_tracking_and_one_catch_progress_bar() -> void:
	var state: Variant = hud.get("_fish_state")
	assert_not_null(state,"Fishing needs a readable action state, not bars alone")
	if state == null: return
	var data: Dictionary = _snapshot()
	data.fishing = {"crew_1":{"elapsed":0.4,"bar_position":0.5,"bar_width":0.34,"fish_position":0.5,"tracking":true,"progress":0.1}}
	hud.update_view(data,"crew_1","")
	assert_string_contains(state.text,"BITE")
	data.fishing.crew_1.elapsed = 2.0
	data.reel_active = true
	hud.update_view(data,"crew_1","")
	assert_string_contains(state.text,"ON TARGET")
	assert_eq(hud._fish_state.get_theme_color("font_color"),GameHUD.MINT)
	assert_almost_eq(hud._progress.value,0.1,0.001)
	data.fishing.crew_1.tracking = false
	data.fishing.crew_1.fish_position = 0.9
	hud.update_view(data,"crew_1","")
	assert_string_contains(state.text,"FOLLOW")
	assert_eq(hud._fish_state.get_theme_color("font_color"),GameHUD.AMBER)
	var visible_bars: int = 0
	for bar: Node in hud._fish_card.find_children("*","ProgressBar",true,false):
		if bar.is_visible_in_tree(): visible_bars += 1
	assert_eq(visible_bars,1,"Only catch progress belongs below the tracking rail")
	assert_string_contains(hud._fish_instruction.text,"Hold")
	assert_string_contains(hud._fish_instruction.text,"Release")
	assert_string_contains(hud._fish_instruction.text,"→")
	assert_string_contains(hud._fish_instruction.text,"←")
	assert_false(hud._fish_hint.text.to_lower().contains("tension"))
	assert_false(hud._fish_hint.text.to_lower().contains("opposite"))

func test_tracking_rail_smooths_snapshots_but_direction_feedback_is_immediate() -> void:
	var rail: Control = hud._fish_pull
	assert_true(rail.has_method("set_tracking"))
	assert_true(rail.has_method("set_input_direction"))
	if not rail.has_method("set_tracking") or not rail.has_method("set_input_direction"): return
	rail.set_tracking(0.4,0.34,0.5,true)
	rail.set_tracking(0.7,0.34,0.8,false)
	assert_almost_eq(float(rail.get("_shown_bar")),0.4,0.001,"New snapshots do not snap the window")
	rail._process(0.04)
	assert_gt(float(rail.get("_shown_bar")),0.4)
	assert_lt(float(rail.get("_shown_bar")),0.7)
	rail.set_input_direction(true)
	assert_true(rail.get("rightward"))
	rail.set_input_direction(false)
	assert_false(rail.get("rightward"))
	rail._process(0.06)
	assert_almost_eq(float(rail.get("_shown_bar")),0.7,0.001)
	assert_almost_eq(float(rail.get("_shown_fish")),0.8,0.001)
	assert_false(rail.get("tracking"),"Tracking result comes from authority, not smoothed geometry")

func test_fishing_window_fits_small_screens_and_leaves_rescue_action_clear() -> void:
	var old_size: Vector2i = get_tree().root.size
	var old_scale: Vector2i = get_tree().root.content_scale_size
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		get_tree().root.content_scale_size = size
		get_tree().root.size = size
		var data: Dictionary = _snapshot()
		data.fishing = {"crew_1":{"elapsed":2.0,"bar_position":0.5,"bar_width":0.34,"fish_position":0.5,"tracking":true,"progress":0.6}}
		hud.update_view(data,"crew_1","Hold E · revive Moss")
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(Rect2(Vector2.ZERO,Vector2(size)).encloses(hud._fish_card.get_global_rect()))
		assert_false(hud._fish_card.get_global_rect().intersects(hud._action_card.get_global_rect()))
		assert_gte(hud._fish_pull.size.x,450.0,"The tracking area must be readable")
		assert_lte(hud._fish_card.size.x,540.0)
	get_tree().root.content_scale_size = old_scale
	get_tree().root.size = old_size

func test_saved_local_catch_reveals_actual_specimen_and_saved_milestones() -> void:
	var card: Variant = hud.get("_catch_reveal")
	assert_not_null(card,"A landed local fish needs a catch reveal")
	if card == null: return
	var data: Dictionary = _snapshot()
	hud.update_view(data,"crew_1","")
	_land(data)
	watch_signals(hud)
	hud.update_view(data,"crew_1","")
	assert_true(card.visible)
	assert_string_contains(hud.get("_catch_name").text,"Bellgill")
	assert_string_contains(hud.get("_catch_details").text,"1.37 m")
	assert_string_contains(hud.get("_catch_details").text,"30 coins")
	assert_string_contains(hud.get("_catch_details").text,"Moonlit")
	assert_string_contains(hud.get("_catch_badges").text,"NEW SPECIES")
	assert_string_contains(hud.get("_catch_badges").text,"CREW RECORD")
	assert_string_contains(hud.get("_catch_destination").text,"unbanked")
	assert_signal_not_emitted(hud,"action_requested")

func test_joining_existing_saved_catches_does_not_replay_a_reveal() -> void:
	var card: Variant = hud.get("_catch_reveal")
	assert_not_null(card)
	if card == null: return
	var data: Dictionary = _snapshot()
	_land(data)
	hud.update_view(data,"crew_1","")
	assert_false(card.visible,"Joining must establish a baseline, not celebrate old cargo")

func test_other_crew_and_uncommitted_catches_do_not_claim_a_local_landing() -> void:
	var card: Variant = hud.get("_catch_reveal")
	assert_not_null(card)
	if card == null: return
	var data: Dictionary = _snapshot()
	hud.update_view(data,"crew_1","")
	_land(data,"fishing-feedback:1","crew_2")
	hud.update_view(data,"crew_1","")
	assert_false(card.visible)
	_land(data,"fishing-feedback:2")
	data.progression.landed_catch_ids.erase("fishing-feedback:2")
	hud.update_view(data,"crew_1","")
	assert_false(card.visible,"Failed specimen persistence must not celebrate a landed catch")

func test_duplicate_snapshot_does_not_restart_catch_reveal_or_award_old_badges() -> void:
	var card: Variant = hud.get("_catch_reveal")
	assert_not_null(card)
	if card == null: return
	var data: Dictionary = _snapshot()
	hud.update_view(data,"crew_1","")
	_land(data)
	hud.update_view(data,"crew_1","")
	hud.set("_catch_until",0.0)
	hud._process(0.01)
	hud.update_view(data,"crew_1","")
	assert_false(card.visible)
	_land(data,"fishing-feedback:2")
	data.progression.specimen_records.bellgill = {"count":2,"largest_size":1.37,"largest_catch_id":"fishing-feedback:1"}
	hud.update_view(data,"crew_1","")
	assert_true(card.visible)
	assert_false(hud.get("_catch_badges").text.contains("NEW SPECIES"))
	assert_false(hud.get("_catch_badges").text.contains("CREW RECORD"))

func test_rescue_interrupts_reveal_and_display_panels_never_capture_mouse() -> void:
	var card: Variant = hud.get("_catch_reveal")
	assert_not_null(card)
	if card == null: return
	var data: Dictionary = _snapshot()
	hud.update_view(data,"crew_1","")
	_land(data)
	hud.update_view(data,"crew_1","")
	data.rescue_progress = {"crew_1":{"target":"crew_2","held_s":1.5}}
	hud.update_view(data,"crew_1","Hold E · revive Moss")
	assert_false(card.visible)
	assert_string_contains(hud._context.text,"revive")
	for panel: Control in [card,hud._fish_card]:
		assert_eq(panel.mouse_filter,Control.MOUSE_FILTER_IGNORE)
		for control: Node in panel.find_children("*","Control",true,false):
			assert_eq(control.mouse_filter,Control.MOUSE_FILTER_IGNORE,"Feedback must not intercept cast/movement input")

func test_oversized_packed_fallback_reports_actual_pouch_instead_of_pickup() -> void:
	var data: Dictionary = _snapshot()
	hud.update_view(data,"crew_1","")
	_land(data)
	var record: Dictionary = data.cargo["fishing-feedback:1"].catch_record
	record.trait_id = "oversized"
	record.catch_value = 25
	var cargo := CargoRules.new()
	for index: int in range(3):
		var occupied: Dictionary = record.duplicate(true)
		occupied.catch_id = "capacity:" + str(index)
		cargo.register_catch(occupied,"whole")
	assert_eq(cargo.register_catch(record,"whole").code,"packed_fallback")
	data.cargo = cargo.snapshot()
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud.get("_catch_destination").text,"pouch")
	assert_false(hud.get("_catch_destination").text.contains("pick up"))
	assert_false(hud.get("_catch_destination").text.contains("for more"))

func test_reveal_tracks_current_custodian_and_dismisses_banked_or_lost_fish() -> void:
	var data: Dictionary = _snapshot()
	data.progression.profiles.crew_2.name = "Moss"
	hud.update_view(data,"crew_1","")
	_land(data)
	var entry: Dictionary = data.cargo["fishing-feedback:1"]
	entry.state = "whole_loose"
	entry.catch_record.trait_id = "oversized"
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud.get("_catch_destination").text,"pick up")
	entry.state = "whole_held"
	entry.carrier_id = "crew_2"
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud.get("_catch_destination").text,"Moss")
	assert_false(hud.get("_catch_destination").text.contains("pick up"))
	entry.state = "banked"
	hud.update_view(data,"crew_1","")
	assert_false(hud.get("_catch_reveal").visible)
	_land(data,"fishing-feedback:2")
	hud.update_view(data,"crew_1","")
	assert_true(hud.get("_catch_reveal").visible)
	data.cargo["fishing-feedback:2"].state = "lost"
	hud.update_view(data,"crew_1","")
	assert_false(hud.get("_catch_reveal").visible)
