extends GutTest

const Guide = preload("res://game/ui/outing_guide.gd")

func view() -> Dictionary:
	return {"run": {"phase": "day", "players": {"crew_1": {}}}, "progression": Progression.blank_state(), "cargo": {}}

func surroundings(habitat: String = "") -> Dictionary:
	return {"position": Vector3.ZERO, "habitat": habitat, "interact": "Z", "workshop": "X", "ready": "V", "markers": {"jetty": Vector3(0,0,18), "boat": Vector3(10,0,0), "rod_cache": Vector3(0,0,25), "engine_cache": Vector3(0,0,40), "beacon_parts_cache": Vector3(0,0,60), "beacon_repair": Vector3(0,0,55), "engine_repair": Vector3(10,0,0)}}

func beyond_first_catch() -> Dictionary:
	var data: Dictionary = view()
	data.progression.banked_catch_ids = ["saved_catch"]
	data.progression.owned_rods.append("soft_tip")
	data.progression.profiles.crew_1.rod_id = "soft_tip"
	return data

func packed(profile: String, species: String = "penny_perch") -> Dictionary:
	return {"state": "packed", "pouch_profile_id": profile, "catch_record": {"profile_id": profile, "species_id": species, "trait_id": "none"}}

func test_first_visit_points_to_water_then_teaches_casting_at_any_habitat() -> void:
	assert_string_contains(Guide.next_step(view(), "crew_1", surroundings()).detail, "18 m")
	assert_string_contains(Guide.next_step(view(), "crew_1", surroundings("tidepools")).detail, "LMB")
	assert_false(Guide.next_step(view(), "crew_1", surroundings("tidepools")).detail.contains("Jetty"))

func test_only_local_pouch_or_carried_fish_prompts_banking() -> void:
	var data: Dictionary = view()
	data.cargo.fish = {"state": "packed", "pouch_profile_id": "crew_2", "catch_record": {"profile_id": "crew_2"}}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "Your first catch")
	data.cargo.fish.pouch_profile_id = "crew_1"
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "Bring it home")
	data.cargo.fish = {"state": "whole_held", "carrier_id": "crew_1", "catch_record": {"profile_id": "crew_2"}}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "Bring it home")

func test_loose_catch_teaches_pickup_with_actual_remapped_key() -> void:
	var data: Dictionary = view()
	data.cargo.fish = {"state": "whole_loose", "catch_record": {"profile_id": "crew_1"}}
	assert_string_contains(Guide.next_step(data, "crew_1", surroundings()).detail, "Z")
	data.cargo.fish.state = "lost"
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "Your first catch")

func test_bank_guidance_uses_interact_key_only_in_banking_range() -> void:
	var data: Dictionary = view()
	data.cargo.fish = {"state": "packed", "pouch_profile_id": "crew_1"}
	var nearby: Dictionary = surroundings()
	nearby.position = Vector3(9,0,0)
	assert_string_contains(Guide.next_step(data, "crew_1", nearby).detail, "Z")
	assert_string_contains(Guide.next_step(data, "crew_1", surroundings()).detail, "10 m")

func test_first_bank_can_suggest_the_rod_but_owned_gear_never_blocks_campaign() -> void:
	var data: Dictionary = view()
	data.progression.banked_catch_ids = ["saved_catch"]
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "A better rod awaits")
	data.progression.owned_rods.append("soft_tip")
	var nearby: Dictionary = surroundings()
	nearby.workshop = "X"
	var found: Dictionary = Guide.next_step(data, "crew_1", nearby)
	assert_eq(found.get("marker", ""), "beacon_parts_cache")
	nearby.position = Vector3(9,0,0)
	assert_string_contains(str(Guide.next_step(data, "crew_1", nearby).get("detail", "")), "X")
	for rod: String in ["soft_tip", "braced_reel", "drift_rod"]:
		data.progression.profiles.crew_1.rod_id = rod
		assert_eq(Guide.next_step(data, "crew_1", nearby).get("marker", ""), "beacon_parts_cache", "Continue toward escape with any chosen rod")
	data.progression.profiles.crew_1.rod_id = "starter"
	data.progression.profiles.crew_2.rod_id = "soft_tip"
	assert_eq(Guide.next_step(data, "crew_1", nearby).get("marker", ""), "beacon_parts_cache", "Keeping Starter is a valid choice")

