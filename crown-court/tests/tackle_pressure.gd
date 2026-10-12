extends SceneTree

const Sim = preload("res://sim.gd")
var checks: Array = []
var evidence = "res://tests/tackle-pressure"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"check":label,"passed":ok,"details":details})
	print("PASS " if ok else "FAIL ",label," ",details)

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players:
		place(g,id,Vector3(-28,0,-45+id*2))
		g.players[id].guard = 0
		g.players[id].hype = 0
	return g

func place(g, id: int, pos: Vector3) -> void:
	g.players[id].pos = pos
	g.players[id].pos.y += Sim.floor_height(pos.x,pos.z)
	g.players[id].vel = Vector3.ZERO
	g.players[id].grounded = is_zero_approx(pos.y)
	g.players[id].move = Vector3.ZERO

func settle(g, id: int) -> Dictionary:
	g.bot_command(id)
	g.clock += g.bot_tuning().reaction+g.bot_tuning().decision+.01
	return g.bot_command(id)

func apply(g, id: int, order: Dictionary) -> void:
	g.move_input(id,order.move,order.aim)
	if order.action != "": g.action(id,order.action,order.charge)

func pursuit(side: int) -> void:
	var g = fresh()
	var defender = 1 if side == 0 else 4
	var carrier = 4 if side == 0 else 1
	var direction = -1.0 if side == 0 else 1.0
	for id in g.players: place(g,id,Vector3(-28,0,-45*direction))
	place(g,defender,Vector3(21,0,24*direction))
	place(g,carrier,Vector3(0,0,49*direction))
	g.players[carrier].aim = Vector3(0,0,-direction)
	g.secure_ball(carrier)
	var order = settle(g,defender)
	var toward = (Vector3(g.players[carrier].pos.x,0,g.players[carrier].pos.z)-Vector3(g.players[defender].pos.x,0,g.players[defender].pos.z)).normalized()
	check(g.ball_chaser(defender) == defender,"side%d fixture identifies pressure defender" % side)
	check(order.move.dot(toward) > .99,"side%d pressure defender pursues carrier instead of nearby launch pad" % side,{"alignment":order.move.dot(toward)})

func marking_tackle(side: int) -> void:
	var g = fresh()
	var defender = 1 if side == 0 else 4
	var teammate = defender+1
	var carrier = 4 if side == 0 else 1
	var away = -1.0 if side == 0 else 1.0
	place(g,carrier,Vector3.ZERO)
	place(g,defender,Vector3(0,0,-2.2*away))
	place(g,teammate,Vector3(1.4,0,0))
	g.players[carrier].aim = Vector3.RIGHT
	g.secure_ball(carrier)
	var order = settle(g,defender)
	var toward = (g.players[carrier].pos-g.players[defender].pos).normalized()
	check(g.ball_chaser(defender) == teammate,"side%d fixture uses a nearby marking defender" % side)
	check(order.action == "tackle" and order.move.dot(toward) > .99,"side%d marking tackle movement points toward carrier" % side,{"action":order.action,"alignment":order.move.dot(toward)})
	apply(g,defender,order)
	for frame in 24: g.step(1.0/60)
	check(g.ball.owner == 0 and g.players[carrier].stun > 0 and g.tackles == 1,"side%d bot approach produces real contact and a loose ball" % side,{"owner":g.ball.owner,"tackles":g.tackles})
	check(g.players[teammate].stun == 0,"side%d contest does not knock down teammate" % side)

func aerial_contest() -> void:
	var g = fresh()
	place(g,1,Vector3(0,2.4,0))
	place(g,4,Vector3(0,0,-1.6))
	g.players[1].aim = Vector3.RIGHT
	g.secure_ball(1)
	var order = settle(g,4)
	check(order.action == "jump","reachable airborne carrier gets a jump contest, not a ground dive",{"action":order.action})
	apply(g,4,order)
	check(g.players[4].cooldown == 0 and g.players[4].vel.y > 0,"aerial approach preserves tackle cooldown while taking off")
	var hit_frame = -1
	for frame in 90:
		apply(g,4,g.bot_command(4))
		g.step(1.0/60)
		if g.tackles > 0:
			hit_frame = frame
			break
	check(hit_frame >= 0 and g.ball.owner == 0,"jump contest reaches a real collision and drops possession",{"hit_frame":hit_frame,"owner":g.ball.owner})
	check(g.players[1].guard > 0,"aerial contest retains victim recovery protection")
	g = fresh()
	place(g,1,Vector3(0,12,0))
	place(g,4,Vector3(0,0,-1.6))
	g.players[1].aim = Vector3.RIGHT
	g.secure_ball(1)
	order = settle(g,4)
	check(order.action not in ["jump","tackle"],"unreachable airborne carrier does not waste a ground tackle",{"action":order.action})

