extends "res://addons/gut/test.gd"

const RULES_PATH: String = "res://prototypes/physics_party/party_rules.gd"
var save_path: String

func before_each() -> void:
	save_path = "user://test_party_%s_%s/progress.json" % [Time.get_ticks_usec(), randi()]

func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))

func _rules() -> RefCounted:
	assert_true(FileAccess.file_exists(RULES_PATH), "The party rules module exists")
	if not FileAccess.file_exists(RULES_PATH):
		return null
	return load(RULES_PATH).new()

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(text)
		file.close()

func test_offers_are_seeded_unique_and_cover_all_five_powers() -> void:
	var rules: RefCounted = _rules()
	if rules == null: return
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 814
	second.seed = 814
	assert_eq(rules.draw_offers(first), rules.draw_offers(second))
	var seen: Dictionary = {}
	for seed_value: int in range(30):
		first.seed = seed_value
		var offer: Array = rules.draw_offers(first)
		assert_eq(offer.size(), 3)
		var unique: Dictionary = {}
		for id: String in offer:
			assert_has(["spring", "heavy", "swift", "feather", "grip"], id)
			assert_false(unique.has(id), "No duplicate powers in a choice")
			unique[id] = true
			seen[id] = true
			assert_false(rules.power_info(id).get("name", "").is_empty())
	assert_eq(seen.size(), 5)
	assert_eq(rules.power_info("invented"), {})

func test_completion_requires_explicit_progress_load() -> void:
	var rules: RefCounted = _rules()
	if rules == null: return
	assert_eq(rules.progress, {"level": 1, "completions": 0, "unlocked_power_ids": []})
	assert_false(rules.complete("run-a").ok)
	assert_false(FileAccess.file_exists(save_path))
	assert_true(rules.load_progress(save_path).ok)
	assert_false(FileAccess.file_exists(save_path), "Reading a new profile does not write it")

func test_completed_run_is_saved_once_even_after_reload() -> void:
	var rules: RefCounted = _rules()
	if rules == null: return
	assert_true(rules.load_progress(save_path).ok)
	assert_true(rules.complete("run-a").ok)
	assert_eq(rules.progress, {"level": 1, "completions": 1, "unlocked_power_ids": []})
	var digest: String = FileAccess.get_sha256(save_path)
	assert_true(rules.complete("run-a").ok)
	assert_eq(FileAccess.get_sha256(save_path), digest, "A replay does not rewrite the save")
	var restored: RefCounted = _rules()
	assert_true(restored.load_progress(save_path).ok)
	assert_true(restored.complete("run-a").ok)
	assert_eq(restored.progress.completions, 1)
	assert_true(restored.complete("run-b").ok)
	assert_true(restored.complete("run-c").ok)
	assert_eq(restored.progress, {"level": 2, "completions": 3, "unlocked_power_ids": []})
	var after: RefCounted = _rules()
	assert_true(after.load_progress(save_path).ok)
	assert_eq(after.progress, restored.progress)

func test_corrupt_save_is_preserved_and_cannot_be_overwritten() -> void:
	_write(save_path, "{broken save")
	_write(save_path + ".bak", "also broken")
	var digest: String = FileAccess.get_sha256(save_path)
	var backup_digest: String = FileAccess.get_sha256(save_path + ".bak")
	var rules: RefCounted = _rules()
	if rules == null: return
	var loaded: Dictionary = rules.load_progress(save_path)
	assert_false(loaded.ok)
	assert_eq(loaded.code, "corrupt")
	assert_false(rules.complete("run-a").ok)
	assert_eq(FileAccess.get_sha256(save_path), digest)
	assert_eq(FileAccess.get_sha256(save_path + ".bak"), backup_digest)
	assert_eq(rules.progress.completions, 0)

func test_valid_backup_recovers_without_counting_unconfirmed_temp() -> void:
	var rules: RefCounted = _rules()
	if rules == null: return
	assert_true(rules.load_progress(save_path).ok)
	assert_true(rules.complete("run-a").ok)
	assert_true(rules.complete("run-b").ok)
	_write(save_path, "bad current")
	_write(save_path + ".tmp", '{"version":1,"completed_runs":["run-a","run-b","run-c"]}')
	var restored: RefCounted = _rules()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.progress.completions, 1, "Only the previously committed backup is recovered")
	assert_true(restored.complete("run-c").ok)
	assert_eq(restored.progress.completions, 2)
	var after: RefCounted = _rules()
	assert_true(after.load_progress(save_path).ok)
	assert_eq(after.progress.completions, 2)

