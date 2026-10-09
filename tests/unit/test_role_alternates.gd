extends GutTest
const Abilities=preload("res://game/survival/ability_rules.gd")

func test_sidegrades_trade_range_or_duration_for_cooldown() -> void:
	var a=Abilities.new()
	var keeper=a.use("k","keeper",{"tool_mode":"alternate"},0)
	assert_true(keeper.ok)
	assert_eq(a.keeper_until,7.0)
	assert_eq(a.keeper_radius,2.5)
	assert_false(a.use("k","keeper",{},35).ok)
	assert_true(a.use("k","keeper",{},40).ok)
	assert_eq(a.keeper_radius,4.5)
	assert_false(a.use("r","rigger",{"valid_path":true,"distance":7},0).ok)
	assert_true(a.use("r","rigger",{"valid_path":true,"distance":7,"tool_mode":"alternate"},0).ok)
	assert_false(a.use("x","rigger",{"valid_path":false,"distance":7,"tool_mode":"alternate"},0).ok)

func test_scout_snapshot_captures_activation_mode_not_current_loadout() -> void:
	var a=Abilities.new()
	a.use("s","scout",{"tool_mode":"alternate"},20)
	assert_eq(a.snapshot().active.s.until,30.0)
	assert_eq(a.snapshot().active.s.mode,"alternate")
	assert_eq(a.snapshot().ready_at.s,60.0)
