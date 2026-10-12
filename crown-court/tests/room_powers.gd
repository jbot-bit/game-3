extends SceneTree
## Explicit deterministic fixtures, not a naturally played match or WAN test.
## Real relay, application RPCs, Sim actions/steps, snapshots and world/HUD consumers.

class Probe extends "res://main.gd":
	func save_settings() -> void:
		pass # Never overwrite the household's preferences.

const Sim = preload("res://sim.gd")
var apps: Array = []
var paths: Array[String] = []
var checks: Array[Dictionary] = []
var host
var first
var second
var url = "ws://127.0.0.1:30250/rooms"
var evidence = "res://tests/room-powers"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room-url="): url = arg.trim_prefix("--room-url=")
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String, detail: Dictionary = {}) -> bool:
	checks.append({"check":label,"passed":ok,"detail":detail})
	print("PASS " if ok else "FAIL ",label," ",detail)
	return ok

func until(condition: Callable, seconds: float = 4.0) -> bool:
	var began = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-began < seconds*1000: await process_frame
	return condition.call()

func make_app(label: String, power: String):
	var branch = Node.new()
	branch.name = label
	root.add_child(branch)
	var api = SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app = Probe.new()
	app.name = "App"
	app.manual_input_enabled = false
	var path = "user://room_power_%s_%d.json" % [label,Time.get_ticks_usec()]
	paths.append(path)
	app.profile = app.Profile.new(path)
	branch.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.room_server_url = url
	app.nickname = label
	app.selected_power = power
	app.muted = true
	apps.append(app)
	return app

func publish() -> bool:
	host.state = host.sim.snapshot()
	host.state["match_id"] = host.match_id
	var packet: PackedByteArray = host.encode_snapshot()
	var sequence: int = host.snapshot_serial
	for peer in host.connected_peers(): host.send_snapshot(peer,packet)
	var delivered = await until(func():
		for app in apps:
			if app != host and app.phase == "match" and app.snapshot_received_sequence < sequence: return false
		return true)
	for app in apps:
		if app.phase != "match" or app.state.is_empty(): continue
		app.ui_clock += .05
		app.update_hud(1.0/60)
		for frame in 20: app.world.present(app.state,app.local_seat,1.0/60,0,.43)
	return delivered

func fixture() -> void:
	host.sim.reset_time = 0
	host.sim.celebration_time = 0
	host.sim.power_pads.clear()
	host.sim.power_balls.clear()
	var index = 0
	for id in host.sim.players:
		var p: Dictionary = host.sim.players[id]
		p.pos = Vector3(-22+index*8,0,32)
		p.pos.y = Sim.floor_height(p.pos.x,p.pos.z)
		p.vel = Vector3.ZERO
		p.move = Vector3.ZERO
		p.aim = Vector3.FORWARD
		p.grounded = true
		p.jump_count = 0
		for key in ["hype","giant","stun","guard","dive","dunk","cooldown","pad_cooldown","boost_time","hazard_cooldown"]: p[key] = 0.0
		index += 1
	host.sim.ball.owner = 0
	host.sim.ball.pos = Vector3(0,Sim.BALL_RADIUS,-38)
	host.sim.ball.vel = Vector3.ZERO
	host.sim.ball.lock = 0
	host.sim.ball.pass_target = 0
	host.sim.ball.last_touch = 0

func step_frames(count: int) -> void:
	for index in count:
		host.sim.step(1.0/60)
		if index % 120 == 119: await process_frame

func earn_ready(app) -> void:
	var id: int = app.local_seat
	var p: Dictionary = host.sim.players[id]
	p.hype = 96 # Seed partial charge; the final4 must come from a real catch.
	host.sim.ball.owner = 0
	host.sim.ball.lock = 0
	host.sim.ball.pos = p.pos+Vector3.UP
	host.sim.ball.vel = Vector3.ZERO
	await publish()
	app.submit_action("hype")
	await create_timer(.06).timeout
	check(host.sim.players[id].hype == 96,"Below-full activation is rejected for "+str(p.power))
	app.submit_action("catch")
	check(await until(func(): return host.sim.ball.owner == id),"Real catch reaches host for "+str(p.power))
	await publish()
	check(host.sim.players[id].hype == 100 and app.hype_ring.status_text == "Ready","Earned charge and ready feedback replicate for "+str(p.power))

