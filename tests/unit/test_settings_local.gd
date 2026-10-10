extends GutTest

const Settings = preload("res://game/ui/settings_local.gd")
var path: String

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	path = "user://tests/settings_" + str(Time.get_ticks_usec()) + ".json"

func after_each() -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_local_preferences_roundtrip_without_household_state() -> void:
	var settings = Settings.new(path)
	settings.set_value("master_volume", 0.35)
	settings.set_value("threat_volume", 0.2)
	settings.set_value("mouse_sensitivity", 1.7)
	settings.set_value("invert_y", true)
	settings.set_value("window_mode", "borderless")
	settings.set_value("reduced_effects", true)
	settings.set_value("shadows", true)
	settings.set_binding("interact", KEY_Z)
	assert_eq(settings.save_settings(), OK)
	var reloaded = Settings.new(path)
	var state: Dictionary = reloaded.load_settings()
	assert_eq(state.get("master_volume"), 0.35)
	assert_eq(state.get("threat_volume"), 0.2)
	assert_eq(state.get("mouse_sensitivity"), 1.7)
	assert_eq(state.get("invert_y"), true)
	assert_eq(state.get("window_mode"), "borderless")
	assert_eq(state.get("reduced_effects"), true)
	assert_eq(state.get("shadows"), true)
	assert_eq(reloaded.action_key("interact"), KEY_Z)
	assert_false(state.has("coins"))

func test_numeric_bounds_and_invalid_values_cannot_poison_preferences() -> void:
	var settings = Settings.new(path)
	settings.set_value("master_volume", 9.0)
	settings.set_value("threat_volume", -2.0)
	settings.set_value("mouse_sensitivity", 100.0)
	assert_eq(settings.snapshot().get("master_volume"), 1.0)
	assert_eq(settings.snapshot().get("threat_volume"), 0.0)
	assert_eq(settings.snapshot().get("mouse_sensitivity"), 3.0)
	assert_false(settings.set_value("mouse_sensitivity", NAN))
	assert_false(settings.set_value("window_mode", "unsafe_unknown"))
	assert_false(settings.set_value("invert_y", "true"))
	assert_false(settings.set_value("coins", 10000))
	assert_eq(settings.snapshot().get("mouse_sensitivity"), 3.0)

func test_remapping_swaps_conflicts_and_matches_physical_key() -> void:
	var settings = Settings.new(path)
	assert_true(settings.set_binding("interact", KEY_Q))
	assert_eq(settings.action_key("interact"), KEY_Q)
	assert_eq(settings.action_key("ability"), KEY_E)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_A
	event.pressed = true
	assert_true(settings.event_matches(event, "interact"))
	assert_false(settings.event_matches(event, "ability"))
	assert_false(settings.set_binding("unknown_action", KEY_Z))
	assert_false(settings.set_binding("interact", KEY_SHIFT))
	assert_eq(settings.key_label("interact"), "Q")

func test_corrupt_local_settings_use_defaults_and_preserve_the_file() -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not valid json")
	file.close()
	var settings = Settings.new(path)
	var state: Dictionary = settings.load_settings()
	assert_eq(state.get("master_volume"), 1.0)
	assert_eq(settings.action_key("move_forward"), KEY_W)
	assert_eq(FileAccess.get_file_as_string(path), "not valid json")

func test_snapshot_binding_edits_do_not_change_live_input() -> void:
	var settings = Settings.new(path)
	var state: Dictionary = settings.snapshot()
	if state.has("bindings"): state.bindings.interact = KEY_X
	assert_eq(settings.action_key("interact"), KEY_E)

func test_save_failure_is_reported_without_changing_other_files() -> void:
	var settings = Settings.new("user://tests/nonexistent_" + str(Time.get_ticks_usec()) + "/settings.json")
	settings.set_value("master_volume", 0.5)
	assert_ne(settings.save_settings(), OK)
