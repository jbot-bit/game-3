extends GutTest
const Modes = preload("res://prototypes/physics_party/party_modes.gd")

func test_knockout_is_a_separate_ring_match_and_preserves_existing_modes() -> void:
	assert_eq(Modes.IDS, ["coop", "gladiator", "wipeout", "knockout"])
	assert_eq(Modes.mode_name("knockout"), "Knockout")
	assert_true(Modes.valid("knockout"))
	assert_false(Modes.valid("unknown"))
	assert_true(Modes.is_ring_match("knockout"))
	assert_true(Modes.is_ring_match("gladiator"))
	assert_false(Modes.is_ring_match("coop"))
	assert_false(Modes.is_ring_match("wipeout"))
