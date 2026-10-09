class_name CatchTable
extends RefCounted

static func roll(habitat_id: String, time_band: String, dry_streak: int, species_roll: float, trait_roll: float, size_roll: float) -> Dictionary:
	for v in [species_roll, trait_roll, size_roll]:
		if not is_finite(v) or v < 0.0 or v >= 1.0:
			return {"ok": false, "code": "invalid_roll"}
	if habitat_id not in ["jetty", "reeds"] or time_band not in ["day", "dusk", "night", "storm"]:
		return {"ok": false, "code": "invalid_pool"}
	var rare: bool = habitat_id == "reeds" and time_band != "day"
	var species_id: String = "penny_perch"
	if rare:
		if dry_streak >= 11 or species_roll >= 0.9:
			species_id = "lantern_eel"
		elif species_roll >= 0.6:
			species_id = "bellgill"
	elif species_roll >= 0.7:
		species_id = "bellgill"
	var base: int = {"penny_perch":10, "bellgill":20, "lantern_eel":40}[species_id]
	var oversized: bool = trait_roll < 0.1
	return {"ok":true, "code":"rolled", "species_id":species_id,
		"habitat_id":habitat_id, "rare_eligible":rare,
		"trait_id":"oversized" if oversized else "none",
		"size":snappedf((0.6 + size_roll * 0.8) * (2.0 if oversized else 1.0), 0.01),
		"catch_value":int(floor(base * 1.25)) if oversized else base}

static func next_streak(current: int, rare_eligible: bool, rare_landed: bool) -> int:
	if not rare_eligible:
		return current
	return 0 if rare_landed else mini(current + 1, 11)
