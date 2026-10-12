extends SceneTree
## Focused production pose probes: timer-driven impact and phase-aligned dunk.
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var checks: Array = []
var evidence = "C:/game-3/build/crown-court-evidence/presentation-v11"
var court
var game
var capture_enabled = false
var captures: Dictionary = {}

func check(ok: bool, label: String, detail = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+JSON.stringify(detail))

func stable_pose(timer: float, clock: float) -> Dictionary:
	var player: Dictionary = game.players[1]
	player.pos = Vector3(0,1,0)
	player.vel = Vector3(8,3,0)
	player.stun = timer
	player.knockback_time = timer
	player.grounded = false
	player.jump_count = 0
	player.dunk = 0
	player.dive = 0
	player.facing = Vector3.FORWARD
	game.ball.owner = 0
	game.ball.pos = Vector3(0,5,0)
	for frame in 60:
		court.clock_time = clock
		court.present(game.snapshot(),1,1.0/60,0,.43)
	var actor: Dictionary = court.actors[1]
	return {"rig":actor.rig.rotation,"lift":actor.rig.position.y,"hands":[actor.left_hand.position,actor.right_hand.position],"camera":court.camera.transform,"root":actor.root.transform}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
		if arg=="--capture": capture_enabled=true
	run.call_deferred()

func capture(label: String) -> void:
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = {"path":path,"sha256":FileAccess.get_sha256(path),"camera":str(court.camera.transform),"fov":court.camera.fov,"fixture":true}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,800)
	court = World.new()
	root.add_child(court)
	court.build("coop")
	game = Sim.new()
	game.reset("coop")
	game.reset_time = 0
	game.players = {1:game.players[1]}
	var early = stable_pose(.63,0)
	await capture("01-impact")
	var peak = stable_pose(.40,0)
	await capture("02-peak-roll")
	var late = stable_pose(.04,0)
	await capture("03-recovery")
	check(absf(peak.rig.z)>1.7 and absf(late.rig.z)<.10 and absf(early.rig.z)<absf(peak.rig.z),"One impact roll grows then returns upright with actual recovery timer",{"early":str(early.rig),"peak":str(peak.rig),"late":str(late.rig)})
	check(early.camera.is_equal_approx(peak.camera) and peak.camera.is_equal_approx(late.camera) and early.root.is_equal_approx(late.root),"Impact pose leaves player root aim and followed camera fixed")
	var first = stable_pose(.32,0)
	var second = stable_pose(.32,9.7)
	check(first.rig.distance_to(second.rig)<.0001 and first.hands[0].distance_to(second.hands[0])<.0001 and first.hands[1].distance_to(second.hands[1])<.0001,"Recovery pose does not wobble with unrelated world clock")
	game.reset("coop")
	game.reset_time = 0
	game.players = {1:game.players[1]}
	var player: Dictionary = game.players[1]
	player.pos = Sim.NORTH+Vector3(0,-Sim.HOOP_Y,3)
	player.pos.y = Sim.floor_height(player.pos.x,player.pos.z)
	player.aim = Vector3.FORWARD
	player.facing = Vector3.FORWARD
	game.secure_ball(1)
	game.action(1,"jump")
	for frame in 12: game.step(1.0/60)
	game.action(1,"dunk")
	var frozen: Vector3 = player.dunk_direction
	var alignment = 0.0
	var changed = false
	var released = false
	for frame in 100:
		game.move_input(1,Vector3.RIGHT,Vector3.RIGHT)
		game.step(1.0/60)
		var state: Dictionary = game.snapshot()
		var before = var_to_bytes(state)
		court.present(state,1,1.0/60,1.4,.2)
		changed = changed or before!=var_to_bytes(state)
		if game.ball.owner==1 and player.dunk>0:
			var actor: Dictionary = court.actors[1]
			var midpoint: Vector3 = (actor.left_hand.global_position+actor.right_hand.global_position)*.5
			alignment = maxf(alignment,midpoint.distance_to(court.ball_root.global_position))
			check(player.dunk_direction.is_equal_approx(frozen),"Committed dunk axis survives fresh aim "+str(frame))
		if game.ball.owner==0 and not released:
			released = true
			check(not court.actors[1].dunk_ring.visible,"Visible wind-up ends on physical slam release phase")
		if game.baskets>0: break
	check(not changed and released and game.baskets==1,"Dunk pose preserves authority and real scoring path")
	check(alignment<.16,"Faster dunk keeps both hands attached to actual carried ball",{"max_midpoint_error":alignment})
	var report = {"passed":checks.all(func(row):return row.passed),"checks":checks,"world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"probe_sha256":FileAccess.get_sha256(get_script().resource_path),"rendered":capture_enabled,"captures":captures,"fixture":true}
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PRESENTATION_V11_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
