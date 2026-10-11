extends GutTest
## Main-game safeguards. Stage fixtures below isolate completion from traversal;
## the separate three-puppet physics probe proves the physical obstacles.
const Game = preload("res://prototypes/physics_party/main.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
var port: int = 25031
var save_path: String

class FailingRules extends "res://prototypes/physics_party/party_rules.gd":
	var fail_writes: bool = true
	func _commit(runs: Array[String], powers: Array[String]) -> Error:
		return ERR_FILE_CANT_WRITE if fail_writes else super._commit(runs, powers)

func before_each() -> void:
	save_path = "user://test_party_coop_%s_%s/progress.json" % [Time.get_ticks_usec(), randi()]

func after_each() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))

func _host(count: int = 3, storage: RefCounted = null):
	var app = Game.new()
	if storage != null: app.rules = storage
	app.scripted = true
	app.progress_path = save_path
	app.game_port = port
	port += 1
	add_child_autofree(app)
	app._host("Host")
	app.set_process(false)
	app.set_physics_process(false)
	for slot in range(1, count): app.session.players["crew_%d" % (slot + 1)] = {"peer": slot + 20, "slot": slot, "name": "Friend %d" % slot}
	app._roster_changed(app.session.players)
	for id in app.state.players: app._action(id, "power", "spring")
	return app

func _solved_fixture(app) -> void:
	for stage in app.teamwork.stages:
		stage.latched = true
		stage.amount = 1.0
	for id in app.avatars:
		app.state.players[id].checkpoint = 5
		app.avatars[id].reset_at(app._goal_spawn(int(app.session.players[id].slot)))

func test_every_course_requires_three_team_stages_and_cannot_clear_at_either_exit() -> void:
	var app = _host()
	for course in Courses.IDS:
		app._restart(course)
		assert_not_null(app.teamwork, course + " includes the mandatory stages in the shipped default")
		assert_eq(app.teamwork.stages.size(), 3)
		assert_true(app.world.props.has("team_cargo"))
		for destination in ["old", "new"]:
			for id in app.avatars:
				app.state.players[id].power = "spring"
				app.state.players[id].checkpoint = 1
				var slot: int = app.session.players[id].slot
				app.avatars[id].reset_at(app.world.spawn_point(slot, 2) if destination == "old" else app._goal_spawn(slot))
			app._physics_process(1.0 / 60.0)
			assert_eq(app.state.phase, "play", course + " cannot clear by grappling straight to " + destination + " exit")
			assert_eq(app.state.completions, 0)
			assert_eq(app.state.reward_cards, [])
		for stage in app.teamwork.stages:
			assert_true(stage.near.is_finite() and stage.far.is_finite())
			assert_lt(stage.far.length(), 500.0)
		assert_gt(app._goal_spawn(1).distance_to(app.world.spawn_point(1, 2)), 120.0)
		await get_tree().process_frame
	app.session.close()
	await get_tree().process_frame

func test_finish_requires_all_three_and_awards_one_bag_then_preserves_the_earned_style() -> void:
	var app = _host()
	app._action("crew_2", "appearance", "mint|crown")
	assert_eq(app.state.players.crew_2.appearance, Cosmetics.default_style(1), "A forged appearance cannot unlock cards")
	assert_eq(app.rules.cosmetic_collection(), [])
	_solved_fixture(app)
	app.avatars.crew_3.reset_at(app.world.spawn_point(2))
	app._physics_process(1.0 / 60.0)
	assert_eq(app.state.phase, "play", "Two at extraction cannot finish for a missing third player")
	app.avatars.crew_3.reset_at(app._goal_spawn(2))
	app._physics_process(1.0 / 60.0)
	assert_eq(app.state.phase, "complete")
	assert_eq(app.state.reward_cards.size(), 3)
	assert_eq(app.state.reward_run_id, app.run_id)
	assert_eq(app.state.completions, 1)
	var cards: Array = app.state.reward_cards.duplicate()
	var rng_state: int = app.rules.reward_rng.state
	app._physics_process(1.0 / 60.0)
	assert_eq(app.state.reward_cards, cards)
	assert_eq(app.rules.reward_rng.state, rng_state)
	assert_eq(app.state.completions, 1)
	var style: Dictionary = Cosmetics.default_style(1)
	var earned: Dictionary = Cosmetics.card_info(cards[0])
	style["color" if earned.kind == "color" else "accessory"] = earned.value
	app._action("crew_2", "appearance", style.color + "|" + style.accessory)
	assert_eq(app.state.players.crew_2.appearance, style)
	assert_eq(app.avatars.crew_2._appearance, style)
	assert_eq(app.rules.appearance_for(1), style)
	app._restart()
	assert_eq(app.state.players.crew_2.appearance, style)
	assert_eq(app.state.reward_cards, [], "A restart does not reopen the previous run's bag")
	assert_eq(app.teamwork.capture().latched, [false, false, false])
	assert_eq(app.state.teamwork, app.teamwork.capture(), "Reliable restart state cannot retain old stage latches")
	assert_eq(app.state.completions, 1)
	app.session.close()
	await get_tree().process_frame

func test_even_solved_stages_cannot_finish_with_only_two_players() -> void:
	var app = _host(2)
	_solved_fixture(app)
	app._physics_process(1.0 / 60.0)
	assert_eq(app.state.phase, "play")
	assert_eq(app.state.completions, 0)
	assert_eq(app.state.reward_cards, [])
	app.session.close()
	await get_tree().process_frame

func test_failed_save_retry_keeps_the_same_clear_and_reveals_its_bag_before_replay() -> void:
	var storage := FailingRules.new()
	var app = _host(3, storage)
	_solved_fixture(app)
	app._physics_process(1.0 / 60.0)
	var completed_run: String = app.run_id
	var rolled_state: int = storage.reward_rng.state
	assert_true(app.state.save_failed)
	assert_eq(app.state.reward_cards, [])
	assert_eq(app.state.completions, 0)
	app._restart()
	assert_eq(storage.reward_rng.state, rolled_state, "Repeated failure cannot reroll the pending bag")
	assert_eq(app.run_id, completed_run)
	storage.fail_writes = false
	app._restart()
	assert_eq(app.run_id, completed_run)
	assert_eq(app.state.phase, "complete", "Retry save stays on the completed run so the bag can be opened")
	assert_false(app.state.save_failed)
	assert_eq(app.state.reward_run_id, completed_run)
	assert_eq(app.state.reward_cards.size(), 3)
	assert_eq(app.state.completions, 1)
	assert_eq(storage.reward_rng.state, rolled_state)
	app._action("crew_1", "next_course", "")
	assert_eq(app.course_id, "counterweight")
	assert_eq(app.state.completions, 1)
	assert_ne(app.run_id, completed_run)
	assert_eq(app.state.reward_cards, [])
	app.session.close()
	await get_tree().process_frame
