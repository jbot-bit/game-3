extends GutTest
const Match = preload("res://prototypes/physics_party/party_match.gd")

class Arena extends Node3D:
	var elimination_y: float = -2.0
	var hazard_phase: String = "unconfigured"
	var hazard_round: int = -1
	func set_round_phase(value: String, number: int) -> void:
		hazard_phase = value
		hazard_round = number

class Actor extends Node3D:
	var point := Vector3(0, 5, 0)
	var is_on_floor: bool = true
	var physics_bones: Array[PhysicalBone3D] = []
	func body_position() -> Vector3: return point
	func set_combat_visual(_enabled: bool, _swing: float, _braced: bool, _yaw: float) -> void: pass
	func apply_combat_impact(_velocity: Vector3, _grace: float) -> void: pass

func fixture(count: int = 2) -> Dictionary:
	var arena := Arena.new()
	add_child_autofree(arena)
	var match_rules = Match.new()
	match_rules.configure(arena)
	var actors: Dictionary = {}
	for index in count:
		var actor := Actor.new()
		add_child_autofree(actor)
		actors["crew_" + str(index + 1)] = actor
	return {"match": match_rules, "actors": actors}

func advance(data: Dictionary, seconds: float) -> Dictionary:
	var result: Dictionary = {}
	for step in ceili(seconds * 60.0): result = data.match.tick(data.actors, {}, 1.0 / 60.0)
	return result

func start_fight(data: Dictionary) -> void:
	var event: Dictionary = data.match.tick(data.actors, {}, 1.0 / 60.0)
	assert_eq(event.reset_ids.size(), data.actors.size())
	assert_eq(data.match.phase, "countdown")
	assert_false(data.match.controls_allowed("crew_1"))
	advance(data, 3.1)
	assert_eq(data.match.phase, "fight")
	assert_true(data.match.controls_allowed("crew_1"))

func test_solo_is_practice_without_wins_and_falls_reset() -> void:
	var data := fixture(1)
	advance(data, 5)
	assert_eq(data.match.phase, "practice")
	data.actors.crew_1.point.y = -3
	var event: Dictionary = data.match.tick(data.actors, {}, 0.02)
	assert_eq(event.reset_ids, ["crew_1"])
	assert_false(event.completed)
	assert_eq(data.match.scores.crew_1, 0)
	assert_eq(data.match.winner_id(), "")

func test_hazards_follow_match_lifecycle_including_reset_and_disconnect() -> void:
	var data := fixture(2)
	var arena: Arena = data.match.world
	assert_eq(arena.hazard_phase, "practice", "New world receives the practice phase")
	data.match.tick(data.actors, {}, 1.0 / 60.0)
	assert_eq(arena.hazard_phase, "countdown", "Round setup stops the hazards")
	assert_eq(arena.hazard_round, 1)
	advance(data, 3.1)
	assert_eq(arena.hazard_phase, "fight", "Hazards start only when players can move")
	data.actors.erase("crew_2")
	advance(data, 0.1)
	assert_eq(arena.hazard_phase, "practice")
	data.match.reset()
	assert_eq(arena.hazard_round, 0, "Rematch resets the hazard round identity")

func test_three_wins_complete_exactly_once() -> void:
	var data := fixture(2)
	start_fight(data)
	for round_index in 3:
		data.actors.crew_2.point.y = -3
		var completion_events: int = 0
		for step in 15:
			if data.match.tick(data.actors, {}, 1.0 / 60.0).completed: completion_events += 1
		assert_eq(data.match.scores.crew_1, round_index + 1)
		if round_index < 2:
			assert_eq(completion_events, 0)
			data.actors.crew_2.point.y = 5
			advance(data, 6.2)
			assert_eq(data.match.phase, "fight")
		else:
			assert_eq(completion_events, 1)
			assert_eq(data.match.phase, "complete")
			assert_eq(data.match.winner_id(), "crew_1")
	assert_false(advance(data, 2).completed)
	assert_true(Match.valid_snapshot(data.match.capture()))

func test_simultaneous_fall_draw_and_timeout_draw() -> void:
	var data := fixture(2)
	start_fight(data)
	data.actors.crew_1.point.y = -3
	advance(data, 0.05)
	data.actors.crew_2.point.y = -3
	advance(data, 0.2)
	assert_eq(data.match.phase, "intermission")
	assert_eq(data.match.scores, {"crew_1": 0, "crew_2": 0})
	for actor: Actor in data.actors.values(): actor.point.y = 5
	advance(data, 6.2)
	advance(data, 90.1)
	assert_eq(data.match.phase, "intermission")
	assert_eq(data.match.scores, {"crew_1": 0, "crew_2": 0})

func test_disconnect_aborts_round_without_win_and_late_join_waits() -> void:
	var data := fixture(2)
	start_fight(data)
	var newcomer := Actor.new()
	add_child_autofree(newcomer)
	data.actors.crew_3 = newcomer
	advance(data, 0.1)
	assert_false(data.match.controls_allowed("crew_3"))
	assert_false("crew_3" in data.match.alive)
	data.actors.erase("crew_2")
	advance(data, 0.1)
	assert_eq(data.match.phase, "intermission")
	assert_eq(data.match.scores.crew_1, 0)
	assert_eq(data.match.winner_id(), "")
	advance(data, 6.2)
	assert_true(data.match.controls_allowed("crew_3"))
	assert_has(data.match.alive, "crew_3")

func test_recover_forfeits_and_cannot_escape_elimination() -> void:
	var data := fixture(2)
	start_fight(data)
	data.match.forfeit("crew_1")
	advance(data, 0.3)
	assert_eq(data.match.scores.crew_2, 1)
	assert_false(data.match.controls_allowed("crew_1"))

func test_snapshot_validation_and_interpolation() -> void:
	var data := fixture(3)
	start_fight(data)
	var snapshot: Dictionary = data.match.capture()
	assert_true(Match.valid_snapshot(snapshot))
	for bad: Variant in [null, [], {}, {"version": 1}]: assert_false(Match.valid_snapshot(bad))
	for value: Variant in [NAN, INF, -1, 91, "2"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		malformed.timer = value
		assert_false(Match.valid_snapshot(malformed))
	var unknown: Dictionary = snapshot.duplicate(true)
	unknown.fighters.crew_1.brace = 1
	assert_false(Match.valid_snapshot(unknown))
	unknown = snapshot.duplicate(true)
	unknown.alive = ["crew_1", "crew_1"]
	assert_false(Match.valid_snapshot(unknown))
	var next: Dictionary = snapshot.duplicate(true)
	snapshot.fighters.crew_1.swing = 0.2
	next.fighters.crew_1.swing = 0.6
	assert_almost_eq(Match.interpolate(snapshot, next, 0.5).fighters.crew_1.swing, 0.4, 0.0001)
	snapshot.fighters.crew_1.yaw = 3.0
	next.fighters.crew_1.yaw = -3.0
	assert_true(Match.valid_snapshot(Match.interpolate(snapshot, next, 0.8)), "Turning through PI preserves bounded network pose")
	assert_eq(Match.interpolate({}, next, 0.5), {})
