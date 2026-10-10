extends GutTest
const HUD = preload("res://game/ui/hud.gd")
var hud: GameHUD

func before_each() -> void:
	hud=HUD.new()
	add_child_autofree(hud)
	hud.show_game()

func test_connection_details_live_in_pause_instead_of_gameplay() -> void:
	hud.update_view({"is_host":true,"host_addresses":["192.168.1.20"]},"crew_1","")
	assert_false(hud._host_address.is_visible_in_tree())
	hud.toggle_panel("pause")
	assert_true(hud._host_address.is_visible_in_tree())
	assert_string_contains(hud._host_address.text,"192.168.1.20")
	hud.update_view({"is_host":false},"crew_2","")
	assert_false(hud._host_address.visible)

func test_crew_pills_preserve_urgent_status_without_showing_empty_slots() -> void:
	hud.update_view({"run":{"players":{"crew_1":{},"crew_2":{"downed":true,"down_left":15}}},"progression":{"profiles":{"crew_1":{"name":"Harbour"},"crew_2":{"name":"Moss"}}},"poses":{"players":{"crew_1":{"position":Vector3.ZERO},"crew_2":{"position":Vector3(0,0,5)}}}},"crew_1","")
	await get_tree().process_frame
	assert_false(hud._crew_labels[2].get_parent().visible)
	assert_lt(hud._crew_labels[0].get_parent().size.y,56.0)
	assert_string_contains(hud._crew_labels[1].text,"HELP")
	assert_string_contains(hud._crew_labels[1].text,"5m")
	assert_string_contains(hud._crew_labels[1].text,"15s")

func test_play_screen_keeps_only_context_and_status_at_the_bottom() -> void:
	hud.update_view({"lights":{"station_until":{"jetty":390,"reeds":240}},"run":{"elapsed_s":300}},"crew_1","E · feed the Jetty light")
	await get_tree().process_frame
	assert_false(hud._controls.visible)
	assert_lt(hud._context.get_parent().get_parent().size.y,90.0)
	assert_string_contains(hud._equipment.text,"Jetty 90s")
	for label: Node in hud._game.find_children("*","Label",true,false):
		assert_false(str(label.text).contains("ONE MORE CAST  /"))

func test_workshop_outfits_follow_unlocks_and_emit_one_equip_action() -> void:
	var buttons: Variant = hud.get("_outfit_buttons")
	assert_true(buttons is Dictionary)
	if not buttons is Dictionary: return
	hud.update_view({"progression":{"profiles":{"crew_1":{"outfit_id":"harbour"}}}},"crew_1","")
	assert_eq(buttons.size(),4)
	assert_true(buttons.harbour.disabled)
	assert_true(buttons.angler.disabled)
	assert_true(buttons.deckhand.disabled)
	assert_true(buttons.stormwatch.disabled)
	hud.update_view({"progression":{"discoveries":["penny_perch","bellgill"],"repairs":{"return_walkway":true},"profiles":{"crew_1":{"outfit_id":"harbour"}}}},"crew_1","")
	assert_false(buttons.angler.disabled)
	assert_false(buttons.deckhand.disabled)
	assert_true(buttons.stormwatch.disabled)
	watch_signals(hud)
	buttons.angler.pressed.emit()
	assert_signal_emitted_with_parameters(hud,"action_requested",["equip_outfit",{"outfit_id":"angler"}])

func test_pause_actions_fit_without_scrolling_past_leave() -> void:
	hud.update_view({"is_host":true,"run":{"paused":true},"host_addresses":["192.168.1.20"]},"crew_1","")
	hud.toggle_panel("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(hud._panels.pause.size.y,hud._panel_scroll.size.y)
