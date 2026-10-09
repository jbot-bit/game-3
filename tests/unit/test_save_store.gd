extends "res://addons/gut/test.gd"

const Store = preload("res://game/progression/save_store.gd")
const Progress = preload("res://game/progression/progression.gd")

class FailedPromotionStore extends "res://game/progression/save_store.gd":
	var deny_promotion: bool = false
	func _replace_file(from_path: String, to_path: String) -> Error:
		if deny_promotion and to_path == ProjectSettings.globalize_path(save_path):
			return ERR_FILE_CANT_WRITE
		return super._replace_file(from_path, to_path)

var save_path: String

func before_each() -> void:
	save_path = "user://test_save_store_%s_%s/household.json" % [Time.get_ticks_usec(), randi()]

func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(text)
		file.close()

func test_missing_save_is_distinct_from_corruption() -> void:
	var result: Dictionary = Store.new(save_path).load_or_recover()
	assert_false(result.ok)
	assert_eq(result.code, "not_found")
	assert_false(FileAccess.file_exists(save_path))

func test_committed_state_roundtrips() -> void:
	var state: Dictionary = Progress.blank_state()
	state.coins = 12
	state.lifetime_banked = 12
	assert_eq(Store.new(save_path).commit(state), OK)
	var result: Dictionary = Store.new(save_path).load_or_recover()
	assert_true(result.ok)
	assert_eq(result.source, "current")
	assert_eq(result.state, state)

func test_corrupt_current_recovers_previous_valid_backup() -> void:
	var store: Store = Store.new(save_path)
	var state: Dictionary = Progress.blank_state()
	state.coins = 10
	state.lifetime_banked = 10
	assert_eq(store.commit(state), OK)
	state.coins = 20
	state.lifetime_banked = 20
	state.revision = 1
	assert_eq(store.commit(state), OK)
	write_text(save_path, "{broken")
	var result: Dictionary = store.load_or_recover()
	assert_true(result.ok)
	assert_eq(result.source, "backup")
	assert_eq(result.state.get("coins", -1), 10)
	assert_eq(FileAccess.get_file_as_string(save_path), "{broken")

func test_invalid_schema_uses_backup() -> void:
	var state: Dictionary = Progress.blank_state()
	write_text(save_path + ".bak", JSON.stringify(state))
	state.schema_version = 900
	write_text(save_path, JSON.stringify(state))
	var result: Dictionary = Store.new(save_path).load_or_recover()
	assert_true(result.ok)
	assert_eq(result.source, "backup")

func test_two_invalid_saves_are_preserved() -> void:
	write_text(save_path, "damaged current")
	write_text(save_path + ".bak", "damaged backup")
	var result: Dictionary = Store.new(save_path).load_or_recover()
	assert_false(result.ok)
	assert_eq(result.code, "corrupt")
	assert_eq(FileAccess.get_file_as_string(save_path), "damaged current")
	assert_eq(FileAccess.get_file_as_string(save_path + ".bak"), "damaged backup")

func test_invalid_commit_does_not_replace_valid_state() -> void:
	var store: Store = Store.new(save_path)
	var state: Dictionary = Progress.blank_state()
	assert_eq(store.commit(state), OK)
	var bad: Dictionary = state.duplicate(true)
	bad.coins = -1
	assert_ne(store.commit(bad), OK)
	assert_eq(store.load_or_recover().state, state)

func test_failed_promotion_keeps_confirmed_state_and_ignores_temp() -> void:
	var store: FailedPromotionStore = FailedPromotionStore.new(save_path)
	var state: Dictionary = Progress.blank_state()
	assert_eq(store.commit(state), OK)
	store.deny_promotion = true
	var next: Dictionary = state.duplicate(true)
	next.coins = 50
	next.lifetime_banked = 50
	assert_ne(store.commit(next), OK)
	assert_eq(store.load_or_recover().state, state)

func test_recovery_commit_preserves_good_backup() -> void:
	var store: Store = Store.new(save_path)
	var state: Dictionary = Progress.blank_state()
	write_text(save_path + ".bak", JSON.stringify(state))
	write_text(save_path, "invalid current")
	state.coins = 15
	state.lifetime_banked = 15
	assert_eq(store.commit(state), OK)
	assert_eq(store.load_or_recover().state.get("coins", -1), 15)
	write_text(save_path, "broken again")
	assert_eq(store.load_or_recover().state.get("coins", -1), 0)

func test_commit_cannot_silently_reset_two_corrupt_saves() -> void:
	write_text(save_path, "damaged current")
	write_text(save_path + ".bak", "damaged backup")
	assert_ne(Store.new(save_path).commit(Progress.blank_state()), OK)
	assert_eq(FileAccess.get_file_as_string(save_path), "damaged current")
	assert_eq(FileAccess.get_file_as_string(save_path + ".bak"), "damaged backup")
