extends GutTest

const Rules = preload("res://prototypes/physics_party/party_rules.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
var save_path: String

class FailingRules extends "res://prototypes/physics_party/party_rules.gd":
	var fail_writes: bool = false
	func _commit(runs: Array[String], unlocked: Array[String]) -> Error:
		return ERR_FILE_CANT_WRITE if fail_writes else super._commit(runs, unlocked)


func before_each() -> void:
	save_path = "user://test_party_cosmetics_%s_%s/progress.json" % [Time.get_ticks_usec(), randi()]


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))


func _write(saved: Variant, suffix: String = "") -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	var file := FileAccess.open(save_path + suffix, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(saved if saved is String else JSON.stringify(saved))
		file.close()


func test_catalog_exposes_four_rarities_and_equips_only_owned_items() -> void:
	assert_eq(Cosmetics.colors([]).size(), 12)
	assert_eq(Cosmetics.accessories([]).size(), 7)
	var rarity_counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	var seen: Array[String] = []
	for card: Dictionary in Cosmetics.CARDS:
		assert_false(card.id in seen)
		seen.append(card.id)
		assert_eq(Cosmetics.card_info(card.id), card)
		assert_has(rarity_counts, card.rarity)
		rarity_counts[card.rarity] += 1
	assert_eq(rarity_counts, {"common": 6, "rare": 4, "epic": 3, "legendary": 2})
	assert_eq(Cosmetics.card_info("invented"), {})
	for slot in 3:
		var default: Dictionary = Cosmetics.default_style(slot)
		assert_eq(default.accessory, "none")
		assert_eq(Cosmetics.sanitize({}, [], slot), default)
		assert_eq(Cosmetics.sanitize({"color": "mint", "accessory": "crown"}, [], slot), default)
		assert_eq(Cosmetics.sanitize({"color": 7, "accessory": ["cap"]}, [], slot), default)
	assert_eq(Cosmetics.default_style(0).color, "orange")
	assert_eq(Cosmetics.default_style(1).color, "blue")
	assert_eq(Cosmetics.default_style(2).color, "lilac")
	var owned: Array = ["paint_mint", "gear_crown"]
	assert_eq(Cosmetics.sanitize({"color": "mint", "accessory": "crown"}, owned, 0), {"color": "mint", "accessory": "crown"})
	assert_eq(Cosmetics.color_for("mint"), Color("43d6cf"))
	for entry: Dictionary in Cosmetics.colors(owned):
		assert_eq(entry.unlocked, entry.id in ["orange", "blue", "lilac", "mint"])
	for entry: Dictionary in Cosmetics.accessories(owned):
		assert_eq(entry.unlocked, entry.id in ["none", "crown"])


func test_bags_are_seeded_and_prefer_unowned_cards_within_the_rolled_tier() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 82418
	second.seed = first.seed
	var owned: Array[String] = []
	for draw in 30:
		var bag: Array[String] = Cosmetics.draw_bag(owned, first)
		assert_eq(bag, Cosmetics.draw_bag(owned, second))
		assert_eq(bag.size(), 3)
		for id: String in bag:
			var info: Dictionary = Cosmetics.card_info(id)
			assert_false(info.is_empty())
			var fresh_in_tier: bool = false
			for other: Dictionary in Cosmetics.CARDS:
				if other.rarity == info.rarity and other.id not in owned:
					fresh_in_tier = true
			if fresh_in_tier:
				assert_false(id in owned, "An unowned card wins within the rolled tier")
			if id not in owned:
				owned.append(id)
	assert_eq(owned.size(), Cosmetics.CARDS.size(), "The fixed sample collects the entire catalog")


func test_seeded_distribution_matches_advertised_rarity_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 730149
	var counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for bag in 3000:
		for id: String in Cosmetics.draw_bag([], rng):
			counts[Cosmetics.card_info(id).rarity] += 1
	for rarity: String in counts:
		var expected: float = {"common": 0.60, "rare": 0.28, "epic": 0.10, "legendary": 0.02}[rarity]
		assert_almost_eq(float(counts[rarity]) / 9000.0, expected, 0.025, rarity)


func test_legacy_save_is_unchanged_until_a_new_clear_awards_one_persisted_bag() -> void:
	_write({"version": 1, "completed_runs": ["a", "b", "c"], "unlocked_power_ids": ["swift"]})
	var digest: String = FileAccess.get_sha256(save_path)
	var rules = Rules.new()
	rules.reward_rng.seed = 12
	assert_true(rules.load_progress(save_path).ok)
	assert_eq(rules.appearance_for(1), Cosmetics.default_style(1))
	assert_eq(rules.cosmetic_collection(), [])
	assert_eq(rules.last_reward(), {})
	assert_eq(FileAccess.get_sha256(save_path), digest)
	assert_true(rules.complete("new-clear", ["grip"]).ok)
	assert_eq(rules.last_reward().cards.size(), 3)
	assert_eq(rules.last_reward().run_id, "new-clear")
	assert_eq(rules.progress.completions, 4)
	assert_eq(rules.progress.unlocked_power_ids, ["swift", "grip"])
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	assert_eq(stored.version, 1.0)
	assert_eq(stored.last_reward, rules.last_reward())
	assert_eq(stored.cosmetic_cards, rules.cosmetic_collection())
	var restored = Rules.new()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.last_reward(), rules.last_reward())
	assert_eq(restored.cosmetic_collection(), rules.cosmetic_collection())


