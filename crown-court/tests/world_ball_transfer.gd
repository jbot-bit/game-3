extends SceneTree
## Diagnostic fixture: actual Sim catch/pass/step; World receives immutable snapshots.
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
const DT := 1.0/60.0
var world
var sim
var evidence := "C:/game-3/build/crown-court-evidence/v9-ball-transfer-before"
var rows: Array = []
var unchanged := true
var captures := {}
var capture_enabled := false
var pack_source := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func present(dt: float = DT) -> void:
	var state: Dictionary = sim.snapshot()
	var original := var_to_bytes(state)
	world.present(state,1,dt,0,.43)
	unchanged = unchanged and original == var_to_bytes(state)

func capture(label: String) -> void:
	if not capture_enabled: return
	world.camera.position = Vector3(6,3.2,1)
	world.camera.look_at(Vector3(0,1.7,-2.1))
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func prepare(giant: bool, loose: Vector3) -> void:
	sim = Sim.new()
	sim.reset("coop")
	sim.players = {1:sim.players[1],2:sim.players[2]}
	sim.reset_time = 0
	for id in sim.players:
		var p: Dictionary = sim.players[id]
		p.pos = Vector3(0,0,0 if id==1 else -20)
		p.pos.y = Sim.floor_height(p.pos.x,p.pos.z)
		p.vel = Vector3.ZERO
		p.move = Vector3.ZERO
		p.aim = Vector3.FORWARD
		p.facing = p.aim
		p.giant = 7.0 if giant and id==1 else 0.0
	sim.ball.owner = 0
	sim.ball.lock = 0
	sim.ball.pos = loose
	for i in 60: present()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	for giant in [false,true]:
		for delay in [0,2,8]:
			prepare(giant,Vector3(0,1.1,-2.2))
			sim.action(1,"catch")
			present(0)
			for i in delay:
				sim.step(DT)
				present()
			var previous: Vector3 = world.ball_root.position
			if not giant and delay==2: await capture("01-caught")
			var original: Vector3 = sim.ball.pos
			sim.action(1,"pass")
			present(0)
			var release_jump: float = previous.distance_to(world.ball_root.position)
			previous = world.ball_root.position
			original = sim.ball.pos
			var launch: Vector3 = sim.ball.vel.normalized()
			var horizontal := Vector3(launch.x,0,launch.z).normalized()
			if not giant and delay==2: await capture("02-released")
			var samples: Array = []
			var backwards := 0.0
			var horizontal_backwards := 0.0
			var correction_speed := 0.0
			for frame in 18:
				sim.step(DT)
				present()
				var rendered: Vector3 = world.ball_root.position
				var step: Vector3 = rendered-previous
				var actual_step: Vector3 = sim.ball.pos-original
				backwards = minf(backwards,step.dot(launch))
				horizontal_backwards = minf(horizontal_backwards,step.dot(horizontal))
				correction_speed = maxf(correction_speed,(step-actual_step).length()/DT)
				samples.append({"t":(frame+1)*DT,"rendered":rendered,"actual":sim.ball.pos,"rendered_forward_step":step.dot(launch),"actual_forward_step":actual_step.dot(launch),"offset":rendered.distance_to(sim.ball.pos),"owner":sim.ball.owner})
				previous = rendered
				original = sim.ball.pos
				if not giant and delay==2 and frame<6: await capture("%02d-flight" % (frame+3))
			rows.append({"giant":giant,"delay_frames":delay,"pass":release_jump<.001 and horizontal_backwards>-.001 and world.ball_root.position.distance_to(sim.ball.pos)<.025,"release_jump_m":release_jump,"max_backwards_step_m":-backwards,"max_horizontal_backwards_step_m":-horizontal_backwards,"max_correction_speed_m_s":correction_speed,"residual_300ms_m":world.ball_root.position.distance_to(sim.ball.pos),"samples":samples})
	var failures := rows.filter(func(row): return not row.pass)
	prepare(false,Vector3(0,1.1,-2.2))
	sim.action(1,"catch")
	present(0)
	for i in 2:
		sim.step(DT)
		present()
	sim.action(1,"pass")
	present(0)
	var frozen_start: Vector3 = world.ball_root.position
	for i in 12: present()
	var frozen_drift: float = frozen_start.distance_to(world.ball_root.position)
	var frozen_check := {"case":"loose incoming position frozen for200ms despite nonzero velocity","pass":frozen_drift<.001,"rendered_drift_m":frozen_drift}
	if not frozen_check.pass: failures.append(frozen_check)
	var report := {"fixture":true,"description":"Real catch/pass commands and physical steps from controlled initial conditions; not a natural match or networking test.","world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"input_unchanged":unchanged,"cases":rows,"frozen_input":frozen_check,"failures":failures,"captures":captures}
	if not pack_source.is_empty():
		report["pack_sha256"] = FileAccess.get_sha256(pack_source)
		report["world_sha256"] = ""
		report["sim_sha256"] = ""
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for row in rows: print("TRANSFER ",row.giant," delay ",row.delay_frames," release_jump ",row.release_jump_m," reverse ",row.max_horizontal_backwards_step_m," correction_speed ",row.max_correction_speed_m_s)
	print("FROZEN_TRANSFER ",JSON.stringify(frozen_check))
	world.free()
	quit(0 if unchanged and failures.is_empty() else 1)
