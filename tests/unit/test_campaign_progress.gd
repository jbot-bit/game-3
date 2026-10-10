extends GutTest

const Campaign = preload("res://game/progression/campaign_rules.gd")
var path: String
var p: Progression

class RefusingStore extends SaveStore:
	var refuse: bool = false
	func commit(state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(state)

func before_each() -> void:
	path = "user://tests/campaign-%s-%s/household.json" % [Time.get_ticks_usec(), randi()]
	var state: Dictionary = Progression.blank_state()
	state.coins = 500
	state.lifetime_banked = 500
	p = Progression.new(SaveStore.new(path), state)

func _supply_campaign() -> void:
	for id: String in ["lido_workshop_cache", "walkway_parts_cache", "terraces_parts_cache", "beacon_parts_cache", "tide_engine_cache"]:
		assert_true(p.open_cache(id).ok, id)

func _complete_repairs() -> void:
	_supply_campaign()
	for id: String in ["workshop", "return_walkway", "ridge_steps", "beacon", "moth_engine"]:
		assert_true(p.repair(id, "repair-" + id).ok, id)

func test_legacy_household_gains_defaults_without_losing_progress() -> void:
	var old: Dictionary = p.snapshot()
	for profile: Dictionary in old.profiles.values():
		profile.erase("tool_mode")
	old.opened_caches = ["lido_workshop_cache"]
	old.owned_lamps.append("surveyor")
	assert_eq(SaveStore.new(path).commit(old), OK)
	var loaded: Dictionary = SaveStore.new(path).load_or_recover().state
	assert_eq(loaded.profiles.crew_1.get("tool_mode", ""), "standard")
	assert_true(loaded.campaign_flags.get("workshop_tools", false))
	assert_has(loaded.owned_lamps, "surveyor")
	assert_eq(loaded.coins, 500)
	assert_eq(loaded.household_id, old.household_id)

func test_story_parts_and_costs_are_atomic_without_optional_prerequisites() -> void:
	var before: Dictionary = p.snapshot()
	assert_eq(p.repair("beacon", "early").code, "missing_requirements")
	assert_eq(p.snapshot(), before)
	_supply_campaign()
	assert_true(p.repair("moth_engine", "engine").ok)
	assert_true(p.repair("beacon", "beacon").ok)
	assert_true(p.repair("workshop", "workshop").ok)
	assert_true(p.repair("ridge_steps", "ridge").ok)
	assert_eq(p.snapshot().coins, 380)
	assert_true(p.snapshot().campaign_flags.get("engine_part", false), "Story part stays as a durable found flag")
	assert_false(p.repair("moth_engine", "engine-again").ok)
	assert_eq(p.snapshot().coins, 380)

func test_gear_crafting_never_spends_campaign_parts() -> void:
	_supply_campaign()
	assert_true(p.open_cache("reel_cache").ok)
	var flags: Dictionary = p.snapshot().campaign_flags
	assert_true(p.craft("braced_reel", "braced").ok)
	assert_has(p.snapshot().owned_rods, "braced_reel")
	assert_eq(p.snapshot().campaign_flags, flags)
	assert_eq(p.snapshot().salvage.brass_fitting, 1)
	assert_eq(p.snapshot().salvage.cord_spool, 0)
	assert_true(p.repair("return_walkway", "walkway").ok)

func test_failed_repair_does_not_spend_or_unlock() -> void:
	_supply_campaign()
	var store: RefusingStore = RefusingStore.new(path)
	p = Progression.new(store, p.snapshot())
	var before: Dictionary = p.snapshot()
	store.refuse = true
	assert_eq(p.repair("workshop", "workshop").code, "save_failed")
	assert_eq(p.snapshot(), before)
	store.refuse = false
	assert_true(p.repair("workshop", "workshop").ok)

func test_tools_unlock_by_role_and_reset_safely_on_role_change() -> void:
	assert_false(p.set_tool("crew_1", "alternate").ok)
	assert_false(p.set_tool("crew_1", "invented").ok)
	assert_true(p.open_cache("walkway_parts_cache").ok)
	assert_true(p.repair("return_walkway", "walkway").ok)
	assert_true(p.set_tool("crew_3", "alternate").ok)
	assert_eq(p.snapshot().profiles.crew_3.get("tool_mode", ""), "alternate")
	assert_true(p.set_profile("crew_3", "Harbour", "keeper").ok)
	assert_eq(p.snapshot().profiles.crew_3.get("tool_mode", ""), "standard")
	assert_false(Campaign.tool_unlocked(p.snapshot(), "keeper"))
	_complete_missing_repairs()
	assert_true(Campaign.tool_unlocked(p.snapshot(), "keeper"))

func _complete_missing_repairs() -> void:
	for cache_id: String in ["lido_workshop_cache", "terraces_parts_cache", "beacon_parts_cache", "tide_engine_cache"]:
		assert_true(p.open_cache(cache_id).ok)
	for id: String in ["workshop", "ridge_steps", "beacon", "moth_engine"]:
		assert_true(p.repair(id, id).ok)

func test_six_unique_species_unlock_shared_rod_and_scout_tool() -> void:
	var state: Dictionary = p.snapshot()
	state.discoveries = ["penny_perch", "bellgill", "lantern_eel", "pebble_dab", "ribbon_minnow", "moss_skipper"]
	p = Progression.new(SaveStore.new(path), state)
	assert_has(p.snapshot().owned_rods, "drift_rod")
	assert_true(Campaign.tool_unlocked(p.snapshot(), "scout"))
	assert_true(p.set_tool("crew_1", "alternate").ok)
	assert_true(p.set_rod("crew_2", "drift_rod").ok)
	assert_eq(SaveStore.new(path).load_or_recover().state.get("profiles", {}).get("crew_1", {}).get("tool_mode", ""), "alternate")

func test_new_catalog_traits_and_second_rare_use_authoritative_values() -> void:
	var records: Array[Dictionary] = []
	for pair: Array in [["penny_perch", "moonlit"], ["penny_perch", "stormmarked"], ["crown_ray", "none"]]:
		var record: Dictionary = {"catch_id": "new:" + str(records.size()), "run_id": "trip", "profile_id": "crew_1", "species_id": pair[0], "habitat_id": "beacon", "rare_eligible": true, "trait_id": pair[1], "size": 1.0, "catch_value": 99999}
		records.append(record)
		assert_true(p.record_specimen(record).ok)
	assert_eq(p.snapshot().dry_streaks.get("beacon", -1), 0)
	assert_true(p.bank(records).ok)
	assert_eq(p.snapshot().coins, 582)

func test_sixth_discovery_unlock_is_part_of_the_landing_transaction() -> void:
	var state: Dictionary = p.snapshot()
	state.discoveries = ["penny_perch", "bellgill", "lantern_eel", "pebble_dab", "ribbon_minnow"]
	var store: RefusingStore = RefusingStore.new(path)
	p = Progression.new(store, state)
	var record: Dictionary = {"catch_id": "sixth:1", "run_id": "sixth", "profile_id": "crew_2", "species_id": "moss_skipper", "habitat_id": "terraces", "rare_eligible": false, "trait_id": "none", "size": 1.0}
	store.refuse = true
	assert_false(p.record_specimen(record).ok)
	assert_false("drift_rod" in p.snapshot().owned_rods)
	store.refuse = false
	assert_true(p.record_specimen(record).ok)
	assert_has(p.snapshot().owned_rods, "drift_rod")
	assert_has(SaveStore.new(path).load_or_recover().state.get("owned_rods", []), "drift_rod")

func test_campaign_ending_and_rewards_commit_once_together() -> void:
	assert_eq(p.settle_run("premature", [], {}, true).code, "campaign_locked")
	_complete_repairs()
	assert_true(Campaign.status(p.snapshot()).can_escape)
	var record: Dictionary = {"catch_id": "final:1", "run_id": "final", "profile_id": "crew_1", "species_id": "penny_perch", "habitat_id": "jetty", "rare_eligible": false, "trait_id": "none", "size": 1.0}
	assert_true(p.record_specimen(record).ok)
	var store: RefusingStore = RefusingStore.new(path)
	p = Progression.new(store, p.snapshot())
	var before: Dictionary = p.snapshot()
	store.refuse = true
	assert_eq(p.settle_run("final", [record], {}, true).code, "save_failed")
	assert_eq(p.snapshot(), before)
	store.refuse = false
	var settled: Dictionary = p.settle_run("final", [record], {}, true)
	assert_true(settled.ok, str(settled))
	assert_true(p.snapshot().campaign_flags.get("escaped", false))
	assert_eq(p.snapshot().coins, before.coins + 10)
	assert_eq(p.snapshot().day_index, 1)
	assert_false(p.settle_run("final", [record], {}, true).ok)
	assert_true(Campaign.status(p.snapshot()).completed)
	assert_true(p.settle_run("continued-island", []).ok)
	assert_eq(p.snapshot().day_index, 2)

func test_status_and_marker_data_are_actionable_and_defensive_copies() -> void:
	var status: Dictionary = Campaign.status(p.snapshot())
	assert_eq(status.get("repair_id", ""), "beacon")
	assert_eq(status.get("repairs", []).size(), 5)
	assert_false(status.get("can_escape", true))
	assert_eq(IslandContent.cache_markers().get("lido_workshop_cache", ""), "lens_cache")
	assert_eq(IslandContent.repair_markers().get("return_walkway", ""), "repair")
	assert_has(Crafting.recipes_all(), "braced_reel")
	var data: Dictionary = IslandContent.repair("workshop")
	data.coins = 99
	assert_eq(IslandContent.repair("workshop").get("coins", -1), 0)
