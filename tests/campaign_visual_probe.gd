extends SceneTree
## Actual controller/world/HUD rendering with authored poses and earned-state fixtures.
## This verifies presentation, not hands-on fun, session pacing, or physical LAN latency.
const Game=preload("res://game/main.gd")
var app: Node3D

func _initialize() -> void: call_deferred("_run")

func capture(label: String) -> void:
	for frame in range(30): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://logs/campaign-"+label+".png"))
	if error!=OK:
		push_error("CAMPAIGN_RENDER_FAIL "+label)
		quit(1)
	print("CAMPAIGN_RENDER_OK "+label)

func at(marker: String) -> void:
	var actor=app.controller.avatars.crew_1
	actor.global_position=app.world.markers[marker]
	actor.last_dry=actor.global_position
	actor.velocity=Vector3.ZERO
	app.first_game_frame=true
	await physics_frame

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	app=Game.new()
	app.settings_path="user://tests/campaign-render-settings.json"
	root.add_child(app)
	app.game_port=24633
	app.save_path="user://tests/campaign-render-"+str(Time.get_ticks_usec())+".json"
	app._host("Harbour")
	app.set_physics_process(false)
	var c=app.controller
	c.set_physics_process(false)
	for peer in [2,3]: app.session.roster.assign(peer,peer-1,Session.BUILD_ID)
	c._roster_changed(app.session.roster.snapshot())
	var state: Dictionary=c.progression.snapshot()
	for id in CampaignRules.required_repairs(): state.repairs[id]=true
	state.profiles.crew_1.tool_mode="alternate"
	state.discoveries=Species.catalog().keys().slice(0,6)
	c.progression=Progression.new(SaveStore.new(app.save_path),state)
	c._publish()
	for habitat in ["terraces","tidepools","beacon","reeds"]:
		await at(habitat)
		if habitat=="reeds": c.avatars.crew_1.global_position+=Vector3(0,0,9)
		app.cast_was_active=false
		var cast: Dictionary=c._cast("crew_1")
		if not cast.ok:
			push_error("CAMPAIGN_RENDER_CAST_FAIL "+habitat+str(cast)); quit(1); return
		c._tick_players(0.02)
		c._publish()
		await process_frame
		c.apply_intent(1,"move",{"direction":Vector2.ZERO,"yaw":app.camera.yaw},"facing-"+habitat)
		c._tick_players(0.02)
		await capture("cast-"+habitat)
		c.fishing.cancel("crew_1")
		c._publish()
	await at("beacon_repair")
	c.run.elapsed_s=300
	c.run.phase="night"
	c.apply_intent(1,"use_ability",{},"render-trail")
	c._publish()
	app.camera.yaw=0.8
	await capture("beacon-trail")
	await at("boat")
	c.apply_intent(1,"arm_escape",{},"render-arm")
	await at("beacon_repair")
	c.apply_intent(1,"signal_escape",{},"render-signal")
	for id in c.avatars:
		c.avatars[id].global_position=app.world.markers.boat+Vector3(-c._slot(id),0,0)
		c.run.set_aboard(id,true)
		c.run.set_ready(id,true)
	c._physics_process(0.1)
	c._physics_process(14)
	c._publish()
	app.camera.yaw=PI
	app.camera.pitch=-0.5
	await capture("escape")
	c._physics_process(6)
	c._publish()
	await capture("ending")
	if not c.snapshot().escape.completed:
		push_error("CAMPAIGN_RENDER_ENDING_NOT_SAVED"); quit(1); return
	app.session.close()
	quit(0)
