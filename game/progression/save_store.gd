class_name SaveStore
extends RefCounted

var save_path: String

func _init(path: String = "user://household.json") -> void:
	save_path = path

func load_or_recover() -> Dictionary:
	for candidate: String in [save_path, save_path + ".bak"]:
		var loaded: Dictionary = _read_valid(candidate)
		if loaded.ok:
			loaded.source = "current" if candidate == save_path else "backup"
			return loaded
	var exists: bool = FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	return {"ok": false, "state": {}, "source": "none", "code": "corrupt" if exists else "not_found"}

func commit(next_state: Dictionary) -> Error:
	if not _valid_state(next_state):
		return ERR_INVALID_DATA
	var absolute: String = ProjectSettings.globalize_path(save_path)
	var has_prior: bool = FileAccess.file_exists(absolute) or FileAccess.file_exists(absolute + ".bak")
	if has_prior and not _read_valid(absolute).ok and not _read_valid(absolute + ".bak").ok:
		# A fresh game must use a new path or explicitly archive corrupt saves.
		return ERR_FILE_CORRUPT
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if mkdir_error != OK:
		return mkdir_error
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(next_state))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	if not _read_valid(temporary).ok:
		return ERR_FILE_CORRUPT
	# Never replace a good backup with a corrupt current file during recovery.
	if _read_valid(absolute).ok:
		var copy_error: Error = DirAccess.copy_absolute(absolute, absolute + ".bak.tmp")
		if copy_error != OK:
			return copy_error
		var backup_error: Error = _replace_file(absolute + ".bak.tmp", absolute + ".bak")
		if backup_error != OK:
			return backup_error
	# Same-directory rename keeps the old confirmed file until promotion succeeds.
	# A leftover .tmp is never treated as a committed save when loading.
	return _replace_file(temporary, absolute)

func _replace_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path, to_path)

func _read_valid(path: String) -> Dictionary:
	var failed: Dictionary = {"ok": false, "state": {}, "source": "none", "code": "invalid"}
	if not FileAccess.file_exists(path):
		return failed
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return failed
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return failed
	var state: Dictionary = parser.data
	if not _valid_state(state):
		return failed
	for key: String in ["schema_version", "revision", "coins", "lifetime_banked", "day_index"]:
		state[key] = int(state[key])
	for field: String in ["salvage", "dry_streaks"]:
		for key: Variant in state[field]:
			state[field][key] = int(state[field][key])
	for species: Variant in state.specimen_records:
		state.specimen_records[species].count = int(state.specimen_records[species].count)
	return {"ok": true, "state": state, "source": "current", "code": "ok"}

func _valid_state(state: Dictionary) -> bool:
	for key: String in ["schema_version", "revision", "coins", "lifetime_banked", "day_index"]:
		if not _nonnegative_integer(state.get(key)):
			return false
	if int(state.schema_version) != 1 or state.coins > state.lifetime_banked:
		return false
	if not state.get("household_id") is String or state.household_id.is_empty():
		return false
	for key: String in ["known_recipes", "owned_rods", "owned_lamps", "discoveries", "opened_caches", "landed_catch_ids", "banked_catch_ids", "craft_ids", "repair_ids", "settled_run_ids"]:
		if not _unique_strings(state.get(key)):
			return false
	for key: String in ["salvage", "specimen_records", "dry_streaks", "repairs", "campaign_flags", "profiles"]:
		if not state.get(key) is Dictionary:
			return false
	for key: String in ["salvage", "dry_streaks"]:
		for entry: Variant in state[key]:
			if not entry is String or entry.is_empty() or not _nonnegative_integer(state[key][entry]):
				return false
	for key: String in ["repairs", "campaign_flags"]:
		for entry: Variant in state[key]:
			if not entry is String or not state[key][entry] is bool:
				return false
	if state.profiles.size() != 3:
		return false
	for id: String in ["crew_1", "crew_2", "crew_3"]:
		if not state.profiles.get(id) is Dictionary:
			return false
		var profile: Dictionary = state.profiles[id]
		for key: String in ["name", "role_id", "rod_id", "lamp_id"]:
			if not profile.get(key) is String:
				return false
		if profile.role_id not in ["scout", "keeper", "rigger"] or profile.rod_id not in state.owned_rods or profile.lamp_id not in state.owned_lamps:
			return false
	for species: Variant in state.specimen_records:
		if not species is String or not state.specimen_records[species] is Dictionary:
			return false
		var record: Dictionary = state.specimen_records[species]
		if not _nonnegative_integer(record.get("count")) or not record.get("largest_size") is float and not record.get("largest_size") is int:
			return false
		if not is_finite(float(record.largest_size)) or float(record.largest_size) < 0.0:
			return false
		if not record.get("largest_catch_id") is String or not record.get("angler_profile_id") is String or not _unique_strings(record.get("traits")):
			return false
	for id: String in state.banked_catch_ids:
		if id not in state.landed_catch_ids:
			return false
	return true

func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and float(value) == floor(float(value))

func _unique_strings(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is String or item.is_empty() or seen.has(item):
			return false
		seen[item] = true
	return true
