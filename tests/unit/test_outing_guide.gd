extends GutTest

const Guide = preload("res://game/ui/outing_guide.gd")

func view() -> Dictionary:
	return {"run": {"phase": "day", "players": {"crew_1": {}}}, "progression": Progression.blank_state(), "cargo": {}}

func surroundings(habitat: String = "") -> Dictionary:
	return {"position": Vector3.ZERO, "habitat": habitat, "interact": "Z", "markers": {"jetty": Vector3(0,0,18), "boat": Vector3(10,0,0), "rod_cache": Vector3(0,0,25)}}

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

func test_banked_progress_points_to_real_rod_cache_then_equipment_at_moth() -> void:
	var data: Dictionary = view()
	data.progression.banked_catch_ids = ["saved_catch"]
	assert_eq(Guide.next_step(data, "crew_1", surroundings()).title, "A better rod awaits")
	data.progression.owned_rods.append("soft_tip")
	var nearby: Dictionary = surroundings()
	nearby.workshop = "X"
	var found: Dictionary = Guide.next_step(data, "crew_1", nearby)
	assert_string_contains(str(found.get("title", "")), "Soft-tip Rod")
	assert_string_contains(str(found.get("detail", "")), "Moth")
	assert_string_contains(str(found.get("detail", "")), "10 m")
	nearby.position = Vector3(9,0,0)
	assert_string_contains(str(Guide.next_step(data, "crew_1", nearby).get("detail", "")), "X")
	for rod: String in ["soft_tip", "braced_reel", "drift_rod"]:
		data.progression.profiles.crew_1.rod_id = rod
		assert_eq(Guide.next_step(data, "crew_1", nearby), {}, "Respect the equipped rod choice")
	data.progression.profiles.crew_1.rod_id = "starter"
	data.progression.profiles.crew_2.rod_id = "soft_tip"
	assert_false(Guide.next_step(data, "crew_1", nearby).is_empty(), "Another player's loadout must not hide local guidance")

func test_fishing_night_rescue_and_departure_take_priority() -> void:
	for change: Dictionary in [{"paused": true}, {"terminal": true}, {"phase": "night"}, {"crossing_left": 8.0}]:
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
