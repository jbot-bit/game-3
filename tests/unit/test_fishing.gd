extends GutTest
const Rules = preload("res://game/fishing/fishing_rules.gd")

func test_one_outcome_per_cast_and_cancel():
	var f = Rules.new()
	assert_true(f.start("crew_1", "penny_perch", "run-a:1").ok)
	var found: Dictionary = {}
	for i in range(700):
		var s: Dictionary = f.snapshot().get("crew_1", {})
		var result: Dictionary = f.step("crew_1", float(s.get("tension",0.0)) < 0.65, 1.0, 0.1)
		if result.code == "caught":
			found = result.catch
			break
	assert_eq(found.get("catch_id",""), "run-a:1")
	assert_eq(f.step("crew_1", true, 1.0, 0.1).code, "no_cast")
	f.start("crew_1", "bellgill", "run-a:2")
	f.cancel("crew_1")
	assert_eq(f.step("crew_1", true, 1.0, 0.1).code, "no_cast")

func test_assistance_is_optional_bounded_and_not_self():
	var f = Rules.new()
	f.start("crew_1", "bellgill", "run-a:1")
	assert_false(f.assist("crew_1", "crew_1", "generic").ok)
	assert_true(f.assist("crew_2", "crew_1", "generic").ok)
	assert_false(f.assist("crew_3", "crew_1", "generic").ok)
	assert_true(f.assist("crew_3", "crew_1", "rigger").ok)
	assert_false(f.assist("crew_2", "crew_1", "rigger").ok)

func test_invalid_input_cannot_complete_or_replace_a_cast():
	var f = Rules.new()
	assert_false(f.start("crew_1", "fake_fish", "x").ok)
	assert_true(f.start("crew_1", "bellgill", "x").ok)
	assert_false(f.start("crew_1", "penny_perch", "y").ok)
	assert_false(f.step("crew_1", true, NAN, 0.1).ok)
	assert_false(f.step("crew_1", true, 1.0, -1.0).ok)
	assert_lt(float(f.snapshot().get("crew_1",{}).get("progress", 999)), 1.0)
