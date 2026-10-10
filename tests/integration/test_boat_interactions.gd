extends GutTest
const Game = preload("res://game/main.gd")
var app: Node3D

func before_each() -> void:
	app = Game.new()
	var stamp: String = str(Time.get_ticks_usec())
	app.save_path = "user://tests/boat-actions-" + stamp + ".json"
	app.settings_path = "user://tests/boat-settings-" + stamp + ".json"
	app.game_port = 24887
	add_child_autofree(app)
	app._host("Boat test")
	app.set_physics_process(false)
	app.set_process(false)
	app.controller.set_physics_process(false)
	app.controller.avatars.crew_1.global_position = app.world.markers.boat
	app.controller.avatars.crew_1.last_dry = app.world.markers.boat
	await wait_physics_frames(2)
	app.controller._publish()

func after_each() -> void:
	app.session.close()

func add_pouch() -> void:
	var record: Dictionary = CatchTable.roll("jetty","day",0,0.2,0.5,0.5)
	record.merge({"catch_id":"boat-catch","run_id":app.controller.run.run_id,"profile_id":"crew_1"})
	assert_true(app.controller.progression.record_specimen(record).ok)
	app.controller._add_landed(record)
	app.controller._publish()

func tap(action: String) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = app.settings.action_key(action)
	key.pressed = true
	app._unhandled_input(key)

func test_interact_banks_pouch_while_keeping_held_cell() -> void:
	add_pouch()
	var c: RunController = app.controller
	var actor: Angler = c.avatars.crew_1
	c.supply_bodies.cell_1.global_position = actor.global_position+Vector3.UP
	c.supply_bodies.cell_1.freeze = true
	assert_true(c.apply_intent(1,"grab_cell",{"cell_id":"cell_1"},"grab").ok)
	c.supply_bodies.cell_1.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6)
	await wait_physics_frames(2)
	c._publish()
	assert_eq(app._context().get("action"), "bank")
	tap("interact")
	assert_eq(c.progression.snapshot().coins, 10)
	assert_eq(c.supplies.held_by("crew_1"), "cell_1")

func test_nearby_loose_cell_does_not_steal_the_bank_action() -> void:
	add_pouch()
	app.controller.supply_bodies.cell_1.global_position = app.world.markers.boat+Vector3.UP
	app.controller.supply_bodies.cell_1.freeze = true
	app.controller._publish()
	assert_eq(app._context().get("action"), "bank")
	tap("interact")
	assert_eq(app.controller.progression.snapshot().coins, 10)
	assert_eq(app.controller.supplies.held_by("crew_1"), "")

func test_first_outing_shows_remapped_ready_control_before_engine_repair() -> void:
	app.settings.set_binding("ready", KEY_N)
	assert_string_contains(app._context().text, "N")
	assert_string_contains(app._context().text.to_lower(), "refuge")
	tap("ready")
	app.controller._physics_process(0.02)
	assert_eq(app.controller.run.phase, "refuge")
	assert_gt(app.controller.run.crossing_left, 0.0)
	assert_false(app.controller.progression.snapshot().repairs.get("moth_engine", false))

func test_found_engine_part_reports_coin_shortfall_and_keeps_refuge_visible() -> void:
	var data: Dictionary = app.controller.snapshot()
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 49
	var context: Dictionary = app._boat_context(data,"crew_1","E")
	assert_string_contains(context.text,"31")
	assert_false(context.text.contains("Find the engine part"))
	assert_string_contains(context.text,"refuge")

func test_rescuing_nearby_teammate_still_precedes_banking() -> void:
	add_pouch()
	app.session.roster.assign(2,1,Session.BUILD_ID)
	app.controller._roster_changed(app.session.roster.snapshot())
	app.controller.avatars.crew_2.global_position = app.world.markers.boat+Vector3(1,0,0)
	app.controller.run.players.crew_2.protection = 0.0
	app.controller.run.down("crew_2")
	app.controller._publish()
	assert_eq(app._context().get("action"),"revive")

func test_escape_and_affordable_engine_actions_keep_their_priority() -> void:
	var data: Dictionary = app.controller.snapshot()
	data.escape.can_arm = true
	assert_eq(app._boat_context(data,"crew_1","E").get("action"),"arm_escape")
	data.escape.can_arm = false
	data.progression.campaign_flags.engine_part = true
	data.progression.coins = 80
	assert_eq(app._boat_context(data,"crew_1","E").get("action"),"repair")
	data.progression.repairs.moth_engine = true
	data.escape.signalled = true
	assert_string_contains(app._boat_context(data,"crew_1","E").text,"escape")
