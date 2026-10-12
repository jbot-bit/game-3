extends SceneTree
const Sim = preload("res://sim.gd")
var checks = 0
var failures = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players.keys():
		if id != 1: g.players.erase(id)
	g.players[1].pos = Vector3.ZERO
	g.players[1].guard = 0
	return g

func ticks(g, count: int) -> void:
	for i in count: g.step(1.0/60)

func _initialize() -> void:
	var g = fresh()
	g.players[1].pos = Sim.PADS[0]
	g.players[1].pos.y = Sim.floor_height(g.players[1].pos.x,g.players[1].pos.z)
	var start = g.players[1].pos
	ticks(g,1)
	check(not g.players[1].grounded,"Pad launches without a jump button")
	ticks(g,8)
	var up_before = g.players[1].vel.y
	g.action(1,"jump")
	check(g.players[1].vel.y >= up_before,"Extra jump never cuts upward booster momentum")
	check(g.players[1].jump_count == 2,"Booster leaves exactly one extra jump")
	var jump_speed = g.players[1].vel.y
	g.action(1,"jump")
	check(g.players[1].vel.y == jump_speed,"Third jump cannot add altitude")
	ticks(g,60)
	check(g.flat_distance(start,g.players[1].pos)>12,"Traveling launch clears twelve metres without holding movement")
	check(g.players[1].pos.y>10,"Launch has a sustained high aerial route")
	g = fresh()
	g.move_input(1,Vector3.FORWARD,Vector3.FORWARD)
	ticks(g,30)
	g.action(1,"jump")
	g.move_input(1,Vector3.ZERO,Vector3.FORWARD)
	start = g.players[1].pos
	ticks(g,24)
	check(g.flat_distance(start,g.players[1].pos)>3,"Letting go in the air keeps useful forward momentum")
	g = fresh()
	g.players[1].pos = g.hoop(1)+Vector3(0,-Sim.HOOP_Y,3)
	g.ball.owner = 1
	g.action(1,"jump")
	ticks(g,1)
	g.action(1,"dunk")
	ticks(g,10)
	check(g.dunks==1,"Quick jump then dunk queues until the feet clear the ground")
	ticks(g,100)
	check(g.baskets==1,"Buffered dunk completes a physical basket")
	g = fresh()
	g.players[1].pos = Vector3(0,.05,0)
	g.players[1].grounded = false
	g.players[1].jump_count = 2
	g.players[1].vel.y = -3
	g.action(1,"jump")
	ticks(g,5)
	check(g.players[1].pos.y>.5 and not g.players[1].grounded,"Jump just before landing buffers into a new takeoff")
	g = fresh()
	g.ball.pos=Vector3(0,1,-3.4)
	g.ball.vel=Vector3(0,0,75)
	g.action(1,"catch")
	ticks(g,3)
	check(g.ball.owner==1,"Catch window captures a fast incoming ball before body deflection")
	g = fresh()
	g.players[1].pos = g.hoop(1)+Vector3(1,-3,3)
	g.players[1].grounded = false
	g.players[1].vel = Vector3(2,8,-7)
	g.ball.owner = 1
	g.action(1,"dunk")
	var biggest_step = 0.0
	var hand_snap = 0.0
	var last_pos: Vector3 = g.players[1].pos
	var last_ball: Vector3 = g.hand_position(1)
	for frame in 100:
		var held: bool = g.ball.owner == 1
		# Kickoff deliberately respawns after the scored follow-through.
		if g.celebration_time > 0 and g.celebration_time <= 1.0/60: break
		g.step(1.0/60)
		biggest_step=maxf(biggest_step,last_pos.distance_to(g.players[1].pos))
		if held and g.ball.owner == 0: hand_snap = last_ball.distance_to(g.ball.pos)
		last_pos = g.players[1].pos
		last_ball = g.ball.pos
	check(biggest_step<.6,"Dunk approach and scored follow-through have no player teleport")
	check(hand_snap<.3,"Dunk release continues from the carried ball without a rim snap")
	check(g.baskets==1,"Smooth dunk still scores exactly once")
	ticks(g,180)
	check(g.reset_time<=0 and g.ball.pos.distance_to(Vector3(0,Sim.BALL_RADIUS,0))<1,"Post-score celebration returns to a playable kickoff")
	var giant_makes = 0
	var giant_floor_gap = 0.0
	for angle in [0.0,PI*.5,PI,PI*1.5]:
		g=fresh()
		g.players[1].pos=g.hoop(1)+Vector3(cos(angle)*3,5,sin(angle)*3)
		g.players[1].grounded=false
		g.players[1].giant=.2
		g.ball.owner=1
		g.action(1,"dunk")
		for frame in 150:
			g.step(1.0/60)
			var position: Vector3 = g.players[1].pos
			giant_floor_gap=minf(giant_floor_gap,position.y-Sim.floor_height(position.x,position.z))
		if g.baskets==1: giant_makes+=1
	check(giant_makes==4,"Giant expiring mid-dunk does not shrink the release below the hoop")
	check(giant_floor_gap>=-.03,"Giant dunk follows the raised bank without sinking or snapping out")
	g = Sim.new()
	g.reset("coop")
	var bot_boosts = 0
	for frame in 60*15:
		for id in g.players:
			var order = g.bot_command(id)
			g.move_input(id,order.move,order.aim)
			if order.action != "": g.action(id,order.action,order.charge)
		g.step(1.0/60)
		for id in g.players:
			if g.players[id].get("boost_time",0)>1.1: bot_boosts += 1
	check(bot_boosts>0,"Bots use traveling launch routes during actual kickoff play")
	print("FEEL_SIM_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
