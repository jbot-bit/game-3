extends GutTest

const Expedition = preload("res://game/expedition/expedition_rules.gd")
const SUPPLY_PATH: String = "res://game/physics/supply_rules.gd"

func rescue_run() -> RefCounted:
	var run: RefCounted = Expedition.new()
	var profiles: Array[String]=["crew_1","crew_2","crew_3"]
	run.start("rescue",profiles)
	return run

func has_carry(run: RefCounted) -> bool:
	assert_true(run.has_method("pickup_teammate"),"Downed teammates need exclusive carry ownership")
	return run.has_method("pickup_teammate")

func supply_model() -> RefCounted:
	assert_true(ResourceLoader.exists(SUPPLY_PATH),"Two physical supply cells need a custody model")
	if not ResourceLoader.exists(SUPPLY_PATH): return null
	return load(SUPPLY_PATH).new()

func test_rescue_has_one_carrier_and_preserves_downed_timer() -> void:
	var run: RefCounted = rescue_run()
	if not has_carry(run): return
	run.down("crew_2")
	run.advance(5.0)
	assert_true(run.pickup_teammate("crew_1","crew_2",{}).ok)
	assert_eq(run.carried_by("crew_2"),"crew_1")
	assert_eq(run.carrying_teammate("crew_1"),"crew_2")
	assert_false(run.pickup_teammate("crew_3","crew_2",{}).ok)
	run.down("crew_3")
	assert_false(run.pickup_teammate("crew_1","crew_3",{}).ok)
	assert_false(run.pickup_teammate("crew_2","crew_3",{}).ok)
	run.advance(2.0)
	assert_eq(run.players.crew_2.down_left,18.0)
	assert_true(run.players.crew_2.downed)
	assert_eq(run.snapshot().players.crew_2.carried_by,"crew_1")
	assert_true(run.release_teammate("crew_1").ok)
	assert_eq(run.carried_by("crew_2"),"")
	assert_eq(run.players.crew_2.down_left,18.0)
	assert_false(run.release_teammate("crew_1").ok)

func test_carry_rejects_invalid_states_and_stays_paused() -> void:
	var run: RefCounted = rescue_run()
	if not has_carry(run): return
	assert_false(run.pickup_teammate("crew_1","crew_2",{}).ok)
	assert_false(run.pickup_teammate("crew_1","crew_1",{}).ok)
	assert_false(run.pickup_teammate("unknown","crew_2",{}).ok)
	run.down("crew_2")
	run.set_paused(true)
	assert_false(run.pickup_teammate("crew_1","crew_2",{}).ok)
	run.set_paused(false)
	assert_true(run.pickup_teammate("crew_1","crew_2",{}).ok)
	run.set_paused(true)
	assert_false(run.release_teammate("crew_1").ok)
	run.advance(40.0)
	assert_eq(run.players.crew_2.down_left,25.0)
	run.set_paused(false)
	run.crossing_left=20.0
	assert_false(run.pickup_teammate("crew_3","crew_2",{}).ok)

func test_revive_remains_universal_and_clears_carry() -> void:
	var run: RefCounted = rescue_run()
	if not has_carry(run): return
	run.down("crew_2")
	run.pickup_teammate("crew_1","crew_2",{})
	assert_false(run.revive("crew_3","crew_2",2.99).ok)
	assert_false(run.revive("crew_3","crew_2",NAN).ok)
	var revived: Dictionary=run.revive("crew_3","crew_2",3.0)
	assert_true(revived.ok)
	assert_has(revived.released_ids,"crew_2")
	assert_eq(run.carrying_teammate("crew_1"),"")
	assert_false(run.players.crew_2.downed)
	assert_eq(run.players.crew_2.protection,3.0)

func test_down_disconnect_timeout_and_new_day_release_attachment() -> void:
	var run: RefCounted = rescue_run()
	if not has_carry(run): return
	run.down("crew_2")
	run.pickup_teammate("crew_1","crew_2",{})
	assert_has(run.down("crew_1").released_ids,"crew_2")
	assert_eq(run.carried_by("crew_2"),"")
	for disconnected: String in ["crew_1","crew_2"]:
		run=rescue_run()
		run.down("crew_2")
		run.pickup_teammate("crew_1","crew_2",{})
		assert_has(run.disconnect_profile(disconnected).released_ids,"crew_2")
		assert_eq(run.carrying_teammate("crew_1"),"")
	run=rescue_run()
	run.down("crew_2")
	run.pickup_teammate("crew_1","crew_2",{})
	var tick: Dictionary=run.advance(25.0)
	assert_has(tick.returned,"crew_2")
	assert_has(tick.released_ids,"crew_2")
	assert_eq(run.carried_by("crew_2"),"")
	var next_profiles: Array[String]=["crew_1","crew_2"]
	run.start("next",next_profiles)
	assert_eq(run.carried_by("crew_2"),"")

func test_two_cells_are_exclusive_and_consumed_only_once() -> void:
	var supplies: RefCounted=supply_model()
	if supplies==null: return
	assert_eq(supplies.snapshot().size(),2)
	var touch: Dictionary={"active":true,"distance_m":1.0,"line_of_sight":true}
	assert_true(supplies.grab("cell_1","crew_1",touch).ok)
	assert_false(supplies.grab("cell_1","crew_2",touch).ok)
	assert_false(supplies.grab("cell_2","crew_1",touch).ok)
	assert_eq(supplies.held_by("crew_1"),"cell_1")
	assert_true(supplies.consume("cell_1").ok)
	assert_eq(supplies.held_by("crew_1"),"")
	assert_eq(supplies.snapshot().cell_1.state,"consumed")
	assert_false(supplies.consume("cell_1").ok)
	assert_false(supplies.grab("cell_1","crew_2",touch).ok)
	assert_false(supplies.grab("cell_3","crew_2",touch).ok)
	assert_true(supplies.grab("cell_2","crew_1",touch).ok)
	assert_true(supplies.disconnect_profile("crew_1").ok)
	assert_eq(supplies.snapshot().cell_2.state,"free")
	assert_true(supplies.grab("cell_2","crew_3",touch).ok)
	assert_true(supplies.release("crew_3").ok)
	assert_eq(supplies.snapshot().cell_2.state,"free")
	assert_false(supplies.release("crew_3").ok)

func test_supply_grab_rejects_bad_touch_and_pause_keeps_custody() -> void:
	var supplies: RefCounted=supply_model()
	if supplies==null: return
	for touch: Dictionary in [{"active":false,"distance_m":1.0,"line_of_sight":true},
		{"active":true,"distance_m":2.01,"line_of_sight":true},
		{"active":true,"distance_m":NAN,"line_of_sight":true},
		{"active":true,"distance_m":1.0,"line_of_sight":false}]:
		assert_false(supplies.grab("cell_1","crew_1",touch).ok)
	var valid: Dictionary={"active":true,"distance_m":2.0,"line_of_sight":true}
	assert_false(supplies.grab("cell_1","unknown",valid).ok)
	assert_true(supplies.grab("cell_1","crew_1",valid).ok)
	supplies.set_paused(true)
	assert_false(supplies.release("crew_1").ok)
	assert_false(supplies.consume("cell_1").ok)
	assert_false(supplies.grab("cell_2","crew_2",valid).ok)
	assert_eq(supplies.held_by("crew_1"),"cell_1")
	assert_true(supplies.disconnect_profile("crew_1").ok)
	assert_eq(supplies.snapshot().cell_1.state,"free")
