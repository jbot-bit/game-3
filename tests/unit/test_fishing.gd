extends GutTest
const Rules = preload("res://game/fishing/fishing_rules.gd")

func _tracking_input(cast: Dictionary) -> bool:
	return float(cast.get("bar_position", 0.5)) < float(cast.get("fish_position", 0.5))

func test_one_outcome_per_cast_and_cancel():
	var f = Rules.new()
	assert_true(f.start("crew_1", "penny_perch", "run-a:1").ok)
	var found: Dictionary = {}
	for i in range(700):
		var s: Dictionary = f.snapshot().get("crew_1", {})
		var result: Dictionary = f.step("crew_1", _tracking_input(s), 1.0, 0.05)
		if result.code == "caught":
			found = result.catch
			break
	assert_eq(found.get("catch_id",""), "run-a:1")
	assert_eq(f.step("crew_1", true, 1.0, 0.1).code, "no_cast")
	f.start("crew_1", "bellgill", "run-a:2")
	f.cancel("crew_1")
	assert_eq(f.step("crew_1", true, 1.0, 0.1).code, "no_cast")

func test_forgiving_bite_then_hold_moves_right_and_release_moves_left():
	var f = Rules.new()
	f.start("a", "penny_perch", "a:1")
	var initial: Dictionary = f.snapshot().a
	assert_gt(float(initial.get("progress", 0.0)), 0.0, "Start with a recoverable progress buffer")
	assert_true(initial.has("bar_position") and initial.has("bar_width") and initial.has("fish_position"))
	if not initial.has("bar_position"): return
	for i in range(3): assert_eq(f.step("a", true, 0.0, 0.25).code, "waiting")
	assert_almost_eq(float(f.snapshot().a.bar_position), 0.5, 0.00001)
	assert_almost_eq(float(f.snapshot().a.progress), float(initial.progress), 0.00001)
	f.step("a", true, 0.0, 0.15)
	var right: float = f.snapshot().a.bar_position
	assert_gt(right, 0.5)
	f.step("a", false, 0.0, 0.1)
	assert_lt(float(f.snapshot().a.bar_position), right)

func test_progress_rises_only_while_the_fish_is_inside_the_control_bar():
	var f = Rules.new()
	f.start("a", "bellgill", "a:1")
	var saw_match: bool = false
	var saw_miss: bool = false
	for tick in range(200):
		var before: Dictionary = f.snapshot().get("a", {})
		if before.is_empty(): break
		var result: Dictionary = f.step("a", true, 0.0, 0.05)
		var after: Dictionary = f.snapshot().get("a", {})
		if after.is_empty() or result.code == "waiting": continue
		if not after.has("tracking"):
			fail_test("Authoritative state must expose whether fish is inside the bar")
			return
		var inside: bool = absf(float(after.fish_position) - float(after.bar_position)) <= float(after.bar_width) * 0.5
		assert_eq(bool(after.tracking), inside)
		if inside:
			saw_match = true
			assert_gt(float(after.progress), float(before.progress))
		else:
			saw_miss = true
			assert_lt(float(after.progress), float(before.progress))
	assert_true(saw_match)
	assert_true(saw_miss)

func test_fish_motion_is_independent_of_input_and_all_normalized_positions_stay_bounded():
	var left = Rules.new()
	var right = Rules.new()
	left.start("a", "crown_ray", "left")
	right.start("a", "crown_ray", "right")
	for tick in range(60):
		if not left.casts.has("a") or not right.casts.has("a"): break
		left.step("a", false, -1.0, 0.05)
		right.step("a", true, 1.0, 0.05)
		if not left.casts.has("a") or not right.casts.has("a"): break
		var a: Dictionary = left.snapshot().a
		var b: Dictionary = right.snapshot().a
		if not a.has("fish_position"):
			fail_test("Control-bar fishing state is required")
			return
		assert_almost_eq(float(a.fish_position), float(b.fish_position), 0.000001)
		for cast: Dictionary in [a, b]:
			assert_between(float(cast.fish_position), 0.0, 1.0)
			assert_gte(float(cast.bar_position) - float(cast.bar_width) * 0.5, -0.000001)
			assert_lte(float(cast.bar_position) + float(cast.bar_width) * 0.5, 1.000001)

func test_every_species_has_the_requested_skilled_solo_duration():
	for species: String in Species.catalog():
		var f = Rules.new()
		f.start("a", species, "duration")
		var seconds: float = 0.0
		var result: Dictionary = {}
		for tick in range(600):
			var cast: Dictionary = f.snapshot().get("a", {})
			if cast.is_empty(): break
			result = f.step("a", _tracking_input(cast), 0.0, 0.05)
			seconds += 0.05
			if result.code in ["caught", "fish_escaped", "line_broke"]: break
		assert_eq(result.get("code", ""), "caught", species)
		assert_between(seconds, 9.0 if Species.is_rare(species) else 5.0, 12.0 if Species.is_rare(species) else 8.0, species + " skilled catch duration")

