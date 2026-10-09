extends "res://addons/gut/test.gd"

const Store = preload("res://game/progression/save_store.gd")
const Progress = preload("res://game/progression/progression.gd")
const Cargo = preload("res://game/fishing/cargo_rules.gd")
const Rolls = preload("res://game/fishing/catch_table.gd")
const Run = preload("res://game/expedition/expedition_rules.gd")

class RefusingStore extends "res://game/progression/save_store.gd":
	var refuse: bool = false
	func commit(next_state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(next_state)

var save_path: String
var p: Progress
var cargo: Cargo
var run: Run

func before_each() -> void:
	save_path = "user://test_integrated_run_%s_%s/household.json" % [Time.get_ticks_usec(), randi()]
	p = Progress.new(Store.new(save_path), Progress.blank_state())
	cargo = Cargo.new()
	run = Run.new()
	run.start("run-a", ["crew_1", "crew_2", "crew_3"])

func make_catch(id: String, heavy: bool = false, oversized: bool = false) -> Dictionary:
	var result: Dictionary = Rolls.roll("jetty", "day", 0, 0.8 if heavy else 0.2, 0.05 if oversized else 0.5, 0.5)
	result.merge({"catch_id": id, "run_id": "run-a", "profile_id": "crew_1"})
	return result

func close_context() -> Dictionary:
	return {"active": true, "distance_m": 1.0, "line_of_sight": true}

func test_real_models_fishing_craft_repair_pass_rescue_refuge_reload() -> void:
	var ids: Array[String] = ["run-a:1", "run-a:2", "run-a:3"]
	for i: int in range(3):
		var record: Dictionary = make_catch(ids[i], i == 2)
		var landed: Dictionary = p.record_specimen(record)
		assert_true(landed.ok, "The real catch-table record must persist before cargo is granted")
		if not landed.ok:
			return
		assert_true(cargo.register_catch(record, "packed").ok)
	var reservation: Dictionary = cargo.reserve_bank(ids, {"eligible_ids": ids})
	assert_true(reservation.ok)
	assert_true(p.bank(reservation.catches, reservation.delivery_modes).ok)
	assert_true(cargo.finish_bank(reservation.reservation_id, true).ok)
	assert_eq(p.snapshot().coins, 40)
	assert_true(p.open_cache("shore_rod_cache").ok)
	assert_true(p.open_cache("lido_workshop_cache").ok)
	assert_true(p.craft("surveyor_lantern", "craft-a").ok)
	assert_true(p.open_cache("walkway_parts_cache").ok)
	assert_true(p.repair("return_walkway", "repair-a").ok)
	assert_true(p.set_rod("crew_1", "soft_tip").ok)
	assert_true(p.set_lamp("crew_2", "surveyor").ok)
	assert_eq(p.snapshot().coins, 10)
	assert_eq(p.snapshot().lifetime_banked, 40)
	var trophy: Dictionary = make_catch("run-a:4", false, true)
	assert_true(p.record_specimen(trophy).ok)
	assert_true(cargo.register_catch(trophy, "whole").ok)
	assert_true(cargo.grab(trophy.catch_id, "crew_1", close_context()).ok)
	assert_true(cargo.release("crew_1", "toss").ok)
	assert_true(cargo.receive(trophy.catch_id, [{"profile_id": "crew_3", "distance_m": 1.0, "active": true, "facing": true, "receiving": true}]).ok)
	run.advance(250.0)
	assert_true(run.down("crew_2").ok)
	assert_true(run.revive("crew_1", "crew_2", 3.0).ok)
	for id: String in ["crew_1", "crew_2", "crew_3"]:
		run.set_aboard(id, true)
		run.set_ready(id, true)
	assert_eq(run.advance(0.0).code, "depart")
	assert_eq(run.advance(20.0).code, "settle")
	cargo.set_paused(true)
	var final_ids: Array[String] = [trophy.catch_id]
	var final_reservation: Dictionary = cargo.reserve_bank(final_ids, {"eligible_ids": final_ids})
	assert_true(final_reservation.ok)
	assert_true(p.settle_run("run-a", final_reservation.catches, final_reservation.delivery_modes).ok)
	assert_true(cargo.finish_bank(final_reservation.reservation_id, true).ok)
	var saved: Dictionary = p.snapshot()
	assert_eq(saved.coins, 30)
	assert_eq(saved.lifetime_banked, 60)
	assert_eq(saved.day_index, 1)
	assert_true(saved.repairs.return_walkway)
	assert_eq(saved.profiles.crew_2.lamp_id, "surveyor")
	assert_eq(saved.profiles.crew_1.rod_id, "soft_tip")
	assert_eq(saved.salvage.glass_lens, 0)
	assert_eq(saved.salvage.brass_fitting, 0)
	assert_eq(saved.opened_caches.size(), 3)
	assert_false(p.bank(reservation.catches, reservation.delivery_modes).ok)
	assert_false(p.craft("surveyor_lantern", "craft-a").ok)
	assert_false(p.repair("return_walkway", "repair-a").ok)
	assert_false(p.settle_run("run-a", final_reservation.catches, final_reservation.delivery_modes).ok)
	assert_eq(p.snapshot(), saved)
	var loaded: Dictionary = Store.new(save_path).load_or_recover()
	assert_true(loaded.ok)
	assert_eq(loaded.state, saved)
	run.start("run-b", ["crew_1", "crew_2", "crew_3"])
	assert_eq(run.snapshot().elapsed_s, 0.0)
	assert_true(p.snapshot().repairs.return_walkway)

func test_failed_terminal_save_keeps_reserved_cargo_and_frozen_outcome() -> void:
	var store: RefusingStore = RefusingStore.new(save_path)
	p = Progress.new(store, Progress.blank_state())
	var trophy: Dictionary = make_catch("run-a:1", false, true)
	assert_true(p.record_specimen(trophy).ok)
	assert_true(cargo.register_catch(trophy, "whole").ok)
	assert_true(cargo.grab(trophy.catch_id, "crew_1", close_context()).ok)
	run.set_aboard("crew_1", true)
	assert_eq(run.advance(630.0).code, "settle")
	var terminal_players: Dictionary = run.snapshot().players.duplicate(true)
	cargo.set_paused(true)
	var ids: Array[String] = [trophy.catch_id]
	var reservation: Dictionary = cargo.reserve_bank(ids, {"eligible_ids": ids})
	store.refuse = true
	var before: Dictionary = p.snapshot()
	assert_eq(p.settle_run("run-a", reservation.catches, reservation.delivery_modes).code, "save_failed")
	assert_false(cargo.finish_bank(reservation.reservation_id, false).ok)
	assert_eq(p.snapshot(), before)
	assert_eq(cargo.snapshot()[trophy.catch_id].state, "bank_pending")
	assert_false(cargo.grab(trophy.catch_id, "crew_2", close_context()).ok)
	assert_false(cargo.pack(trophy.catch_id, "crew_1", 0.5, close_context()).ok)
	run.set_aboard("crew_2", true)
	run.advance(30.0)
	assert_eq(run.snapshot().players, terminal_players)
	store.refuse = false
	assert_true(p.settle_run("run-a", reservation.catches, reservation.delivery_modes).ok)
	assert_true(cargo.finish_bank(reservation.reservation_id, true).ok)
	assert_eq(p.snapshot().coins, 20)
	assert_eq(p.snapshot().day_index, 1)
	assert_false(p.settle_run("run-a", reservation.catches, reservation.delivery_modes).ok)

func test_packed_transfer_disconnect_uses_custodian_not_angler() -> void:
	var trophy: Dictionary = make_catch("run-a:1", false, true)
	assert_true(p.record_specimen(trophy).ok)
	assert_true(cargo.register_catch(trophy, "whole").ok)
	assert_true(cargo.grab(trophy.catch_id, "crew_2", close_context()).ok)
	assert_true(cargo.pack(trophy.catch_id, "crew_2", 0.5, close_context()).ok)
	cargo.disconnect_profile("crew_1")
	assert_eq(cargo.snapshot()[trophy.catch_id].state, "packed")
	var ids: Array[String] = [trophy.catch_id]
	var reservation: Dictionary = cargo.reserve_bank(ids, {"eligible_ids": ids})
	assert_true(p.bank(reservation.catches, reservation.delivery_modes).ok)
	assert_true(cargo.finish_bank(reservation.reservation_id, true).ok)
	assert_eq(p.snapshot().coins, 12)
	assert_eq(p.snapshot().specimen_records.penny_perch.angler_profile_id, "crew_1")
	var second: Dictionary = make_catch("run-a:2", false, true)
	assert_true(p.record_specimen(second).ok)
	assert_true(cargo.register_catch(second, "whole").ok)
	assert_true(cargo.grab(second.catch_id, "crew_2", close_context()).ok)
	assert_true(cargo.pack(second.catch_id, "crew_2", 0.5, close_context()).ok)
	cargo.disconnect_profile("crew_2")
	assert_eq(cargo.snapshot()[second.catch_id].state, "lost")
	assert_false(cargo.reserve_bank([second.catch_id], {"eligible_ids": [second.catch_id]}).ok)
	assert_eq(p.snapshot().coins, 12)
