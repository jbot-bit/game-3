extends RefCounted
## A quiet next step, derived entirely from existing campaign and run state.
## It never gates play, creates quests, or writes onboarding state into a save.

const Campaign = preload("res://game/progression/campaign_rules.gd")
const Content = preload("res://game/world/island_content.gd")
const Fish = preload("res://game/fishing/species.gd")

static func next_step(data: Dictionary, profile: String, surroundings: Dictionary) -> Dictionary:
	var run: Dictionary = data.get("run", {})
	if bool(run.get("paused", false)) or bool(run.get("terminal", false)) or float(run.get("crossing_left", -1.0)) >= 0.0 or bool(data.get("escape", {}).get("departing", false)):
		return {}
	if data.get("fishing", {}).has(profile) or not data.get("rescue_progress", {}).is_empty(): return {}
	for supply: Dictionary in data.get("supplies", {}).values():
		if supply.get("state", "") == "held" and supply.get("carrier_id", "") == profile: return {}
	for player: Dictionary in run.get("players", {}).values():
		if bool(player.get("downed", false)) or not str(player.get("carried_by", "")).is_empty(): return {}
	if data.get("hunter", "") in ["warn", "chase"] and str(data.get("hunter_target", "")) == profile: return {}
	var saved: Dictionary = data.get("progression", {})
	var banked: bool = not saved.get("banked_catch_ids", []).is_empty()
	var key: String = str(surroundings.get("interact", "E"))
	var at: Vector3 = surroundings.get("position", Vector3.ZERO)
	var markers: Dictionary = surroundings.get("markers", {})
	var campaign: Dictionary = Campaign.status(saved)
	if not banked and not bool(campaign.completed):
		var loose: bool = false
		for cargo: Dictionary in data.get("cargo", {}).values():
			if (cargo.get("state", "") == "packed" and cargo.get("pouch_profile_id", "") == profile) or (cargo.get("state", "") == "whole_held" and cargo.get("carrier_id", "") == profile):
				return _bank_step(surroundings, "Bank your catch for crew coins.")
			if cargo.get("state", "") == "whole_loose" and cargo.get("catch_record", {}).get("profile_id", "") == profile:
				loose = true
		if loose: return {"title": "That's a big one", "detail": "%s near the fish · pick it up\nCarry it home to Moth." % key}
		if surroundings.get("habitat", "") == "reeds" and at.distance_to(markers.get("reeds", at)) < 8.0:
			return {"title": "Beyond the shelter", "detail": "Walk farther along the shore.\nReeds fishing starts beyond the lights."}
		if not str(surroundings.get("habitat", "")).is_empty():
			return {"title": "Your first catch", "detail": "LMB · cast into the water\nHold right · release left · follow the fish.", "marker": _fishing_marker(surroundings), "action": "cast", "payload": {}}
		return {"title": "Your first catch", "detail": "Jetty · %d m\nWalk down to the water to cast." % _distance(at, markers, "jetty"), "marker": "jetty", "action": "cast", "payload": {}}
	# Finding the optional rod completes this introduction; equipping it is a choice.
	if "soft_tip" not in saved.get("owned_rods", []) and not _essential_progress(saved) and not bool(campaign.completed):
		return _waypoint("A better rod awaits", "Shore rod cache", "rod_cache", surroundings, "%s · open the shore rod cache" % key, "Follow the coast past the Jetty.", "open_cache", {"cache_id": "shore_rod_cache"})
	var step: Dictionary = _campaign_step(data, profile, surroundings, campaign)
	if "soft_tip" in saved.get("owned_rods", []) and str(saved.get("profiles", {}).get(profile, {}).get("rod_id", "starter")) == "starter" and _near(surroundings, "boat"):
		step.detail = str(step.get("detail", "")) + "\n%s · Gear: try Soft-tip (optional)." % str(surroundings.get("workshop", "K"))
	return step

static func _essential_progress(saved: Dictionary) -> bool:
	for id: String in Campaign.required_repairs():
		if bool(saved.get("repairs", {}).get(id, false)): return true
		for flag: String in Content.repair(id).get("flags", []):
			if bool(saved.get("campaign_flags", {}).get(flag, false)): return true
	return false

