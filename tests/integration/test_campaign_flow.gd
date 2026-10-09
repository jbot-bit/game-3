extends GutTest
const Game=preload("res://game/main.gd")
var app: Node3D
var serial: int=0

class RefusingStore extends SaveStore:
	var refuse: bool=true
	func commit(state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(state)

func before_each() -> void:
	app=Game.new()
	add_child_autofree(app)
	app.game_port=24612
	app.save_path="user://tests/campaign-controller-"+str(Time.get_ticks_usec())+".json"
	app._host("Crew")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await get_tree().physics_frame

func after_each() -> void:
	app.session.close()

func action(id: String,payload: Dictionary={}) -> Dictionary:
	serial+=1
	return app.controller.apply_intent(1,id,payload,"campaign-"+str(serial))

func at(marker: String) -> void:
	app.controller.avatars.crew_1.global_position=app.world.markers[marker]
	app.controller.avatars.crew_1.last_dry=app.world.markers[marker]
	app.controller.avatars.crew_1.velocity=Vector3.ZERO

func complete_repairs() -> void:
	# An earned-wallet fixture isolates campaign gates; fishing earnings have a separate real-reel probe.
	var state: Dictionary=app.controller.progression.snapshot()
	state.coins=385
	state.lifetime_banked=385
	app.controller.progression=Progression.new(SaveStore.new(app.save_path),state)
	for id in IslandContent.cache_markers():
		at(IslandContent.cache_markers()[id])
		var result: Dictionary=action("open_cache",{"cache_id":id})
		assert_true(result.ok,id+": "+str(result))
	for id in CampaignRules.required_repairs():
		at(IslandContent.repair_markers()[id])
		assert_true(action("repair",{"repair_id":id}).ok,id)
	assert_eq(app.controller.progression.snapshot().coins,65)

func launch_escape() -> void:
	var c=app.controller
	c.run.elapsed_s=300
	c.run.phase="night"
	at("boat")
	assert_true(action("arm_escape").ok)
	assert_false(action("signal_escape").ok,"Signal must be at the repaired beacon")
	at("beacon_repair")
	assert_true(action("signal_escape").ok)
	at("boat")
	assert_true(action("ready",{"ready":true}).ok)
	c._physics_process(0.1)
	assert_eq(c.run.phase,"escape")
	assert_false(c.progression.snapshot().campaign_flags.get("escaped",false),"Departure isn't settlement")

func test_real_intents_repair_escape_persist_and_continue_without_erasing_progress() -> void:
	assert_false(action("arm_escape").ok)
	complete_repairs()
	at("boat")
	assert_true(action("craft",{"recipe_id":"braced_reel"}).ok)
	assert_true(action("craft",{"recipe_id":"surveyor_lantern"}).ok)
	assert_true(action("equip_rod",{"rod_id":"braced_reel"}).ok)
	assert_true(action("set_profile",{"name":"Crew","role_id":"rigger"}).ok)
	assert_true(action("set_tool",{"mode":"alternate"}).ok)
	assert_false(action("arm_escape").ok,"Ready repairs still require night")
	launch_escape()
	app.controller._physics_process(20)
	assert_true(app.controller.snapshot().escape.completed)
	assert_eq(app.controller.next_day_at,-1.0,"Ending stays visible until crew continues")
	var loaded: Dictionary=SaveStore.new(app.save_path).load_or_recover()
	assert_true(loaded.ok)
	assert_true(loaded.state.campaign_flags.escaped)
	assert_eq(loaded.state.day_index,1)
	assert_eq(loaded.state.coins,0)
	assert_eq(loaded.state.profiles.crew_1.tool_mode,"alternate")
	assert_true(action("continue_island").ok)
	assert_false(app.controller.snapshot().escape.completed)
	assert_true(app.controller.snapshot().campaign.completed)
	assert_eq(app.controller.run.phase,"day")
	assert_eq(app.controller.progression.snapshot().profiles.crew_1.rod_id,"braced_reel")
	assert_false(action("continue_island").ok)

func test_final_save_failure_freezes_completion_and_retries_exactly_once() -> void:
	complete_repairs()
	launch_escape()
	var c=app.controller
	var store=RefusingStore.new(app.save_path)
	c.progression=Progression.new(store,c.progression.snapshot())
	c._physics_process(20)
	assert_true(c.run.paused)
	assert_true(c.pending_write.complete_campaign)
	assert_false(c.snapshot().escape.completed)
	assert_false(c.progression.snapshot().campaign_flags.get("escaped",false))
	assert_false(action("continue_island").ok)
	store.refuse=false
	assert_true(action("pause",{"paused":false}).ok)
	assert_true(c.snapshot().escape.completed)
	assert_true(c.progression.snapshot().campaign_flags.escaped)
	assert_eq(c.progression.snapshot().day_index,1)
	c._physics_process(50)
	assert_eq(c.progression.snapshot().day_index,1)

func test_ordinary_refuge_never_earns_escape_and_all_five_habitats_cast() -> void:
	complete_repairs()
	for habitat in app.world.fishing_markers():
		at(habitat)
		if habitat=="reeds": app.controller.avatars.crew_1.global_position+=Vector3(0,0,9)
		assert_true(action("cast").ok,habitat)
		assert_eq(app.controller.fishing.casts.crew_1.habitat_id,habitat)
		action("cancel_cast")
	at("boat")
	action("ready",{"ready":true})
	app.controller._physics_process(0.1)
	assert_eq(app.controller.run.phase,"refuge")
	app.controller._physics_process(20)
	assert_false(app.controller.progression.snapshot().campaign_flags.get("escaped",false))
	assert_false(app.controller.snapshot().escape.completed)

func test_rigger_cannot_waste_cooldown_on_a_used_catch_assist() -> void:
	var c=app.controller
	app.session.roster.assign(2,1,Session.BUILD_ID)
	c._roster_changed(app.session.roster.snapshot())
	assert_true(c.progression.set_profile("crew_1","Rig","rigger").ok)
	c.avatars.crew_1.global_position=app.world.markers.jetty
	c.avatars.crew_1.last_dry=app.world.markers.jetty
	c.avatars.crew_2.global_position=app.world.markers.jetty+Vector3(1,0,0)
	c.avatars.crew_2.last_dry=c.avatars.crew_2.global_position
	c.fishing.start("crew_2","bellgill","assist-budget")
	c.fishing.assist("another_rigger","crew_2","rigger")
	assert_false(action("use_ability",{"target_id":"crew_2"}).ok)
	assert_false(c.abilities.ready_at.has("crew_1"),"Rejected assist must preserve rescue cooldown")
