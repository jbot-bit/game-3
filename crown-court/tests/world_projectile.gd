extends SceneTree
## Actual Sim Hype activation/motion, sampled at20Hz and presented at60Hz.
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
const DT := 1.0/60
var world
var sim
var checks: Array = []
var samples: Array = []
var captures := {}
var evidence := "C:/game-3/build/crown-court-evidence/v9-projectile-headless"
var capture_enabled := false
var pack_source := ""
var unchanged := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"pass":ok,"label":label,"details":details})
	print("PROJECTILE_CHECK ",label," ",ok," ",JSON.stringify(details))

func prepare(owner_z: float = 0, target_z: float = -40) -> void:
	sim = Sim.new()
	sim.reset("coop")
	sim.players = {1:sim.players[1],4:sim.players[4]}
	sim.reset_time = 0
	for id in sim.players:
		var p: Dictionary = sim.players[id]
		p.pos = Vector3(0,0,owner_z if id==1 else target_z)
		p.pos.y = Sim.floor_height(p.pos.x,p.pos.z)
		p.vel = Vector3.ZERO
		p.move = Vector3.ZERO
		p.aim = Vector3.FORWARD
		p.grounded = true
		p.boost_time = 0
	sim.players[1].power = "blast"
	sim.players[1].hype = 100
	sim.action(1,"hype")
	world._present_powers({},DT)

func present(snapshot: Dictionary, age: float) -> Dictionary:
	var shown := snapshot.duplicate(true)
	shown["snapshot_clock"] = snapshot.clock
	shown["clock"] = float(snapshot.clock)+clampf(age,0,.08)
	shown["match_id"] = "projectile-diagnostic"
	var before := var_to_bytes(shown)
	world._present_powers(shown,DT)
	unchanged = unchanged and before == var_to_bytes(shown)
	return shown

func capture(label: String) -> void:
	if not capture_enabled: return
	world.camera.position = Vector3(10,6,1)
	world.camera.look_at(Vector3(0,1.4,-3.3))
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	world = World.new()
	root.add_child(world)
	if capture_enabled: world.build("coop")
	else:
		world.effect_root = Node3D.new()
		world.add_child(world.effect_root)
	prepare()
	var id: int = sim.power_balls[0].id
	var snapshot: Dictionary = sim.snapshot()
	present(snapshot,0)
	var previous: Vector3 = world.power_orbs[id].node.position
	var maximum_step := 0.0
	var maximum_error := 0.0
	var stalled := 0
	for frame in range(1,91):
		if frame==35: sim.move_input(4,Vector3.RIGHT,Vector3.FORWARD)
		sim.step(DT)
		if frame%3==0: snapshot = sim.snapshot()
		present(snapshot,(frame%3)*DT)
		var at: Vector3 = world.power_orbs[id].node.position
		var step := at.distance_to(previous)
		maximum_step = maxf(maximum_step,step)
		maximum_error = maxf(maximum_error,at.distance_to(sim.power_balls[0].pos))
		if step<.001: stalled += 1
		samples.append({"frame":frame,"snapshot_clock":snapshot.clock,"age":(frame%3)*DT,"rendered":at,"authority":sim.power_balls[0].pos,"step":step})
		if frame in [5,6,7,8]: await capture("%02d-flight" % (frame-4))
		previous = at
	check(stalled==0,"20Hz actual homing snapshots advance visually on every60Hz frame",{"stalled_frames":stalled})
	check(maximum_step<.38,"snapshot updates do not make0.9m projectile jumps",{"max_step_m":maximum_step})
	check(maximum_error<.18,"bounded extrapolation stays close to actual curved homing motion",{"max_error_m":maximum_error})
	var capped: Vector3
	for frame in range(1,31):
		present(snapshot,frame*DT)
		if frame==6: capped=world.power_orbs[id].node.position
	var frozen: Vector3 = world.power_orbs[id].node.position
	check(capped.distance_to(frozen)<.001,"projectile position stops at the shared80ms prediction cap",{"post_cap_drift_m":capped.distance_to(frozen)})
	check(frozen.distance_to(snapshot.power_balls[0].pos)<=1.5,"starved projectile never extrapolates indefinitely",{"bounded_lead_m":frozen.distance_to(snapshot.power_balls[0].pos)})
	var host_snapshot := snapshot.duplicate(true)
	for field in ["reset_time","celebration_time"]:
		host_snapshot[field] = 1.0
		world._present_powers(host_snapshot,DT)
	var host_error: float = world.power_orbs[id].node.position.distance_to(host_snapshot.power_balls[0].pos)
	check(host_error<.000001,"host and frozen authority snapshots remain exact without extrapolation",{"error_m":host_error})
	var restarted := snapshot.duplicate(true)
	restarted["snapshot_clock"] = restarted.clock
	restarted["clock"] = float(restarted.clock)+.05
	restarted["match_id"] = "replacement-round"
	restarted.power_balls[0].pos += Vector3(8,0,0)
	var restart_bytes := var_to_bytes(restarted)
	world._present_powers(restarted,DT)
	var restart_expected: Vector3 = restarted.power_balls[0].pos+restarted.power_balls[0].vel*.05
	var restart_error: float = world.power_orbs[id].node.position.distance_to(restart_expected)
	check(restart_error<.000001 and bool(world.power_orbs[id].reset_trail),"new round discards prior projectile correction and trail",{"error_m":restart_error})
	unchanged = unchanged and restart_bytes==var_to_bytes(restarted)
	var paused := restarted.duplicate(true)
	paused["reset_time"] = 1.0
	paused["clock"] = paused.snapshot_clock
	world._present_powers(paused,DT)
	var pause_position: Vector3 = world.power_orbs[id].node.position
	for frame in 12: world._present_powers(paused,DT)
	check(world.power_orbs[id].node.position.distance_to(pause_position)<.000001,"repeated frozen network snapshots cannot keep the projectile moving")
	var old_node: Node3D = world.power_orbs[id].node
	var deleted := snapshot.duplicate(true)
	deleted.power_balls.clear()
	present(deleted,0)
	check(world.power_orbs.is_empty() and (not old_node.visible or old_node.is_queued_for_deletion()),"authoritative deletion removes the orb and its effect cache immediately")
	prepare(45,-45)
	for frame in 237: sim.step(DT)
	var expiring: Dictionary = sim.snapshot()
	check(expiring.power_balls.size()==1,"expiry probe is an actual live projectile before its lifetime ends")
	present(expiring,.08)
	check(world.power_orbs.is_empty(),"predicted lifetime cannot display an already expired orb")
	check(unchanged,"projectile presentation never mutates input snapshots")
	var report := {"fixture":true,"checks":checks,"failures":checks.filter(func(row):return not row.pass),"samples":samples,"captures":captures,"world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"probe_sha256":FileAccess.get_sha256(get_script().resource_path)}
	if not pack_source.is_empty():
		report["pack_sha256"] = FileAccess.get_sha256(pack_source)
		report["world_sha256"] = ""
		report["sim_sha256"] = ""
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if report.failures.is_empty() else 1)