static func _campaign_step(data: Dictionary, profile: String, surroundings: Dictionary, campaign: Dictionary) -> Dictionary:
	var saved: Dictionary = data.get("progression", {})
	var escape: Dictionary = data.get("escape", {})
	var key: String = str(surroundings.get("interact", "E"))
	var bank_value: int = _local_bank_value(data.get("cargo", {}), profile)
	for entry: Dictionary in data.get("cargo", {}).values():
		if entry.get("state", "") == "whole_held" and entry.get("carrier_id", "") == profile:
			return _bank_step(surroundings, "Deliver whole fish for a bigger payout.")
	# Match Moth's real E interaction: bank local cargo before repairing or arming.
	if bank_value > 0 and _near(surroundings, "boat"):
		return _bank_step(surroundings, "Keep your catch's coins before the next step.")
	if bool(campaign.completed) and not bool(escape.get("armed", false)) and not bool(escape.get("signalled", false)):
		return {"title": "The island is yours", "detail": str(campaign.collection_objective) + "\nExplore, collect, or choose another night escape."}
	if bool(campaign.can_escape): return _escape_step(data, surroundings)
	var repair_id: String = str(campaign.repair_id)
	var repair: Dictionary = Content.repair(repair_id)
	var shortfall: int = maxi(0, int(repair.get("coins", 0)) - int(saved.get("coins", 0)))
	if shortfall > 0 and bank_value >= shortfall:
		return _bank_step(surroundings, "Bank %d coins toward your next repair." % bank_value)
	for flag: String in repair.get("flags", []):
		if bool(saved.get("campaign_flags", {}).get(flag, false)): continue
		for cache_id: String in Content.cache_markers():
			var cache: Dictionary = Content.cache(cache_id)
			if flag not in cache.get("flags", []): continue
			return _waypoint("Find " + str(cache.name), str(cache.name), str(Content.cache_markers()[cache_id]), surroundings, "%s · open the cache" % key, "For " + str(repair.name).to_lower() + ".", "open_cache", {"cache_id": cache_id})
	if Campaign.requirements_met(saved, repair):
		return _waypoint(str(repair.name), str(repair.location), str(Content.repair_markers()[repair_id]), surroundings, "%s · repair (%d coins)" % [key, int(repair.get("coins", 0))], "Ready to repair · %d shared coins." % int(repair.get("coins", 0)), "repair", {"repair_id": repair_id})
	var marker: String = _fishing_marker(surroundings)
	var detail: String = "%d more banked coins needed.\nFish and bank your catch at Moth." % shortfall
	if str(surroundings.get("habitat", "")).is_empty():
		detail = "Jetty · %d m\nFish and bank %d more coins at Moth." % [_distance(surroundings.get("position", Vector3.ZERO), surroundings.get("markers", {}), "jetty"), shortfall]
	return {"title": str(repair.name), "detail": detail, "marker": marker, "action": "cast", "payload": {}}

static func _escape_step(data: Dictionary, surroundings: Dictionary) -> Dictionary:
	var escape: Dictionary = data.get("escape", {})
	var run: Dictionary = data.get("run", {})
	var key: String = str(surroundings.get("interact", "E"))
	var ready: String = str(surroundings.get("ready", "B"))
	if bool(escape.get("signalled", false)):
		return _waypoint("Bring everyone home", "Moth", "boat", surroundings, "%s · ready to escape\nEveryone must board and ready." % ready, "Board together, then %s · ready to escape." % ready, "ready", {"ready": true})
	if bool(escape.get("armed", false)):
		return _waypoint("Signal the escape", "Beacon ridge", "beacon_repair", surroundings, "%s · send the beacon signal" % key, "Signal the channel, then return to Moth.", "signal_escape", {})
	if bool(escape.get("can_arm", false)):
		return _waypoint("Prepare the night escape", "Moth", "boat", surroundings, "%s · prepare the night escape" % key, "The boat and beacon are repaired.", "arm_escape", {})
	if str(run.get("phase", "day")) in ["day", "dusk"]:
		return {"title": "Boat ready", "detail": "Explore or collect until night.\nThen prepare the escape at Moth."}
	return _waypoint("Return safely", "Moth", "boat", surroundings, "%s · ready for refuge" % ready, "The escape window has closed. Return with your catch.", "ready", {"ready": true})

static func _local_bank_value(cargo: Dictionary, profile: String) -> int:
	var total: int = 0
	for entry: Dictionary in cargo.values():
		var packed: bool = entry.get("state", "") == "packed" and entry.get("pouch_profile_id", "") == profile
		var whole: bool = entry.get("state", "") == "whole_held" and entry.get("carrier_id", "") == profile
		if not packed and not whole: continue
		var record: Dictionary = entry.get("catch_record", {})
		total += maxi(0, Fish.value_for(str(record.get("species_id", "")), str(record.get("trait_id", "none")), whole))
	return total

static func _bank_step(surroundings: Dictionary, reason: String) -> Dictionary:
	return _waypoint("Bring it home", "Moth", "boat", surroundings, "%s · bank your catch at Moth" % str(surroundings.get("interact", "E")), reason, "bank", {})

static func _fishing_marker(surroundings: Dictionary) -> String:
	var habitat: String = str(surroundings.get("habitat", ""))
	if habitat == "reeds": return "reeds_cast"
	return habitat if not habitat.is_empty() else "jetty"

static func _waypoint(title: String, label: String, marker: String, surroundings: Dictionary, nearby: String, away: String, action: String, payload: Dictionary) -> Dictionary:
	var distance: int = _distance(surroundings.get("position", Vector3.ZERO), surroundings.get("markers", {}), marker)
	return {"title": title, "detail": nearby if _near(surroundings, marker) else "%s · %d m\n%s" % [label, distance, away], "marker": marker, "action": action, "payload": payload}

static func _near(surroundings: Dictionary, marker: String) -> bool:
	var markers: Dictionary = surroundings.get("markers", {})
	return markers.has(marker) and (surroundings.get("position", Vector3.ZERO) as Vector3).distance_to(markers[marker]) <= 3.0

static func _distance(at: Vector3, markers: Dictionary, marker: String) -> int:
	return ceili(at.distance_to(markers.get(marker, at)))
