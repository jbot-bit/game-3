extends GutTest
const Game = preload("res://game/main.gd")
var app: Node3D

func before_each() -> void:
	app = Game.new()
	app.game_port = 24891
	var fixture: String = "user://tests/one-button-" + str(Time.get_ticks_usec())
	app.save_path = fixture + "-household.json"
	app.settings_path = fixture + "-settings.json"
	add_child_autofree(app)
	app._host("Angler")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	app.controller.avatars.crew_1.global_position = app.world.markers.jetty
	app.controller.avatars.crew_1.last_dry = app.world.markers.jetty
	await get_tree().physics_frame

func after_each() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	app.session.close()

func mouse(held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	event.position = Vector2(450,250)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_real_mouse_hold_moves_right_and_release_moves_left() -> void:
	mouse(true)
	await get_tree().process_frame
	assert_true(app.controller.fishing.casts.has("crew_1"),"Left click starts the cast")
	if not app.controller.fishing.casts.has("crew_1"): return
	# Advance only the ordinary controller; no cast state or progress injection.
	for frame: int in range(20):
		app._physics_process(0.05)
		app.controller._tick_players(0.05)
	var right: float = app.controller.fishing.casts.crew_1.bar_position
	assert_gt(right,0.5,"Holding the button moves right without any directional keys")
	mouse(false)
	await get_tree().process_frame
	for frame: int in range(4):
		app._physics_process(0.05)
		app.controller._tick_players(0.05)
	assert_lt(float(app.controller.fishing.casts.crew_1.bar_position),right,"Releasing moves left")
	assert_almost_eq(float(app.controller.inputs.crew_1.pull),0.0,0.00001,"No keyboard counter-pull is sent")

func test_fish_escape_clears_the_pending_catch_and_tells_you_how_to_retry() -> void:
	assert_true(app.controller._cast("crew_1").ok)
	app.controller.apply_intent(1,"reel",{"held":true,"pull":0.0},"hold-away")
	for frame: int in range(520):
		if not app.controller.fishing.casts.has("crew_1"): break
		app.controller._tick_players(0.05)
	assert_false(app.controller.fishing.casts.has("crew_1"))
	assert_false(app.controller.rolled.has("crew_1"),"An escaped fish cannot be landed or saved later")
	assert_eq(app.controller.progression.snapshot().landed_catch_ids.size(),0)
	assert_string_contains(app.controller.notes.back().text,"inside your bar")
	assert_true(app.controller._cast("crew_1").ok,"Retry is immediate")

func test_tracking_lands_exactly_one_real_catch_and_banks_it_once() -> void:
	assert_true(app.controller._cast("crew_1").ok)
	var seconds: float = 0.0
	for frame: int in range(300):
		if not app.controller.fishing.casts.has("crew_1"): break
		var cast: Dictionary = app.controller.fishing.casts.crew_1
		app.controller.apply_intent(1,"reel",{"held":float(cast.fish_position)>float(cast.bar_position),"pull":0.0},"track-"+str(frame))
		app.controller._tick_players(0.05)
		seconds += 0.05
	assert_between(seconds,5.0,8.0,"Ordinary first catches finish quickly with good tracking")
	var saved: Dictionary = app.controller.progression.snapshot()
	assert_eq(saved.landed_catch_ids.size(),1)
	assert_false(app.controller.rolled.has("crew_1"))
	if saved.landed_catch_ids.is_empty(): return
	var id: String = saved.landed_catch_ids[0]
	# A natural oversized roll still requires ordinary pickup before banking.
	if app.controller.cargo.snapshot()[id].state == "whole_loose":
		assert_true(app.controller.apply_intent(1,"grab_fish",{"catch_id":id},"carry").ok)
	app.controller.avatars.crew_1.global_position = app.world.markers.boat
	assert_true(app.controller.apply_intent(1,"bank",{},"bank-once").ok)
	var coins: int = app.controller.progression.snapshot().coins
	assert_gt(coins,0)
	app.controller.apply_intent(1,"bank",{},"bank-twice")
	assert_eq(app.controller.progression.snapshot().coins,coins,"Repeated banking never repeats the reward")
