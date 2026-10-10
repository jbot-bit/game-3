extends GutTest
const Lights=preload("res://game/survival/light_rules.gd")
const Hunter=preload("res://game/survival/hunter_rules.gd")

func test_day_cell_and_later_reserve_add_without_overwriting_each_other():
	var lights=Lights.new()
	assert_true(lights.has_method("feed_station"),"Field cells must extend a real finite power budget")
	if not lights.has_method("feed_station"): return
	assert_true(lights.feed_station("reeds","cell_1",30.0).ok)
	assert_eq(lights.station_remaining("reeds",100.0),90.0)
	assert_true(lights.set_reserve("reeds").ok)
	assert_true(lights.station_powered("reeds",479.9))
	assert_false(lights.station_powered("reeds",480.0))
	assert_eq(lights.station_remaining("reeds",100.0),240.0)
	var alternate=Lights.new()
	alternate.set_reserve("reeds")
	alternate.feed_station("reeds","cell_1",100.0)
	assert_eq(alternate.station_remaining("reeds",100.0),240.0)

func test_expired_station_relights_from_delivery_time_and_cell_cannot_power_twice():
	var lights=Lights.new()
	assert_true(lights.has_method("feed_station"))
	if not lights.has_method("feed_station"): return
	assert_false(lights.station_powered("jetty",400.0))
	assert_true(lights.feed_station("jetty","cell_1",400.0).ok)
	assert_true(lights.station_powered("jetty",489.9))
	assert_false(lights.station_powered("jetty",490.0))
	assert_false(lights.feed_station("reeds","cell_1",410.0).ok)
	assert_false(lights.station_powered("reeds",410.0))
	assert_eq(lights.station_remaining("jetty",410.0),80.0)
	assert_true(lights.feed_station("jetty","cell_2",420.0).ok)
	assert_eq(lights.station_remaining("jetty",420.0),160.0)

func test_power_rejects_invalid_deliveries_without_consuming_cell_and_stops_at_storm_end():
	var lights=Lights.new()
	assert_true(lights.has_method("feed_station"))
	if not lights.has_method("feed_station"): return
	assert_false(lights.feed_station("boat","cell_1",300.0).ok)
	assert_false(lights.feed_station("jetty","cell_1",NAN).ok)
	assert_false(lights.feed_station("jetty","cell_1",-1.0).ok)
	assert_false(lights.feed_station("jetty","",300.0).ok)
	assert_true(lights.feed_station("jetty","cell_1",600.0).ok)
	assert_eq(lights.station_remaining("jetty",600.0),30.0)
	assert_false(lights.feed_station("jetty","cell_2",610.0).ok)
	assert_true(lights.feed_station("reeds","cell_2",610.0).ok)
	assert_true(lights.station_powered("reeds",629.9))
	assert_false(lights.station_powered("reeds",630.0))
	assert_false(lights.feed_station("jetty","cell_3",630.0).ok)
	assert_eq(lights.station_remaining("reeds",640.0),0.0)
	assert_false(lights.station_powered("jetty",NAN))
	var data: Dictionary=lights.snapshot()
	data.station_until.jetty=1000.0
	assert_false(lights.station_powered("jetty",700.0))

func test_revive_hold_delays_new_hunt_but_does_not_cancel_a_committed_chase():
	var hunter=Hunter.new()
	assert_eq(hunter.advance(4.0,{"night":true,"target_visible":true,"rescuing":true}).state,"patrol")
	assert_eq(hunter.advance(0.0,{"night":true,"target_visible":true}).state,"warn")
	assert_false(hunter.advance(1.99,{"night":true,"target_visible":true}).can_attack)
	assert_true(hunter.advance(0.01,{"night":true,"target_visible":true}).can_attack)
	assert_true(hunter.advance(0.1,{"night":true,"rescuing":true}).can_attack)
	assert_eq(hunter.advance(0.0,{"night":true,"caught":true}).state,"recover")
	assert_eq(hunter.advance(100.0,{"night":true,"paused":true}).state,"recover")
	assert_eq(hunter.advance(12.0,{"night":true,"target_visible":true}).state,"patrol")
	assert_eq(hunter.advance(0.0,{"night":true,"target_visible":true}).state,"warn")
	assert_false(hunter.advance(0.0,{"night":true,"target_visible":true}).can_attack)

