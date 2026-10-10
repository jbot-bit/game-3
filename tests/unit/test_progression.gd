extends "res://addons/gut/test.gd"

const Store = preload("res://game/progression/save_store.gd")
const Progress = preload("res://game/progression/progression.gd")
const Gear = preload("res://game/progression/equipment.gd")
const Rolls = preload("res://game/fishing/catch_table.gd")

class RefusingStore extends "res://game/progression/save_store.gd":
	var refuse: bool = false
	func commit(next_state: Dictionary) -> Error:
		if refuse:
			return ERR_FILE_CANT_WRITE
		return super.commit(next_state)

var save_path: String
var p: Progress

func before_each() -> void:
	save_path = "user://test_progression_%s_%s/household.json" % [Time.get_ticks_usec(), randi()]
	p = Progress.new(Store.new(save_path), Progress.blank_state())

func catch_record(id: String, species: String = "penny_perch", trait_id: String = "") -> Dictionary:
	return {"catch_id": id, "run_id": "run-a", "profile_id": "crew_1", "species_id": species, "habitat_id": "reeds", "rare_eligible": true, "trait_id": trait_id, "size": 1.2, "catch_value": 99999}

func test_bank_records_once_and_uses_catalog_values() -> void:
	var a: Dictionary = catch_record("run-a:1")
	var b: Dictionary = catch_record("run-a:2", "bellgill")
	assert_true(p.record_specimen(a).ok)
	assert_true(p.record_specimen(b).ok)
	assert_true(p.bank([a, b]).ok)
	assert_eq(p.snapshot().coins, 30)
	assert_eq(p.snapshot().lifetime_banked, 30)
	assert_false(p.bank([a]).ok)
	assert_eq(p.snapshot().coins, 30)

func test_unrecorded_and_mixed_duplicate_batches_are_atomic() -> void:
	var a: Dictionary = catch_record("run-a:1")
	var b: Dictionary = catch_record("run-a:2")
	assert_false(p.bank([a]).ok)
	assert_true(p.record_specimen(a).ok)
	assert_true(p.record_specimen(b).ok)
	assert_true(p.bank([a]).ok)
	assert_false(p.bank([a, b]).ok)
	assert_eq(p.snapshot().coins, 10)
	assert_true(p.bank([b]).ok)
	assert_eq(p.snapshot().coins, 20)

func test_oversized_payouts_replace_packed_value() -> void:
	var species: Array[String] = ["penny_perch", "bellgill", "lantern_eel"]
	var packed_values: Array[int] = [12, 25, 50]
	var whole_values: Array[int] = [20, 40, 80]
	var total: int = 0
	for i: int in range(species.size()):
		var packed: Dictionary = catch_record("run-a:p%s" % i, species[i], "oversized")
		var whole: Dictionary = catch_record("run-a:w%s" % i, species[i], "oversized")
		assert_true(p.record_specimen(packed).ok)
		assert_true(p.record_specimen(whole).ok)
		assert_true(p.bank([packed]).ok)
		total += packed_values[i]
		assert_eq(p.snapshot().coins, total)
		assert_true(p.bank([whole], {whole.catch_id: "whole"}).ok)
		total += whole_values[i]
		assert_eq(p.snapshot().coins, total)
		assert_false(p.bank([whole]).ok)

func test_ordinary_whole_and_unknown_species_are_rejected() -> void:
	var a: Dictionary = catch_record("run-a:1")
	assert_true(p.record_specimen(a).ok)
	assert_false(p.bank([a], {a.catch_id: "whole"}).ok)
	assert_false(p.record_specimen(catch_record("run-a:2", "invented")).ok)
	assert_eq(p.snapshot().coins, 0)

func test_record_counter_and_discovery_are_saved_once() -> void:
	var a: Dictionary = catch_record("run-a:1")
	assert_true(p.record_specimen(a).ok)
	var revision: int = int(p.snapshot().revision)
	assert_false(p.record_specimen(a).ok)
	assert_eq(p.snapshot().revision, revision)
	assert_eq(p.snapshot().dry_streaks.get("reeds", -1), 1)
	assert_has(p.snapshot().discoveries, "penny_perch")
	var rare: Dictionary = catch_record("run-a:2", "lantern_eel")
	assert_true(p.record_specimen(rare).ok)
	assert_eq(p.snapshot().dry_streaks.get("reeds", -1), 0)
	var day: Dictionary = catch_record("run-a:3")
	day.rare_eligible = false
	day.habitat_id = "jetty"
	assert_true(p.record_specimen(day).ok)
	assert_eq(p.snapshot().dry_streaks.get("jetty", 0), 0)
	var restored: Dictionary = Store.new(save_path).load_or_recover()
	assert_true(restored.ok)
	assert_eq(restored.state.get("discoveries", []), p.snapshot().discoveries)
	assert_eq(restored.state.get("dry_streaks", {}), p.snapshot().dry_streaks)

