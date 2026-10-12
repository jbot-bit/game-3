extends SceneTree
const Sim = preload("res://sim.gd")
const Court = preload("res://world.gd")
var sim = Sim.new()
var court
var evidence = "C:/game-3/build/crown-court-evidence/v5-reference-render"
var captures = {}
var checks = []

func _initialize():
	run.call_deferred()

func frame(step: bool = true):
	if step: sim.step(1.0/60)
	if sim.ball.owner > 0: sim.ball.pos = sim.hand_position(sim.ball.owner)
	court.present(sim.snapshot(),1,1.0/60,0,.43)
	await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String):
	var path = evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence=argument.substr(15)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,800)
	court=Court.new()
	root.add_child(court)
	court.build("coop")
	sim.reset("coop")
	for i in 40: await frame(false)
	capture("01-kickoff-deck")
	for i in 215: await frame()
	capture("02-kickoff-airborne")
	for i in 155: await frame()
	capture("03-kickoff-landed")
	checks.append({"label":"launch_lands_in_court","pass":absf(sim.players[1].pos.z)<15 and sim.players[1].grounded})
	# Explicit render fixtures; full-match driver is verified separately.
	sim.reset_time=0
	sim.ball.lock=0
	for id in sim.players.keys():
		if id not in [1,2]: sim.players.erase(id)
	sim.players[1].pos=Vector3(-2,0,5)
	sim.players[2].pos=Vector3(5,0,-14)
	sim.players[1].aim=(sim.players[2].pos-sim.players[1].pos).normalized()
	sim.ball.owner=1
	court.camera_ready=false
	for i in 35: await frame(false)
	sim.action(1,"pass")
	for i in 26: await frame()
	capture("04-pass-trail")
	checks.append({"label":"pass_history_visible","pass":court.pass_history.size()>4 and court.pass_trail_mesh.get_surface_count()>0})
	for i in 100: await frame()
	checks.append({"label":"trail_cleared_on_catch","pass":sim.ball.owner==2 and court.pass_history.is_empty()})
	sim.players.erase(2)
	sim.players[1].pos=sim.hoop(1)+Vector3(0,-3,3)
	sim.players[1].vel=Vector3(0,6,-7)
	sim.players[1].grounded=false
	sim.players[1].aim=Vector3.FORWARD
	sim.ball.owner=1
	sim.ball.lock=0
	court.camera_ready=false
	for i in 35: await frame(false)
	sim.action(1,"dunk")
	for i in 23: await frame()
	capture("05-dunk-rise")
	for i in 20: await frame()
	capture("06-dunk-windup")
	for i in 34: await frame()
	capture("07-dunk-release")
	for i in 10: await frame()
	capture("08-dunk-score")
	checks.append({"label":"dunk_scores","pass":sim.baskets==1})
	var report={"checks":checks,"failures":checks.filter(func(c):return not c.pass),"captures":captures,"fixtures":true,"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"world_sha256":FileAccess.get_sha256("res://world.gd")}
	var file=FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("REFERENCE_RENDER_RESULT ",JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