func test_patrol_visits_both_coasts_and_continues_cyclically():
	var patrol=_patrol()
	if patrol==null: return
	var route: Array=[Vector3(-60,2,10),Vector3(-40,2,-55),Vector3(65,2,-30)]
	assert_eq(patrol.next_goal(240.0,Vector3(60,2,-25),route),Vector3(65,2,-30))
	assert_eq(patrol.next_goal(242.0,Vector3(65,2,-30),route),Vector3(-60,2,10))
	assert_eq(patrol.next_goal(300.0,Vector3(-60,2,10),route),Vector3(-40,2,-55))
	assert_eq(patrol.next_goal(330.0,Vector3(-40,2,-55),route),Vector3(65,2,-30))
	assert_eq(patrol.mode,"patrol")

func test_heard_noise_draws_hunter_then_expires_without_following_moving_players():
	var patrol=_patrol()
	if patrol==null: return
	var route: Array=[Vector3(-60,2,10),Vector3(65,2,-30)]
	patrol.next_goal(240.0,Vector3(-55,2,10),route)
	assert_true(patrol.record_noise(Vector3(-30,2,10),241.0))
	assert_eq(patrol.next_goal(242.0,Vector3(-55,2,10),route),Vector3(-30,2,10))
	assert_eq(patrol.mode,"investigate")
	assert_eq(patrol.next_goal(252.9,Vector3(-55,2,10),route),Vector3(-30,2,10))
	assert_eq(patrol.next_goal(253.0,Vector3(-55,2,10),route),Vector3(-60,2,10))
	assert_eq(patrol.mode,"patrol")

func test_far_noise_and_invalid_noise_do_not_reveal_crew_anywhere_on_island():
	var patrol=_patrol()
	if patrol==null: return
	var route: Array=[Vector3(-60,2,10),Vector3(65,2,-30)]
	assert_true(patrol.record_noise(Vector3(65,2,-30),240.0))
	assert_eq(patrol.next_goal(241.0,Vector3(-55,2,10),route),Vector3(-60,2,10))
	assert_eq(patrol.mode,"patrol")
	assert_false(patrol.record_noise(Vector3(NAN,2,10),242.0))
	assert_false(patrol.record_noise(Vector3(-30,2,10),NAN))
	assert_eq(patrol.next_goal(242.0,Vector3(-55,2,10),[]),Vector3(-55,2,10))

func test_arriving_at_noise_resumes_patrol_and_stale_noise_cannot_replace_newer_cue():
	var patrol=_patrol()
	if patrol==null: return
	var route: Array=[Vector3(-60,2,10),Vector3(65,2,-30)]
	patrol.next_goal(240.0,Vector3(-55,2,10),route)
	patrol.record_noise(Vector3(-30,2,10),242.0)
	assert_false(patrol.record_noise(Vector3(-40,2,10),241.0))
	assert_eq(patrol.next_goal(243.0,Vector3(-55,2,10),route),Vector3(-30,2,10))
	assert_eq(patrol.next_goal(244.0,Vector3(-30,2,10),route),Vector3(-60,2,10))
	assert_eq(patrol.mode,"patrol")

func test_inaudible_other_crews_cast_does_not_erase_a_heard_noise():
	var patrol=_patrol()
	if patrol==null: return
	var route: Array=[Vector3(-60,2,10),Vector3(65,2,-30)]
	patrol.record_noise(Vector3(-30,2,10),240.0)
	assert_eq(patrol.next_goal(241.0,Vector3(-55,2,10),route),Vector3(-30,2,10))
	patrol.record_noise(Vector3(65,2,-30),242.0)
	assert_eq(patrol.next_goal(243.0,Vector3(-55,2,10),route),Vector3(-30,2,10))
	assert_eq(patrol.noise_until,252.0)
	patrol.record_noise(Vector3(-25,2,10),244.0)
	patrol.record_noise(Vector3(65,2,-30),244.1)
	assert_eq(patrol.next_goal(245.0,Vector3(-55,2,10),route),Vector3(-25,2,10))
	assert_eq(patrol.noise_until,256.0)

func _patrol():
	var path: String="res://game/survival/patrol_rules.gd"
	assert_true(FileAccess.file_exists(path),"Hunter needs a patrol/investigation model")
	if not FileAccess.file_exists(path): return null
	var script: GDScript=load(path)
	return script.new()
