extends GutTest

class CountingHUD:
	extends GameHUD
	var journal_refreshes: int=0
	var workshop_refreshes: int=0
	func _update_journal(saved: Dictionary) -> void:
		journal_refreshes+=1
		super._update_journal(saved)
	func _update_workshop(saved: Dictionary,profile: Dictionary) -> void:
		workshop_refreshes+=1
		super._update_workshop(saved,profile)

var hud: CountingHUD
func before_each() -> void:
	hud=CountingHUD.new()
	add_child_autofree(hud)

func test_host_and_join_are_separate_menu_flows() -> void:
	assert_true(hud.has_method("show_menu_flow"))
	if not hud.has_method("show_menu_flow"): return
	watch_signals(hud)
	hud.show_menu_flow("host")
	assert_true(hud._menu_name.is_visible_in_tree())
	assert_false(hud._address.is_visible_in_tree())
	assert_signal_not_emitted(hud,"host_requested")
	hud.show_menu_flow("join")
	assert_true(hud._address.is_visible_in_tree())
	assert_false(hud._menu_name.is_visible_in_tree())
	assert_signal_not_emitted(hud,"join_requested")

func test_quiet_play_screen_hides_generic_objective_and_empty_action() -> void:
	hud.show_game()
	hud.update_view({"campaign":{"objective":"Bring the lens to the beacon"}},"crew_1","")
	assert_false(hud._objective.is_visible_in_tree())
	assert_false(hud._context.get_parent().get_parent().is_visible_in_tree())
	hud.update_view({},"crew_1","E · bank your catch")
	await get_tree().process_frame
	assert_true(hud._context.is_visible_in_tree())
	assert_lt(hud._context.get_parent().get_parent().size.x,760.0)

func test_unchanged_progress_does_not_rebuild_hidden_catalogs() -> void:
	hud.show_game()
	var data: Dictionary={"progression":Progression.blank_state()}
	for i: int in range(20):
		data.run={"elapsed_s":float(i)}
		hud.update_view(data,"crew_1","")
	assert_eq(hud.journal_refreshes,1)
	assert_eq(hud.workshop_refreshes,1)
	data.progression.revision=1
	hud.update_view(data,"crew_1","")
	assert_eq(hud.journal_refreshes,2)

func test_debug_overlay_is_optional_and_never_invents_rtt() -> void:
	assert_true(hud.has_method("toggle_debug"))
	if not hud.has_method("toggle_debug"): return
	assert_false(hud.debug_enabled)
	hud.toggle_debug()
	hud.update_debug({"fps":72.0,"frame_ms":13.9,"role":"host","draw_calls":88,"objects":33,"primitives":2400})
	assert_true(hud.debug_enabled)
	assert_string_contains(hud._debug_text.text,"72 FPS")
	assert_string_contains(hud._debug_text.text,"13.9 ms")
	assert_string_contains(hud._debug_text.text,"88 draws")
	assert_false(hud._debug_text.text.contains("RTT"))
	hud.update_debug({"fps":60,"frame_ms":16.7,"role":"client","rtt_ms":3.2})
	assert_string_contains(hud._debug_text.text,"3.2 ms RTT")
	hud.toggle_debug()
	assert_false(hud.debug_enabled)

func test_workshop_tabs_keep_one_small_choice_group_visible() -> void:
	assert_true(hud.has_method("_workshop_page"))
	if not hud.has_method("_workshop_page"): return
	hud.show_game()
	hud.update_view({"progression":Progression.blank_state()},"crew_1","")
	hud.toggle_panel("workshop")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hud._workshop_pages.gear.is_visible_in_tree())
	assert_false(hud._workshop_pages.make.is_visible_in_tree())
	assert_false(hud._workshop_pages.crew.is_visible_in_tree())
	assert_lte(hud._panels.workshop.size.y,hud._panel_scroll.size.y,"Default gear choices fit without scrolling")
	watch_signals(hud)
	hud._workshop_page("crew")
	assert_true(hud._profile_name.is_visible_in_tree())
	assert_false(hud._outfit_grid.is_visible_in_tree())
	assert_signal_not_emitted(hud,"action_requested")

func test_journal_selects_one_fish_without_a_catalog_wall() -> void:
	var picker: Variant=hud.get("_journal_species")
	assert_not_null(picker)
	if picker==null: return
	hud.update_view({"progression":Progression.blank_state()},"crew_1","")
	assert_eq(picker.item_count,Species.catalog().size())
	assert_lt(hud._journal.text.length(),480)
	for i: int in range(picker.item_count):
		picker.select(i)
		hud._update_journal(hud._data.progression)
		var metadata: Dictionary=Species.catalog()[str(picker.get_item_metadata(i))]
		assert_string_contains(hud._journal.text,metadata.name)
		assert_string_contains(hud._journal.text,metadata.habitat_hint)

func test_home_secondary_links_have_clickable_text_width() -> void:
	hud.show_menu_flow("home")
	await get_tree().process_frame
	for node: Node in hud._menu.find_children("*","Button",true,false):
		if node.text in ["Settings","Help"]:
			assert_gt(node.size.x,35.0,"Secondary menu link must not collapse in its row")
