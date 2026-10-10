extends GutTest
var hud: GameHUD
var old_size: Vector2i
var old_scale: Vector2i

func before_each() -> void:
	old_size = get_tree().root.size
	old_scale = get_tree().root.content_scale_size
	hud = GameHUD.new()
	add_child_autofree(hud)
	hud.show_game()

func after_each() -> void:
	get_tree().root.size = old_size
	get_tree().root.content_scale_size = old_scale

func _shelter_view() -> Dictionary:
	return {
		"run":{"run_id":"shelter-test","elapsed_s":365.0,"phase":"night","players":{"crew_1":{}}},
		"progression":Progression.blank_state(),
		"lights":{"batteries":{"crew_1":90},"station_until":{"jetty":240,"reeds":390}},
		"safety":{"crew_1":{"shelter_id":"reeds","protected":true,"field_protected":true,"station_remaining":25.0,"shelter_distance":2.0,"moth_distance":59.1}},
		"cargo":{}}

func _land(data: Dictionary) -> void:
	data.progression.landed_catch_ids.append("shelter-test:1")
	data.cargo["shelter-test:1"] = {"state":"packed","pouch_profile_id":"crew_1","catch_record":{"catch_id":"shelter-test:1","profile_id":"crew_1","species_id":"bellgill","size":1.0,"catch_value":20}}

func test_expiry_countdown_survives_catch_toast_and_catch_reveal() -> void:
	var data: Dictionary = _shelter_view()
	hud.update_view(data,"crew_1","")
	_land(data)
	hud.update_view(data,"crew_1","")
	hud.toast("Bellgill packed. Bank it at Moth.")
	assert_true(hud._catch_reveal.visible)
	assert_true(hud._vote_notice.is_visible_in_tree())
	assert_string_contains(hud._vote_notice.text,"25s")
	assert_string_contains(hud._vote_notice.text,"Reeds")
	assert_string_contains(hud._vote_notice.text,"Moth")
	assert_string_contains(hud._vote_notice.text,"60 m away")
	hud._toast_until = 0
	hud._process(0)
	assert_true(hud._vote_notice.is_visible_in_tree(),"The warning persists after the toast expires")

func test_active_chase_reports_existing_cover_instead_of_ordering_a_flee() -> void:
	var data: Dictionary = _shelter_view()
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	hud.update_view(data,"crew_1","")
	assert_true(hud._vote_notice.visible)
	assert_string_contains(hud._context.text,"Safe here")
	assert_string_contains(hud._context.text,"Reeds")
	assert_string_contains(hud._context.text,"25s")
	assert_false(hud._context.text.contains("run to a lit"))
	data.safety.crew_1.shelter_id = "boat"
	data.safety.crew_1.moth_distance = 2.0
	hud.update_view(data,"crew_1","E · Bank catch")
	assert_string_contains(hud._context.text,"Protected at Moth")
	assert_false(hud._context.text.contains("run"))

func test_expiry_immediately_replaces_safe_claim_with_moth_destination() -> void:
	var data: Dictionary = _shelter_view()
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	hud.update_view(data,"crew_1","")
	data.run.elapsed_s = 390.0
	data.safety.crew_1.protected = false
	data.safety.crew_1.field_protected = false
	data.safety.crew_1.station_remaining = 0.0
	hud.update_view(data,"crew_1","")
	assert_true(hud._vote_notice.visible)
	assert_string_contains(hud._context.text.to_lower(),"dark")
	assert_string_contains(hud._context.text,"Moth")
	assert_string_contains(hud._context.text,"60 m away")
	assert_false(hud._context.text.contains("Safe"))
	assert_false(hud._context.text.contains("lit shelter"))

func test_nearby_light_does_not_claim_protection_outside_its_safe_radius() -> void:
	var data: Dictionary = _shelter_view()
	data.safety.crew_1.protected = false
	data.safety.crew_1.field_protected = false
	data.safety.crew_1.shelter_distance = 8.0
	hud.update_view(data,"crew_1","")
	assert_true(hud._vote_notice.visible)
	assert_string_contains(hud._vote_notice.text,"25s")
	assert_false(hud._vote_notice.text.contains("Safe here"))
	assert_false(hud._vote_notice.text.contains("Protected"))

