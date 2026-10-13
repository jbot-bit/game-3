extends SceneTree
# Sweet-spot shot assist, contact pickup, per-player stats and the match intro.
# Deterministic simulation checks; no claim about how the assist feels to play.
const Sim=preload("res://sim.gd")
var checks=[]
func check(ok:bool,label:String,details={}):
	checks.append({"passed":ok,"check":label,"detail":details})
	if not ok: printerr("FAIL ",label," ",details)
func fresh(setup:Dictionary={}):
	var g=Sim.new()
	g.reset("coop",setup)
	g.reset_time=0
	g.ball.lock=0
	for id in g.players:
		g.players[id].pos=Vector3(26,0,id*4-14)
		g.players[id].guard=0
	return g
func ticks(g,count:int):
	for frame in count: g.step(1.0/60)
func human_aim(g,id:int,yaw_error:float):
	# A casual player: facing the hoop within a few degrees, default 48 degree loft.
	var to_hoop:Vector3=g.hoop(id)-g.players[id].pos
	to_hoop.y=0
	var forward=to_hoop.normalized().rotated(Vector3.UP,deg_to_rad(yaw_error))
	g.players[id].aim=forward
	g.set_shot_aim(id,forward*cos(deg_to_rad(48))+Vector3.UP*sin(deg_to_rad(48)))
