class_name CampaignRules
extends RefCounted

const ALL_REPAIRS: Array[String] = ["workshop", "return_walkway", "ridge_steps", "beacon", "moth_engine"]
const REQUIRED_REPAIRS: Array[String] = ["beacon", "moth_engine"]

static func required_repairs() -> Array[String]:
	return REQUIRED_REPAIRS.duplicate()

static func status(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"stage": "escape", "title": "Cross the outer channel", "objective": "At night, arm Moth, signal from the beacon, then bring everyone aboard and ready.", "repair_id": "", "can_escape": true, "completed": bool(state.get("campaign_flags", {}).get("escaped", false)), "repairs": [], "tools": {}, "collection_objective": ""}
	var next_priority: int = -1
	for id: String in ALL_REPAIRS:
		var repair: Dictionary = IslandContent.repair(id)
		repair.salvage = repair.get("salvage", {})
		repair.flags = repair.get("flags", [])
		repair.id = id
		repair.marker = IslandContent.repair_markers().get(id, "")
		repair.complete = bool(state.get("repairs", {}).get(id, false))
		repair.available = requirements_met(state, repair)
		repair.optional = id not in REQUIRED_REPAIRS
		result.repairs.append(repair)
		if not repair.optional and not repair.complete:
			result.can_escape = false
			# Either essential can come first. Prefer one the crew can repair now,
			# then one whose part is already found, over a fresh scavenging target.
			var part_found: bool = true
			for flag: String in repair.flags:
				part_found = part_found and bool(state.get("campaign_flags", {}).get(flag, false))
			var priority: int = 2 if repair.available else (1 if part_found else 0)
			if priority > next_priority:
				next_priority = priority
				result.repair_id = id
				result.stage = repair.stage
				result.title = repair.name
				result.objective = "%s: %s." % [repair.location, repair.requirements]
	for role: String in ["scout", "keeper", "rigger"]:
		var info: Dictionary = tool_info(role)
		info.unlocked = tool_unlocked(state, role)
		result.tools[role] = info
	if result.completed:
		# Completion is a durable record. It must not disable another outing's
		# arm/signal/escape sequence or replace that goal with collection chores.
		result.collection_objective = _collection_objective(state)
	return result

static func _collection_objective(state: Dictionary) -> String:
	var catalog: Dictionary = Species.catalog()
	for id: String in catalog:
		if id not in state.get("discoveries", []):
			return "Find %s · %s." % [catalog[id].name, str(catalog[id].habitat_hint).to_lower()]
	var best: float = float(state.get("specimen_records", {}).get("penny_perch", {}).get("largest_size", 0.0))
	return "Beat your %.2f m Penny Perch record · fish the Jetty with a different rod." % best

static func requirements_met(state: Dictionary, requirements: Dictionary) -> bool:
	if int(state.get("coins", 0)) < int(requirements.get("coins", 0)):
		return false
	for id: String in requirements.get("prerequisites", []):
		if not bool(state.get("repairs", {}).get(id, false)):
			return false
	for id: String in requirements.get("flags", []):
		if not bool(state.get("campaign_flags", {}).get(id, false)):
			return false
	for id: String in requirements.get("salvage", {}):
		if int(state.get("salvage", {}).get(id, 0)) < int(requirements.salvage[id]):
			return false
	return true

static func tool_unlocked(state: Dictionary, role: String) -> bool:
	match role:
		"scout": return state.get("discoveries", []).size() >= 6
		"keeper": return bool(state.get("repairs", {}).get("beacon", false))
		"rigger": return bool(state.get("repairs", {}).get("return_walkway", false))
	return false

static func tool_info(role: String) -> Dictionary:
	match role:
		"scout": return {"name": "Trail Mark", "hint": "Discover six different species", "description": "Shows a path home for 10 seconds instead of revealing the Lifeguard for 5 seconds. Cooldown: 40 seconds (standard: 30)."}
		"keeper": return {"name": "Steady Glow", "hint": "Restore the beacon", "description": "Protects a 2.5 m circle for 7 seconds; standard protects 4.5 m for 4 seconds. Cooldown: 40 seconds (standard: 30)."}
		"rigger": return {"name": "Long Line", "hint": "Repair the return walkway", "description": "Reaches 8 m for rescue or a 10% catch boost; standard reaches 5 m with a 20% boost. Cooldown: 40 seconds (standard: 30)."}
	return {"name": "", "hint": "Unknown role"}