func test_temporary_protection_never_claims_a_dark_station_is_safe() -> void:
	var data: Dictionary = _shelter_view()
	data.run.elapsed_s = 400.0
	data.safety.crew_1.field_protected = false
	data.safety.crew_1.station_remaining = 0.0
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._context.text,"Protected for now")
	assert_false(hud._context.text.contains("Safe here"))
	assert_string_contains(hud._vote_notice.text.to_lower(),"reeds dark")

func test_chase_outside_powered_shelter_directs_player_into_its_light() -> void:
	var data: Dictionary = _shelter_view()
	data.safety.crew_1.protected = false
	data.safety.crew_1.field_protected = false
	data.safety.crew_1.shelter_distance = 9.0
	hud.update_view(data,"crew_1","LMB · Cast")
	var ordinary_advice: String = hud._vote_notice.text
	for threat: String in ["warn","chase"]:
		data.hunter = threat
		data.hunter_target = "crew_1"
		hud.update_view(data,"crew_1","LMB · Cast")
		assert_string_contains(hud._context.text,"LIFEGUARD NEAR")
		assert_string_contains(hud._context.text,"move inside Reeds light")
		assert_string_contains(hud._context.text,"25s")
		assert_false(hud._context.text.contains("Safe here"))
		assert_eq(hud._vote_notice.text,ordinary_advice,"The countdown advice remains independent of danger context")

func test_rescue_downed_carry_panel_and_departure_keep_priority() -> void:
	for state: String in ["downed","carried","rescue","panel","departing"]:
		var data: Dictionary = _shelter_view()
		match state:
			"downed":
				data.run.players.crew_1.downed = true
				data.hunter = "chase"
				data.hunter_target = "crew_1"
			"carried": data.run.players.crew_1.carried_by = "crew_2"
			"rescue": data.rescue_progress = {"crew_1":{"target":"crew_2","held_s":1.0}}
			"panel": hud.toggle_panel("journal")
			"departing": data.run.crossing_left = 20.0
		hud.update_view(data,"crew_1","CALL FOR HELP" if state == "downed" else "")
		assert_false(hud._vote_notice.visible,state)
		if state == "downed": assert_eq(hud._context.text,"CALL FOR HELP")
		if state == "panel": hud.toggle_panel("journal")

func test_moth_protection_preserves_real_escape_and_ready_guidance() -> void:
	var data: Dictionary = _shelter_view()
	data.safety.crew_1.shelter_id = "boat"
	data.progression.banked_catch_ids = ["banked"]
	data.progression.repairs = {"moth_engine":true,"beacon":true}
	var surroundings: Dictionary = {"position":Vector3.ZERO,"markers":{"boat":Vector3.ZERO},"interact":"E","ready":"B"}
	for signalled: bool in [false,true]:
		data.escape = {"can_arm":not signalled,"signalled":signalled}
		data.next_step = preload("res://game/ui/outing_guide.gd").next_step(data,"crew_1",surroundings)
		hud.update_view(data,"crew_1","B · Ready to escape" if signalled else "E · Prepare the night escape")
		assert_true(hud._next_step_card.visible)
		assert_false(hud._vote_notice.visible)
		assert_eq(hud._next_step_title.text,"Bring everyone home" if signalled else "Prepare the night escape")
		assert_string_contains(hud._field_status.text,"Protected at Moth")
		assert_string_contains(hud._context.text,"escape")

func test_low_light_advice_and_catch_never_overlap_at_supported_resolutions() -> void:
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		get_tree().root.size = size
		get_tree().root.content_scale_size = size
		var data: Dictionary = _shelter_view()
		data.run.run_id = str(size.x)
		hud.update_view(data,"crew_1","")
		_land(data)
		hud.update_view(data,"crew_1","")
		hud.toast("A new catch is packed. Bank it at Moth.")
		await get_tree().process_frame
		await get_tree().process_frame
		hud._process(0)
		assert_true(hud._vote_notice.is_visible_in_tree())
		assert_false(hud._vote_notice.get_global_rect().intersects(hud._catch_reveal.get_global_rect()))
		assert_false(hud._vote_notice.get_global_rect().intersects(hud._toast_card.get_global_rect()))
		for control: Control in [hud._vote_notice,hud._catch_reveal,hud._toast_card]:
			assert_true(Rect2(Vector2.ZERO,Vector2(size)).encloses(control.get_global_rect()))
