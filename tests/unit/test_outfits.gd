extends GutTest
const Gear=preload("res://game/progression/equipment.gd")
const Progress=preload("res://game/progression/progression.gd")
const Store=preload("res://game/progression/save_store.gd")
const Art=preload("res://game/world/block_art.gd")
const PlayerBody=preload("res://game/player/player.gd")

class RefusingStore extends "res://game/progression/save_store.gd":
	var refuse: bool=false
	func commit(next_state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(next_state)

func gear_ready() -> bool:
	var gear: RefCounted=Gear.new()
	assert_true(gear.has_method("outfits_all"),"Earned complete outfits need a shared catalogue")
	return gear.has_method("outfits_all")

func test_outfit_unlocks_follow_existing_discoveries_and_repair() -> void:
	if not gear_ready(): return
	var gear: RefCounted=Gear.new()
	var state: Dictionary=Progress.blank_state()
	assert_eq(gear.outfits_all().size(),4)
	assert_true(gear.outfit_unlocked(state,"harbour"))
	assert_false(gear.outfit_unlocked(state,"angler"))
	assert_false(gear.outfit_unlocked(state,"deckhand"))
	assert_false(gear.outfit_unlocked(state,"stormwatch"))
	state.discoveries=["penny_perch","bellgill"]
	assert_true(gear.outfit_unlocked(state,"angler"))
	assert_false(gear.outfit_unlocked(state,"stormwatch"))
	state.repairs.return_walkway=true
	assert_true(gear.outfit_unlocked(state,"deckhand"))
	state.discoveries.append_array(["pebble_dab","moss_skipper"])
	assert_true(gear.outfit_unlocked(state,"stormwatch"))
	assert_false(gear.outfit_unlocked(state,"invented"))
	assert_almost_eq(float(gear.outfit("angler").tension_gain_multiplier),0.9,0.00001)
	assert_almost_eq(float(gear.outfit("deckhand").carry_speed),4.6,0.00001)
	assert_almost_eq(float(gear.outfit("stormwatch").lamp_drain_multiplier)*1.2,1.0,0.00001)

func test_outfit_equip_is_saved_and_failures_are_atomic() -> void:
	var path: String="user://test_outfit_%s/household.json"%Time.get_ticks_usec()
	var store: RefusingStore=RefusingStore.new(path)
	var state: Dictionary=Progress.blank_state()
	state.discoveries=["penny_perch","bellgill"]
	var progress: RefCounted=Progress.new(store,state)
	assert_true(progress.has_method("set_outfit"),"Outfit choice must pass through atomic save commits")
	if not progress.has_method("set_outfit"): return
	var before: Dictionary=progress.snapshot()
	assert_eq(progress.set_outfit("crew_1","stormwatch").code,"locked")
	assert_eq(progress.set_outfit("crew_1","invented").code,"invalid_outfit")
	assert_eq(progress.set_outfit("unknown","angler").code,"unknown_profile")
	assert_eq(progress.snapshot(),before)
	store.refuse=true
	assert_eq(progress.set_outfit("crew_1","angler").code,"save_failed")
	assert_eq(progress.snapshot(),before)
	store.refuse=false
	assert_true(progress.set_outfit("crew_1","angler").ok)
	var restored: Dictionary=Store.new(path).load_or_recover()
	assert_true(restored.ok)
	assert_eq(restored.state.profiles.crew_1.outfit_id,"angler")
	assert_eq(restored.state.profiles.crew_2.outfit_id,"harbour")
	assert_eq(restored.state.coins,0)

func test_legacy_profiles_get_harbour_and_invalid_equipped_sets_are_rejected() -> void:
	var old: Dictionary=Progress.blank_state()
	for profile: Dictionary in old.profiles.values(): profile.erase("outfit_id")
	var defaults: Dictionary=Store.with_defaults(old)
	assert_eq(defaults.profiles.crew_1.get("outfit_id","missing"),"harbour")
	assert_false(old.profiles.crew_1.has("outfit_id"))
	var store=Store.new("user://test_outfit_validation_%s/household.json"%Time.get_ticks_usec())
	assert_true(store._valid_state(old))
	old.profiles.crew_1.outfit_id="invented"
	assert_false(store._valid_state(old))
	old.profiles.crew_1.outfit_id="stormwatch"
	assert_false(store._valid_state(old))
	old.discoveries=["penny_perch","bellgill","pebble_dab","moss_skipper"]
	assert_true(store._valid_state(old))

func test_outfits_preserve_animation_pivots_and_cached_held_tool() -> void:
	var art: RefCounted=Art.new()
	assert_true(art.has_method("set_outfit_appearance"),"Complete outfits need a cached appearance update")
	if not art.has_method("set_outfit_appearance"): return
	var crew: Node3D=Art.crew(Color("62b9db"))
	assert_eq(str(crew.name),"BlockCrew","Gameplay effects resolve this stable visual path")
	var head: Node3D=crew.get_node("Head")
	var tool: Node3D=crew.get_node("RightArm/HeldTool")
	Art.set_rod_appearance(crew,"drift_rod")
	for outfit: String in ["harbour","angler","deckhand","stormwatch"]:
		art.set_outfit_appearance(crew,outfit)
		assert_same(crew.get_node("Head"),head)
		assert_same(crew.get_node("RightArm/HeldTool"),tool)
		assert_eq(tool.get_meta("rod_id"),"drift_rod")
		assert_eq(tool.get_node("RodTip").position,Vector3(0,1.63,-0.54))
		var face: Node3D=head.get_node("Face")
		art.set_outfit_appearance(crew,outfit)
		assert_same(head.get_node("Face"),face,"Repeated loadout refresh must retain meshes")
		assert_eq(crew.get_meta("crew_color"),Color("62b9db"))
		assert_true(crew.get_node("Torso").has_node("CrewScarf"))
	crew.free()

func test_fish_have_rounded_species_bodies_and_real_fins() -> void:
	for species: String in ["penny_perch","bellgill","lantern_eel","crown_ray"]:
		var fish: Node3D=Art.fish(species)
		assert_eq(str(fish.name),"BlockFish","Cargo cosmetics resolve this stable visual path")
		var body: MeshInstance3D=fish.get_node("Body")
		assert_false(body.mesh is BoxMesh,"Fish should read as fish instead of cubes: "+species)
		assert_true(fish.has_node("DorsalFin") or species=="crown_ray")
		assert_true(fish.has_node("Tail"))
		fish.free()

func test_deckhand_loadout_boosts_cargo_but_keeps_rescue_weight() -> void:
	var actor: CharacterBody3D=PlayerBody.new()
	actor.setup("crew_1",Color("62b9db"))
	add_child_autofree(actor)
	var floor:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(100,1,100)
	collision.shape=shape
	floor.add_child(collision)
	floor.position.y=0.5
	add_child_autofree(floor)
	actor.position=Vector3(0,1.02,0)
	actor.last_dry=actor.position
	await get_tree().physics_frame
	await get_tree().physics_frame
	actor.set_loadout({"outfit_id":"deckhand"},90.0,false)
	actor.carrying=true
	for i: int in range(20): actor.advance(0.01,Vector2.RIGHT,0,true)
	assert_almost_eq(actor.velocity.x,4.6,0.00001)
	actor.carrying_teammate=true
	for i: int in range(20): actor.advance(0.01,Vector2.RIGHT,0,true)
	assert_almost_eq(actor.velocity.x,3.5,0.00001)
	actor.carrying_teammate=false
	actor.carrying=false
	for i: int in range(20): actor.advance(0.01,Vector2.RIGHT,0,true)
	assert_eq(actor.velocity.x,5.0)
	actor.set_loadout({},90.0,false)
	actor.carrying=true
	for i: int in range(20): actor.advance(0.01,Vector2.RIGHT,0,true)
	assert_eq(actor.velocity.x,4.25)
