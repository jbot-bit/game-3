extends "res://addons/gut/test.gd"

const Store = preload("res://game/progression/save_store.gd")
const Progress = preload("res://game/progression/progression.gd")
const Island = preload("res://game/world/island_content.gd")

var save_path: String
var p: Progress

func before_each() -> void:
	save_path = "user://test_world_progress_%s_%s/household.json" % [Time.get_ticks_usec(), randi()]
	p = Progress.new(Store.new(save_path), Progress.blank_state())

func test_found_rod_is_shared_and_cache_cannot_repeat() -> void:
	assert_true(p.open_cache("shore_rod_cache").ok)
	for id: String in ["crew_1", "crew_2", "crew_3"]:
		assert_true(p.set_rod(id, "soft_tip").ok)
	var before: Dictionary = p.snapshot()
	assert_false(p.open_cache("shore_rod_cache").ok)
	assert_false(p.open_cache("invented").ok)
	assert_eq(p.snapshot(), before)

func test_repair_and_empty_cache_survive_reload() -> void:
	assert_true(p.open_cache("walkway_parts_cache").ok)
	assert_true(p.repair("return_walkway", "repair-1").ok)
	assert_true(p.snapshot().repairs.get("return_walkway", false))
	assert_eq(p.snapshot().salvage.get("brass_fitting", -1), 0)
	var before: Dictionary = p.snapshot()
	assert_false(p.repair("return_walkway", "repair-1").ok)
	assert_false(p.repair("return_walkway", "repair-2").ok)
	assert_eq(p.snapshot(), before)
	var loaded: Dictionary = Store.new(save_path).load_or_recover()
	assert_eq(loaded.state.get("repairs", {}), before.repairs)
	assert_eq(loaded.state.get("opened_caches", []), before.opened_caches)

func test_missing_and_unknown_repairs_cannot_change_state() -> void:
	var before: Dictionary = p.snapshot()
	assert_false(p.repair("return_walkway", "repair-1").ok)
	assert_false(p.repair("invented", "repair-2").ok)
	assert_eq(p.snapshot(), before)
	assert_true(Island.cache("invented").is_empty())
	assert_true(Island.repair("invented").is_empty())
