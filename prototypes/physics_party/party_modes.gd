extends RefCounted
const IDS: Array[String] = ["coop", "gladiator", "wipeout", "knockout"]
const NAMES: Dictionary = {"coop": "Co-op", "gladiator": "Gladiator", "wipeout": "Wipeout", "knockout": "Knockout"}

static func valid(id: String) -> bool: return id in IDS
static func mode_name(id: String) -> String: return NAMES.get(id, "Unknown mode")
static func is_ring_match(id: String) -> bool: return id in ["gladiator", "knockout"]
