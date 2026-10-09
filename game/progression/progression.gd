class_name Progression
extends RefCounted

var _store: SaveStore
var _state: Dictionary

static func blank_state() -> Dictionary:
	return {
		"schema_version": 1, "household_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"revision": 0, "coins": 0, "lifetime_banked": 0, "salvage": {},
		"known_recipes": [], "owned_rods": ["starter"], "owned_lamps": ["flood"],
		"discoveries": [], "specimen_records": {}, "dry_streaks": {},
		"opened_caches": [], "repairs": {}, "campaign_flags": {}, "day_index": 0,
		"profiles": {
			"crew_1": {"name": "Angler 1", "role_id": "scout", "rod_id": "starter", "lamp_id": "flood", "tool_mode": "standard"},
			"crew_2": {"name": "Angler 2", "role_id": "keeper", "rod_id": "starter", "lamp_id": "flood", "tool_mode": "standard"},
			"crew_3": {"name": "Angler 3", "role_id": "rigger", "rod_id": "starter", "lamp_id": "flood", "tool_mode": "standard"}},
		"landed_catch_ids": [], "banked_catch_ids": [], "craft_ids": [],
		"repair_ids": [], "settled_run_ids": []}

func _init(store: SaveStore, initial_state: Dictionary) -> void:
	_store = store
	_state = SaveStore.with_defaults(initial_state)

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func record_specimen(catch_record: Dictionary) -> Dictionary:
	if not _valid_catch(catch_record):
		return _failure("invalid_catch")
	var id: String = catch_record.catch_id
	if id in _state.landed_catch_ids:
		return _failure("duplicate")
	if catch_record.run_id in _state.settled_run_ids:
		return _failure("run_settled")
	var next: Dictionary = snapshot()
	var species: String = catch_record.species_id
	var first_discovery: bool = species not in next.discoveries
	if first_discovery:
		next.discoveries.append(species)
	if next.discoveries.size() >= 6 and "drift_rod" not in next.owned_rods:
		next.owned_rods.append("drift_rod")
	var record: Dictionary = next.specimen_records.get(species, {
		"count": 0, "largest_size": 0.0, "largest_catch_id": "", "angler_profile_id": "", "traits": []})
	record.count = int(record.count) + 1
	var new_record: bool = float(catch_record.size) > float(record.largest_size)
	if new_record:
		record.largest_size = float(catch_record.size)
		record.largest_catch_id = id
		record.angler_profile_id = catch_record.profile_id
	var trait_id: String = catch_record.trait_id
	if trait_id not in ["", "none"] and trait_id not in record.traits:
		record.traits.append(trait_id)
	next.specimen_records[species] = record
	if catch_record.rare_eligible:
		var habitat: String = catch_record.habitat_id
		next.dry_streaks[habitat] = 0 if Species.is_rare(species) else int(next.dry_streaks.get(habitat, 0)) + 1
	next.landed_catch_ids.append(id)
	return _commit(next, {"new_discovery": first_discovery, "new_record": new_record, "catch_id": id})

func bank(catches: Array[Dictionary], delivery_modes: Dictionary = {}) -> Dictionary:
	if catches.is_empty():
		return _failure("empty_batch")
	var next: Dictionary = snapshot()
	var result: Dictionary = _apply_bank(next, catches, delivery_modes)
	if not result.ok:
		return result
	return _commit(next, {"awarded": result.awarded, "catch_ids": result.catch_ids})

func settle_run(run_id: String, catches: Array[Dictionary], delivery_modes: Dictionary = {}, complete_campaign: bool = false) -> Dictionary:
	if run_id.is_empty():
		return _failure("invalid_run")
	if run_id in _state.settled_run_ids:
		return _failure("duplicate")
	if complete_campaign and not CampaignRules.status(_state).can_escape:
		return _failure("campaign_locked")
	for record: Dictionary in catches:
		if record.get("run_id", "") != run_id:
			return _failure("wrong_run")
	var next: Dictionary = snapshot()
	var result: Dictionary = _apply_bank(next, catches, delivery_modes)
	if not result.ok:
		return result
	next.settled_run_ids.append(run_id)
	next.day_index = int(next.day_index) + 1
	if complete_campaign:
		next.campaign_flags["escaped"] = true
	return _commit(next, {"awarded": result.awarded, "catch_ids": result.catch_ids, "run_id": run_id, "day_index": next.day_index})

