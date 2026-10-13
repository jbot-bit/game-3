extends SceneTree
var app
var evidence = "C:/game-3/build/crown-court-evidence/v152-visual"
func _initialize(): run.call_deferred()
func capture(label):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
func run():
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,800)
	app=load("res://main.gd").new()
	app.manual_input_enabled=false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.muted=true
	app.practice_game("coop")
	app.sim.reset_time=0
	for id in app.sim.players:
		app.sim.players[id].pos=Vector3(15,0,id*3)
	var p=app.sim.players[1]
	p.pos=Vector3(0,0,-43)
	p.grounded=true
	p.aim=Vector3.FORWARD
	app.sim.ball.owner=1
	app.sim.ball.pos=app.sim.hand_position(1)
	app.state=app.sim.snapshot()
	app.state.cosmetics={1:{"character":"dad","outfit":"blank","accessory":"none"}}
	for i in 45: app.world.present(app.state,1,1.0/60,0,.43)
	app.update_hud(.016)
	await capture("family-hoop-gameplay")
	app.world.camera.position=Vector3(12,7,-37)
	app.world.camera.look_at(Vector3(0,3,-47))
	await capture("family-hoop-side")
	var q=app.sim.players[4]
	q.pos=Vector3(0,2,-45)
	q.dunk=.95
	q.dunk_duration=.95
	q.guard=0
	q.team=1
	p.stun=0
	p.dunk=0
	p.dive=0
	p.cooldown=0
	p.jump_count=0
	app.sim.ball.owner=4
	app.sim.ball.pos=app.sim.hand_position(4)
	app.state=app.sim.snapshot()
	for i in 30: app.world.present(app.state,1,1.0/60,0,.43)
	app.update_hud(.016)
	await capture("counterplay-hint")
	app.set_paused(true)
	await capture("controls")
	quit()
