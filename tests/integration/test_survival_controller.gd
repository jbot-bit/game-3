extends GutTest
const Game=preload("res://game/main.gd")
var app: Node
var c: Node

func before_each() -> void:
	app=Game.new()
	app.game_port=24618
	app.save_path="user://tests/survival-"+str(Time.get_ticks_usec())+".json"
	app.settings_path="user://tests/survival-settings-"+str(Time.get_ticks_usec())+".json"
	add_child_autofree(app)
	app._host("Survival")
	c=app.controller
	c.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	await get_tree().physics_frame

func after_each() -> void:
	app.session.close()

func add_teammate() -> void:
	app.session.roster.assign(2,1,Session.BUILD_ID)
	c._roster_changed(app.session.roster.snapshot())
	c.avatars.crew_2.global_position=c.avatars.crew_1.global_position+Vector3(1,0,0)
	c.avatars.crew_2.last_dry=c.avatars.crew_2.global_position
	c.run.players.crew_2.protection=0.0

func test_daylight_does_not_spend_the_night_lamp():
	c.avatars.crew_1.global_position=app.world.markers.jetty
	c.lights.recharge("crew_1","flood")
	c._tick_players(10.0)
	assert_eq(float(c.lights.snapshot().batteries.crew_1),90.0)

func test_idle_hunter_really_patrols_at_night():
	c.run.elapsed_s=300.0
	c._tick_hunter(0.1)
	assert_gt(Vector2(c.hunter.velocity.x,c.hunter.velocity.z).length(),2.0)

func test_station_art_and_safety_expire_together():
	c.lights.set_reserve("jetty")
	c.run.elapsed_s=391.0
	assert_false(c._safe(app.world.markers.jetty))
	c._publish()
	assert_eq(float(c.snapshot().lights.station_until.jetty),390.0)

func test_spare_cell_requires_reach_and_is_consumed_once():
	assert_has(c.snapshot(),"supplies")
	if not c.snapshot().has("supplies"): return
	c.avatars.crew_1.global_position=app.world.markers.reeds
	assert_false(c.apply_intent(1,"grab_cell",{"cell_id":"cell_1"},"far").ok)
	c.avatars.crew_1.global_position=c.supply_bodies.cell_1.global_position-Vector3.UP
	assert_true(c.apply_intent(1,"grab_cell",{"cell_id":"cell_1"},"grab").ok)
	assert_false(c.apply_intent(1,"cast",{},"full").ok)
	c.avatars.crew_1.global_position=app.world.markers.jetty
	assert_true(c.apply_intent(1,"feed_station",{"station_id":"jetty"},"feed").ok)
	assert_eq(c.snapshot().supplies.cell_1.state,"consumed")
	assert_eq(float(c.snapshot().lights.station_until.jetty),330.0)
	assert_false(c.apply_intent(1,"feed_station",{"station_id":"jetty"},"twice").ok)

func test_rescue_pickup_and_disconnect_release_the_passenger():
	add_teammate()
	c.run.down("crew_2")
	assert_true(c.apply_intent(1,"carry_teammate",{"target_id":"crew_2"},"lift").ok)
	assert_eq(c.run.players.crew_2.get("carried_by",""),"crew_1")
	c._peer_left("crew_1")
	assert_eq(c.run.players.crew_2.get("carried_by",""),"")
	assert_true(app.world._route_ground(c.avatars.crew_2.global_position))

func test_rescue_requires_range_and_blocks_other_cargo():
	add_teammate()
	c.run.down("crew_2")
	c.avatars.crew_2.global_position=app.world.markers.reeds
	assert_false(c.apply_intent(1,"carry_teammate",{"target_id":"crew_2"},"far").ok)
	c.avatars.crew_2.global_position=c.avatars.crew_1.global_position+Vector3.RIGHT
	assert_true(c.apply_intent(1,"carry_teammate",{"target_id":"crew_2"},"lift").ok)
	assert_eq(c.apply_intent(1,"cast",{},"full").code,"hands_full")
	c.apply_intent(1,"drop_teammate",{},"drop")
	assert_eq(c.run.players.crew_2.get("carried_by",""),"")

func test_down_countdown_is_not_global_hunter_immunity():
	add_teammate()
	c.run.down("crew_2")
	c.run.elapsed_s=300.0
	c.hunter.global_position=app.world.markers.reeds
	c.avatars.crew_1.global_position=app.world.markers.reeds+Vector3(0,0,10)
	c._tick_hunter(0.1)
	assert_eq(c.hunter_rules.state,"warn")

func test_retreat_recap_does_not_claim_a_safe_departure():
	c.run.down("crew_1")
	c._physics_process(0.1)
	assert_eq(c.snapshot().get("trip_result",{}).get("outcome",""),"retreat")
	assert_false("Safe at the mooring" in c.notes.back().text)

func outfit_fixture() -> void:
	var state: Dictionary=c.progression.snapshot()
	state.discoveries=["penny_perch","bellgill","pebble_dab","moss_skipper"]
	state.repairs["return_walkway"]=true
	c.progression=Progression.new(SaveStore.new(app.save_path),state)

func test_outfit_equip_uses_network_gate_and_workshop_range():
	outfit_fixture()
	c.avatars.crew_1.global_position=app.world.markers.boat
	app.session.submit_intent("equip_outfit",{"outfit_id":"angler"},"outfit-net")
	assert_eq(c.progression.snapshot().profiles.crew_1.outfit_id,"angler",str(c.notes.back()))
	c.avatars.crew_1.global_position=app.world.markers.reeds
	assert_eq(c.apply_intent(1,"equip_outfit",{"outfit_id":"stormwatch"},"far").code,"return_to_workshop")
	assert_eq(c.progression.snapshot().profiles.crew_1.outfit_id,"angler")

func test_equipped_angler_bonus_changes_the_real_cast_once():
	outfit_fixture()
	var equipped: Dictionary=c.progression.set_outfit("crew_1","angler")
	assert_true(equipped.ok,str(equipped))
	c.avatars.crew_1.global_position=app.world.markers.jetty
	assert_true(c._cast("crew_1").ok)
	assert_almost_eq(float(c.fishing.casts.crew_1.bar_width),0.34*1.1,0.0001)
	c.fishing.cancel("crew_1")
	c._cast("crew_1")
	assert_almost_eq(float(c.fishing.casts.crew_1.bar_width),0.34*1.1,0.0001)

func test_stormwatch_lamp_lasts_twenty_percent_longer_at_night():
	outfit_fixture()
	var equipped: Dictionary=c.progression.set_outfit("crew_1","stormwatch")
	assert_true(equipped.ok,str(equipped))
	c.avatars.crew_1.global_position=app.world.markers.jetty
	c.avatars.crew_1.last_dry=app.world.markers.jetty
	c.lights.recharge("crew_1","flood")
	c.run.elapsed_s=300
	c._tick_players(18.0)
	assert_almost_eq(float(c.lights.snapshot().batteries.crew_1),75.0,0.001)
