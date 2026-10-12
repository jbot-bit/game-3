extends "res://tests/network_actions.gd"

class FixtureApp extends RefCounted:
	const Sim = preload("res://sim.gd")
	var sim = Sim.new()

var fixture_checks = 0
var fixture_failures = 0

func _initialize() -> void:
	call_deferred("check_fixture")

func _process(_dt: float) -> bool:
	return false

func check_fixture() -> void:
	app = FixtureApp.new()
	app.sim.reset("teams", {"humans": [1,2,3], "teams": {1:0,2:0,3:1}, "balance":false})
	app.sim.reset_time = 0
	app.sim.launch_kickoff()
	var kickoff = app.sim.snapshot()
	verify(not expected_matches(expectation(8), kickoff), "Fresh kickoff must not satisfy side-pad launch checkpoint")
	place(2,app.Sim.PADS[2],Vector3.FORWARD)
	verify(app.sim.players[2].pad_cooldown == 0, "Fixture placement removes inherited kickoff pad cooldown")
	app.sim.step(1.0/60)
	verify(app.sim.players[2].jump_count == 1 and app.sim.players[2].vel.y > 25, "Placed actor launches from actual pad on physics step")
	var accepted = false
	for tick in 30:
		app.sim.step(1.0/60)
		if expected_matches(expectation(8),app.sim.snapshot()):
			accepted = true
			break
	verify(accepted, "Real pad ascent satisfies bounded launch checkpoint")
	app.sim.action(2,"jump")
	for tick in 20: app.sim.step(1.0/60)
	verify(expected_matches(expectation(9),app.sim.snapshot()), "Extra jump after real launch satisfies checkpoint")
	place(2,app.Sim.SPEED_PADS[0],Vector3.FORWARD)
	app.sim.move_input(2,Vector3.FORWARD,Vector3.FORWARD)
	var speed_accepted = false
	for tick in 10:
		app.sim.step(1.0/60)
		if expected_matches(expectation(10),app.sim.snapshot()): speed_accepted = true
	verify(speed_accepted, "Real speed strip accepts grounded boost on raised terrain")
	var airborne = app.sim.snapshot()
	airborne.players[2].pos.y = app.Sim.floor_height(airborne.players[2].pos.x,airborne.players[2].pos.z)+3
	verify(not expected_matches(expectation(10),airborne), "Airborne launch cannot satisfy grounded speed-strip checkpoint")
	print("NETWORK_ACTION_FIXTURE_RESULT checks=%d failures=%d" % [fixture_checks,fixture_failures])
	quit(0 if fixture_failures == 0 else 1)

func verify(ok: bool, label: String) -> void:
	fixture_checks += 1
	if not ok: fixture_failures += 1
	print(("PASS " if ok else "FAIL ")+label)
