class_name CargoRules
extends RefCounted

const PROFILES: Array[String] = ["crew_1", "crew_2", "crew_3"]
const CAPACITY: int = 3
const CARRY_SPEED_FACTOR: float = 0.85
var _cargo: Dictionary = {}
var _reservations: Dictionary = {}
var _completed_reservations: Dictionary = {}
var _reservation_sequence: int = 0
var _paused: bool = false

func register_catch(record: Dictionary, mode: String, pouch_profile_id: String = "") -> Dictionary:
	var catch_id: String = str(record.get("catch_id", ""))
	var angler: String = str(record.get("profile_id", ""))
	if catch_id.is_empty() or angler not in PROFILES or mode not in ["whole", "packed"]:
		return _failure("invalid_catch")
	if _cargo.has(catch_id):
		return _failure("duplicate")
	var custodian: String = angler if pouch_profile_id.is_empty() else pouch_profile_id
	if custodian not in PROFILES:
		return _failure("invalid_profile")
	var whole_count: int = 0
	for entry: Dictionary in _cargo.values():
		if entry.state in ["whole_loose", "whole_held"] or (entry.state == "bank_pending" and entry.delivery_mode == "whole"):
			whole_count += 1
	var whole: bool = mode == "whole" and record.get("trait_id", "") == "oversized" and whole_count < CAPACITY
	_cargo[catch_id] = {"catch_record": record.duplicate(true), "state": "whole_loose" if whole else "packed", "carrier_id": "", "pouch_profile_id": "" if whole else custodian, "sequence": 0, "delivery_mode": "whole" if whole else "packed", "reservation_id": ""}
	var code: String = "registered" if whole or mode == "packed" else "packed_fallback"
	return _result(catch_id, code)

func grab(catch_id: String, profile_id: String, context: Dictionary) -> Dictionary:
	var check: Dictionary = _can_touch(catch_id, profile_id, context, 2.0)
	if not check.ok:
		return check
	var entry: Dictionary = _cargo[catch_id]
	if entry.state == "whole_held":
		return _failure("already_held")
	if not held_by(profile_id).is_empty():
		return _failure("hands_full")
	entry.state = "whole_held"
	entry.carrier_id = profile_id
	entry.sequence += 1
	return _result(catch_id, "grabbed")

func release(profile_id: String, kind: String) -> Dictionary:
	if _paused:
		return _failure("paused")
	if kind not in ["drop", "toss"]:
		return _failure("invalid_action")
	var catch_id: String = held_by(profile_id)
	if catch_id.is_empty():
		return _failure("not_holding")
	return _release_id(catch_id, kind)

func pack(catch_id: String, profile_id: String, held_s: float, context: Dictionary) -> Dictionary:
	var check: Dictionary = _can_touch(catch_id, profile_id, context, 2.0)
	if not check.ok:
		return check
	var entry: Dictionary = _cargo[catch_id]
	if entry.state == "whole_held" and entry.carrier_id != profile_id:
		return _failure("already_held")
	if entry.state == "whole_loose" and entry.catch_record.profile_id != profile_id:
		return _failure("not_holder")
	if not is_finite(held_s) or held_s < 0.5:
		return _failure("hold_incomplete")
	entry.state = "packed"
	entry.carrier_id = ""
	entry.pouch_profile_id = profile_id
	entry.delivery_mode = "packed"
	entry.sequence += 1
	return _result(catch_id, "packed")

func receive(catch_id: String, candidates: Array[Dictionary]) -> Dictionary:
	if _paused:
		return _failure("paused")
	if not _cargo.has(catch_id) or _cargo[catch_id].state != "whole_loose":
		return _failure("not_loose")
	var best_id: String = ""
	var best_distance: float = INF
	for candidate: Dictionary in candidates:
		var profile_id: String = str(candidate.get("profile_id", ""))
		var distance: float = float(candidate.get("distance_m", INF))
		if profile_id not in PROFILES or not held_by(profile_id).is_empty():
			continue
		if not candidate.get("active", false) or not candidate.get("facing", false) or not candidate.get("receiving", false):
			continue
		if not is_finite(distance) or distance < 0.0 or distance > 1.5:
			continue
		if distance < best_distance or (is_equal_approx(distance, best_distance) and profile_id < best_id):
			best_distance = distance
			best_id = profile_id
	if best_id.is_empty():
		return _failure("no_receiver")
	return grab(catch_id, best_id, {"distance_m": best_distance, "active": true, "line_of_sight": true})

func disconnect_profile(profile_id: String) -> Dictionary:
	var released: Array[String] = []
	var lost: Array[String] = []
	for catch_id: String in _cargo:
		var entry: Dictionary = _cargo[catch_id]
		if entry.state == "whole_held" and entry.carrier_id == profile_id:
			_release_id(catch_id, "drop")
			released.append(catch_id)
		elif entry.state == "packed" and entry.pouch_profile_id == profile_id:
			entry.state = "lost"
			entry.sequence += 1
			lost.append(catch_id)
	return {"ok": true, "code": "disconnected", "released_ids": released, "lost_ids": lost}