func test_malformed_run_history_fails_closed() -> void:
	_write(save_path, '{"version":1,"completed_runs":["run-a","run-a"]}')
	var rules: RefCounted = _rules()
	if rules == null: return
	assert_false(rules.load_progress(save_path).ok)
	assert_false(rules.complete("run-b").ok)

func test_failed_write_keeps_progress_unchanged_and_rejects_empty_run() -> void:
	_write(save_path, "file blocks directory")
	var rules: RefCounted = _rules()
	if rules == null: return
	assert_true(rules.load_progress(save_path + "/child.json").ok)
	assert_false(rules.complete("").ok)
	assert_false(rules.complete("run-a").ok)
	assert_eq(rules.progress, {"level": 1, "completions": 0, "unlocked_power_ids": []})
	assert_eq(FileAccess.get_file_as_string(save_path), "file blocks directory")

func test_hud_blocks_movement_only_while_player_must_use_an_overlay() -> void:
	var hud: CanvasLayer = load("res://prototypes/physics_party/party_hud.gd").new()
	add_child_autofree(hud)
	assert_true(hud.blocks_input(), "Start menu owns input")
	hud.show_game()
	var state: Dictionary = {
		"players": {"crew_1": {"name": "River", "power": "", "finished": false}},
		"offers": {"crew_1": ["spring", "swift", "heavy"]},
		"phase": "play", "level": 1, "completions": 0,
	}
	hud.update_view(state, "crew_1", true)
	assert_true(hud.blocks_input(), "Choose a power before movement")
	state.players.crew_1.power = "spring"
	hud.update_view(state, "crew_1", true)
	assert_false(hud.blocks_input(), "Movement resumes after the confirmed choice")
	state.phase = "complete"
	hud.update_view(state, "crew_1", true)
	assert_true(hud.blocks_input(), "The completed-run screen owns input")
	hud.reset_session("Disconnected")
	assert_true(hud.blocks_input())

func _can_collect(rules: RefCounted) -> bool:
	for method: Dictionary in rules.get_method_list():
		if str(method.name) == "complete":
			assert_eq(method.args.size(), 2, "Completing a run accepts the crew's used powers")
			return method.args.size() == 2
	return false

func test_clear_collects_used_powers_once_across_reload() -> void:
	var rules: RefCounted = _rules()
	if rules == null or not _can_collect(rules): return
	assert_true(rules.load_progress(save_path).ok)
	var earned: Dictionary = rules.complete("run-a", ["spring", "spring", "feather"])
	assert_true(earned.ok)
	assert_eq(earned.unlocked_power_ids, ["spring", "feather"])
	var restored: RefCounted = _rules()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.progress.unlocked_power_ids, ["spring", "feather"])
	var digest: String = FileAccess.get_sha256(save_path)
	assert_true(restored.complete("run-a", ["heavy"]).ok)
	assert_eq(restored.progress.unlocked_power_ids, ["spring", "feather"], "Replaying a completed run cannot award another power")
	assert_eq(FileAccess.get_sha256(save_path), digest)
	assert_true(restored.complete("run-b", ["heavy"]).ok)
	assert_eq(restored.progress.unlocked_power_ids, ["spring", "heavy", "feather"])
	var copied: Dictionary = restored.progress
	copied.unlocked_power_ids.clear()
	assert_eq(restored.progress.unlocked_power_ids.size(), 3, "Callers cannot mutate saved ownership through a snapshot")

func test_failed_clear_does_not_award_power_or_completion() -> void:
	_write(save_path, "blocks save directory")
	var rules: RefCounted = _rules()
	if rules == null or not _can_collect(rules): return
	assert_true(rules.load_progress(save_path + "/child.json").ok)
	assert_false(rules.complete("run-a", ["grip"]).ok)
	assert_eq(rules.progress.completions, 0)
	assert_eq(rules.progress.unlocked_power_ids, [])

