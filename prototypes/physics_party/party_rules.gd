extends RefCounted

const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
const DEFAULT_PATH: String = "user://physics_party/progress.json"
const POWER_IDS: Array[String] = ["spring", "heavy", "swift", "feather", "grip"]
const POWERS: Dictionary = {
	"spring": {"name": "SPRING LEGS", "description": "A stronger jump.", "jump": 1.3},
	"heavy": {"name": "HEAVYWEIGHT", "description": "More weight. Harder to shove.", "mass": 1.7},
	"swift": {"name": "QUICK FEET", "description": "Move 25% faster.", "speed": 1.25},
	"feather": {"name": "FEATHER FALL", "description": "Fall gently. Stay airborne longer.", "gravity": 0.7},
	"grip": {"name": "IRON GRIP", "description": "Stronger arms when grabbing.", "grip": 1.2},
}

var _save_path: String = ""
var _completed_runs: Array[String] = []
var _unlocked_power_ids: Array[String] = []
var _cosmetic_cards: Array[String] = []
var _last_reward: Dictionary = {}
var _appearance_by_slot: Dictionary = {}
var _pending_rewards: Dictionary = {}
var _staged_profile: Dictionary = {}
var reward_rng := RandomNumberGenerator.new()
var _loaded: bool = false
var _load_error: String = "not_loaded"
var progress: Dictionary:
	get:
		return {"level": 1 + floori(_completed_runs.size() / 3.0), "completions": _completed_runs.size(), "unlocked_power_ids": _unlocked_power_ids.duplicate()}

static func power_info(id: String) -> Dictionary:
	return POWERS.get(id, {}).duplicate(true)

