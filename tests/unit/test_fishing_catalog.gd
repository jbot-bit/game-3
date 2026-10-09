extends GutTest
const Data = preload("res://game/fishing/species.gd")
const Table = preload("res://game/fishing/catch_table.gd")
const Rules = preload("res://game/fishing/fishing_rules.gd")
const Gear = preload("res://game/progression/equipment.gd")
const Art = preload("res://game/world/block_art.gd")
const FishBody = preload("res://game/fishing/physical_fish.gd")
const HABITATS: Array[String] = ["jetty","reeds","terraces","tidepools","beacon"]
const BANDS: Array[String] = ["day","dusk","night","storm"]

func test_twelve_species_have_six_common_four_uncommon_two_rare_and_three_behaviors() -> void:
	var counts: Dictionary = {"common":0,"uncommon":0,"rare":0}
	var behaviors: Dictionary = {}
	assert_eq(Data.catalog().size(),12)
	for fish: Dictionary in Data.catalog().values():
		var rarity: String = str(fish.get("rarity",""))
		assert_true(counts.has(rarity), "Every species needs a valid rarity")
		if counts.has(rarity): counts[rarity] += 1
		behaviors[fish.get("behavior","")] = true
		assert_false(str(fish.get("habitat_hint","")).is_empty())
	assert_eq(counts,{"common":6,"uncommon":4,"rare":2})
	assert_eq(behaviors.size(),3)

func test_journal_pool_matches_every_roll_interval_and_reaches_the_full_catalogue() -> void:
	var table: RefCounted = Table.new()
	assert_true(table.has_method("pool"))
	if not table.has_method("pool"): return
	var reachable: Dictionary = {}
	for habitat: String in HABITATS:
		for band: String in BANDS:
			var pool: Array = table.call("pool",habitat,band)
			var lower: float = 0.0
			for entry: Dictionary in pool:
				var chance: float = float(entry.chance)
				assert_gt(chance,0.0)
				var roll: Dictionary = Table.roll(habitat,band,0,lower+chance*0.5,0.5,0.5)
				assert_true(roll.ok)
				assert_eq(roll.species_id,entry.species_id)
				reachable[roll.species_id] = true
				lower += chance
			assert_almost_eq(lower,1.0,0.000001)
	assert_eq(reachable.size(),12)
	assert_eq(table.call("pool","unknown","night"),[])
	assert_false(Table.roll("beacon","refuge",0,0.5,0.5,0.5).ok)

func test_second_rare_uses_the_same_landed_catch_pity_contract() -> void:
	var forced: Dictionary = Table.roll("beacon","night",11,0.0,0.5,0.5)
	assert_true(forced.ok)
	assert_eq(forced.get("species_id",""),"crown_ray")
	assert_true(forced.get("rare_eligible",false))
	assert_ne(Table.roll("beacon","day",999,0.0,0.5,0.5).get("species_id",""),"crown_ray")
	assert_eq(Table.roll("reeds","storm",11,0.0,0.5,0.5).get("species_id",""),"lantern_eel")

func test_optional_traits_are_exclusive_and_condition_specific() -> void:
	assert_eq(Table.roll("jetty","day",0,0.0,0.099,0.5).trait_id,"oversized")
	assert_eq(Table.roll("jetty","day",0,0.0,0.1,0.5).trait_id,"none")
	assert_eq(Table.roll("jetty","night",0,0.0,0.1,0.5).trait_id,"moonlit")
	assert_eq(Table.roll("jetty","dusk",0,0.0,0.179,0.5).trait_id,"moonlit")
	assert_eq(Table.roll("jetty","night",0,0.0,0.18,0.5).trait_id,"none")
	assert_eq(Table.roll("jetty","storm",0,0.0,0.1,0.5).trait_id,"stormmarked")
	assert_eq(Table.roll("jetty","storm",0,0.0,0.199,0.5).trait_id,"stormmarked")
	assert_eq(Table.roll("jetty","storm",0,0.0,0.2,0.5).trait_id,"none")

func test_host_values_reject_unknowns_and_only_oversized_gets_whole_bonus() -> void:
	var data: RefCounted = Data.new()
	assert_true(data.has_method("value_for"))
	assert_true(data.has_method("is_rare"))
	if not data.has_method("value_for"): return
	for species: String in Data.catalog():
		var base: int = int(Data.catalog()[species].value)
		for trait_id: String in ["none","oversized","moonlit","stormmarked"]:
			var multiplier: float = {"none":1.0,"oversized":1.25,"moonlit":1.5,"stormmarked":1.75}[trait_id]
			assert_eq(data.call("value_for",species,trait_id,false),floori(base*multiplier))
			assert_eq(data.call("value_for",species,trait_id,true),base*2 if trait_id=="oversized" else -1)
	assert_eq(data.call("value_for","invented","none"),-1)
	assert_eq(data.call("value_for","penny_perch","invented"),-1)
	assert_true(data.call("is_rare","crown_ray"))
	assert_true(data.call("is_rare","lantern_eel"))
	assert_false(data.call("is_rare","bellgill"))

