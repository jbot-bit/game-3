extends GutTest

const RosterModel = preload("res://game/session/roster.gd")

func test_profile_survives_peer_change_without_slot_theft() -> void:
	var roster = RosterModel.new()
	assert_true(roster.assign(2, 1, "0.1.0-slice").ok)
	var before: Dictionary = roster.snapshot()
	assert_eq(roster.assign(3, 1, "0.1.0-slice").code, "slot_taken")
	assert_eq(roster.snapshot(), before)
	assert_eq(roster.disconnect_peer(2), "crew_2")
	assert_true(roster.assign(9, 1, "0.1.0-slice").ok)
	assert_eq(roster.profile_for_peer(9), "crew_2")
	assert_eq(roster.profile_for_peer(2), "")

func test_build_mismatch_and_invalid_slot_leave_roster_unchanged() -> void:
	var roster = RosterModel.new()
	assert_eq(roster.assign(2, 1, "wrong").code, "build_mismatch")
	assert_eq(roster.assign(2, 3, "0.1.0-slice").code, "invalid_slot")
	assert_eq(roster.snapshot(), {})

func test_three_slots_and_one_profile_per_connection() -> void:
	var roster = RosterModel.new()
	for slot: int in range(3):
		assert_true(roster.assign(slot + 1, slot, "0.1.0-slice").ok)
	assert_eq(roster.assign(4, 2, "0.1.0-slice").code, "slot_taken")
	assert_eq(roster.assign(1, 1, "0.1.0-slice").code, "already_assigned")
	assert_eq(roster.snapshot().size(), 3)

func test_snapshot_cannot_mutate_authoritative_roster() -> void:
	var roster = RosterModel.new()
	roster.assign(1, 0, "0.1.0-slice")
	var external: Dictionary = roster.snapshot()
	external.clear()
	assert_eq(roster.profile_for_peer(1), "crew_1")
