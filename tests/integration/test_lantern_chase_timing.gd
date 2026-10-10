extends GutTest

const Game = preload("res://game/main.gd")
var app: Node
var controller: RunController

func before_each() -> void:
	app = Game.new()
	app.game_port = 24979
	var fixture: String = "user://tests/lantern-chase-" + str(Time.get_ticks_usec())
	app.save_path = fixture + ".json"
	app.settings_path = fixture + "-settings.json"
	add_child_autofree(app)
	app._host("Lantern timing")
	controller = app.controller
	controller.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	await get_tree().physics_frame
	var actor: Angler = controller.avatars.crew_1
	actor.global_position = Vector3(0,2.05,-22.7)
	actor.rotation.y = PI / 2.0
	actor.set_loadout(controller.progression.snapshot().profiles.crew_1,90,true)
	controller.hunter.global_position = Vector3(-6,2.05,-22.7)
	controller.run.elapsed_s = 300.0
	controller.run.phase = "night"

func after_each() -> void:
	app.session.close()

func _speed() -> float:
	return Vector2(controller.hunter.velocity.x,controller.hunter.velocity.z).length()

func test_facing_stationary_warning_does_not_spend_lantern_slowdown() -> void:
	controller._tick_hunter(0.0)
	assert_eq(controller.hunter_rules.state,"warn")
	assert_eq(_speed(),0.0)
	assert_eq(controller.hunter_slow_until,0.0)
	assert_false(controller.lights.slow_ready.has("lifeguard"))

func test_lantern_starts_full_effect_when_warning_becomes_chase() -> void:
	controller._tick_hunter(0.0)
	controller.run.elapsed_s = 302.1
	controller._tick_hunter(2.1)
	assert_eq(controller.hunter_rules.state,"chase")
	assert_almost_eq(_speed(),4.7 * 0.35,0.0001)
	assert_almost_eq(controller.hunter_slow_until,304.1,0.0001)
	assert_almost_eq(float(controller.lights.slow_ready.lifeguard),310.1,0.0001)
	assert_false(controller.run.players.crew_1.downed)

func test_active_chase_keeps_two_second_effect_and_eight_second_cooldown() -> void:
	controller.hunter_rules.state = "chase"
	controller.hunter_target = "crew_1"
	controller._tick_hunter(0.0)
	assert_almost_eq(_speed(),4.7 * 0.35,0.0001)
	assert_almost_eq(controller.hunter_slow_until,302.0,0.0001)
	assert_almost_eq(float(controller.lights.slow_ready.lifeguard),308.0,0.0001)
	controller.run.elapsed_s = 302.1
	controller._tick_hunter(2.1)
	assert_almost_eq(_speed(),4.7,0.0001)
	controller.run.elapsed_s = 307.99
	controller._tick_hunter(5.89)
	assert_almost_eq(_speed(),4.7,0.0001)
	assert_almost_eq(float(controller.lights.slow_ready.lifeguard),308.0,0.0001)
	controller.run.elapsed_s = 308.0
	controller._tick_hunter(0.01)
	assert_almost_eq(_speed(),4.7 * 0.35,0.0001)
	assert_almost_eq(controller.hunter_slow_until,310.0,0.0001)
	assert_almost_eq(float(controller.lights.slow_ready.lifeguard),316.0,0.0001)
