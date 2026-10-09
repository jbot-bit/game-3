class_name CatchTable
extends RefCounted
const FishData = preload("res://game/fishing/species.gd")

static func pool(habitat_id: String, time_band: String) -> Array[Dictionary]:
	## Ordered probabilities shared by the actual roll and the journal.
	if time_band not in ["day", "dusk", "night", "storm"]:
		return []
	var dark: bool = time_band != "day"
	match habitat_id:
		"jetty": return _pool(["penny_perch","bellgill"],[0.7,0.3])
		"reeds":
			return _pool(["penny_perch","bellgill","lantern_eel"],[0.6,0.3,0.1]) if dark else _pool(["penny_perch","bellgill"],[0.7,0.3])
		"terraces":
			return _pool(["pebble_dab","ribbon_minnow","moss_skipper","glass_roach","cloud_carp"],[0.3,0.2,0.2,0.2,0.1]) if dark else _pool(["pebble_dab","ribbon_minnow","moss_skipper","glass_roach"],[0.35,0.3,0.2,0.15])
		"tidepools":
			return _pool(["cork_chub","kite_sprat","copperfin","glass_roach"],[0.25,0.3,0.25,0.2]) if dark else _pool(["cork_chub","kite_sprat","copperfin","glass_roach"],[0.35,0.3,0.2,0.15])
		"beacon":
			return _pool(["moss_skipper","kite_sprat","cloud_carp","copperfin","crown_ray"],[0.2,0.2,0.3,0.2,0.1]) if dark else _pool(["moss_skipper","kite_sprat","cloud_carp","copperfin"],[0.3,0.3,0.25,0.15])
	return []

static func _pool(ids: Array, chances: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(ids.size()):
		result.append({"species_id":str(ids[index]),"chance":float(chances[index])})
	return result

static func roll(habitat_id: String, time_band: String, dry_streak: int, species_roll: float, trait_roll: float, size_roll: float) -> Dictionary:
	for v in [species_roll, trait_roll, size_roll]:
		if not is_finite(v) or v < 0.0 or v >= 1.0:
			return {"ok": false, "code": "invalid_roll"}
	var entries: Array[Dictionary] = pool(habitat_id, time_band)
	if entries.is_empty():
		return {"ok": false, "code": "invalid_pool"}
	var rare_id: String = ""
	for entry: Dictionary in entries:
		if FishData.is_rare(entry.species_id): rare_id = entry.species_id
	var species_id: String = str(entries.back().species_id)
	var upper: float = 0.0
	for entry: Dictionary in entries:
		# Round authored decimal odds so exact 0.6/0.7/0.9 boundaries stay stable.
		upper = snappedf(upper + float(entry.chance), 0.000001)
		if species_roll < upper:
			species_id = entry.species_id
			break
	if dry_streak >= 11 and not rare_id.is_empty(): species_id = rare_id
	var trait_id: String = "none"
	if trait_roll < 0.1: trait_id = "oversized"
	elif time_band == "storm" and trait_roll < 0.2: trait_id = "stormmarked"
	elif time_band in ["dusk","night"] and trait_roll < 0.18: trait_id = "moonlit"
	return {"ok":true, "code":"rolled", "species_id":species_id,
		"habitat_id":habitat_id, "rare_eligible":not rare_id.is_empty(),
		"trait_id":trait_id,
		"size":snappedf((0.6 + size_roll * 0.8) * (2.0 if trait_id == "oversized" else 1.0), 0.01),
		"catch_value":FishData.value_for(species_id,trait_id)}

static func next_streak(current: int, rare_eligible: bool, rare_landed: bool) -> int:
	if not rare_eligible:
		return current
	return 0 if rare_landed else mini(current + 1, 11)
