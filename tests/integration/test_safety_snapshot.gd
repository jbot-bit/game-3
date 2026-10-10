extends GutTest
const Game = preload("res://game/main.gd")
var app: Node

func before_each() -> void:
	app=Game.new()
	app.game_port=24936
	app.save_path="user://tests/shelter-truth-"+str(Time.get_ticks_usec())+".json"
	app.settings_path=app.save_path+"-settings.json"
	add_child_autofree(app)
	app._host("Shelter")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await get_tree().process_frame

func after_each() -> void:
	app.session.close()

func test_powered_field_boundary_and_expiry_match_hunter_safety() -> void:
	var c: Node=app.controller
	c.run.elapsed_s=360.0
	c.lights.set_reserve("reeds")
	c.avatars.crew_1.global_position=app.world.markers.reeds
	var status: Dictionary=c.snapshot().safety.crew_1
	assert_eq(status.shelter_id,"reeds")
	assert_true(status.protected)
	assert_true(status.field_protected)
	assert_almost_eq(status.station_remaining,30.0,0.001)
	c.avatars.crew_1.global_position=app.world.markers.reeds+Vector3(6.5,0,0)
	status=c.snapshot().safety.crew_1
	assert_false(status.protected,"A nearby light is not protection outside its circle")
	assert_false(status.field_protected)
	c.avatars.crew_1.global_position=app.world.markers.reeds
	c.run.elapsed_s=390.0
	status=c.snapshot().safety.crew_1
	assert_false(status.protected)
	assert_eq(status.station_remaining,0.0)

func test_keeper_does_not_relight_a_dark_station_and_moth_stays_safe() -> void:
	var c: Node=app.controller
	c.run.elapsed_s=400.0
	c.avatars.crew_1.global_position=app.world.markers.reeds
	c.keeper_position=app.world.markers.reeds
	c.abilities.keeper_until=410.0
	var status: Dictionary=c.snapshot().safety.crew_1
	assert_true(status.protected)
	assert_false(status.field_protected,"Keeper protection must not be attributed to an expired field light")
	assert_eq(status.station_remaining,0.0)
	c.avatars.crew_1.global_position=app.world.markers.boat
	c.run.elapsed_s=620.0
	status=c.snapshot().safety.crew_1
	assert_eq(status.shelter_id,"boat")
	assert_true(status.protected)
	assert_false(status.field_protected)
	assert_almost_eq(status.moth_distance,0.0,0.001)
