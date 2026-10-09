extends "res://addons/gut/test.gd"

const Store = preload("res://game/progression/save_store.gd")
const Progress = preload("res://game/progression/progression.gd")
const Recipes = preload("res://game/progression/crafting.gd")

class RefusingStore extends "res://game/progression/save_store.gd":
	var refuse: bool = false
	func commit(next_state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(next_state)

var save_path: String
var p: Progress

func before_each() -> void:
	save_path = "user://test_crafting_%s_%s/household.json" % [Time.get_ticks_usec(), randi()]
	var state: Dictionary = Progress.blank_state()
	state.coins = 40
	state.lifetime_banked = 40
	p = Progress.new(Store.new(save_path), state)

func test_recipe_has_only_authored_requirements() -> void:
	var recipe: Dictionary = Recipes.recipe("surveyor_lantern")
	assert_eq(recipe.get("coins", -1), 30)
	assert_eq(recipe.get("salvage", {}), {"glass_lens": 1})
	assert_true(Recipes.recipe("invented").is_empty())

func test_craft_consumes_once_and_unlocks_for_all_profiles() -> void:
	assert_true(p.open_cache("lido_workshop_cache").ok)
	assert_true(p.craft("surveyor_lantern", "craft-1").ok)
	assert_eq(p.snapshot().coins, 10)
	assert_eq(p.snapshot().lifetime_banked, 40)
	assert_eq(p.snapshot().salvage.get("glass_lens", -1), 0)
	for id: String in ["crew_1", "crew_2", "crew_3"]:
		assert_true(p.set_lamp(id, "surveyor").ok)
	var saved: Dictionary = p.snapshot()
	assert_false(p.craft("surveyor_lantern", "craft-1").ok)
	assert_false(p.craft("surveyor_lantern", "craft-2").ok)
	assert_eq(p.snapshot(), saved)
	var loaded: Dictionary = Store.new(save_path).load_or_recover()
	assert_eq(loaded.state.get("profiles", {}), saved.profiles)

func test_missing_requirements_and_unknown_recipe_spend_nothing() -> void:
	var before: Dictionary = p.snapshot()
	assert_false(p.craft("surveyor_lantern", "craft-1").ok)
	assert_false(p.craft("invented", "craft-2").ok)
	assert_eq(p.snapshot(), before)
	assert_true(p.open_cache("lido_workshop_cache").ok)
	var poor: Dictionary = p.snapshot()
	poor.coins = 0
	p = Progress.new(Store.new(save_path), poor)
	before = p.snapshot()
	assert_false(p.craft("surveyor_lantern", "craft-3").ok)
	assert_eq(p.snapshot(), before)

func test_failed_craft_grants_and_spends_nothing() -> void:
	var refusing: RefusingStore = RefusingStore.new(save_path)
	p = Progress.new(refusing, p.snapshot())
	assert_true(p.open_cache("lido_workshop_cache").ok)
	var before: Dictionary = p.snapshot()
	refusing.refuse = true
	assert_eq(p.craft("surveyor_lantern", "craft-1").code, "save_failed")
	assert_eq(p.snapshot(), before)
	refusing.refuse = false
	assert_true(p.craft("surveyor_lantern", "craft-1").ok)

func test_crafting_cannot_consume_walkway_component() -> void:
	assert_true(p.open_cache("lido_workshop_cache").ok)
	assert_true(p.open_cache("walkway_parts_cache").ok)
	assert_true(p.craft("surveyor_lantern", "craft-1").ok)
	assert_eq(p.snapshot().salvage.get("brass_fitting", -1), 1)
