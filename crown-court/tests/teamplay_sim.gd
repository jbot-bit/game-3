extends SceneTree
const Sim = preload("res://sim.gd")
var results = []

func check(ok: bool, label: String, detail = {}) -> void:
	results.append({"check":label,"passed":ok,"detail":detail})
	if not ok: printerr("FAIL: "+label+" "+str(detail))

func fresh(mode = "coop"):
	var g = Sim.new()
	g.reset(mode)
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players:
		g.players[id].pos = Vector3(-18+id*5,0,28)
		g.players[id].vel = Vector3.ZERO
		g.players[id].guard = 0
		g.players[id].hype = 0
	return g

func apply_bot(g, id: int) -> void:
	var order = g.bot_command(id)
	g.move_input(id,order.move,order.aim)
	if order.action != "": g.action(id,order.action,order.charge)

func settled_order(g, id: int) -> Dictionary:
	# These fixtures examine decision priority after a real possession delay;
	# gameplay_v11 separately rejects any immediate shot/pass after a catch.
	g.bot_command(id)
	g.clock += g.bot_tuning().hold+g.bot_tuning().reaction+g.bot_tuning().decision
	return g.bot_command(id)

func catch_credit(active: bool) -> void:
	var g = fresh()
	g.players[1].pos = Vector3.ZERO
	g.players[2].pos = Vector3(0,0,-8)
	g.players[1].aim = Vector3.FORWARD
	g.ball.owner = 1
	g.action(1,"pass")
	for frame in 120:
		if active: g.action(2,"catch")
		g.step(1.0/60)
		if g.ball.owner == 2: break
	var label = "active" if active else "automatic"
	check(g.ball.owner==2,label+" receive catches a real moving pass")
	check(g.players[1].hype==Sim.HYPE_PASS,label+" receive credits passer once",{"hype":g.players[1].hype})
	check(g.players[2].hype==Sim.HYPE_CATCH,label+" receive credits catcher once",{"hype":g.players[2].hype})
	for i in 5: g.action(2,"catch")
	check(g.players[1].hype==Sim.HYPE_PASS and g.players[2].hype==Sim.HYPE_CATCH and g.grabs==1,label+" repeated catch cannot duplicate rewards")

