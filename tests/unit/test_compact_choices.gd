extends GutTest

func test_one_player_can_commit_the_shared_reserve_and_disconnect_cannot_undo_it() -> void:
	var choice := CrewChoice.new()
	assert_true(choice.open(["crew_1", "crew_2", "crew_3"], 20.0).ok)
	var picked: Dictionary = choice.vote("crew_2", "reeds", 100.0)
	assert_true(picked.ok, "A physical choice remains available until dusk; no rushed ballot")
	assert_eq(picked.get("committed_station", ""), "reeds")
	assert_eq(choice.snapshot().get("decided_by", ""), "crew_2")
	assert_false(choice.vote("crew_1", "jetty", 101.0).ok)
	choice.roster_changed(["crew_1", "crew_3"])
	assert_eq(choice.snapshot().committed, "reeds")
	assert_false(choice.tick(180.0).has("committed_station"))

func test_unknown_crew_cannot_choose_and_dusk_has_a_safe_default() -> void:
	var choice := CrewChoice.new()
	choice.open(["crew_1", "crew_2"], 20.0)
	assert_false(choice.vote("outsider", "reeds", 30.0).ok)
	assert_false(choice.vote("crew_1", "invented", 30.0).ok)
	assert_eq(choice.tick(180.0).get("committed_station", ""), "jetty")
	assert_false(choice.vote("crew_2", "reeds", 180.0).ok)

func test_rods_offer_at_most_one_benefit_and_one_tradeoff() -> void:
	for id: String in Equipment.rods_all():
		var rod: Dictionary = Equipment.rod(id)
		var benefits: int = 0
		var costs: int = 0
		for modifier: String in ["tension_gain_multiplier", "dart_progress_multiplier", "heavy_progress_multiplier", "surge_progress_multiplier"]:
			var difference: float = float(rod[modifier]) - 1.0
			if modifier == "tension_gain_multiplier": difference = -difference
			if difference > 0.001: benefits += 1
			if difference < -0.001: costs += 1
		assert_lte(benefits, 1, id + " has one understandable strength")
		assert_lte(costs, 1, id + " has at most one tradeoff")