func test_fishing_rescue_pause_and_departure_take_priority() -> void:
	for change: Dictionary in [{"paused": true}, {"terminal": true}, {"crossing_left": 8.0}]:
		var data: Dictionary = view()
		data.run.merge(change, true)
		assert_eq(Guide.next_step(data, "crew_1", surroundings()), {})
	var data: Dictionary = view()
	data.run.players.crew_2 = {"downed": true}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()), {})
	data = view()
	data.fishing = {"crew_1": {"progress": 0.2}}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()), {})
	data = view()
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	assert_eq(Guide.next_step(data, "crew_1", surroundings()), {})

func test_guidance_does_not_mutate_saved_state() -> void:
	var data: Dictionary = view()
	var before: Dictionary = data.duplicate(true)
	Guide.next_step(data, "crew_1", surroundings())
	assert_eq(data, before)

func test_reeds_shelter_and_occupied_hands_never_advertise_an_invalid_cast() -> void:
	var nearby: Dictionary = surroundings("reeds")
	nearby.markers.reeds = Vector3.ZERO
	assert_false(Guide.next_step(view(), "crew_1", nearby).detail.contains("LMB"))
	nearby.position = Vector3(0,0,9)
	assert_string_contains(Guide.next_step(view(), "crew_1", nearby).detail, "LMB")
	var data: Dictionary = view()
	data.supplies = {"cell": {"state":"held", "carrier_id":"crew_1"}}
	assert_eq(Guide.next_step(data, "crew_1", nearby), {})

func test_equipping_a_rod_transitions_to_a_real_named_essential_cache() -> void:
	var data: Dictionary = beyond_first_catch()
	var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
	assert_eq(step.get("marker", ""), "beacon_parts_cache")
	assert_eq(step.get("action", ""), "open_cache")
	assert_eq(step.get("payload", {}).get("cache_id", ""), "beacon_parts_cache")
	assert_string_contains(str(step.get("title", "")), "Beacon coil")
	assert_string_contains(str(step.get("detail", "")), "60 m")
	var nearby: Dictionary = surroundings()
	nearby.position = nearby.markers.beacon_parts_cache
	assert_string_contains(str(Guide.next_step(data, "crew_1", nearby).get("detail", "")), "Z")

func test_a_known_essential_part_takes_priority_even_if_starter_and_rod_cache_skipped() -> void:
	var data: Dictionary = view()
	data.progression.banked_catch_ids = ["saved_catch"]
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 80
	var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
	assert_eq(step.get("action", ""), "repair")
	assert_eq(step.get("payload", {}).get("repair_id", ""), "moth_engine")

func test_repair_guidance_supports_either_order_and_uses_the_remapped_interact_key() -> void:
	for order: Array in [["moth_engine", "engine_part", "beacon", "beacon_parts_cache"], ["beacon", "beacon_coil", "moth_engine", "engine_cache"]]:
		var data: Dictionary = beyond_first_catch()
		data.progression.coins = 120
		data.progression.campaign_flags[order[1]] = true
		var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
		assert_eq(step.get("payload", {}).get("repair_id", ""), order[0])
		var nearby: Dictionary = surroundings()
		nearby.position = nearby.markers.get(step.get("marker", ""), Vector3.ZERO)
		assert_string_contains(str(Guide.next_step(data, "crew_1", nearby).get("detail", "")), "Z")
		data.progression.repairs[order[0]] = true
		var after: Dictionary = Guide.next_step(data, "crew_1", surroundings())
		assert_eq(after.get("marker", ""), order[3], "Next essential part after either first repair")

func test_local_pouch_plus_shared_coins_prompts_banking_when_it_funds_the_goal() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 70
	data.cargo.mine = packed("crew_1") # 10 coins, exactly enough for the 80-coin engine.
	var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
	assert_eq(step.get("action", ""), "bank")
	assert_eq(step.get("marker", ""), "boat")
	assert_string_contains(str(step.get("detail", "")), "10 m")
	var nearby: Dictionary = surroundings()
	nearby.position = nearby.markers.boat
	assert_string_contains(str(Guide.next_step(data, "crew_1", nearby).get("detail", "")), "Z")

func test_other_players_cargo_and_unbankable_states_do_not_promise_local_funding() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 70
	for cargo_state: String in ["packed", "whole_loose", "bank_pending", "banked", "lost"]:
		data.cargo.fish = packed("crew_2" if cargo_state == "packed" else "crew_1")
		data.cargo.fish.state = cargo_state
		var step: Dictionary = Guide.next_step(data, "crew_1", surroundings("jetty"))
		assert_ne(step.get("action", ""), "bank", cargo_state)
		assert_string_contains(str(step.get("detail", "")), "10", cargo_state)
		assert_string_contains(str(step.get("detail", "")).to_lower(), "bank", cargo_state)

