extends SceneTree
## Explicit support-transition fixtures, then unchanged real physics and packets.
const App = preload("res://main.gd")
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
var evidence = "res://tests/deck-edge-prediction"
var pack_source = ""
var checks: Array = []
var samples: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, observed = null) -> void:
	checks.append({"passed":ok,"check":label,"observed":observed})
	print(("PASS " if ok else "FAIL ")+label+" "+JSON.stringify(observed))

func app_for(label: String, id: int, position: Vector3, direction: Vector3):
	var app = App.new()
	app.manual_input_enabled = false
	app.phase = "match"
	app.match_id = label
	app.local_seat = 1
	app.sim.reset("coop")
	app.sim.players = {id:app.sim.players[id]}
	app.sim.reset_time = 0
	var p: Dictionary = app.sim.players[id]
	p.pos = position
	p.move = direction
	p.vel = direction*Sim.SPEED*.94
	p.aim = direction
	p.grounded = true
	p.boost_time = 0
	p.pad_cooldown = 10
	app.local_direction = direction
	app.last_aim = direction
	app.sim.secure_ball(id)
	return app

func packet(app, serial: int) -> PackedByteArray:
	var wire: Dictionary = app.sim.snapshot()
	wire.match_id = app.match_id
	wire._snapshot_seq = serial
	return var_to_bytes(wire).compress(FileAccess.COMPRESSION_DEFLATE)

func deck_case(side: int, lateral: bool, id: int) -> void:
	var label = "deck_%d_%s_%s"%[side,"side" if lateral else "front","local" if id==1 else "remote"]
	var direction = Vector3.RIGHT if lateral else Vector3(0,0,-side)
	var position = Vector3(Sim.KICKOFF_HALF_WIDTH-.5,Sim.KICKOFF_Y,side*Sim.KICKOFF_Z) if lateral else Vector3(4,Sim.KICKOFF_Y,side*(Sim.KICKOFF_Z-Sim.KICKOFF_HALF_DEPTH+.5))
	var app = app_for(label,id,position,direction)
	var world = World.new()
	root.add_child(world)
	world.actor_root = Node3D.new()
	world.add_child(world.actor_root)
	world.effect_root = Node3D.new()
	world.add_child(world.effect_root)
	var actor: Dictionary = world._make_actor(id)
	var packets: Array = []
	var sequence = 0
	var minimum_error = 0.0
	var minimum_actor_error = 0.0
	var max_step = 0.0
	var last_y = position.y
	var held_error = 0.0
	var immutable = true
	var walked_off = false
	for tick in 30:
		app.ui_clock = tick/60.0
		if tick%3 == 0:
			sequence += 1
			packets.append({"deliver":tick+1,"packet":packet(app,sequence)})
		if not packets.is_empty() and int(packets[0].deliver)<=tick:
			app.receive_state(packets.pop_front().packet)
		if not app.state.is_empty():
			var before = var_to_bytes(app.state)
			var shown: Dictionary = app.predict_render_state(app.ui_clock-app.snapshot_received_at)
			var target: Vector3 = shown.players[id].pos
			world._present_actor(actor,id,shown.players[id],id==1,true,shown.ball.pos,"Probe",1.0/60)
			var actual_y: float = app.sim.players[id].pos.y
			minimum_error = minf(minimum_error,target.y-actual_y)
			minimum_actor_error = minf(minimum_actor_error,actor.root.position.y-actual_y)
			max_step = maxf(max_step,absf(target.y-last_y))
			last_y = target.y
			app.presentation_sim.players = shown.players
			held_error = maxf(held_error,shown.ball.pos.distance_to(app.presentation_sim.hand_position(id)))
			immutable = immutable and before==var_to_bytes(app.state)
			walked_off = walked_off or not bool(app.sim.players[id].grounded)
			samples.append({"case":label,"time":app.ui_clock,"authority_y":actual_y,"packet_grounded":app.state.players[id].grounded,"packet_pos":app.state.players[id].pos,"target":target,"actor":actor.root.position})
		app.sim.step(1.0/60)
	check(walked_off and app.snapshot_count==10,"Real physics walks off with ten accepted compressed snapshots: "+label,app.snapshot_count)
	check(minimum_error>-.25 and minimum_actor_error>-.25 and max_step<.35,"Deck exit has no false multi-metre drop/rebound: "+label,{"minimum_target_error":minimum_error,"minimum_actor_error":minimum_actor_error,"max_target_y_step":max_step})
	check(held_error<.001 and immutable,"Held ball follows presentation without changing authority: "+label,held_error)
	world.free()
	app.free()

func guards() -> void:
	var x = lerpf(Sim.SIDE_BANK_START,Sim.HALF_WIDTH,.56)
	var app = app_for("bank",2,Vector3(x,Sim.floor_height(x,0),0),Vector3.LEFT)
	var maximum_clearance = 0.0
	var sequence = 0
	for frame in 30:
		if frame>0: app.sim.step(1.0/60)
		app.ui_clock = frame/60.0
		if frame==0 or (frame>=12 and frame%3==0):
			sequence += 1
			app.receive_state(packet(app,sequence))
		var shown: Dictionary = app.predict_render_state(app.ui_clock-app.snapshot_received_at)
		var p: Vector3 = shown.players[2].pos
		maximum_clearance = maxf(maximum_clearance,absf(p.y-Sim.floor_height(p.x,p.z)))
	check(maximum_clearance<.001 and app.snapshot_count==7,"Delayed continuous bank recovery still follows the real contact surface",maximum_clearance)
	app.free()
	app = app_for("jump",1,Vector3(0,Sim.KICKOFF_Y,-Sim.KICKOFF_Z),Vector3.FORWARD)
	app.receive_state(packet(app,1))
	app.predict_render_state(0)
	app.begin_jump_prediction(app.state.players[1])
	app.ui_clock = 1.0/60
	var shown: Dictionary = app.predict_render_state(1.0/60)
	check(shown.players[1].pos.y>Sim.KICKOFF_Y+.1 and app.visual_jump_started>=0,"Pending local jump remains above the deck",shown.players[1].pos.y)
	app.free()
	app = app_for("below_deck",1,Vector3(0,Sim.floor_height(0,-Sim.KICKOFF_Z),-Sim.KICKOFF_Z),Vector3.RIGHT)
	app.receive_state(packet(app,1))
	app.ui_clock = .05
	shown = app.predict_render_state(.05)
	check(absf(shown.players[1].pos.y-Sim.floor_height(shown.players[1].pos.x,shown.players[1].pos.z))<.001,"Travel below a one-way deck never snaps onto its top",shown.players[1].pos.y)
	app.free()

func run() -> void:
	for side in [-1,1]:
		for lateral in [false,true]:
			for id in [1,2]: deck_case(side,lateral,id)
	guards()
	var passed = checks.all(func(row): return row.passed)
	var report = {"passed":passed,"checks":checks,"samples":samples,"main_sha256":FileAccess.get_sha256("res://main.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"pack_sha256":FileAccess.get_sha256(pack_source) if not pack_source.is_empty() else "","scope":"Initial support fixtures; then real Sim physics,20Hz compressed receive_state,60Hz presentation and actual actor transforms. No live network, native pixels or physical input."}
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DECK_EDGE_RESULT "+JSON.stringify({"passed":passed,"checks":checks.size()}))
	quit(0 if passed else 1)