func _initialize() -> void:
	catch_credit(true)
	catch_credit(false)
	var g = fresh()
	g.players[1].pos = Vector3.ZERO
	g.players[2].pos = Vector3(0,0,8)
	g.players[3].pos = Vector3(0,0,-Sim.PASS_RANGE-1)
	g.players[1].aim = Vector3.FORWARD
	g.ball.owner = 1
	g.action(1,"pass")
	check(g.ball.owner==1 and g.throws==0,"Looking between a rear teammate and an unreachable teammate keeps possession")
	g.players[2].pos = Vector3(12,0,-2)
	check(g.pass_target(1)==0,"A teammate far outside the forward cone is not an accidental target")
	g.players[2].pos = Vector3(4,0,-8)
	check(g.pass_target(1)==2,"A visible forward teammate remains selectable")
	g.players[2].stun = .5
	check(g.pass_target(1)==0,"A stunned receiver cannot be selected")
	g = fresh("versus")
	g.ball.owner = 1
	g.action(1,"pass")
	check(g.ball.owner==1 and g.pass_target(1)==0,"FFA still has no teammate pass")
	g = fresh()
	g.players[1].hype = 20
	g.players[4].pos = Vector3.ZERO
	g.ball = {"pos":Vector3(0,1.1,0),"vel":Vector3.ZERO,"owner":0,"last_touch":1,"pass_target":2,"lock":0.0}
	g.action(4,"catch")
	check(g.ball.owner==4 and g.players[1].hype==20 and g.players[4].hype==Sim.HYPE_CATCH,"An opponent intercept does not credit the passer")
	g = fresh()
	g.players[1].pos = Vector3.ZERO
	g.players[2].pos = Vector3(0,0,-8)
	g.players[3].stun = 3
	g.players[1].aim = Vector3.FORWARD
	g.ball.owner = 1
	g.action(1,"pass")
	for frame in 120:
		g.step(1.0/60)
		if g.ball.owner==2: break
	g.players[1].request_time = 2
	check(g.ball.owner==2 and g.bot_command(2).action!="pass","A requested return pass waits after an actual receive")
	g.players[2].aim = Vector3.BACK
	g.action(2,"pass")
	check(g.ball.owner==0 and g.ball.pass_target==1,"Bot cooldown leaves the explicit human return pass available")
	g = fresh()
	g.ball.pos = Vector3(0,1.1,0)
	g.players[1].pos = Vector3(0,0,2)
	g.players[2].pos = Vector3(-5,0,5)
	g.players[3].pos = Vector3(5,0,5)
	var order = g.bot_command(1)
	check(order.move.dot(Vector3.FORWARD)>.99,"Nearest teammate commits directly to the loose ball")
	for id in [2,3]:
		order = g.bot_command(id)
		var ball_direction = Vector3(-g.players[id].pos.x,0,-g.players[id].pos.z).normalized()
		check(order.move.dot(ball_direction)<.9,"Loose-ball support %d spaces away from the chaser"%id,{"move":order.move})
	g = fresh()
	g.players[1].pos = Vector3(0,0,20)
	g.players[2].pos = Vector3(0,0,10)
	g.players[3].pos = Vector3(7,0,15)
	g.ball.owner = 1
	for frame in 150:
		apply_bot(g,2)
		g.step(1.0/60)
	check(g.flat_distance(g.players[1].pos,g.players[2].pos)<18 and absf(g.players[2].pos.x)>3,"Support stays within a useful wide outlet distance instead of camping at the far hoop",{"position":g.players[2].pos})
	g = fresh()
	g.players[1].pos = Vector3(0,0,5)
	g.players[2].pos = Vector3(-7,0,-3)
	g.players[3].pos = Vector3(8,0,4)
	g.players[4].pos = Vector3(1,0,3)
	g.ball.owner = 1
	order = settled_order(g,1)
	check(order.action=="pass","A pressured carrier initiates a safe pass without a human request",order)
	g.move_input(1,order.move,order.aim)
	if order.action!="": g.action(1,order.action,order.charge)
	check(g.ball.owner==0 and g.ball.pass_target==2,"Pressure pass actually releases toward the advancing open teammate")
	for frame in 90:
		g.step(1.0/60)
		if g.ball.owner==2: break
	check(g.ball.owner==2,"The autonomous outlet decision completes a physical receive")
	if g.ball.owner==2:
		g.players[1].request_time = 2
		g.players[4].pos = g.players[2].pos+Vector3(0,0,-2)
		order = g.bot_command(2)
		check(order.action!="pass","A newly received pass cannot instantly ping-pong back",order)
		g.players[1].aim = Vector3.FORWARD
		g.players[2].aim = (g.players[1].pos-g.players[2].pos).normalized()
		g.action(2,"pass")
		check(g.ball.owner==0,"Bot receive cooldown never blocks an explicit human pass")
	g = fresh()
	g.players[1].pos = Sim.NORTH+Vector3(0,2-Sim.HOOP_Y,3)
	g.players[1].grounded = false
	g.players[1].hype = 100
	g.players[2].pos = Vector3(5,0,-20)
	g.players[2].request_time = 2
	g.ball.owner = 1
	g.clock = 4
	check(settled_order(g,1).action=="dunk","A valid dunk outranks a request and full Hype")
	g = fresh()
	g.players[1].pos = Vector3(0,0,5)
	g.players[2].pos = Vector3(-7,0,-3)
	g.players[2].request_time = 2
	g.players[3].stun = 1
	g.players[1].hype = 100
	g.ball.owner = 1
	g.clock = 4
	check(settled_order(g,1).action=="pass","An intentional safe requested pass outranks Hype")
	g.players[1].hype = 0
	g.players[4].pos = g.players[2].pos+Vector3(0,0,1)
	check(g.bot_command(1).action!="pass","A tightly marked requested receiver is not an automatic turnover")
	g = fresh()
	g.players[1].pos = Vector3(0,0,10)
	g.players[2].pos = Vector3(0,0,-10)
	g.players[3].pos = Vector3(0,0,2)
	g.players[4].pos = Vector3(3,0,2)
	g.ball.owner = 1
	order = g.bot_command(1)
	g.move_input(1,order.move,order.aim)
	if order.action!="": g.action(1,order.action,order.charge)
	check(order.action!="pass" or g.ball.pass_target==2,"Bot safety applies to the actual aim-selected receiver, including collinear teammates",{"action":order.action,"receiver":g.ball.pass_target})
	# Both attack directions must make the same pressure decision; a particular
	# natural match need not give the losing side enough possession to pass.
	for side in [0,1]:
		g = fresh()
		var carrier = 1 if side==0 else 4
		var receiver = carrier+1
		var defender = 4 if side==0 else 1
		var direction = -1.0 if side==0 else 1.0
		g.players[carrier].pos = Vector3(0,0,-5*direction)
		g.players[receiver].pos = Vector3(-7,0,3*direction)
		g.players[carrier+2].stun = 3
		g.players[defender].pos = Vector3(1,0,-3*direction)
		# Keep the remaining opponents away from the mirrored outlet.
		for id in g.players:
			if g.team(id)!=side and id!=defender: g.players[id].pos = Vector3(16,0,0)
		g.ball.owner = carrier
		order = settled_order(g,carrier)
		g.move_input(carrier,order.move,order.aim)
		if order.action!="": g.action(carrier,order.action,order.charge)
		check(order.action=="pass" and g.ball.pass_target==receiver,"Side%d makes the same safe pressure outlet"%side)
		for frame in 90:
			g.step(1.0/60)
			if g.ball.owner==receiver: break
		check(g.ball.owner==receiver,"Side%d pressure outlet physically reaches its teammate"%side)
	var passed = results.all(func(row): return row.passed)
	print("TEAMPLAY_RESULT "+JSON.stringify({"passed":passed,"checks":results}))
	quit(0 if passed else 1)
