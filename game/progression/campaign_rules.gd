class_name CampaignRules
extends RefCounted

const ALL_REPAIRS: Array[String] = ["workshop", "return_walkway", "ridge_steps", "beacon", "moth_engine"]

static func required_repairs() -> Array[String]:
	return ALL_REPAIRS.duplicate()

static func status(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"stage": "escape", "title": "Cross the outer channel", "objective": "At night, arm Moth, signal from the beacon, then bring everyone aboard and ready.", "repair_id": "", "can_escape": true, "completed": bool(state.get("campaign_flags", {}).get("escaped", false)), "repairs": [], "tools": {}}
	for id: String in ALL_REPAIRS:
		var repair: Dictionary = IslandContent.repair(id)
		repair.salvage = repair.get("salvage", {})
		repair.flags = repair.get("flags", [])
		repair.id = id
		repair.marker = IslandContent.repair_markers().get(id, "")
		repair.complete = bool(state.get("repairs", {}).get(id, false))
		repair.available = requirements_met(state, repair)
		result.repairs.append(repair)
		if not repair.complete:
			result.can_escape = false
			if str(result.repair_id).is_empty():
				result.repair_id = id
				result.stage = repair.stage
				result.title = repair.name
				result.objective = "%s: %s." % [repair.location, repair.requirements]
	for role: String in ["scout", "keeper", "rigger"]:
		var info: Dictionary = tool_info(role)
		info.unlocked = tool_unlocked(state, role)
		result.tools[role] = info
	if result.completed:
		result.stage = "complete"
		result.title = "The channel is behind you"
		result.objective = "Your crew made it home. Continue Island to finish your collection and try another loadout."
		result.can_escape = false
	return result

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
