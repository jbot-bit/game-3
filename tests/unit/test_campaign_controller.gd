extends GutTest
const Mission=preload("res://game/expedition/campaign_controller.gd")

func test_escape_needs_repairs_night_signal_and_departure() -> void:
	var mission=Mission.new()
	assert_eq(mission.arm(false,250).code,"finish_repairs_first")
	assert_eq(mission.arm(true,100).code,"wait_for_night")
	assert_false(mission.signal_beacon(250).ok)
	assert_true(mission.arm(true,250).ok)
	assert_false(mission.depart(260))
	assert_true(mission.signal_beacon(260).ok)
	assert_true(mission.depart(270))
	assert_true(mission.departing)
	assert_false(mission.completed)
	mission.settled()
	assert_true(mission.completed)

func test_failed_or_ordinary_outing_cannot_finish_campaign() -> void:
	var mission=Mission.new()
	mission.settled()
	assert_false(mission.completed)
	mission.arm(true,250)
	mission.signal_beacon(251)
	assert_false(mission.depart(630))
	mission.settled()
	assert_false(mission.completed)

func test_departure_receipt_and_continue_are_separate_from_persistent_completion() -> void:
	var mission=Mission.new()
	mission.arm(true,250)
	mission.signal_beacon(251)
	mission.depart(252)
	assert_eq(mission.arm(true,253).code,"already_departing")
	mission.settled()
	assert_true(mission.snapshot(true,270).completed)
	mission.reset()
	assert_false(mission.snapshot(true,0).completed)
	assert_false(mission.departing)