func _initialize():
	# Intro only when requested; fixtures keep the three second countdown.
	var plain=Sim.new()
	plain.reset("coop")
	check(plain.reset_time==3.0 and plain.intro_time==0.0,"Plain reset keeps the three second countdown")
	var intro=Sim.new()
	intro.reset("coop",{"intro":true})
	check(intro.reset_time==Sim.INTRO_TIME and intro.ball.lock==Sim.INTRO_TIME,"Match intro extends the opening reset",{"reset":intro.reset_time})
	check(intro.players[1].stats.points==0 and intro.players[1].stats.has("steals"),"Players start with empty stat lines")
	# Assisted shots: facing the hoop, slightly off in yaw, released on the mark.
	for distance in [6.0,10.0,16.0,24.0,32.0]:
		var g=fresh()
		for other in g.players.keys():
			if other!=1: g.players.erase(other)
		g.players[1].pos=g.hoop(1)+Vector3.BACK*distance-Vector3.UP*Sim.HOOP_Y
		g.players[1].pos.y=g.floor_height(g.players[1].pos.x,g.players[1].pos.z)
		g.ball.owner=1
		human_aim(g,1,7.0)
		var mark=g.ideal_charge(1)
		check(mark>=0 and mark<=1,"Sweet spot exists facing the hoop at %.0fm"%distance,{"mark":mark})
		var raw=g.raw_throw_velocity(1,mark)
		var helped=g.throw_velocity(1,mark)
		check(helped.distance_to(raw)>.5,"Release on the mark bends the launch toward the rim at %.0fm"%distance)
		g.action(1,"throw",mark)
		ticks(g,300)
		check(g.baskets==1,"Assisted shot on the mark scores at %.0fm"%distance,{"ball":g.ball.pos})
		check(g.players[1].stats.points==1,"Scorer earns a point on the stat line")
	var g=fresh()
	g.players[1].pos=Vector3(0,0,-30)
	g.ball.owner=1
	human_aim(g,1,7.0)
	var mark=g.ideal_charge(1)
	check(g.throw_velocity(1,1.3).distance_to(g.raw_throw_velocity(1,1.3))<.00001,"Overcharge is the red zone: literal physics, no help")
	var early=clampf(mark+.5,0,1)
	check(g.throw_velocity(1,early).distance_to(g.raw_throw_velocity(1,early))<.00001,"Releasing far from the mark is unassisted",{"mark":mark,"charge":early})
	human_aim(g,1,60.0)
	check(g.ideal_charge(1)<0 and g.throw_velocity(1,.6).distance_to(g.raw_throw_velocity(1,.6))<.00001,"Facing away from the hoop gets no assist or mark")
	g.shot_assist=false
	human_aim(g,1,7.0)
	check(g.ideal_charge(1)<0 and g.throw_velocity(1,mark).distance_to(g.raw_throw_velocity(1,mark))<.00001,"Assist off restores literal aim")
	g.shot_assist=true
	g.players[1].bot_aimed=true
	check(g.throw_velocity(1,mark).distance_to(g.raw_throw_velocity(1,mark))<.00001,"Bot releases keep their difficulty error")
	# Contact pickup: walking into a loose ball gathers it; reach needs a press.
	g=fresh()
	g.ball.pos=g.players[1].pos+Vector3(0,1.1,0)+Vector3.FORWARD*1.2
	g.ball.vel=Vector3.ZERO
	ticks(g,1)
	check(g.ball.owner==1,"Loose ball inside the gather radius is picked up without a press",{"owner":g.ball.owner})
	g=fresh()
	g.ball.pos=g.players[1].pos+Vector3(0,1.1,0)+Vector3.FORWARD*2.1
	g.ball.vel=Vector3.ZERO
	ticks(g,1)
	check(g.ball.owner==0,"A ball just outside the gather radius stays loose")
	g.action(1,"catch")
	ticks(g,1)
	check(g.ball.owner==1,"A pressed catch still reaches the farther ball")
	g=fresh()
	g.players[1].pos=Vector3(0,0,10)
	g.players[4].pos=Vector3(0,0,10.9)
	g.ball.pos=Vector3(0,1.1,10.4)
	g.ball.vel=Vector3.ZERO
	ticks(g,1)
	check(g.ball.owner==1,"Nearest body wins a contested loose ball deterministically",{"owner":g.ball.owner})
	g=fresh()
	g.reset_time=2.0
	g.ball.pos=g.players[1].pos+Vector3(0,1.1,0)
	ticks(g,1)
	check(g.ball.owner==0,"No pickup during the kickoff reset")
	# Steals and tackles on the stat line.
	g=fresh()
	g.players[1].pos=Vector3(0,0,0)
	g.players[4].pos=Vector3(0,0,1.0)
	g.secure_ball(4)
	g.hit(1,4)
	check(g.players[1].stats.tackles==1 and g.players[1].stats.steals==1,"Dislodging tackle records a tackle and a steal",{"stats":g.players[1].stats})
	g=fresh()
	g.players[1].pos=Vector3(0,0,0)
	g.players[4].pos=Vector3(0,0,20)
	g.secure_ball(4)
	g.players[4].aim=Vector3.BACK
	g.action(4,"throw",.9)
	g.players[1].pos=g.ball.pos+Vector3.BACK*1.0-Vector3.UP*1.1
	g.ball.lock=0
	ticks(g,1)
	check(g.ball.owner==1 and g.players[1].stats.steals==1,"Intercepting a live opponent release counts as a steal",{"owner":g.ball.owner,"stats":g.players[1].stats})
	# Announcer flavour and final celebration.
	g=fresh()
	g.players[1].pos=Vector3(0,0,-40)
	g.ball.owner=1
	human_aim(g,1,0.0)
	g.action(1,"throw",g.ideal_charge(1))
	ticks(g,300)
	check(g.baskets==1 and not g.last_score_text.is_empty() and g.last_score_text==g.snapshot().score_text,"Score line is authored once and shared in the snapshot",{"text":g.last_score_text})
	g.scores[0]=3
	g.scores[1]=0
	g.reset_time=0
	g.celebration_time=0
	g.ball.lock=0
	g.players[1].pos=Vector3(0,0,-40)
	g.ball.owner=1
	human_aim(g,1,0.0)
	g.action(1,"throw",g.ideal_charge(1))
	for frame in 300:
		g.step(1.0/60)
		if g.baskets==2: break
	check(g.winner==0 and g.celebration_time>0 and g.celebration_time<=Sim.FINAL_CELEBRATION,"Winning basket opens the extended final celebration",{"celebration":g.celebration_time,"baskets":g.baskets})
	ticks(g,int(Sim.FINAL_CELEBRATION*60)+5)
	check(g.winner==0 and g.celebration_time==0 and g.scores[0]==4,"Final celebration ends without respawning or changing the result")
	var failed=checks.filter(func(r):return not r.passed).size()
	print("SHOT_ASSIST_RESULT ",JSON.stringify({"checks":checks,"failures":failed}))
	quit(0 if failed==0 else 1)