func test_poor_tracking_loses_the_fish_and_cannot_leave_an_endless_cast():
	for held: bool in [true, false]:
		var f = Rules.new()
		f.start("a", "penny_perch", "miss")
		var result: Dictionary = {}
		for tick in range(400):
			result = f.step("a", held, 0.0, 0.05)
			if result.code != "waiting" and not result.ok: break
		assert_eq(result.get("code", ""), "fish_escaped")
		assert_false(f.casts.has("a"))
		assert_eq(f.step("a", held, 0.0, 0.1).code, "no_cast")

func test_balanced_near_misses_still_end_by_the_deadline():
	var f = Rules.new()
	f.start("a", "lantern_eel", "timeout")
	var pursuing: bool = true
	var result: Dictionary = {}
	for tick in range(500):
		var cast: Dictionary = f.snapshot().get("a", {})
		if cast.is_empty(): break
		if not cast.has("bar_position"):
			fail_test("Control-bar fishing state is required")
			return
		if cast.progress > 0.5: pursuing = false
		elif cast.progress < 0.3: pursuing = true
		var target: float = cast.fish_position if pursuing else (0.1 if cast.fish_position > 0.5 else 0.9)
		result = f.step("a", cast.bar_position < target, 0.0, 0.05)
		if not result.ok: break
	assert_eq(result.get("code", ""), "fish_escaped")
	assert_false(f.casts.has("a"))

func test_assistance_is_optional_bounded_and_cannot_finish_without_tracking():
	var f = Rules.new()
	f.start("crew_1", "bellgill", "run-a:1")
	assert_false(f.assist("crew_1", "crew_1", "generic").ok)
	assert_true(f.assist("crew_2", "crew_1", "generic").ok)
	assert_false(f.assist("crew_3", "crew_1", "generic").ok)
	assert_true(f.assist("crew_3", "crew_1", "rigger").ok)
	assert_false(f.assist("crew_2", "crew_1", "rigger").ok)
	assert_lt(float(f.snapshot().crew_1.progress), 1.0)
	f.casts.crew_1.progress = 0.99
	f.casts.crew_1.assists.clear()
	assert_true(f.assist("crew_2", "crew_1", "generic").ok)
	assert_lte(float(f.snapshot().crew_1.progress), 0.99, "Assist cannot create terminal success")

func test_invalid_input_leaves_the_cast_unchanged_and_finite_legacy_pull_is_ignored():
	var f = Rules.new()
	assert_false(f.start("crew_1", "fake_fish", "x").ok)
	assert_true(f.start("crew_1", "bellgill", "x").ok)
	assert_false(f.start("crew_1", "penny_perch", "y").ok)
	var before: Dictionary = f.snapshot()
	for pair: Array in [[NAN, 0.1], [INF, 0.1], [0.0, NAN], [0.0, INF], [0.0, -1.0], [0.0, 0.0]]:
		assert_false(f.step("crew_1", true, pair[0], pair[1]).ok)
		assert_eq(f.snapshot(), before)
	var g = Rules.new()
	g.start("crew_1", "bellgill", "x")
	for tick in range(20):
		f.step("crew_1", tick % 2 == 0, -999.0, 0.05)
		g.step("crew_1", tick % 2 == 0, 999.0, 0.05)
	assert_eq(f.snapshot(), g.snapshot(), "A/D legacy payload must not affect fishing")
	var old: float = f.casts.crew_1.elapsed
	f.step("crew_1", true, 0.0, 999.0)
	assert_lte(float(f.casts.crew_1.elapsed) - old, 0.250001, "Large deltas cannot bypass the authoritative clock")

func test_equipped_angler_outfit_widens_the_actual_bar_without_stacking_on_reapply():
	var f = Rules.new()
	f.start("a", "penny_perch", "outfit")
	assert_true(f.has_method("configure_outfit"))
	if not f.has_method("configure_outfit"): return
	var baseline: float = f.snapshot().a.bar_width
	assert_true(f.configure_outfit("a", "angler"))
	var wider: float = f.snapshot().a.bar_width
	assert_gt(wider, baseline)
	f.configure_outfit("a", "angler")
	assert_almost_eq(float(f.snapshot().a.bar_width), wider, 0.000001)
	assert_true(f.configure_rod("a", "soft_tip"))
	assert_gt(float(f.snapshot().a.bar_width), wider, "Outfit and rod benefits combine")
	f.configure_outfit("a", "harbour")
	assert_gt(float(f.snapshot().a.bar_width), baseline, "Removing outfit retains equipped rod benefit")
	assert_false(f.configure_outfit("a", "invented"))