func test_whole_fish_funding_uses_canonical_delivery_bonus_and_current_carrier() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 60
	data.cargo.big = {"state": "whole_held", "carrier_id": "crew_1", "catch_record": {"profile_id": "crew_2", "species_id": "penny_perch", "trait_id": "oversized", "catch_value": 12}}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).get("action", ""), "bank", "Whole delivery is worth 20, not the packed 12")
	data.cargo.big.carrier_id = "crew_2"
	assert_ne(Guide.next_step(data, "crew_1", surroundings()).get("action", ""), "bank")

func test_a_held_whole_fish_is_banked_even_if_it_cannot_fully_fund_the_repair() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.campaign_flags.engine_part = true
	data.cargo.big = {"state": "whole_held", "carrier_id": "crew_1", "catch_record": {"profile_id": "crew_1", "species_id": "penny_perch", "trait_id": "oversized"}}
	assert_eq(Guide.next_step(data, "crew_1", surroundings("jetty")).get("action", ""), "bank", "Full hands cannot follow a cast instruction")

func test_night_guidance_still_yields_to_immediate_threat_and_preserves_all_input_state() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.repairs = {"moth_engine": true, "beacon": true}
	data.run.merge({"phase": "night", "elapsed_s": 240.0})
	data.escape = {"can_arm": true}
	var before: Dictionary = data.duplicate(true)
	var context: Dictionary = surroundings()
	var before_context: Dictionary = context.duplicate(true)
	Guide.next_step(data, "crew_1", context)
	assert_eq(data, before)
	assert_eq(context, before_context)
	data.hunter = "chase"
	data.hunter_target = "crew_1"
	assert_eq(Guide.next_step(data, "crew_1", context), {})

func test_banking_at_moth_precedes_an_affordable_engine_or_arming_prompt() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 80
	data.cargo.mine = packed("crew_1")
	var nearby: Dictionary = surroundings()
	nearby.position = nearby.markers.boat
	assert_eq(Guide.next_step(data, "crew_1", nearby).get("action", ""), "bank", "E actually banks before it repairs")
	data.progression.repairs = {"moth_engine": true, "beacon": true}
	data.run.merge({"phase": "night", "elapsed_s": 240.0})
	data.escape = {"can_arm": true}
	assert_eq(Guide.next_step(data, "crew_1", nearby).get("action", ""), "bank", "E actually banks before it arms")

func test_completed_repairs_progress_from_day_exploration_to_the_real_night_escape() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.repairs = {"moth_engine": true, "beacon": true}
	var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
	assert_string_contains(str(step.get("title", "")), "Boat ready")
	assert_string_contains(str(step.get("detail", "")).to_lower(), "night")
	assert_ne(step.get("action", ""), "arm_escape")
	data.run.merge({"phase": "night", "elapsed_s": 240.0})
	data.escape = {"can_arm": true}
	step = Guide.next_step(data, "crew_1", surroundings())
	assert_eq(step.get("marker", ""), "boat")
	assert_eq(step.get("action", ""), "arm_escape")
	data.escape = {"armed": true, "can_signal": true}
	step = Guide.next_step(data, "crew_1", surroundings())
	assert_eq(step.get("marker", ""), "beacon_repair")
	assert_eq(step.get("action", ""), "signal_escape")
	data.escape = {"armed": true, "signalled": true}
	var nearby: Dictionary = surroundings()
	nearby.position = nearby.markers.boat
	step = Guide.next_step(data, "crew_1", nearby)
	assert_eq(step.get("action", ""), "ready")
	assert_string_contains(str(step.get("detail", "")), "V")
	assert_true(step.get("payload", {}).get("ready", false))

func test_continued_island_offers_collection_without_forcing_another_escape() -> void:
	var data: Dictionary = beyond_first_catch()
	data.progression.repairs = {"moth_engine": true, "beacon": true}
	data.progression.campaign_flags.escaped = true
	data.run.merge({"phase": "night", "elapsed_s": 240.0})
	data.escape = {"can_arm": true, "completed": false}
	var step: Dictionary = Guide.next_step(data, "crew_1", surroundings())
	assert_string_contains(str(step.get("detail", "")), "Penny Perch")
	assert_ne(step.get("action", ""), "arm_escape")
	data.escape = {"armed": true, "can_signal": true}
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).get("action", ""), "signal_escape", "Voluntarily starting another escape still gets guidance")