func set_paused(value: bool) -> void:
	_paused = value

func snapshot() -> Dictionary:
	return _cargo.duplicate(true)

func reserve_bank(ids: Array[String], context: Dictionary) -> Dictionary:
	if ids.is_empty():
		return _failure("empty")
	var eligible: Array = context.get("eligible_ids", [])
	var seen: Dictionary = {}
	var catches: Array[Dictionary] = []
	var modes: Dictionary = {}
	for catch_id: String in ids:
		if seen.has(catch_id):
			return _failure("duplicate")
		seen[catch_id] = true
		if not _cargo.has(catch_id):
			return _failure("unknown_catch")
		var entry: Dictionary = _cargo[catch_id]
		if entry.state == "bank_pending":
			return _failure("bank_pending")
		if entry.state not in ["whole_loose", "whole_held", "packed"]:
			return _failure("already_settled")
		if catch_id not in eligible:
			return _failure("out_of_range")
		catches.append(entry.catch_record.duplicate(true))
		modes[catch_id] = "packed" if entry.state == "packed" else "whole"
	_reservation_sequence += 1
	var reservation_id: String = "cargo:%d" % _reservation_sequence
	var result: Dictionary = {"ok": true, "code": "reserved", "reservation_id": reservation_id, "catches": catches, "delivery_modes": modes}
	_reservations[reservation_id] = {"ids": ids.duplicate(), "result": result.duplicate(true)}
	for catch_id: String in ids:
		var entry: Dictionary = _cargo[catch_id]
		entry.state = "bank_pending"
		entry.reservation_id = reservation_id
		entry.delivery_mode = modes[catch_id]
		entry.carrier_id = ""
		entry.sequence += 1
	return result

func finish_bank(id: String, committed: bool) -> Dictionary:
	if _completed_reservations.has(id):
		return _failure("duplicate")
	if not _reservations.has(id):
		return _failure("unknown_reservation")
	if not committed:
		var pending: Dictionary = _reservations[id].result.duplicate(true)
		pending.ok = false
		pending.code = "save_failed"
		return pending
	for catch_id: String in _reservations[id].ids:
		var entry: Dictionary = _cargo[catch_id]
		entry.state = "banked"
		entry.pouch_profile_id = ""
		entry.sequence += 1
	_completed_reservations[id] = true
	_reservations.erase(id)
	return {"ok": true, "code": "banked", "reservation_id": id}

func mark_lost(ids: Array[String]) -> Dictionary:
	for catch_id: String in ids:
		if not _cargo.has(catch_id):
			return _failure("unknown_catch")
		if _cargo[catch_id].state in ["bank_pending", "banked"]:
			return _failure("locked")
	for catch_id: String in ids:
		var entry: Dictionary = _cargo[catch_id]
		entry.state = "lost"
		entry.carrier_id = ""
		entry.pouch_profile_id = ""
		entry.sequence += 1
	return {"ok": true, "code": "lost"}

func held_by(profile_id: String) -> String:
	for catch_id: String in _cargo:
		if _cargo[catch_id].state == "whole_held" and _cargo[catch_id].carrier_id == profile_id:
			return catch_id
	return ""

func _can_touch(catch_id: String, profile_id: String, context: Dictionary, range_m: float) -> Dictionary:
	if _paused:
		return _failure("paused")
	if profile_id not in PROFILES:
		return _failure("invalid_profile")
	if not _cargo.has(catch_id):
		return _failure("unknown_catch")
	if _cargo[catch_id].state == "bank_pending":
		return _failure("bank_pending")
	if _cargo[catch_id].state not in ["whole_loose", "whole_held"]:
		return _failure("not_whole")
	if not context.get("active", false):
		return _failure("inactive")
	var distance: float = float(context.get("distance_m", INF))
	if not is_finite(distance) or distance < 0.0 or distance > range_m:
		return _failure("out_of_range")
	if not context.get("line_of_sight", false):
		return _failure("blocked")
	return {"ok": true, "code": "allowed"}

func _release_id(catch_id: String, kind: String) -> Dictionary:
	var entry: Dictionary = _cargo[catch_id]
	entry.state = "whole_loose"
	entry.carrier_id = ""
	entry.sequence += 1
	var result: Dictionary = _result(catch_id, "released")
	result.kind = kind
	return result

func _result(catch_id: String, code: String) -> Dictionary:
	var result: Dictionary = _cargo[catch_id].duplicate(true)
	result.ok = true
	result.code = code
	result.catch_id = catch_id
	return result

func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