func test_bank_replay_is_rejected_after_reload() -> void:
	var a: Dictionary = catch_record("run-a:1")
	assert_true(p.record_specimen(a).ok)
	assert_true(p.bank([a]).ok)
	var loaded: Dictionary = Store.new(save_path).load_or_recover()
	assert_true(loaded.ok)
	var reloaded: Progress = Progress.new(Store.new(save_path), loaded.state)
	assert_false(reloaded.bank([a]).ok)
	assert_eq(reloaded.snapshot().get("coins", -1), 10)

func test_failed_record_bank_and_settlement_preserve_state() -> void:
	var refusing: RefusingStore = RefusingStore.new(save_path)
	p = Progress.new(refusing, Progress.blank_state())
	var a: Dictionary = catch_record("run-a:1")
	refusing.refuse = true
	var before: Dictionary = p.snapshot()
	assert_eq(p.record_specimen(a).code, "save_failed")
	assert_eq(p.snapshot(), before)
	refusing.refuse = false
	assert_true(p.record_specimen(a).ok)
	before = p.snapshot()
	refusing.refuse = true
	assert_eq(p.bank([a]).code, "save_failed")
	assert_eq(p.snapshot(), before)
	assert_eq(p.settle_run("run-a", [a]).code, "save_failed")
	assert_eq(p.snapshot(), before)
	refusing.refuse = false
	assert_true(p.settle_run("run-a", [a]).ok)
	assert_eq(p.snapshot().coins, 10)
	assert_eq(p.snapshot().day_index, 1)

func test_settlement_is_atomic_and_replay_safe() -> void:
	var a: Dictionary = catch_record("run-a:1", "penny_perch", "oversized")
	assert_true(p.record_specimen(a).ok)
	assert_true(p.settle_run("run-a", [a], {a.catch_id: "whole"}).ok)
	var saved: Dictionary = p.snapshot()
	assert_eq(saved.coins, 20)
	assert_eq(saved.day_index, 1)
	assert_false(p.settle_run("run-a", [a], {a.catch_id: "whole"}).ok)
	assert_eq(p.snapshot(), saved)
	assert_false(p.bank([a]).ok)
	assert_true(p.settle_run("run-b", []).ok)
	assert_eq(p.snapshot().day_index, 2)

func test_settlement_rejects_cross_run_catches() -> void:
	var a: Dictionary = catch_record("run-a:1")
	assert_true(p.record_specimen(a).ok)
	assert_false(p.settle_run("run-other", [a]).ok)
	assert_eq(p.snapshot().coins, 0)
	assert_eq(p.snapshot().day_index, 0)

func test_equipment_choices_and_snapshot_are_isolated() -> void:
	assert_false(p.set_lamp("crew_1", "surveyor").ok)
	assert_false(p.set_rod("crew_1", "soft_tip").ok)
	assert_false(p.set_lamp("invented", "flood").ok)
	assert_true(p.set_lamp("crew_1", "flood").ok)
	var copy: Dictionary = p.snapshot()
	copy.profiles.crew_1.lamp_id = "invented"
	assert_eq(p.snapshot().profiles.crew_1.lamp_id, "flood")
	assert_eq(Gear.lamp("flood").get("active_seconds", -1), 90.0)
	assert_eq(Gear.lamp("surveyor").get("active_seconds", -1), 45.0)
	assert_gt(float(Gear.rod("soft_tip").get("bar_width_multiplier", 1.0)), 1.0)
	assert_eq(Gear.rod("soft_tip").get("heavy_progress_multiplier", -1), 0.85)

func test_real_catch_table_normal_trait_records_and_banks() -> void:
	var record: Dictionary = Rolls.roll("jetty", "day", 0, 0.1, 0.5, 0.5)
	record.merge({"catch_id": "run-a:real", "run_id": "run-a", "profile_id": "crew_1"})
	assert_true(p.record_specimen(record).ok)
	assert_true(p.bank([record]).ok)
	assert_eq(p.snapshot().coins, 10)
	assert_eq(p.snapshot().specimen_records.get("penny_perch", {}).get("traits", []), [])

func test_profile_name_and_role_persist_with_validation() -> void:
	assert_true(p.set_profile("crew_2", "  River  ", "scout").ok)
	assert_eq(p.snapshot().profiles.crew_2.name, "River")
	assert_eq(p.snapshot().profiles.crew_2.role_id, "scout")
	var before: Dictionary = p.snapshot()
	assert_false(p.set_profile("unknown", "River", "scout").ok)
	assert_false(p.set_profile("crew_2", " ", "scout").ok)
	assert_false(p.set_profile("crew_2", "R".repeat(33), "scout").ok)
	assert_false(p.set_profile("crew_2", "River\nAdmin", "scout").ok)
	assert_false(p.set_profile("crew_2", "River", "invented").ok)
	assert_eq(p.snapshot(), before)
	assert_eq(Store.new(save_path).load_or_recover().state.get("profiles", {}), before.profiles)