func test_unknown_power_rejects_the_whole_clear() -> void:
	var rules: RefCounted = _rules()
	if rules == null or not _can_collect(rules): return
	assert_true(rules.load_progress(save_path).ok)
	assert_false(rules.complete("run-a", ["spring", "invented"]).ok)
	assert_eq(rules.progress.completions, 0)
	assert_eq(rules.progress.unlocked_power_ids, [])
	assert_false(FileAccess.file_exists(save_path))

func test_legacy_clear_save_loads_without_inventing_collected_powers() -> void:
	_write(save_path, '{"version":1,"completed_runs":["old-run"]}')
	var original: String = FileAccess.get_sha256(save_path)
	var rules: RefCounted = _rules()
	if rules == null or not _can_collect(rules): return
	assert_true(rules.load_progress(save_path).ok)
	assert_eq(rules.progress.completions, 1)
	assert_eq(rules.progress.unlocked_power_ids, [])
	assert_eq(FileAccess.get_sha256(save_path), original)
	assert_true(rules.complete("new-run", ["grip"]).ok)
	var restored: RefCounted = _rules()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.progress.unlocked_power_ids, ["grip"])
	assert_eq(restored.progress.completions, 2)

func test_invalid_saved_power_collection_is_preserved() -> void:
	for collection: Variant in [["invented"], ["spring", "spring"], [99], "spring"]:
		_write(save_path, JSON.stringify({"version": 1, "completed_runs": ["old-run"], "unlocked_power_ids": collection}))
		var digest: String = FileAccess.get_sha256(save_path)
		var rules: RefCounted = _rules()
		if rules == null: return
		assert_false(rules.load_progress(save_path).ok, "Unknown, duplicate or incorrectly typed ownership fails closed")
		assert_false(rules.complete("new-run").ok)
		assert_eq(FileAccess.get_sha256(save_path), digest)

func test_collected_power_is_selectable_even_when_not_in_random_offer() -> void:
	var hud: CanvasLayer = load("res://prototypes/physics_party/party_hud.gd").new()
	add_child_autofree(hud)
	watch_signals(hud)
	hud.show_game()
	hud.update_view({
		"players": {"crew_1": {"name": "River", "power": "", "finished": false}},
		"offers": {"crew_1": ["spring", "swift", "heavy"]},
		"unlocked_power_ids": ["grip"], "phase": "play",
	}, "crew_1", true)
	var owned_button: Button
	for button: Node in hud.find_children("*", "Button", true, false):
		if button.text == "IRON GRIP" and button.is_visible_in_tree():
			owned_button = button
	assert_not_null(owned_button, "An earned power remains a choice outside the random three")
	if owned_button != null:
		owned_button.pressed.emit()
		assert_signal_emitted_with_parameters(hud, "power_chosen", ["grip"])

func test_all_collected_power_choices_fit_a_960_by_540_viewport() -> void:
	var window: Window = get_tree().root
	var previous_size: Vector2i = window.size
	var previous_scale: Vector2i = window.content_scale_size
	window.size = Vector2i(960, 540)
	window.content_scale_size = Vector2i(960, 540)
	var hud: CanvasLayer = load("res://prototypes/physics_party/party_hud.gd").new()
	add_child_autofree(hud)
	hud.show_game()
	hud.update_view({
		"players": {"crew_1": {"name": "River", "power": "", "finished": false}},
		"offers": {"crew_1": ["spring", "swift", "heavy"]},
		"unlocked_power_ids": ["spring", "heavy", "swift", "feather", "grip"], "phase": "play",
	}, "crew_1", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var visible_choices: int = 0
	for button: Node in hud.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree(): continue
		visible_choices += 1
		var bounds: Rect2 = button.get_global_rect()
		assert_gt(bounds.size.x, 0.0)
		assert_gt(bounds.size.y, 0.0)
		assert_true(bounds.position.x >= 0.0 and bounds.position.y >= 0.0, "Choice starts inside the window")
		assert_true(bounds.end.x <= 960.0 and bounds.end.y <= 540.0, "Choice ends inside the window")
	assert_eq(visible_choices, 9, "Three random powers, five collected powers and Customize remain visible")
	window.size = previous_size
	window.content_scale_size = previous_scale
