extends RefCounted
## A quiet first-loop suggestion, derived entirely from existing saved progress.
## It never gates play, creates quests, or writes onboarding state into a save.

static func next_step(data: Dictionary, profile: String, surroundings: Dictionary) -> Dictionary:
	var run: Dictionary = data.get("run", {})
	if bool(run.get("paused", false)) or bool(run.get("terminal", false)) or str(run.get("phase", "day")) != "day" or float(run.get("crossing_left", -1.0)) >= 0.0:
		return {}
	if data.get("fishing", {}).has(profile) or not data.get("rescue_progress", {}).is_empty(): return {}
	for supply: Dictionary in data.get("supplies", {}).values():
		if supply.get("state", "") == "held" and supply.get("carrier_id", "") == profile: return {}
	for player: Dictionary in run.get("players", {}).values():
		if bool(player.get("downed", false)) or not str(player.get("carried_by", "")).is_empty(): return {}
	if data.get("hunter", "") in ["warn", "chase"] and str(data.get("hunter_target", "")) == profile: return {}
	var saved: Dictionary = data.get("progression", {})
	var banked: bool = not saved.get("banked_catch_ids", []).is_empty()
	if banked and str(saved.get("profiles", {}).get(profile, {}).get("rod_id", "starter")) != "starter": return {}
	var key: String = str(surroundings.get("interact", "E"))
	var at: Vector3 = surroundings.get("position", Vector3.ZERO)
	var markers: Dictionary = surroundings.get("markers", {})
	if not banked:
		var loose: bool = false
		for cargo: Dictionary in data.get("cargo", {}).values():
			if (cargo.get("state", "") == "packed" and cargo.get("pouch_profile_id", "") == profile) or (cargo.get("state", "") == "whole_held" and cargo.get("carrier_id", "") == profile):
				var distance: int = _distance(at, markers, "boat")
				return {"title": "Bring it home", "detail": ("%s · bank your catch at Moth" % key) if distance <= 3 else ("Moth · %d m\nBank your catch for crew coins." % distance)}
			if cargo.get("state", "") == "whole_loose" and cargo.get("catch_record", {}).get("profile_id", "") == profile:
				loose = true
		if loose: return {"title": "That's a big one", "detail": "%s near the fish · pick it up\nCarry it home to Moth." % key}
		if surroundings.get("habitat", "") == "reeds" and at.distance_to(markers.get("reeds", at)) < 8.0:
			return {"title": "Beyond the shelter", "detail": "Walk farther along the shore.\nReeds fishing starts beyond the lights."}
		if not str(surroundings.get("habitat", "")).is_empty():
			return {"title": "Your first catch", "detail": "LMB · cast into the water\nHold right · release left · follow the fish."}
		return {"title": "Your first catch", "detail": "Jetty · %d m\nWalk down to the water to cast." % _distance(at, markers, "jetty")}
	if "soft_tip" in saved.get("owned_rods", []):
		var distance: int = _distance(at, markers, "boat")
		var workshop: String = str(surroundings.get("workshop", "K"))
		return {"title": "Soft-tip Rod found", "detail": ("%s · Gear at Moth\nTry your new rod." % workshop) if distance <= 3 else ("Moth · %d m\nReturn to try your Soft-tip Rod." % distance)}
	var distance: int = _distance(at, markers, "rod_cache")
	return {"title": "A better rod awaits", "detail": ("%s · open the shore rod cache" % key) if distance <= 3 else ("Shore rod cache · %d m\nFollow the coast past the Jetty." % distance)}

static func _distance(at: Vector3, markers: Dictionary, marker: String) -> int:
	return ceili(at.distance_to(markers.get(marker, at)))
