extends GutTest

const CargoModel = preload("res://game/fishing/cargo_rules.gd")

func catch_record(id: String = "run-a:1", angler: String = "crew_1", oversized: bool = true) -> Dictionary:
	return {"catch_id": id, "run_id": "run-a", "profile_id": angler, "species_id": "penny_perch", "habitat_id": "jetty", "rare_eligible": false, "trait_id": "oversized" if oversized else "", "size": 1.2, "catch_value": 12 if oversized else 10}

func nearby() -> Dictionary:
	return {"distance_m": 1.0, "line_of_sight": true, "active": true}

func test_simultaneous_grab_has_one_holder_and_holder_cannot_take_second() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	cargo.register_catch(catch_record("run-a:2"), "whole")
	assert_true(cargo.grab("run-a:1", "crew_2", nearby()).ok)
	assert_eq(cargo.grab("run-a:1", "crew_3", nearby()).code, "already_held")
	assert_eq(cargo.grab("run-a:2", "crew_2", nearby()).code, "hands_full")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("carrier_id", ""), "crew_2")

func test_failed_grab_and_paused_actions_preserve_state() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	var before: Dictionary = cargo.snapshot()
	assert_eq(cargo.grab("run-a:1", "crew_2", {"distance_m": 2.1, "line_of_sight": true, "active": true}).code, "out_of_range")
	assert_eq(cargo.grab("run-a:1", "crew_2", {"distance_m": 1.0, "line_of_sight": false, "active": true}).code, "blocked")
	assert_eq(cargo.grab("run-a:1", "crew_9", nearby()).code, "invalid_profile")
	cargo.set_paused(true)
	assert_eq(cargo.grab("run-a:1", "crew_2", nearby()).code, "paused")
	assert_eq(cargo.snapshot(), before)

func test_toss_is_one_edge_and_receive_uses_nearest_stable_tie_break() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	cargo.grab("run-a:1", "crew_1", nearby())
	assert_true(cargo.release("crew_1", "toss").ok)
	assert_eq(cargo.release("crew_1", "toss").code, "not_holding")
	var result: Dictionary = cargo.receive("run-a:1", [
		{"profile_id": "crew_3", "distance_m": 1.0, "facing": true, "receiving": true, "active": true},
		{"profile_id": "crew_2", "distance_m": 1.0, "facing": true, "receiving": true, "active": true}])
	assert_true(result.ok)
	assert_eq(result.carrier_id, "crew_2")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("catch_record", {}).get("profile_id", ""), "crew_1")

func test_pack_changes_custody_once_and_disconnect_uses_custodian() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	cargo.grab("run-a:1", "crew_2", nearby())
	assert_eq(cargo.pack("run-a:1", "crew_2", 0.49, nearby()).code, "hold_incomplete")
	assert_true(cargo.pack("run-a:1", "crew_2", 0.5, nearby()).ok)
	assert_eq(cargo.grab("run-a:1", "crew_3", nearby()).code, "not_whole")
	cargo.disconnect_profile("crew_1")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("state", ""), "packed")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("pouch_profile_id", ""), "crew_2")
	cargo.disconnect_profile("crew_2")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("state", ""), "lost")

func test_carrier_disconnect_drops_shared_fish_even_when_paused() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	cargo.grab("run-a:1", "crew_2", nearby())
	cargo.disconnect_profile("crew_1")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("carrier_id", ""), "crew_2")
	cargo.set_paused(true)
	cargo.disconnect_profile("crew_2")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("state", ""), "whole_loose")

func test_capacity_overflow_and_normal_catch_pack_without_erasing_world_fish() -> void:
	var cargo = CargoModel.new()
	for index: int in range(4):
		assert_true(cargo.register_catch(catch_record("run-a:%d" % index), "whole").ok)
	assert_eq(cargo.snapshot().get("run-a:3", {}).get("state", ""), "packed")
	assert_eq(cargo.snapshot().get("run-a:0", {}).get("state", ""), "whole_loose")
	assert_true(cargo.register_catch(catch_record("normal", "crew_2", false), "whole").ok)
	assert_eq(cargo.snapshot().get("normal", {}).get("state", ""), "packed")
	assert_eq(cargo.register_catch(catch_record("normal"), "whole").code, "duplicate")

func test_reservation_retry_locks_same_objects_until_commit() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	var ids: Array[String] = ["run-a:1"]
	var reservation: Dictionary = cargo.reserve_bank(ids, {"eligible_ids": ids})
	assert_true(reservation.ok)
	assert_eq(reservation.delivery_modes.get("run-a:1", ""), "whole")
	assert_eq(cargo.grab("run-a:1", "crew_2", nearby()).code, "bank_pending")
	assert_eq(cargo.reserve_bank(ids, {"eligible_ids": ids}).code, "bank_pending")
	assert_eq(cargo.finish_bank(reservation.reservation_id, false).code, "save_failed")
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("state", ""), "bank_pending")
	assert_true(cargo.finish_bank(reservation.reservation_id, true).ok)
	assert_eq(cargo.snapshot().get("run-a:1", {}).get("state", ""), "banked")
	assert_eq(cargo.finish_bank(reservation.reservation_id, true).code, "duplicate")

func test_invalid_bank_batch_and_lost_batch_are_atomic() -> void:
	var cargo = CargoModel.new()
	assert_true(cargo.register_catch(catch_record(), "whole").ok)
	var before: Dictionary = cargo.snapshot()
	var ids: Array[String] = ["run-a:1", "missing"]
	assert_false(cargo.reserve_bank(ids, {"eligible_ids": ids}).ok)
	assert_eq(cargo.snapshot(), before)
	assert_false(cargo.mark_lost(ids).ok)
	assert_eq(cargo.snapshot(), before)
