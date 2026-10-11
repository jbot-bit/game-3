extends GutTest
const Race = preload("res://prototypes/physics_party/party_race.gd")
class World extends Node3D:
	var authoritative: bool = true
	func checkpoint_index(at: Vector3) -> int: return clampi(int(at.x), 0, 3)
	func goal_contains(at: Vector3) -> bool: return at.z < -10
class Actor extends Node3D:
	var is_on_floor: bool = true
	var at: Vector3 = Vector3.ZERO
	func body_position() -> Vector3: return at

func fixture() -> Dictionary:
	var world := World.new()
	add_child_autofree(world)
	var a := Actor.new()
	var b := Actor.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var race := Race.new()
	race.configure(world)
	var actors := {"crew_1": a, "crew_2": b}
	for index in 181: race.tick(actors, 1.0 / 60.0)
	return {"race": race, "world": world, "actors": actors, "a": a, "b": b}

func test_finish_requires_supported_sequential_checkpoints() -> void:
	var f := fixture()
	f.a.at = Vector3(3, 2, -15)
	f.race.tick(f.actors, 0.016)
	assert_false(f.race.runners.crew_1.finished, "Direct finish teleport cannot award a clear")
	assert_eq(f.race.checkpoint_for("crew_1"), 0)
	f.a.at = Vector3(1, 2, 0)
	f.a.is_on_floor = false
	f.race.tick(f.actors, 0.016)
	assert_eq(f.race.checkpoint_for("crew_1"), 0, "Airborne flyby does not collect checkpoint")
	f.a.is_on_floor = true
	for cp in [1, 2, 3]:
		f.a.at.x = cp
		f.race.tick(f.actors, 0.016)
		assert_eq(f.race.checkpoint_for("crew_1"), cp)
	f.a.at.z = -15
	var result: Dictionary = f.race.tick(f.actors, 0.016)
	assert_false(result.completed, "Other runner still gets to finish")
	assert_eq(f.race.winner, "crew_1")
	assert_true(f.race.runners.crew_1.finished)
	assert_false(f.race.controls_allowed("crew_1"))

func test_falls_keep_checkpoint_clock_and_require_recovery() -> void:
	var f := fixture()
	f.a.at = Vector3(1, 2, 0)
	f.race.tick(f.actors, 0.016)
	var before: float = f.race.elapsed
	f.a.at.y = -12
	var result: Dictionary = f.race.tick(f.actors, 0.016)
	assert_eq(result.reset_ids, ["crew_1"])
	assert_eq(f.race.runners.crew_1.falls, 1)
	assert_eq(f.race.checkpoint_for("crew_1"), 1)
	assert_gt(f.race.elapsed, before)

func test_finish_awards_once_and_timeout_without_finisher_awards_nothing() -> void:
	var f := fixture()
	for cp in [1, 2, 3]:
		f.a.at.x = cp
		f.b.at.x = cp
		f.race.tick(f.actors, 0.016)
	f.a.at.z = -15
	f.b.at.z = -15
	var result: Dictionary = f.race.tick(f.actors, 0.016)
	assert_true(result.completed)
	assert_true(result.reward)
	assert_false(f.race.tick(f.actors, 0.016).completed)
	f.race.reset()
	for index in 181: f.race.tick(f.actors, 1.0 / 60.0)
	f.race.elapsed = 299.99
	result = f.race.tick(f.actors, 0.02)
	assert_true(result.completed)
	assert_false(result.reward)

func test_replacement_actor_cannot_inherit_checkpoint_and_capture_is_detached() -> void:
	var f := fixture()
	f.a.at.x = 1
	f.race.tick(f.actors, 0.016)
	var copy: Dictionary = f.race.capture()
	copy.runners.crew_1.checkpoint = 3
	assert_eq(f.race.checkpoint_for("crew_1"), 1)
	var replacement := Actor.new()
	add_child_autofree(replacement)
	f.actors.crew_1 = replacement
	f.race.tick(f.actors, 0.016)
	assert_eq(f.race.checkpoint_for("crew_1"), 0)

func test_remote_world_cannot_advance_race() -> void:
	var f := fixture()
	f.world.authoritative = false
	var before: Dictionary = f.race.capture()
	f.race.tick(f.actors, 0.02)
	assert_eq(f.race.capture(), before)

func test_departed_finisher_cannot_give_replacement_a_win() -> void:
	var f := fixture()
	for cp in [1, 2, 3]:
		f.a.at.x = cp
		f.race.tick(f.actors, 0.016)
	f.a.at.z = -15
	f.race.tick(f.actors, 0.016)
	assert_eq(f.race.winner, "crew_1")
	f.a.at.y = -12
	var fallen: Dictionary = f.race.tick(f.actors, 0.016)
	assert_eq(fallen.reset_goal_ids, ["crew_1"], "Finished player cannot fall forever")
	assert_eq(f.race.runners.crew_1.falls, 0, "Post-finish recovery preserves result")
	var replacement := Actor.new()
	add_child_autofree(replacement)
	f.actors.crew_1 = replacement
	f.race.tick(f.actors, 0.016)
	assert_eq(f.race.winner, "")
	assert_false(f.race.runners.crew_1.finished)
