extends GutTest
const Game = preload("res://game/main.gd")
var app: Node3D

func before_each() -> void:
	app = Game.new()
	app.game_port = 24637
	app.save_path = "user://tests/boat-action-" + str(Time.get_ticks_usec()) + ".json"
	app.settings_path = "user://tests/boat-settings-" + str(Time.get_ticks_usec()) + ".json"
	add_child_autofree(app)
	app._host("Crew")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await get_tree().physics_frame
	app.controller.avatars.crew_1.global_position = app.world.markers.boat
	app.controller._publish()

func after_each() -> void:
	app.session.close()

func test_empty_hands_at_ready_boat_offer_escape_instead_of_empty_banking() -> void:
	app.controller.snapshot_data.escape = {"can_arm": true}
	assert_eq(app._context().get("action", ""), "arm_escape")

func test_engine_repair_is_reachable_with_one_context_action() -> void:
	var saved: Dictionary = app.controller.snapshot_data.progression
	saved.coins = 200
	saved.campaign_flags.engine_part = true
	saved.repairs.workshop = true
	saved.repairs.beacon = true
	var context: Dictionary = app._context()
	assert_eq(context.get("action", ""), "repair")
	assert_eq(context.get("payload", {}).get("repair_id", ""), "moth_engine")

func test_bank_real_pouch_before_offering_escape() -> void:
	app.controller.snapshot_data.escape = {"can_arm": true}
	app.controller.snapshot_data.cargo = {"caught": {"state": "packed", "carrier_id": "", "pouch_profile_id": "crew_1"}}
	assert_eq(app._context().get("action", ""), "bank")

func test_empty_unrepaired_boat_explains_goal_without_useless_bank_button() -> void:
	assert_ne(app._context().get("action", ""), "bank")
	assert_string_contains(str(app._context().get("text", "")), "engine")
