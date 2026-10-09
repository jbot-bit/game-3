extends GutTest

var path: String

class DenyCopyStore extends SaveStore:
	func _copy_file(from_path: String, to_path: String) -> Error:
		return ERR_FILE_CANT_WRITE if "/archives/" in to_path else super._copy_file(from_path, to_path)

class DenyResetPromotionStore extends SaveStore:
	var deny: bool = false
	func _replace_file(from_path: String, to_path: String) -> Error:
		if deny and to_path == ProjectSettings.globalize_path(save_path) + ".bak":
			return ERR_FILE_CANT_WRITE
		return super._replace_file(from_path, to_path)

class InterruptResetStore extends SaveStore:
	func _replace_file(from_path: String, to_path: String) -> Error:
		if to_path.ends_with(".bak") or from_path.ends_with(".restore.tmp"):
			return ERR_FILE_CANT_WRITE
		return super._replace_file(from_path, to_path)

func before_each() -> void:
	path = "user://tests/archive-%s-%s/household.json" % [Time.get_ticks_usec(), randi()]

func _seed() -> Dictionary:
	var store: SaveStore = SaveStore.new(path)
	var state: Dictionary = Progression.blank_state()
	state.coins = 10
	state.lifetime_banked = 10
	assert_eq(store.commit(state), OK)
	state.coins = 20
	state.lifetime_banked = 20
	assert_eq(store.commit(state), OK)
	return state

func test_reset_archives_exact_current_and_backup_and_installs_fresh_household() -> void:
	var old: Dictionary = _seed()
	var current: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	var fresh: Dictionary = Progression.blank_state()
	var result: Dictionary = SaveStore.new(path).archive_and_reset(fresh)
	assert_true(result.ok)
	if not result.ok:
		return
	assert_eq(FileAccess.get_file_as_string(str(result.get("archive_dir", "")) + "/household.json"), current)
	assert_eq(FileAccess.get_file_as_string(str(result.get("archive_dir", "")) + "/household.json.bak"), backup)
	var loaded: Dictionary = SaveStore.new(path).load_or_recover().state
	assert_eq(loaded, fresh)
	assert_ne(loaded.household_id, old.household_id)
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(path + ".bak")).household_id, fresh.household_id)
	var again: Dictionary = SaveStore.new(path).archive_and_reset(Progression.blank_state())
	assert_true(again.ok)
	assert_ne(again.get("archive_dir", ""), result.archive_dir)

func test_archive_copy_failure_leaves_both_originals_untouched() -> void:
	_seed()
	var current: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	assert_false(DenyCopyStore.new(path).archive_and_reset(Progression.blank_state()).ok)
	assert_eq(FileAccess.get_file_as_string(path), current)
	assert_eq(FileAccess.get_file_as_string(path + ".bak"), backup)

func test_failed_second_promotion_restores_both_originals() -> void:
	_seed()
	var current: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	var store: DenyResetPromotionStore = DenyResetPromotionStore.new(path)
	store.deny = true
	assert_false(store.archive_and_reset(Progression.blank_state()).ok)
	assert_eq(FileAccess.get_file_as_string(path), current)
	assert_eq(FileAccess.get_file_as_string(path + ".bak"), backup)
	assert_true(SaveStore.new(path).load_or_recover().ok)

func test_corrupt_household_can_only_reset_after_exact_archival() -> void:
	_seed()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("damaged current")
	file.close()
	file = FileAccess.open(path + ".bak", FileAccess.WRITE)
	file.store_string("damaged backup")
	file.close()
	var result: Dictionary = SaveStore.new(path).archive_and_reset(Progression.blank_state())
	assert_true(result.ok)
	if not result.ok:
		return
	assert_eq(FileAccess.get_file_as_string(str(result.get("archive_dir", "")) + "/household.json"), "damaged current")
	assert_eq(FileAccess.get_file_as_string(str(result.get("archive_dir", "")) + "/household.json.bak"), "damaged backup")
	assert_true(SaveStore.new(path).load_or_recover().ok)

func test_reopening_after_interrupted_reset_restores_exact_original_pair() -> void:
	var original: Dictionary = _seed()
	var current: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	var result: Dictionary = InterruptResetStore.new(path).archive_and_reset(Progression.blank_state())
	assert_false(result.ok)
	assert_eq(result.code, "reset_recovery_required")
	assert_true(FileAccess.file_exists(path + ".reset"))
	assert_eq(SaveStore.new(path).commit(Progression.blank_state()), ERR_BUSY)
	var loaded: Dictionary = SaveStore.new(path).load_or_recover()
	assert_true(loaded.ok)
	assert_eq(loaded.state, original)
	assert_eq(FileAccess.get_file_as_string(path), current)
	assert_eq(FileAccess.get_file_as_string(path + ".bak"), backup)
	assert_false(FileAccess.file_exists(path + ".reset"))

func test_damaged_archive_blocks_interrupted_reset_recovery_without_overwriting_files() -> void:
	_seed()
	var result: Dictionary = InterruptResetStore.new(path).archive_and_reset(Progression.blank_state())
	assert_eq(result.get("code", ""), "reset_recovery_required")
	var file: FileAccess = FileAccess.open(str(result.archive_dir) + "/household.json", FileAccess.WRITE)
	file.store_string("damaged archived file")
	file.close()
	var current: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	var loaded: Dictionary = SaveStore.new(path).load_or_recover()
	assert_false(loaded.ok)
	assert_eq(loaded.code, "reset_recovery_required")
	assert_eq(FileAccess.get_file_as_string(path), current)
	assert_eq(FileAccess.get_file_as_string(path + ".bak"), backup)
	assert_true(FileAccess.file_exists(path + ".reset"))
