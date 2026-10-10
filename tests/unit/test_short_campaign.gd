extends GutTest
const Campaign=preload("res://game/progression/campaign_rules.gd")
var path: String

func before_each() -> void:
	path="user://tests/short-campaign-"+str(Time.get_ticks_usec())+".json"

func _progress(coins: int=120) -> Progression:
	var state: Dictionary=Progression.blank_state()
	state.coins=coins
	state.lifetime_banked=coins
	return Progression.new(SaveStore.new(path),state)

func test_only_beacon_and_engine_are_required_and_can_be_repaired_in_either_order() -> void:
	for order: Array in [["beacon","moth_engine"],["moth_engine","beacon"]]:
		var p: Progression=_progress()
		assert_true(p.open_cache("beacon_parts_cache").ok)
		assert_true(p.open_cache("tide_engine_cache").ok)
		assert_false(Campaign.status(p.snapshot()).can_escape)
		assert_true(p.repair(order[0],"first").ok)
		assert_false(Campaign.status(p.snapshot()).can_escape)
		assert_true(p.repair(order[1],"second").ok)
		assert_true(Campaign.status(p.snapshot()).can_escape)
		assert_eq(p.snapshot().coins,0)
		assert_eq(p.snapshot().repairs.size(),2)
		assert_true(SaveStore.new(path).load_or_recover().ok)
		path="user://tests/short-campaign-next-"+str(Time.get_ticks_usec())+".json"

func test_optional_repairs_need_their_parts_but_no_coins_or_other_repairs() -> void:
	var p: Progression=_progress(0)
	for pair: Array in [["ridge_steps","terraces_parts_cache"],["return_walkway","walkway_parts_cache"],["workshop","lido_workshop_cache"]]:
		var before: Dictionary=p.snapshot()
		assert_false(p.repair(pair[0],"missing-"+pair[0]).ok)
		assert_eq(p.snapshot(),before)
		assert_true(p.open_cache(pair[1]).ok)
		assert_true(p.repair(pair[0],"repair-"+pair[0]).ok)
		assert_eq(p.snapshot().coins,0)
	assert_false(Campaign.status(p.snapshot()).can_escape)
	assert_true(Campaign.tool_unlocked(p.snapshot(),"rigger"))

func test_status_labels_optional_repairs_and_follows_an_available_essential() -> void:
	var p: Progression=_progress(80)
	assert_true(p.open_cache("tide_engine_cache").ok)
	var status: Dictionary=Campaign.status(p.snapshot())
	assert_eq(Campaign.required_repairs(),["beacon","moth_engine"])
	assert_eq(status.repair_id,"moth_engine")
	assert_string_contains(status.objective,"Moth")
	assert_eq(status.repairs.size(),5)
	for repair: Dictionary in status.repairs:
		assert_eq(repair.get("optional",null),repair.id not in ["beacon","moth_engine"],repair.id)
	var required: Array[String]=Campaign.required_repairs()
	required.clear()
	assert_eq(Campaign.required_repairs().size(),2)

func test_prior_escape_preserves_progress_and_can_settle_another_escape_once() -> void:
	var p: Progression=_progress()
	assert_true(p.open_cache("beacon_parts_cache").ok)
	assert_true(p.open_cache("tide_engine_cache").ok)
	assert_true(p.repair("beacon","b").ok)
	assert_true(p.repair("moth_engine","m").ok)
	assert_true(p.settle_run("first",[],{},true).ok)
	var before: Dictionary=p.snapshot()
	var status: Dictionary=Campaign.status(before)
	assert_true(status.completed)
	assert_true(status.can_escape)
	assert_eq(status.stage,"escape")
	assert_string_contains(status.objective,"night")
	assert_string_contains(status.get("collection_objective",""),"Penny Perch")
	assert_true(p.settle_run("second",[],{},true).ok)
	assert_false(p.settle_run("second",[],{},true).ok)
	assert_eq(p.snapshot().day_index,2)
	assert_true(SaveStore.new(path).load_or_recover().ok,"A completed two-repair save must reload")
	for field: String in ["repairs","profiles","owned_rods","owned_lamps","discoveries","specimen_records","coins"]:
		assert_eq(p.snapshot()[field],before[field],field+" must survive another escape")
	assert_true(p.snapshot().campaign_flags.get("escaped",false))