func test_surge_has_predictable_release_window_and_reeling_through_it_costs_tension() -> void:
	var rules: RefCounted = Rules.new()
	assert_true(rules.start("a","moss_skipper","a:1").ok)
	if not rules.snapshot().has("a"): return
	for i: int in range(50):
		rules.step("a",false,0.0,0.1)
	var before: Dictionary = rules.snapshot().a
	assert_eq(before.get("behavior",""),"surge")
	assert_true(before.get("surging",false))
	rules.step("a",true,0.0,0.1)
	assert_gt(float(rules.snapshot().a.tension),float(before.tension)+0.05)
	rules.step("a",false,0.0,0.1)
	assert_lt(float(rules.snapshot().a.tension),0.03)
	for i: int in range(15): rules.step("a",false,0.0,0.1)
	assert_false(rules.snapshot().a.get("surging",true))

func test_four_rods_have_real_tradeoffs_and_every_species_is_catchable_alone() -> void:
	var gear: RefCounted = Gear.new()
	assert_true(gear.has_method("rods_all"))
	if not gear.has_method("rods_all"): return
	var rods: Dictionary = gear.call("rods_all")
	assert_eq(rods.size(),4)
	assert_lt(float(Gear.rod("soft_tip").tension_gain_multiplier),1.0)
	assert_lt(float(Gear.rod("soft_tip").heavy_progress_multiplier),1.0)
	assert_gt(float(Gear.rod("braced_reel").heavy_progress_multiplier),1.0)
	assert_gt(float(Gear.rod("braced_reel").tension_gain_multiplier),1.0)
	assert_gt(float(Gear.rod("drift_rod").dart_progress_multiplier),1.0)
	assert_lt(float(Gear.rod("drift_rod").heavy_progress_multiplier),1.0)
	for rod: String in rods:
		for species: String in Data.catalog():
			var rules: RefCounted = Rules.new()
			rules.start("a",species,"solo")
			assert_true(rules.call("configure_rod","a",rod))
			var caught: bool = false
			for tick: int in range(900):
				var cast: Dictionary = rules.snapshot().get("a",{})
				var reel: bool = float(cast.get("tension",1.0))<0.58 and not bool(cast.get("surging",false))
				var result: Dictionary = rules.step("a",reel,1.0,0.1)
				if result.code == "caught":
					caught = true
					break
			assert_true(caught,"Solo completion: " + species + " / " + rod)

func test_art_supports_all_species_and_colored_traits_without_extra_physics() -> void:
	var art: RefCounted = Art.new()
	assert_true(art.has_method("fish_dimensions"))
	if not art.has_method("fish_dimensions"): return
	var signatures: Dictionary = {}
	for species: String in Data.catalog():
		var visual: Node3D = art.call("fish",species,false,"moonlit")
		assert_true(visual.has_node("Tail"))
		assert_true(visual.has_node("TraitMark"))
		var body: MeshInstance3D = visual.get_node("Body")
		signatures[str(body.mesh.size)+str(body.material_override.albedo_color)] = true
		visual.free()
		var fish: RigidBody3D = FishBody.new()
		fish.call("setup","art:"+species,species,true,"oversized")
		assert_eq(fish.collision_layer,4)
		assert_eq(fish.collision_mask,1)
		assert_eq(fish.get_child_count(),2)
		fish.free()
	assert_eq(signatures.size(),12)

func test_alternate_rigger_trades_progress_for_relief_and_shares_assist_budget() -> void:
	var rules: RefCounted = Rules.new()
	rules.start("a","bellgill","assist:1")
	rules.casts.a.tension = 0.6
	var result: Variant = rules.call("assist","b","a","rigger",true)
	assert_not_null(result)
	if result == null: return
	assert_true(result.ok)
	assert_almost_eq(float(rules.casts.a.progress),0.10,0.000001)
	assert_almost_eq(float(rules.casts.a.tension),0.35,0.000001)
	assert_false(rules.assist("c","a","rigger").ok)
	assert_true(rules.assist("c","a","generic").ok)

func test_rod_appearance_changes_in_place_and_keeps_the_cast_tip_contract() -> void:
	var art: RefCounted = Art.new()
	assert_true(art.has_method("set_rod_appearance"))
	if not art.has_method("set_rod_appearance"): return
	var crew: Node3D = Art.crew(Color("62b9db"))
	var tool: Node3D = crew.get_node("RightArm/HeldTool")
	for rod: String in ["starter","soft_tip","braced_reel","drift_rod"]:
		art.call("set_rod_appearance",crew,rod)
		var count: int = tool.get_child_count()
		art.call("set_rod_appearance",crew,rod)
		assert_eq(tool.get_meta("rod_id",""),rod)
		assert_eq(tool.get_child_count(),count)
		assert_eq(tool.get_node("RodTip").position,Vector3(0,1.63,-0.54))
	crew.free()
