extends GutTest
const Game = preload("res://game/main.gd")
var app: Node3D
var sequence: int = 0

class RefusingStore extends SaveStore:
	var refuse: bool = false
	func commit(state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(state)

func before_each() -> void:
	app = Game.new()
	add_child_autofree(app)
	app.game_port = 24639
	app.save_path = "user://tests/earned-gear-" + str(Time.get_ticks_usec()) + ".json"
	app._host("Gear feedback")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await get_tree().physics_frame

func after_each() -> void:
	app.session.close()

func _record(species: String, profile: String = "crew_1") -> Dictionary:
	sequence += 1
	return {"catch_id": "gear-" + str(sequence), "run_id": app.controller.run.run_id, "profile_id": profile, "species_id": species, "trait_id": "none", "size": 1.0, "catch_value": Species.value_for(species, "none"), "habitat_id": "jetty", "rare_eligible": false}

func _land(species: String, profile: String = "crew_1") -> void:
	app.controller.rolled[profile] = _record(species, profile)
	app.controller._land(profile)

func _gear_notices(item: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for note: Dictionary in app.controller.notes:
		if str(note.text).contains(item): result.append(note)
	return result

func test_found_rod_names_the_shared_reward_and_where_to_equip_without_autoequip() -> void:
	app.controller.avatars.crew_1.global_position = app.world.markers.rod_cache
	assert_true(app.controller.apply_intent(1, "open_cache", {"cache_id": "shore_rod_cache"}, "find-rod").ok)
	var notice: String = str(app.controller.notes.back().text)
	assert_string_contains(notice, "Soft-tip Rod")
	assert_string_contains(notice, "Moth")
	assert_string_contains(notice.to_lower(), "equip")
	assert_eq(app.controller.progression.snapshot().profiles.crew_1.rod_id, "starter")
	var notices: int = app.controller.notes.size()
	assert_false(app.controller.apply_intent(1, "open_cache", {"cache_id": "shore_rod_cache"}, "repeat-rod").ok)
	assert_eq(app.controller.notes.size(), notices, "Reopening must not replay the found reward")

func test_second_species_announces_shared_outfit_once_even_when_remote_angler_lands_it() -> void:
	app.session.roster.assign(2, 1, "0.4.0-tide")
	app.controller._roster_changed(app.session.roster.snapshot())
	_land("penny_perch")
	assert_true(_gear_notices("Angler's Kit").is_empty())
	_land("bellgill", "crew_2")
	var earned: Array[Dictionary] = _gear_notices("Angler's Kit")
	assert_eq(earned.size(), 1)
	if not earned.is_empty():
		assert_eq(earned[0].profile, "", "The milestone belongs to the crew, not the receiving client's profile")
		assert_string_contains(str(earned[0].text), "Crew")
		assert_string_contains(str(earned[0].text), "Moth")
	assert_true(Equipment.outfit_unlocked(SaveStore.new(app.save_path).load_or_recover().state, "angler"))
	_land("bellgill")
	assert_eq(_gear_notices("Angler's Kit").size(), 1, "An already discovered species must not repeat the milestone")
	app.controller.start_day()
	assert_eq(_gear_notices("Angler's Kit").size(), 1, "Dawn must not reannounce old rewards")

func test_failed_milestone_save_has_no_success_notice_until_retry_commits_once() -> void:
	_land("penny_perch")
	var store = RefusingStore.new(app.save_path)
	app.controller.progression = Progression.new(store, app.controller.progression.snapshot())
	store.refuse = true
	_land("bellgill")
	assert_true(app.controller.run.paused)
	assert_true(_gear_notices("Angler's Kit").is_empty())
	assert_false(Equipment.outfit_unlocked(app.controller.progression.snapshot(), "angler"))
	store.refuse = false
	assert_true(app.controller._retry_write().ok)
	assert_eq(_gear_notices("Angler's Kit").size(), 1)
	assert_false(app.controller._retry_write().ok)
	assert_eq(_gear_notices("Angler's Kit").size(), 1)

func test_sixth_species_announces_saved_drift_rod_without_repeating_it_on_later_catches() -> void:
	for species: String in ["penny_perch", "bellgill", "pebble_dab", "ribbon_minnow", "moss_skipper"]:
		assert_true(app.controller.progression.record_specimen(_record(species)).ok)
	_land("cork_chub")
	var earned: Array[Dictionary] = _gear_notices("Drift Rod")
	assert_eq(earned.size(), 1)
	assert_true("drift_rod" in SaveStore.new(app.save_path).load_or_recover().state.owned_rods)
	assert_eq(app.controller.progression.snapshot().profiles.crew_1.rod_id, "starter")
	_land("kite_sprat")
	assert_eq(_gear_notices("Drift Rod").size(), 1)
