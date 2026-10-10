extends SceneTree
## Renders the actual game/controller/HUD. Seeded poses/catch are fixtures, not a family playtest.
const Game=preload("res://game/main.gd")
var app: Node3D

func _initialize() -> void: call_deferred("_run")

func _capture(label: String) -> void:
	for frame in range(40): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var output="res://logs/gameplay-"+label+".png"
	var result=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if result!=OK:
		push_error("Screenshot failed: "+error_string(result))
		quit(1)
	print("GAMEPLAY_RENDER_OK "+label)

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	app=Game.new()
	root.add_child(app)
	app.game_port=24631
	app.save_path="user://tests/visual-"+str(Time.get_ticks_usec())+".json"
	app._host("Harbour")
	app.set_physics_process(false)
	var c=app.controller
	app.session.roster.assign(2,1,"0.4.1-tide")
	app.session.roster.assign(3,2,"0.4.1-tide")
	c._roster_changed(app.session.roster.snapshot())
	c._publish()
	await _capture("home")
	var walking_from: Vector3=c.avatars.crew_1.global_position
	for tick in range(20):
		app.session.submit_intent("move",{"direction":Vector2(0,-1),"yaw":0.0},"render-walk-"+str(tick))
		await create_timer(0.05).timeout
	if c.avatars.crew_1.global_position.distance_to(walking_from)<4:
		push_error("Rendered input did not move the player")
		quit(1)
		return
	await _capture("walking")
	app.session.submit_intent("move",{"direction":Vector2.ZERO,"yaw":0.0},"render-walk-stop")
	c.avatars.crew_1.global_position=app.world.markers.jetty+Vector3(-1,0,1)
	c.avatars.crew_1.last_dry=c.avatars.crew_1.global_position
	app.camera.yaw=PI/2
	c.apply_intent(1,"cast",{},"visual-cast")
	await create_timer(0.2).timeout
	c.apply_intent(1,"move",{"direction":Vector2.ZERO,"yaw":app.camera.yaw},"visual-facing")
	c.apply_intent(1,"reel",{"held":true,"pull":0.0},"visual-reel")
	await create_timer(2.0).timeout
	await _capture("fishing")
	c.fishing.cancel("crew_1")
	for id in c.avatars:
		c.avatars[id].global_position=app.world.markers.boat+Vector3(-7-c._slot(id)*2,0,-4)
		c.avatars[id].last_dry=c.avatars[id].global_position
	app.camera.yaw=0.0
	var record=CatchTable.roll("jetty","day",0,0.8,0.05,0.5)
	record.merge({"catch_id":"visual-trophy","run_id":c.run.run_id,"profile_id":"crew_1"})
	if not c.progression.record_specimen(record).ok:
		push_error("Visual fixture save failed")
		quit(1)
		return
	c._add_landed(record)
	await physics_frame
	c.apply_intent(1,"grab_fish",{"catch_id":"visual-trophy"},"visual-grab")
	await _capture("haul")
	c.run.elapsed_s=305
	c.run.phase="night"
	c.lights.set_reserve("reeds")
	c.keeper_position=c.avatars.crew_1.global_position
	c.abilities.keeper_until=315
	c.hunter.global_position=c.avatars.crew_1.global_position+Vector3(4,0,-8)
	c._publish()
	await _capture("night")
	for id in c.avatars:
		c.avatars[id].global_position=app.world.markers.boat+Vector3(-c._slot(id),0,0)
		c.run.set_aboard(id,true)
		c.run.set_ready(id,true)
	await create_timer(5.0).timeout
	await _capture("refuge")
	app.session.close()
	quit(0)
