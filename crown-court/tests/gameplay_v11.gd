extends SceneTree
const Sim=preload("res://sim.gd")
const Shot=preload("res://tests/shot_fixture.gd")
var checks=[]
func check(ok:bool,label:String,details={}):
	checks.append({"passed":ok,"check":label,"detail":details})
	if not ok: printerr("FAIL ",label," ",details)
func fresh():
	var g=Sim.new()
	g.reset("coop")
	# These checks describe literal physical aim; the sweet-spot assist is covered by tests/shot_assist.gd.
	g.shot_assist=false
	g.reset_time=0
	g.ball.lock=0
	for id in g.players:
		g.players[id].pos=Vector3(24,0,id*3)
		g.players[id].guard=0
	return g
func _initialize():
	var g=fresh()
	g.players[1].pos=Vector3(0,0,-34)
	g.players[1].aim=Vector3.FORWARD
	g.ball.owner=1
	for yaw in [-25.0,-6.0,0.0,6.0,25.0,90.0]:
		var direction=(Vector3.FORWARD*cos(deg_to_rad(55))+Vector3.UP*sin(deg_to_rad(55))).rotated(Vector3.UP,deg_to_rad(yaw))
		g.set_shot_aim(1,direction)
		for charge in [0.0,.4,1.0,1.5]:
			var launch=g.throw_velocity(1,charge)
			check(launch.normalized().distance_to(direction)<.00001,"Chosen aim preserved yaw%.1f charge%.2f"%[yaw,charge])
	var close_speed=g.throw_velocity(1,.5)
	g.players[1].pos=Vector3(20,0,30)
	check(g.throw_velocity(1,.5).distance_to(close_speed)<.00001,"Moving away from hoop cannot secretly change launch")
	for id in [1,4]:
		for distance in [5.0,9.0,14.0,25.0,58.0,93.0]:
			g=fresh()
			for other in g.players.keys():
				if other!=id:g.players.erase(other)
			var back=Vector3.BACK if id==1 else Vector3.FORWARD
			g.players[id].pos=g.hoop(id)+back*distance-Vector3.UP*Sim.HOOP_Y
			g.players[id].pos.y=g.floor_height(g.players[id].pos.x,g.players[id].pos.z)
			g.players[id].aim=-back
			g.ball.owner=id
			var charge=Shot.aimed_charge(g,id)
			g.action(id,"throw",charge)
			for frame in 480:
				g.step(1.0/60)
				if g.baskets>0:break
			check(g.baskets==1,"Deliberately aimed physical basket side%d range%.1f"%[id,distance],{"charge":charge,"ball":g.ball.pos})
	var timings={}
	for difficulty in ["easy","normal","hard"]:
		g=fresh()
		g.set_difficulty(difficulty)
		g.players[1].pos=Vector3(0,0,-36)
		g.players[1].aim=Vector3.FORWARD
		g.secure_ball(1)
		var first_release=-1.0
		var visible_windup=false
		for frame in 300:
			var order=g.bot_command(1)
			visible_windup=visible_windup or g.players[1].charge>0
			if order.action in ["pass","throw","dunk"]:
				first_release=g.clock
				check(g.clock>=g.bot_tuning().hold,"No instant release on "+difficulty)
				check(order.action=="throw","Open midrange opportunity becomes charged shot on "+difficulty)
				g.action(1,order.action,order.charge)
				check(g.ball.owner==0,"Bot physically releases on "+difficulty)
				break
			# Hold position to measure decisions independently of route length.
			g.step(1.0/60)
		check(first_release>0 and visible_windup,"Visible windup completes on "+difficulty,{"seconds":first_release})
		timings[difficulty]=first_release
	check(timings.easy>timings.normal and timings.normal>timings.hard,"Difficulty changes real attack timing",timings)
	g=fresh()
	g.players[1].pos=Vector3(0,0,-36)
	g.secure_ball(1)
	for frame in 110:
		g.bot_command(1)
		g.step(1.0/60)
	check(g.players[1].charge>0,"Bot is winding up before interruption")
	g.hit(4,1)
	var interrupted=g.bot_command(1)
	check(interrupted.action=="" and g.players[1].charge==0 and g.ball.owner==0,"Tackle cancels windup and drops possession")
	g=fresh()
	g.players[1].pos=Vector3.ZERO
	g.players[4].pos=Vector3(0,0,-1)
	g.players[1].facing=Vector3.FORWARD
	g.secure_ball(4)
	g.hit(1,4)
	var start:Vector3=g.players[4].pos
	var peak=0.0
	for frame in 30:
		g.step(1.0/60)
		peak=maxf(peak,g.players[4].pos.y)
	check(start.distance_to(g.players[4].pos)>4 and peak>.55,"Tackle has readable airborne knockback",{"distance":start.distance_to(g.players[4].pos),"peak":peak})
	check(g.ball.owner==0 and g.players[4].guard>0,"Knockback drops ball and protects against chain stun")
	g=fresh()
	g.players[2].pos=Vector3(0,0,-36)
	g.secure_ball(2)
	for frame in 110:
		g.bot_command(2)
		g.step(1.0/60)
	check(g.players[2].charge>0,"Empty human seat bot has an active shot windup")
	g.add_human(2,0)
	check(not g.bot_brains.has(2) and g.players[2].charge==0,"Live human takeover clears bot decision and windup")
	g.clock+=8
	g.players[2].pos=Vector3(10,0,-36)
	g.reset_bot(2)
	var resumed=g.bot_command(2)
	check(resumed.action=="" and g.bot_brains[2].windup_until<0,"Departing human leaves a fresh reacting bot, never an expired shot")
	var failed=checks.filter(func(r):return not r.passed).size()
	print("GAMEPLAY_V11_RESULT ",JSON.stringify({"checks":checks,"failures":failed,"scope":"Actual deterministic input, simulation and scoring; no human enjoyment claim"}))
	quit(0 if failed==0 else 1)
