extends GutTest
const Game=preload("res://game/main.gd")
var app: Node

class RefusingStore extends SaveStore:
	var refuse: bool=false
	func commit(state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(state)

func before_each() -> void:
	app=Game.new()
	add_child_autofree(app)
	app.game_port=24609
	app.save_path="user://tests/controller-"+str(Time.get_ticks_usec())+".json"
	app._host("Test")
	app.controller.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	await get_tree().process_frame

func after_each() -> void:
	var key=InputEventKey.new()
	key.physical_keycode=KEY_A
	key.pressed=false
	Input.parse_input_event(key)
	app.session.close()

func test_side_control_can_oppose_fish_without_cancelling():
	var actor=app.controller.avatars.crew_1
	actor.global_position=app.world.markers.jetty
	assert_true(app.controller._cast("crew_1").ok)
	app.controller._publish()
	app.controller.apply_intent(1,"move",{"direction":app._movement_intent(Vector2(-1,0)),"yaw":0.0},"move-test")
	assert_true(app.controller.fishing.casts.has("crew_1"),"A/D must counter a fish, not cancel its cast")

func test_f8_opens_host_panel():
	app.hud.update_view(app.controller.snapshot().merged({"is_host":true}),"crew_1","")
	var key=InputEventKey.new()
	key.physical_keycode=KEY_F8
	key.pressed=true
	app._unhandled_input(key)
	assert_true(app.hud.panel_open(),"Host must be able to open the Lake Office")

func test_lamp_off_survives_snapshot_refresh():
	app.controller.apply_intent(1,"toggle_lamp",{"enabled":false},"lamp")
	app.controller._tick_players(0.02)
	app.controller._publish()
	assert_false(app.controller.avatars.crew_1.lamp.visible,"snapshot must preserve lamp toggle")

func test_v_opens_visible_ballot():
	app.controller.avatars.crew_1.global_position=app.world.markers.vote
	var key=InputEventKey.new()
	key.physical_keycode=KEY_V
	key.pressed=true
	app._unhandled_input(key)
	assert_true(app.hud.panel_open(),"V must expose the vote choices")

func test_open_panel_releases_reel_and_movement():
	app.controller.apply_intent(1,"reel",{"held":true,"pull":0.0},"hold")
	app.controller.apply_intent(1,"move",{"direction":Vector2.RIGHT,"yaw":0.0},"moving")
	app.hud.toggle_panel("journal")
	app._physics_process(0.05)
	assert_false(app.controller.inputs.crew_1.reel)
	assert_eq(app.controller.inputs.crew_1.direction,Vector2.ZERO)

func test_initial_name_applies_without_changing_saved_role():
	app.player_name="Harbour Crew"
	app._process(0.02)
	assert_eq(app.controller.progression.snapshot().profiles.crew_1.name,"Harbour Crew")
	assert_eq(app.controller.progression.snapshot().profiles.crew_1.role_id,"scout")

func test_valuable_reeds_fishing_requires_leaving_shelter():
	app.controller.run.elapsed_s=300
	app.controller.run.phase="night"
	app.controller.lights.set_reserve("reeds")
	app.controller.avatars.crew_1.global_position=app.world.markers.reeds
	assert_false(app.controller._cast("crew_1").ok,"Rare fishing cannot be done inside permanent protection")

func test_hunter_can_leave_a_powered_circle():
	app.controller.run.elapsed_s=300
	app.controller.lights.set_reserve("jetty")
	app.controller.hunter.global_position=app.world.markers.jetty
	app.controller.avatars.crew_1.global_position=app.world.markers.jetty+Vector3(0,0,-12)
	app.controller.hunter_rules.state="chase"
	app.controller._tick_hunter(0.1)
	assert_gt(Vector2(app.controller.hunter.velocity.x,app.controller.hunter.velocity.z).length(),0.1)

func test_safe_return_preserves_a_supported_dry_point_for_every_profile():
	app.session.roster.assign(2,1,"0.1.0-slice")
	app.session.roster.assign(3,2,"0.1.0-slice")
	app.controller._roster_changed(app.session.roster.snapshot())
	for a in app.controller.avatars.values():
		a.global_position=app.world.markers.reeds
		a.last_dry=a.global_position
	app.controller.apply_intent(1,"host_event",{"event_id":"safe_return"},"safe")
	for a in app.controller.avatars.values():
		assert_lt(a.global_position.distance_to(a.last_dry),0.1,"Safe return must update the fallback shore point")
		assert_true(app.controller._near_boat(a.profile_id,5))

func test_failed_land_disconnect_retry_recovers_whole_fish():
	var c=app.controller
	app.session.roster.assign(2,1,"0.1.0-slice")
	c._roster_changed(app.session.roster.snapshot())
	var store=RefusingStore.new(app.save_path)
	c.progression=Progression.new(store,c.progression.snapshot())
	var record=CatchTable.roll("jetty","day",0,0.8,0.05,0.5)
	record.merge({"catch_id":"recover-trophy","run_id":c.run.run_id,"profile_id":"crew_2"})
	c.rolled.crew_2=record
	store.refuse=true
	c._land("crew_2")
	assert_true(c.run.paused)
	c._peer_left("crew_2")
	app.session.roster.disconnect_peer(2)
	c._roster_changed(app.session.roster.snapshot())
	store.refuse=false
	assert_true(c._retry_write().ok)
	assert_true(c.fish_bodies.has("recover-trophy"),"Whole fish needs a body after disconnected-owner retry")
	assert_false(c.run.paused)

func test_new_day_clears_prior_hunter_slowdown():
	app.controller.hunter_slow_until=602.0
	app.controller.start_day()
	assert_eq(app.controller.hunter_slow_until,0.0)

func test_pause_freezes_dawn_recap():
	app.controller.next_day_at=8.0
	app.controller._pause(true)
	var prior_id=app.controller.run.run_id
	app.controller._physics_process(9.0)
	assert_eq(app.controller.next_day_at,8.0)
	assert_eq(app.controller.run.run_id,prior_id)
	assert_true(app.controller.run.paused)

func test_paused_disconnect_releases_physical_hold_after_resume():
	var c=app.controller
	app.session.roster.assign(2,1,"0.1.0-slice")
	c._roster_changed(app.session.roster.snapshot())
	var record=CatchTable.roll("jetty","day",0,0.8,0.05,0.5)
	record.merge({"catch_id":"paused-trophy","run_id":c.run.run_id,"profile_id":"crew_2"})
	c._add_landed(record)
	c.cargo.grab("paused-trophy","crew_2",{"active":true,"distance_m":0.0,"line_of_sight":true})
	var body=c.fish_bodies["paused-trophy"]
	body.held=true
	c._pause(true)
	c._peer_left("crew_2")
	assert_false(body.held)
	assert_true(body.freeze)
	c._pause(false)
	assert_false(body.freeze,"A disconnected carrier cannot leave a permanently frozen fish")

func test_failed_pouch_land_stays_forfeited_after_rejoin_before_retry():
	var c=app.controller
	app.session.roster.assign(2,1,"0.1.0-slice")
	c._roster_changed(app.session.roster.snapshot())
	var store=RefusingStore.new(app.save_path)
	c.progression=Progression.new(store,c.progression.snapshot())
	var record=CatchTable.roll("jetty","day",0,0.2,0.5,0.5)
	record.merge({"catch_id":"pending-pouch","run_id":c.run.run_id,"profile_id":"crew_2"})
	c.rolled.crew_2=record
	store.refuse=true
	c._land("crew_2")
	c._peer_left("crew_2")
	app.session.roster.disconnect_peer(2)
	c._roster_changed(app.session.roster.snapshot())
	app.session.roster.assign(7,1,"0.1.0-slice")
	c._roster_changed(app.session.roster.snapshot())
	store.refuse=false
	assert_true(c._retry_write().ok)
	assert_eq(c.cargo.snapshot()["pending-pouch"].state,"lost")
	assert_has(c.progression.snapshot().discoveries,"penny_perch")
