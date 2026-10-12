extends SceneTree
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
var evidence = "C:/game-3/build/crown-court-evidence/tackle-native"
var sim
var world
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	run.call_deferred()
func capture(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
func run():
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,800)
	sim=Sim.new()
	sim.reset("coop")
	sim.reset_time=0
	for id in sim.players:
		sim.players[id].pos=Vector3(24,0,30+id*2)
		sim.players[id].guard=0
		sim.players[id].vel=Vector3.ZERO
	sim.players[1].pos=Vector3(0,0,4)
	sim.players[4].pos=Vector3(0,0,0)
	sim.players[2].pos=Vector3(-2.8,0,-1.2)
	sim.players[1].aim=Vector3.FORWARD
	sim.players[1].move=Vector3.FORWARD
	sim.secure_ball(4)
	world=World.new()
	root.add_child(world)
	var samples=[]
	for frame in 180:
		if frame==30: sim.action(1,"tackle")
		if frame>45 and frame<100: sim.action(2,"catch")
		sim.step(1.0/60)
		var state=sim.snapshot()
		state.names={1:"Dad",2:"Tyler",4:"Evie"}
		state.cosmetics={1:{"character":"dad"},2:{"character":"tyler"},4:{"character":"evie"}}
		world.present(state,1,1.0/60,0,-.18)
		await process_frame
		if frame in [0,29,33,37,41,48,60,90,179]: await capture("frame-%03d"%frame)
		samples.append({"frame":frame,"owner":sim.ball.owner,"tackles":sim.tackles,"victim_stun":sim.players[4].stun,"victim_pos":str(sim.players[4].pos),"ball":str(sim.ball.pos)})
	var result={"passed":sim.tackles>=1,"samples":samples,"scope":"Native visual fixture using real simulation actions; not human play"}
	var f=FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "));f.close()
	world.queue_free()
	await process_frame
	print("TACKLE_RENDER_RESULT ",result.passed)
	quit(0 if result.passed else 1)