func approaching_carrier(side: int) -> void:
	var g = fresh()
	var defender = 1 if side == 0 else 4
	var carrier = 4 if side == 0 else 1
	var direction = -1.0 if side == 0 else 1.0
	place(g,defender,Vector3.ZERO)
	place(g,carrier,Vector3(0,0,2*direction))
	g.players[carrier].vel = Vector3(0,0,-18*direction)
	g.players[carrier].aim = Vector3.RIGHT
	g.secure_ball(carrier)
	var order = settle(g,defender)
	var toward = Vector3(0,0,direction)
	check(order.action == "tackle" and order.move.dot(toward) > .99 and order.aim.dot(toward) > .99,"side%d fast approaching carrier cannot reverse a close tackle" % side,{"action":order.action,"move_alignment":order.move.dot(toward),"aim_alignment":order.aim.dot(toward)})
	apply(g,defender,order)
	for frame in 12: g.step(1.0/60)
	check(g.tackles == 1 and g.ball.owner == 0 and g.players[carrier].stun > 0,"side%d fast approaching carrier receives real forward contact" % side,{"tackles":g.tackles,"owner":g.ball.owner})

func close_cadence() -> void:
	for difficulty in ["easy","normal","hard"]:
		var g = fresh()
		g.set_difficulty(difficulty)
		place(g,4,Vector3.ZERO)
		place(g,1,Vector3(8,0,0))
		g.players[1].aim = Vector3.RIGHT
		g.secure_ball(1)
		settle(g,4)
		place(g,1,Vector3(2,0,0))
		g.ball.pos = g.hand_position(1)
		# Enter close range between ordinary decisions, after reaction has elapsed.
		g.clock += .14 if difficulty == "easy" else (.11 if difficulty == "normal" else .08)
		var order = g.bot_command(4)
		check(order.action == "tackle",difficulty+" samples a new nearby contest before the ordinary decision tick",{"action":order.action})
		apply(g,4,order)
		g.clock += .01
		check(g.bot_command(4).action == "","close contest does not spam actions each frame on "+difficulty)

func preserved_difficulty() -> void:
	var expected = {"easy":[.32,.5,1.4,.9],"normal":[.22,.32,1.0,.7],"hard":[.12,.18,.65,.5]}
	for difficulty in expected:
		var g = fresh()
		g.set_difficulty(difficulty)
		var tuning = g.bot_tuning()
		check([tuning.decision,tuning.reaction,tuning.hold,tuning.windup] == expected[difficulty],difficulty+" offensive decision, reaction, hold and windup remain unchanged")
		place(g,1,Vector3.ZERO)
		place(g,4,Vector3(0,0,-1.6))
		g.players[1].aim = Vector3.RIGHT
		g.secure_ball(1)
		check(g.bot_command(4).action == "",difficulty+" close defense retains initial reaction delay")
		g.clock = tuning.reaction-.01
		check(g.bot_command(4).action == "",difficulty+" cannot attack before its reaction deadline")
		g.players[1].guard = 1.4
		g.clock += 1
		check(g.bot_command(4).action != "tackle",difficulty+" defender respects recovery guard")

func run() -> void:
	for side in [0,1]:
		pursuit(side)
		marking_tackle(side)
		approaching_carrier(side)
	aerial_contest()
	close_cadence()
	preserved_difficulty()
	var report = {"passed":checks.all(func(item): return item.passed),"checks":checks,"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"fixture":true,"scope":"actual bot commands, movement, tackle/jump actions and collision stepping; not native or natural-match balance evidence"}
	DirAccess.make_dir_recursive_absolute(evidence)
	var file = FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("TACKLE_PRESSURE_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