func run() -> void:
	host = make_app("PowerHost","giant")
	host.host_room("teams")
	if not check(await until(func(): return host.phase == "lobby"),"Room host registers"):
		await finish(); return
	host.start_match()
	fixture()
	var replaced = 0
	for id in host.sim.players:
		if id >= 4: replaced = id
	if not check(replaced > 0,"Custom-team kickoff creates a replaceable opponent bot"):
		await finish(); return
	host.sim.players[replaced].hype = 100
	host.sim.players[replaced].power = "giant"
	host.sim.action(replaced,"hype")
	first = make_app("PowerFirst","pad")
	first.join_room(host.room_code)
	if not check(await until(func(): return first.phase == "match" and host.sim.players.has(first.local_seat) and host.sim.players[first.local_seat].power == "pad"),"Live join replaces bot and registers chosen power through RPC"):
		await finish(); return
	await publish()
	check(not host.sim.players.has(replaced) and first.state.players[first.local_seat].giant > 6.9,"Bot's active Giant survives actual human replacement")
	check(first.hype_ring.power == "Jump pad" and "Giant" in first.hype_ring.status_text and "7s" in first.hype_ring.status_text,"HUD names inherited Giant timer without hiding selected Jump pad",{"selected":first.hype_ring.power,"status":first.hype_ring.status_text})
	second = make_app("PowerSecond","blast")
	second.join_room(host.room_code)
	if not check(await until(func(): return second.phase == "match" and host.seats.size() == 3 and host.powers.get(second.local_seat) == "blast"),"Third peer joins with a distinct selected power"):
		await finish(); return
	host.selected_mode = "coop"
	host.start_match()
	await until(func(): return first.match_id == host.match_id and second.match_id == host.match_id)
	fixture()
	await publish()
	check(host.sim.players[1].power == "giant" and first.state.players[first.local_seat].power == "pad" and second.state.players[second.local_seat].power == "blast","Three lobby choices reach authoritative round and joined snapshots")
	await earn_ready(host)
	host.submit_action("hype")
	await publish()
	var giant_visible = true
	for app in [first,second]: giant_visible = giant_visible and app.state.players[1].giant > 6.9 and float(app.world.actors[1].visual_size) > 1.7
	check(host.sim.players[1].hype == 0 and giant_visible,"Giant spends charge once and visibly enlarges on both joined clients")
	host.sim.players[1].pos = Sim.HAZARDS[0]
	host.sim.players[1].pos.y = Sim.floor_height(Sim.HAZARDS[0].x,Sim.HAZARDS[0].z)
	host.sim.players[4].pos = Sim.HAZARDS[1]
	host.sim.players[4].pos.y = Sim.floor_height(Sim.HAZARDS[1].x,Sim.HAZARDS[1].z)
	await step_frames(1)
	check(host.sim.players[1].stun == 0 and host.sim.players[4].stun > 0,"Giant physically ignores a sweeper that hits an ordinary opponent")
	await step_frames(430)
	await publish()
	check(first.state.players[1].giant == 0 and second.state.players[1].giant == 0 and float(first.world.actors[1].visual_size) < 1.02,"Giant expires in real Sim time and joined actor returns to normal")
	fixture()
	await earn_ready(first)
	first.submit_action("hype")
	await until(func(): return host.sim.power_pads.size() == 1)
	await publish()
	check(host.sim.players[first.local_seat].hype == 0 and first.world.temporary_pads.size() == 1 and second.world.temporary_pads.size() == 1 and first.hype_ring.status_text.begins_with("Active"),"Remote Jump pad activates with joined world effects and lifetime HUD")
	first.submit_move(Vector3.FORWARD,Vector3.FORWARD)
	await until(func(): return host.sim.players[first.local_seat].move.z < -.9)
	var launched = false
	for index in 60:
		host.sim.step(1.0/60)
		launched = launched or host.sim.players[first.local_seat].vel.y > 20
	check(launched,"Walking onto deployed pad causes an authoritative launch")
	first.submit_move(Vector3.ZERO,Vector3.FORWARD)
	await until(func(): return host.sim.players[first.local_seat].move == Vector3.ZERO)
	await step_frames(850)
	await publish()
	check(first.state.power_pads.is_empty() and second.state.power_pads.is_empty() and first.world.temporary_pads.is_empty() and second.world.temporary_pads.is_empty() and not first.hype_ring.status_text.begins_with("Active"),"Pad expires through Sim, disappears on both peers and clears active HUD")
	fixture()
	host.sim.players[second.local_seat].pos = Vector3.ZERO
	host.sim.players[4].pos = Vector3(9,0,0)
	host.sim.secure_ball(4)
	await earn_ready(second)
	# Give the victim possession after earning; a real impact must dislodge it.
	host.sim.secure_ball(4)
	second.submit_move(Vector3.ZERO,Vector3.RIGHT)
	second.submit_action("hype")
	await until(func(): return host.sim.power_balls.size() == 1)
	await publish()
	check(first.world.power_orbs.size() == 1 and second.world.power_orbs.size() == 1 and second.hype_ring.status_text.begins_with("Active"),"Remote Homing ball creates replicated visible projectile and lifetime HUD")
	var hit = false
	for index in 120:
		host.sim.step(1.0/60)
		if host.sim.players[4].stun > 0: hit = true; break
	await publish()
	check(hit and host.sim.ball.owner != 4 and host.sim.players[second.local_seat].hype == 16,"Homing projectile physically hits, drops victim's ball and earns tackle charge")
	check(first.state.power_balls.is_empty() and second.state.power_balls.is_empty() and first.world.power_orbs.is_empty() and second.world.power_orbs.is_empty(),"Projectile impact removes its effect on both joined clients")
	# No-hit lifetime fixture: target starts too far away to reach in4s.
	fixture()
	host.sim.players[second.local_seat].pos = Vector3(0,0,38)
	for id in [4,5,6]: host.sim.players[id].pos = Vector3((id-5)*8,0,-38)
	host.sim.players[second.local_seat].hype = 100
	second.submit_action("hype")
	await until(func(): return host.sim.power_balls.size() == 1)
	await publish()
	await step_frames(245)
	await publish()
	check(host.sim.power_balls.is_empty() and first.world.power_orbs.is_empty() and second.world.power_orbs.is_empty(),"Missed homing projectile expires without leaving joined effects")
	check(apps.all(func(app): return app.profile.data.bags == 0),"Power fixtures do not award match rewards")
	await finish()

func finish() -> void:
	for app in apps: await app.close_session()
	await create_timer(.2).timeout
	for app in apps: app.get_parent().queue_free()
	await process_frame
	for path in paths:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"scope":"Explicit position/partial-charge/time-step fixtures; real three-peer local room RPC/Sim/snapshot/HUD/world-node consumers. No GPU, natural-match, physical-controller or WAN claim."}
	DirAccess.make_dir_recursive_absolute(evidence)
	var file = FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("ROOM POWERS: %d checks, %d failures" % [checks.size(),checks.filter(func(row): return not row.passed).size()])
	quit(0 if report.passed else 1)
