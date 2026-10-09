class_name IntentGate
extends RefCounted

const FIELDS: Dictionary = {
	"move": ["direction", "yaw", "jump"], "cast": ["habitat_id"],
	"reel": ["held", "pull"], "cancel_cast": [], "assist": ["target_id", "catch_id"],
	"bank": [], "grab_fish": ["catch_id"], "drop_fish": [],
	"toss_fish": ["direction"], "pack_fish": ["catch_id", "held_s"],
	"receive_fish": ["held"], "equip_lamp": ["lamp_id"], "equip_rod": ["rod_id"],
	"open_cache": ["cache_id"], "craft": ["recipe_id"], "repair": ["repair_id"],
	"use_ability": ["target_id"], "vote": ["choice", "choice_id"],
	"revive": ["target_id"], "ready": ["ready"], "ping": ["position"],
	"pause": ["paused"], "host_event": ["event_id"],
	"set_profile": ["name", "role_id"], "set_name": ["name"], "toggle_lamp": ["enabled"], "open_vote": []
}
var _paused: bool = false

func authorize(peer_id: int, action: String, payload: Dictionary, roster: RefCounted) -> Dictionary:
	var profile_id: String = roster.profile_for_peer(peer_id)
	if profile_id.is_empty():
		return _failure("unknown_sender")
	if not FIELDS.has(action):
		return _failure("unknown_action")
	if action in ["pause", "host_event"] and peer_id != 1:
		return _failure("not_host")
	for key: Variant in payload:
		if not key is String or key not in FIELDS[action] or not _bounded(payload[key]) or not _field_type(key, payload[key]):
			return _failure("invalid_payload")
	if _paused and action != "pause":
		if action != "host_event" or payload.get("event_id", "") not in ["clear_event", "safe_return"]:
			return _failure("paused")
	return {"ok": true, "code": "authorized", "profile_id": profile_id}

func set_paused(value: bool) -> void:
	_paused = value

func _bounded(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return true
		TYPE_INT:
			return absi(value) <= 10000
		TYPE_FLOAT:
			return is_finite(value) and absf(value) <= 10000.0
		TYPE_STRING:
			return value.length() <= 128 and not value.contains("://") and not value.contains("..")
		TYPE_VECTOR2, TYPE_VECTOR3:
			return value.is_finite() and value.length() <= 10000.0
	return false

func _field_type(key: String, value: Variant) -> bool:
	if key in ["held", "ready", "paused", "enabled", "jump"]:
		return value is bool
	if key in ["yaw", "pull", "held_s"]:
		return typeof(value) in [TYPE_INT, TYPE_FLOAT]
	if key == "direction":
		return (value is Vector2 or value is Vector3) and value.length() <= 1.1
	if key == "position":
		return value is Vector3
	return value is String

func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
