extends GutTest

var hud: GameHUD
var original_size: Vector2i
var original_scale_size: Vector2i

func before_each() -> void:
	original_size = get_tree().root.size
	original_scale_size = get_tree().root.content_scale_size
	hud = GameHUD.new()
	add_child_autofree(hud)
	hud.show_game()

func after_each() -> void:
	get_tree().root.size = original_size
	get_tree().root.content_scale_size = original_scale_size

func _view(elapsed: float) -> Dictionary:
	return {"run":{"elapsed_s":elapsed,"phase":"day" if elapsed < 180 else "dusk" if elapsed < 240 else "night","players":{"crew_1":{}}},"progression":{"profiles":{"crew_1":{"name":"Harbour"}},"coins":12},"choice":{"open":true,"committed":""},"lights":{"batteries":{"crew_1":90},"station_until":{"jetty":240,"reeds":240}}}

func test_dusk_deadline_remains_visible_after_another_toast() -> void:
	var data: Dictionary = _view(195)
	data.choice = {"committed":"jetty"}
	data.lights.station_until.jetty = 390
	hud.update_view(data,"crew_1","")
	hud.toast("The default switch powered Jetty.")
	assert_true(hud._stats.is_visible_in_tree())
	assert_string_contains(hud._stats.text,"Night in 0:45")
	assert_true(hud._vote_notice.is_visible_in_tree())
	assert_string_contains(hud._vote_notice.text,"Jetty")
	assert_string_contains(hud._vote_notice.text,"Moth")

func test_choice_invitation_is_visible_before_lock_and_uses_remapped_key() -> void:
	var settings := SettingsLocal.new()
	settings.set_binding("vote",KEY_U)
	settings.set_value("reduced_effects",true)
	hud.configure_settings(settings)
	var data: Dictionary = _view(150)
	hud.update_view(data,"crew_1","")
	assert_true(hud._vote_notice.is_visible_in_tree())
	assert_string_contains(hud._vote_notice.text,"30s")
	assert_string_contains(hud._vote_notice.text,"dock battery")
	assert_string_contains(hud._vote_notice.text,"U")
	assert_false(hud.panel_open(),"Invitation must not open an obstructive ballot")
	data.run.elapsed_s = 179
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._vote_notice.text,"1s")
	data.run.elapsed_s = 180
	data.choice.committed = "reeds"
	data.lights.station_until.reeds = 390
	hud.update_view(data,"crew_1","")
	assert_false(hud._vote_notice.text.contains("choose"),"Do not invite a choice after it locks")

func test_empty_lantern_names_only_available_recharge_destinations() -> void:
	var data: Dictionary = _view(400)
	data.lights.batteries.crew_1 = 0
	data.lights.station_until = {"jetty":390,"reeds":460}
	hud.update_view(data,"crew_1","LMB · Cast")
	assert_true(hud._vote_notice.is_visible_in_tree())
	assert_string_contains(hud._vote_notice.text,"Lantern empty")
	assert_string_contains(hud._vote_notice.text,"Moth")
	assert_string_contains(hud._vote_notice.text,"Reeds")
	assert_false(hud._vote_notice.text.contains("Jetty"))
	data.lights.station_until.reeds = 400
	hud.update_view(data,"crew_1","")
	assert_string_contains(hud._vote_notice.text,"Moth")
	assert_false(hud._vote_notice.text.contains("Reeds"))
	data.lights.batteries.crew_1 = 90
	hud.update_view(data,"crew_1","")
	assert_false(hud._vote_notice.visible,"Recovery advice clears once recharged")

func test_threat_rescue_and_departure_take_priority_over_night_advice() -> void:
	var data: Dictionary = _view(400)
	data.lights.batteries.crew_1 = 0
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	hud.update_view(data,"crew_1","")
	assert_false(hud._vote_notice.visible)
	assert_string_contains(hud._context.text,"LIFEGUARD")
	data.erase("hunter")
	data.run.players.crew_2 = {"downed":true,"down_left":20}
	hud.update_view(data,"crew_1","Hold E · revive crewmate")
	assert_false(hud._vote_notice.visible)
	assert_string_contains(hud._context.text,"revive")
	data.run.players.erase("crew_2")
	data.run.crossing_left = 20
	hud.update_view(data,"crew_1","")
	assert_false(hud._vote_notice.visible)

func test_advice_yields_to_panel_and_catch_reveal() -> void:
	var data: Dictionary = _view(150)
	hud.update_view(data,"crew_1","")
	hud.toggle_panel("journal")
	hud.update_view(data,"crew_1","")
	assert_false(hud._vote_notice.visible)
	hud.toggle_panel("journal")
	data.progression.landed_catch_ids = ["night-ui:1"]
	data.cargo = {"night-ui:1":{"state":"packed","pouch_profile_id":"crew_1","catch_record":{"catch_id":"night-ui:1","profile_id":"crew_1","species_id":"bellgill","size":1.0,"catch_value":20}}}
	hud.update_view(data,"crew_1","")
	assert_true(hud._catch_reveal.visible)
	assert_false(hud._vote_notice.visible)

func test_compact_advice_fits_small_and_standard_viewports_without_guide_overlap() -> void:
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		get_tree().root.content_scale_size = size
		get_tree().root.size = size
		var data: Dictionary = _view(150)
		data.next_step = {"title":"Your first catch","detail":"Jetty · 19 m"}
		hud.update_view(data,"crew_1","")
		await get_tree().process_frame
		await get_tree().process_frame
		hud._process(0)
		assert_true(hud._vote_notice.is_visible_in_tree())
		assert_true(Rect2(Vector2.ZERO,Vector2(size)).encloses(hud._vote_notice.get_global_rect()))
		assert_false(hud._vote_notice.get_global_rect().intersects(hud._top_strip.get_global_rect()))
		assert_false(hud._next_step_card.visible,"One advisory at a time")
		assert_lte(hud._vote_notice.size.y,66.0,"Keep preparation advice compact")
