class_name Roster
extends RefCounted

const BUILD_ID: String = "0.2.0-campaign"
const PROFILE_IDS: Array[String] = ["crew_1", "crew_2", "crew_3"]
var _entries: Dictionary = {}

func assign(peer_id: int, slot: int, build_id: String) -> Dictionary:
	if build_id != BUILD_ID:
		return {"ok": false, "code": "build_mismatch", "expected_build": BUILD_ID}
	if slot < 0 or slot >= PROFILE_IDS.size():
		return {"ok": false, "code": "invalid_slot"}
	if peer_id <= 0:
		return {"ok": false, "code": "invalid_peer"}
	if not profile_for_peer(peer_id).is_empty():
		return {"ok": false, "code": "already_assigned"}
	var profile_id: String = PROFILE_IDS[slot]
	if _entries.has(profile_id):
		return {"ok": false, "code": "slot_taken"}
	_entries[profile_id] = {"peer_id": peer_id, "slot": slot, "profile_id": profile_id}
	return {"ok": true, "code": "assigned", "profile_id": profile_id}

func profile_for_peer(peer_id: int) -> String:
	for profile_id: String in _entries:
		if int(_entries[profile_id].peer_id) == peer_id:
			return profile_id
	return ""

func disconnect_peer(peer_id: int) -> String:
	var profile_id: String = profile_for_peer(peer_id)
	_entries.erase(profile_id)
	return profile_id

func snapshot() -> Dictionary:
	return _entries.duplicate(true)