func draw_offers(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = POWER_IDS.duplicate()
	var choices: Array[String] = []
	for index: int in range(3):
		var selected: int = rng.randi_range(0, pool.size() - 1)
		choices.append(pool[selected])
		pool.remove_at(selected)
	return choices

func load_progress(path: String = DEFAULT_PATH) -> Dictionary:
	_save_path = path
	_completed_runs.clear()
	_unlocked_power_ids.clear()
	_cosmetic_cards.clear()
	_last_reward.clear()
	_appearance_by_slot.clear()
	_pending_rewards.clear()
	_staged_profile.clear()
	_loaded = false
	_load_error = "corrupt"
	if path.is_empty() or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		_load_error = "invalid_path"
		return _result(false, _load_error)
	for candidate: String in [path, path + ".bak"]:
		var saved: Dictionary = _read_valid(candidate)
		if saved.get("ok", false):
			for run_id: String in saved.completed_runs:
				_completed_runs.append(run_id)
			for power_id: String in saved.unlocked_power_ids:
				_unlocked_power_ids.append(power_id)
			for card_id: String in saved.cosmetic_cards:
				_cosmetic_cards.append(card_id)
			_last_reward = saved.last_reward.duplicate(true)
			_appearance_by_slot = saved.appearance_by_slot.duplicate(true)
			_loaded = true
			_load_error = ""
			var loaded: Dictionary = _result(true, "ok")
			loaded.source = "current" if candidate == path else "backup"
			return loaded
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return _result(false, "corrupt")
	_loaded = true
	_load_error = ""
	return _result(true, "new")

func complete(run_id: String, found_powers: Array = []) -> Dictionary:
	if not _loaded:
		return _result(false, _load_error)
	if not _valid_run_id(run_id):
		return _result(false, "invalid_run")
	if not _valid_power_ids(found_powers, true):
		return _result(false, "invalid_power")
	if run_id in _completed_runs:
		var duplicate: Dictionary = _result(true, "already_saved")
		duplicate.duplicate = true
		return duplicate
	var next_runs: Array[String] = _completed_runs.duplicate()
	next_runs.append(run_id)
	var next_powers: Array[String] = []
	for power_id: String in POWER_IDS:
		if power_id in _unlocked_power_ids or power_id in found_powers:
			next_powers.append(power_id)
	# Keep a failed commit's roll in memory. Retrying cannot fish for rarer cards.
	if not _pending_rewards.has(run_id):
		_pending_rewards[run_id] = Cosmetics.draw_bag(_cosmetic_cards, reward_rng)
	var bag: Array = _pending_rewards[run_id]
	var next_cards: Array[String] = _cosmetic_cards.duplicate()
	for card_id: String in bag:
		if card_id not in next_cards:
			next_cards.append(card_id)
	var reward: Dictionary = {"run_id": run_id, "cards": bag.duplicate()}
	_staged_profile = {"cosmetic_cards": next_cards, "last_reward": reward}
	var error: Error = _commit(next_runs, next_powers)
	_staged_profile.clear()
	if error != OK:
		var failed: Dictionary = _result(false, "save_failed")
		failed.error = error
		return failed
	_completed_runs = next_runs
	_unlocked_power_ids = next_powers
	_cosmetic_cards = next_cards
	_last_reward = reward
	_pending_rewards.erase(run_id)
	return _result(true, "ok")

func cosmetic_collection() -> Array[String]:
	return _cosmetic_cards.duplicate()

func last_reward() -> Dictionary:
	return _last_reward.duplicate(true)

func appearance_for(slot: int) -> Dictionary:
	return Cosmetics.sanitize(_appearance_by_slot.get(str(slot), {}), _cosmetic_cards, slot)

func set_appearance(slot: int, style: Dictionary) -> Dictionary:
	if not _loaded:
		return _result(false, _load_error)
	if slot < 0 or slot > 2:
		return _result(false, "invalid_slot")
	if not _valid_style(style, _cosmetic_cards, slot):
		return _result(false, "invalid_appearance")
	if style == appearance_for(slot):
		var unchanged: Dictionary = _result(true, "already_saved")
		unchanged.appearance = appearance_for(slot)
		return unchanged
	var next_styles: Dictionary = _appearance_by_slot.duplicate(true)
	next_styles[str(slot)] = style.duplicate()
	_staged_profile = {"appearance_by_slot": next_styles}
	var error: Error = _commit(_completed_runs, _unlocked_power_ids)
	_staged_profile.clear()
	if error != OK:
		var failed: Dictionary = _result(false, "save_failed")
		failed.error = error
		return failed
	_appearance_by_slot = next_styles
	var saved: Dictionary = _result(true, "ok")
	saved.appearance = appearance_for(slot)
	return saved

func _result(ok: bool, code: String) -> Dictionary:
	var result: Dictionary = progress
	result.ok = ok
	result.code = code
	return result

func _commit(runs: Array[String], unlocked: Array[String]) -> Error:
	var path: String = ProjectSettings.globalize_path(_save_path)
	var current: Dictionary = _read_valid(path)
	var previous_exists: bool = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	if previous_exists and not current.get("ok", false) and not _read_valid(path + ".bak").get("ok", false):
		return ERR_FILE_CORRUPT
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "completed_runs": runs, "unlocked_power_ids": unlocked,
		"cosmetic_cards": _staged_profile.get("cosmetic_cards", _cosmetic_cards),
		"last_reward": _staged_profile.get("last_reward", _last_reward),
		"appearance_by_slot": _staged_profile.get("appearance_by_slot", _appearance_by_slot)}))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	if not _read_valid(path + ".tmp").get("ok", false):
		return ERR_FILE_CORRUPT
	# Preserve a confirmed backup; a corrupt current file never replaces it.
	if current.get("ok", false):
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK:
			return error
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return error
	# Only the same-directory promotion confirms the new completion.
	return DirAccess.rename_absolute(path + ".tmp", path)

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var saved: Dictionary = parser.data
	if saved.get("version") != 1 or not saved.get("completed_runs") is Array:
		return {}
	var seen: Dictionary = {}
	for run_id: Variant in saved.completed_runs:
		if not run_id is String or not _valid_run_id(run_id) or seen.has(run_id):
			return {}
		seen[run_id] = true
	var owned: Variant = saved.get("unlocked_power_ids", [])
	if not _valid_power_ids(owned):
		return {}
	var cards: Variant = saved.get("cosmetic_cards", [])
	if not _valid_card_ids(cards):
		return {}
	var reward: Variant = saved.get("last_reward", {})
	if not reward is Dictionary:
		return {}
	if not reward.is_empty():
		if reward.size() != 2 or not reward.get("run_id") is String or reward.get("run_id") not in seen:
			return {}
		if not _valid_card_ids(reward.get("cards"), true) or reward.cards.size() != 3:
			return {}
		for card_id: String in reward.cards:
			if card_id not in cards:
				return {}
	var appearances: Variant = saved.get("appearance_by_slot", {})
	if not appearances is Dictionary:
		return {}
	for slot: Variant in appearances:
		if not slot is String or slot not in ["0", "1", "2"] or not _valid_style(appearances[slot], cards, int(slot)):
			return {}
	return {"ok": true, "completed_runs": saved.completed_runs, "unlocked_power_ids": owned,
		"cosmetic_cards": cards, "last_reward": reward, "appearance_by_slot": appearances}

func _valid_card_ids(ids: Variant, duplicates_allowed: bool = false) -> bool:
	if not ids is Array:
		return false
	var seen: Dictionary = {}
	for id: Variant in ids:
		if not id is String or Cosmetics.card_info(id).is_empty() or (seen.has(id) and not duplicates_allowed):
			return false
		seen[id] = true
	return true

func _valid_style(style: Variant, owned: Array, slot: int) -> bool:
	return style is Dictionary and style.size() == 2 and style.get("color") is String and style.get("accessory") is String and Cosmetics.sanitize(style, owned, slot) == style

func _valid_power_ids(ids: Variant, duplicates_allowed: bool = false) -> bool:
	if not ids is Array:
		return false
	var seen: Dictionary = {}
	for id: Variant in ids:
		if not id is String or id not in POWER_IDS or (seen.has(id) and not duplicates_allowed):
			return false
		seen[id] = true
	return true

func _valid_run_id(run_id: String) -> bool:
	return not run_id.strip_edges().is_empty() and run_id.length() <= 128