func test_rewards_are_exactly_once_across_reload_and_public_snapshots_are_copies() -> void:
	var rules = Rules.new()
	assert_true(rules.load_progress(save_path).ok)
	assert_true(rules.complete("one", ["spring"]).ok)
	var saved_reward: Dictionary = rules.last_reward()
	var rng_state: int = rules.reward_rng.state
	var digest: String = FileAccess.get_sha256(save_path)
	assert_eq(rules.complete("one", ["heavy"]).code, "already_saved")
	assert_eq(rules.reward_rng.state, rng_state)
	assert_eq(FileAccess.get_sha256(save_path), digest)
	var copy: Dictionary = rules.last_reward()
	copy.cards.clear()
	var cards: Array = rules.cosmetic_collection()
	cards.clear()
	assert_eq(rules.last_reward(), saved_reward)
	assert_gt(rules.cosmetic_collection().size(), 0)
	var restored = Rules.new()
	assert_true(restored.load_progress(save_path).ok)
	assert_true(restored.complete("one").ok)
	assert_eq(restored.last_reward(), saved_reward)
	assert_eq(FileAccess.get_sha256(save_path), digest)
	assert_eq(restored.progress.unlocked_power_ids, ["spring"])


func test_failed_clear_cannot_award_or_reroll_and_retry_commits_the_cached_bag() -> void:
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 117
	var expected: Array[String] = Cosmetics.draw_bag([], expected_rng)
	var rules = FailingRules.new()
	rules.reward_rng.seed = 117
	assert_true(rules.load_progress(save_path).ok)
	rules.fail_writes = true
	assert_false(rules.complete("retry", ["grip"]).ok)
	var rolled_state: int = rules.reward_rng.state
	assert_eq(rules.cosmetic_collection(), [])
	assert_eq(rules.last_reward(), {})
	assert_eq(rules.progress.completions, 0)
	assert_false(FileAccess.file_exists(save_path))
	assert_false(rules.complete("retry", ["grip"]).ok)
	assert_eq(rules.reward_rng.state, rolled_state, "Retry keeps its first roll")
	rules.fail_writes = false
	assert_true(rules.complete("retry", ["grip"]).ok)
	assert_eq(rules.reward_rng.state, rolled_state)
	assert_eq(rules.last_reward(), {"run_id": "retry", "cards": expected})
	assert_eq(rules.progress.completions, 1)
	assert_eq(rules.progress.unlocked_power_ids, ["grip"])