func set_lamp(profile_id: String, lamp_id: String) -> Dictionary:
	return _set_gear(profile_id, "lamp_id", lamp_id, "owned_lamps")

func set_tool(profile_id: String, mode: String) -> Dictionary:
	if not _state.profiles.has(profile_id):
		return _failure("unknown_profile")
	if mode not in ["standard", "alternate"]:
		return _failure("invalid_tool")
	if mode == "alternate" and not CampaignRules.tool_unlocked(_state, _state.profiles[profile_id].role_id):
		return _failure("locked")
	var next: Dictionary = snapshot()
	next.profiles[profile_id].tool_mode = mode
	return _commit(next, {"profile_id": profile_id, "tool_mode": mode})

func set_rod(profile_id: String, rod_id: String) -> Dictionary:
	return _set_gear(profile_id, "rod_id", rod_id, "owned_rods")

func set_profile(profile_id: String, display_name: String, role_id: String) -> Dictionary:
	if not _state.profiles.has(profile_id):
		return _failure("unknown_profile")
	var cleaned_name: String = display_name.strip_edges()
	if cleaned_name.is_empty() or cleaned_name.length() > 32:
		return _failure("invalid_name")
	for i: int in range(cleaned_name.length()):
		if cleaned_name.unicode_at(i) < 32 or cleaned_name.unicode_at(i) == 127:
			return _failure("invalid_name")
	if role_id not in ["scout", "keeper", "rigger"]:
		return _failure("invalid_role")
	var next: Dictionary = snapshot()
	next.profiles[profile_id].name = cleaned_name
	next.profiles[profile_id].role_id = role_id
	if not CampaignRules.tool_unlocked(next, role_id):
		next.profiles[profile_id].tool_mode = "standard"
	return _commit(next, {"profile_id": profile_id})

func open_cache(cache_id: String) -> Dictionary:
	var contents: Dictionary = IslandContent.cache(cache_id)
	if contents.is_empty():
		return _failure("unknown_cache")
	if cache_id in _state.opened_caches:
		return _failure("already_opened")
	var next: Dictionary = snapshot()
	for recipe_id: String in contents.get("recipes", []):
		if recipe_id not in next.known_recipes:
			next.known_recipes.append(recipe_id)
	for rod_id: String in contents.get("rods", []):
		if rod_id not in next.owned_rods:
			next.owned_rods.append(rod_id)
	var salvage: Dictionary = contents.get("salvage", {})
	for id: String in salvage:
		next.salvage[id] = int(next.salvage.get(id, 0)) + int(salvage[id])
	for id: String in contents.get("flags", []):
		next.campaign_flags[id] = true
	next.opened_caches.append(cache_id)
	return _commit(next, {"cache_id": cache_id})

func craft(recipe_id: String, transaction_id: String) -> Dictionary:
	if transaction_id.is_empty():
		return _failure("invalid_transaction")
	if transaction_id in _state.craft_ids:
		return _failure("duplicate")
	var recipe: Dictionary = Crafting.recipe(recipe_id)
	if recipe.is_empty():
		return _failure("unknown_recipe")
	if recipe_id not in _state.known_recipes:
		return _failure("recipe_locked")
	var owned_field: String = "owned_lamps" if recipe.output_kind == "lamp" else "owned_rods"
	if recipe.output_id in _state[owned_field]:
		return _failure("already_owned")
	var next: Dictionary = snapshot()
	if not _consume_requirements(next, recipe):
		return _failure("missing_requirements")
	next[owned_field].append(recipe.output_id)
	next.craft_ids.append(transaction_id)
	return _commit(next, {"recipe_id": recipe_id, "output_id": recipe.output_id})

func repair(repair_id: String, transaction_id: String) -> Dictionary:
	if transaction_id.is_empty():
		return _failure("invalid_transaction")
	if transaction_id in _state.repair_ids:
		return _failure("duplicate")
	var requirements: Dictionary = IslandContent.repair(repair_id)
	if requirements.is_empty():
		return _failure("unknown_repair")
	if _state.repairs.get(repair_id, false):
		return _failure("already_repaired")
	for id: String in requirements.get("prerequisites", []):
		if not _state.repairs.get(id, false):
			return _failure("prerequisite_locked")
	var next: Dictionary = snapshot()
	if not _consume_requirements(next, requirements):
		return _failure("missing_requirements")
	next.repairs[repair_id] = true
	next.repair_ids.append(transaction_id)
	return _commit(next, {"repair_id": repair_id})

func _apply_bank(next: Dictionary, catches: Array[Dictionary], modes: Dictionary) -> Dictionary:
	var ids: Array[String] = []
	var amount: int = 0
	for record: Dictionary in catches:
		if not _valid_catch(record):
			return _failure("invalid_catch")
		var id: String = record.catch_id
		if id in next.banked_catch_ids or id in ids:
			return _failure("duplicate")
		if id not in next.landed_catch_ids:
			return _failure("unrecorded_catch")
		if record.run_id in next.settled_run_ids:
			return _failure("run_settled")
		var mode: String = str(modes.get(id, "packed"))
		if mode not in ["packed", "whole"] or mode == "whole" and record.trait_id != "oversized":
			return _failure("invalid_delivery")
		amount += Species.value_for(record.species_id, record.trait_id, mode == "whole")
		ids.append(id)
	for id: Variant in modes:
		if id not in ids:
			return _failure("unknown_delivery")
	next.coins = int(next.coins) + amount
	next.lifetime_banked = int(next.lifetime_banked) + amount
	for id: String in ids:
		next.banked_catch_ids.append(id)
	return {"ok": true, "code": "ok", "awarded": amount, "catch_ids": ids}

func _set_gear(profile_id: String, slot: String, item_id: String, owned_field: String) -> Dictionary:
	if not _state.profiles.has(profile_id):
		return _failure("unknown_profile")
	if item_id not in _state[owned_field]:
		return _failure("locked")
	var next: Dictionary = snapshot()
	next.profiles[profile_id][slot] = item_id
	return _commit(next, {"profile_id": profile_id, slot: item_id})

func _consume_requirements(next: Dictionary, requirements: Dictionary) -> bool:
	var coins: int = int(requirements.get("coins", 0))
	var salvage: Dictionary = requirements.get("salvage", {})
	if int(next.coins) < coins:
		return false
	for id: String in requirements.get("flags", []):
		if not next.campaign_flags.get(id, false):
			return false
	for id: String in salvage:
		if int(next.salvage.get(id, 0)) < int(salvage[id]):
			return false
	next.coins = int(next.coins) - coins
	for id: String in salvage:
		next.salvage[id] = int(next.salvage[id]) - int(salvage[id])
	return true

func _valid_catch(record: Dictionary) -> bool:
	for key: String in ["catch_id", "run_id", "profile_id", "species_id", "habitat_id", "trait_id"]:
		if not record.get(key) is String:
			return false
	if record.catch_id.is_empty() or record.run_id.is_empty() or record.habitat_id.is_empty():
		return false
	if not _state.profiles.has(record.profile_id) or not Species.catalog().has(record.species_id):
		return false
	if record.trait_id not in ["", "none", "oversized", "moonlit", "stormmarked"] or not record.get("rare_eligible") is bool:
		return false
	if not record.get("size") is float and not record.get("size") is int:
		return false
	return is_finite(float(record.size)) and float(record.size) > 0.0

func _commit(next: Dictionary, extra: Dictionary = {}) -> Dictionary:
	next.revision = int(_state.revision) + 1
	var error: Error = _store.commit(next)
	if error != OK:
		return {"ok": false, "code": "save_failed", "error": error}
	_state = next
	var result: Dictionary = {"ok": true, "code": "ok", "revision": _state.revision}
	result.merge(extra)
	return result

func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