func test_owned_style_is_per_slot_persistent_and_failed_equips_do_not_leak() -> void:
	_write({"version": 1, "completed_runs": ["old"], "cosmetic_cards": ["paint_cream", "gear_sprout"]})
	var rules = FailingRules.new()
	assert_true(rules.load_progress(save_path).ok)
	var choice := {"color": "cream", "accessory": "sprout"}
	assert_true(rules.set_appearance(2, choice).ok)
	choice.accessory = "none"
	assert_eq(rules.appearance_for(2).accessory, "sprout")
	assert_eq(rules.appearance_for(0), Cosmetics.default_style(0))
	var digest: String = FileAccess.get_sha256(save_path)
	rules.fail_writes = true
	assert_eq(rules.set_appearance(2, {"color": "blue", "accessory": "none"}).code, "save_failed")
	assert_eq(rules.appearance_for(2), {"color": "cream", "accessory": "sprout"})
	assert_eq(FileAccess.get_sha256(save_path), digest)
	rules.fail_writes = false
	assert_true(rules.complete("later", ["grip"]).ok)
	var restored = Rules.new()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.appearance_for(2), {"color": "cream", "accessory": "sprout"})
	var copied: Dictionary = restored.appearance_for(2)
	copied.color = "orange"
	assert_eq(restored.appearance_for(2).color, "cream")
	digest = FileAccess.get_sha256(save_path)
	assert_eq(restored.set_appearance(2, restored.appearance_for(2)).code, "already_saved")
	assert_eq(FileAccess.get_sha256(save_path), digest)


func test_unowned_invalid_and_unloaded_equips_are_rejected_without_mutation() -> void:
	var rules = Rules.new()
	assert_false(rules.set_appearance(0, {"color": "blue", "accessory": "none"}).ok)
	assert_true(rules.load_progress(save_path).ok)
	assert_true(rules.set_appearance(1, {"color": "orange", "accessory": "none"}).ok)
	var digest: String = FileAccess.get_sha256(save_path)
	for choice: Dictionary in [{"color": "cream", "accessory": "none"}, {"color": "orange", "accessory": "crown"}, {"color": "bogus", "accessory": "none"}, {"color": "orange"}, {"color": "blue", "accessory": "none", "extra": true}]:
		assert_false(rules.set_appearance(0, choice).ok)
		assert_eq(rules.appearance_for(0), Cosmetics.default_style(0))
		assert_eq(FileAccess.get_sha256(save_path), digest)
	assert_eq(rules.set_appearance(3, {"color": "blue", "accessory": "none"}).code, "invalid_slot")
	assert_eq(FileAccess.get_sha256(save_path), digest)


func test_malformed_optional_cosmetics_fail_closed() -> void:
	var invalid: Array = [
		{"cosmetic_cards": ["invented"]}, {"cosmetic_cards": ["paint_mint", "paint_mint"]},
		{"cosmetic_cards": "paint_mint"}, {"last_reward": []},
		{"last_reward": {"run_id": "unknown", "cards": ["paint_mint", "paint_rose", "paint_cream"]}},
		{"last_reward": {"run_id": "old", "cards": ["paint_mint", "paint_rose", "paint_cream"]}},
		{"appearance_by_slot": {"3": {"color": "blue", "accessory": "none"}}},
		{"appearance_by_slot": {"0": {"color": "mint", "accessory": "none"}}},
		{"appearance_by_slot": {"0": []}}, {"appearance_by_slot": []},
	]
	for extra: Dictionary in invalid:
		var saved := {"version": 1, "completed_runs": ["old"]}
		saved.merge(extra, true)
		_write(saved)
		var digest: String = FileAccess.get_sha256(save_path)
		var rules = Rules.new()
		assert_false(rules.load_progress(save_path).ok)
		assert_false(rules.complete("new").ok)
		assert_false(rules.set_appearance(0, {"color": "blue", "accessory": "none"}).ok)
		assert_eq(FileAccess.get_sha256(save_path), digest)


func test_backup_recovers_its_reward_and_style_without_uncommitted_awards() -> void:
	var rules = Rules.new()
	assert_true(rules.load_progress(save_path).ok)
	assert_true(rules.complete("first").ok)
	var first_reward: Dictionary = rules.last_reward()
	assert_true(rules.set_appearance(0, {"color": "blue", "accessory": "none"}).ok)
	assert_true(rules.complete("second").ok)
	_write("corrupt current")
	var restored = Rules.new()
	assert_true(restored.load_progress(save_path).ok)
	assert_eq(restored.progress.completions, 1)
	assert_eq(restored.last_reward(), first_reward)
	assert_eq(restored.appearance_for(0), {"color": "blue", "accessory": "none"})
