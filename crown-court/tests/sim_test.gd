extends SceneTree
var checks = 0
var failures = 0
var Sim = preload("res://sim.gd")

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)

func ticks(g, count: int) -> void:
	for i in count: g.step(1.0/60)

func isolated(mode: String = "coop"):
	var g = Sim.new()
	g.reset(mode)
	g.reset_time = 0.0
	g.ball.lock = 0.0
	for id in g.players:
		g.players[id].pos = Vector3(10,2,10+id)
		g.players[id].guard = 0.0
	return g

func goal(g, id: int = 1) -> void:
	g.ball.owner = 0
	g.ball.last_touch = id
	g.ball.pos = g.hoop(id) + Vector3.UP*.2
	g.ball.vel = Vector3.DOWN*8
	g.reset_time = 0.0
	ticks(g,3)

func _initialize() -> void:
	var g = isolated()
	check(g.players.size()==6 and g.time_left==300, "Co-op is three crew versus three bots for five minutes")
	g.players[1].pos = Vector3.ZERO
	g.move_input(1,Vector3(0,0,-20),Vector3.FORWARD)
	ticks(g,60)
	var normalized = isolated()
	normalized.players[1].pos = Vector3.ZERO
	normalized.move_input(1,Vector3.FORWARD,Vector3.FORWARD)
	ticks(normalized,60)
	check(g.players[1].pos.distance_to(normalized.players[1].pos)<.001 and g.players[1].vel.length()<=9.51 and g.players[1].pos.z < -6, "Oversized input matches unit input without a speed exploit")
	g.move_input(1,Vector3.ZERO,Vector3.FORWARD)
	ticks(g,30)
	check(g.players[1].vel.length()<.1,"Releasing movement brakes")
	g.action(1,"jump")
	ticks(g,30)
	check(g.players[1].pos.y>3.4,"First jump has meaningful height and hangtime")
	g.action(1,"jump")
	ticks(g,20)
	check(g.players[1].jump_count==2 and g.players[1].pos.y>5.5,"Double jump extends the airborne route")
	g.action(1,"jump")
	check(g.players[1].jump_count==2,"No third jump")
	ticks(g,180)
	check(g.players[1].grounded,"Jump lands on court")
	g.players[1].pos=Vector3(8,Sim.floor_height(8,0),0)
	g.move_input(1,Vector3.RIGHT,Vector3.RIGHT)
	ticks(g,18)
	check(absf(g.players[1].pos.y-Sim.floor_height(g.players[1].pos.x,0))<.02,"Running follows bank geometry")
	g.players[1].pos=Sim.PADS[0]
	g.players[1].pos.y=Sim.floor_height(g.players[1].pos.x,g.players[1].pos.z)
	g.move_input(1,Vector3.ZERO,Vector3.FORWARD)
	g.players[1].vel=Vector3.ZERO
	ticks(g,20)
	check(g.players[1].pos.y>4,"Physical launch pads give big jumps")
	g=isolated("versus")
	g.players[1].pos=Vector3.ZERO
	g.ball.pos=Vector3(0,1.4,-1.5)
	g.action(1,"catch")
	check(g.ball.owner==1,"Contextual catch claims nearby loose ball")
	g.action(2,"grab")
	check(g.ball.owner==1,"Another player cannot remotely steal possession")
	g.action(1,"throw",.5)
	check(g.ball.owner==0 and g.ball.vel.length()>8,"Throw physically releases ball")
	var old_y=g.ball.vel.y
	ticks(g,1)
	check(g.ball.vel.y<old_y,"Flight obeys gravity")
	g.ball.pos=Vector3(0,.53,0)
	g.ball.vel=Vector3(0,-5,0)
	ticks(g,1)
	check(g.ball.vel.y>0 and g.ball.pos.y>=Sim.BALL_RADIUS,"Ball rebounds off floor")
	g=isolated()
	goal(g)
	check(g.scores[0]==1 and g.baskets==1,"Downward physical passage scores one point")
	var saved_clock=g.time_left
	ticks(g,30)
	check(g.scores[0]==1 and g.time_left==saved_clock,"Scoring cannot repeat; clock pauses for kickoff")
	g=isolated()
	g.ball.pos=Sim.NORTH-Vector3.UP*.2
	g.ball.vel=Vector3.UP*8
	g.ball.last_touch=1
	ticks(g,3)
	check(g.scores[0]==0,"Upward passage is not a goal")
	g=isolated()
	g.ball.pos=Sim.NORTH+Vector3(2.6,.2,0)
	g.ball.vel=Vector3.DOWN*8
	g.ball.last_touch=1
	ticks(g,3)
	check(g.scores[0]==0,"A miss stays a miss")
	g=isolated()
	g.players[1].pos=Sim.NORTH+Vector3(0,-Sim.HOOP_Y+1.3,3)
	g.players[1].grounded=false
	g.ball.owner=1
	g.action(1,"dunk")
	check(g.players[1].dunk>0,"Airborne close carrier starts a dunk")
	ticks(g,ceili(float(g.players[1].dunk_duration)*60)+12)
	check(g.scores[0]==1 and g.dunks==1,"Dunk puts actual ball downward through rim once")
	g=isolated()
	g.players[1].pos=Vector3(0,0,Sim.NORTH.z+2)
	g.ball.owner=1
	g.action(1,"dunk")
	check(g.players[1].dunk==0,"Grounded dunk requires a jump")
	g.players[4].pos=g.players[1].pos+Vector3.BACK*1.1
	g.players[4].aim=Vector3.FORWARD
	g.action(4,"tackle")
	ticks(g,2)
	check(g.players[1].stun>0 and g.ball.owner==0 and g.players[1].guard>0,"Tackle drops ball and grants recovery protection")
	g=isolated()
	g.players[1].pos=Vector3(-.8,0,0)
	g.players[2].pos=Vector3(.8,0,0)
	g.players[4].pos=Vector3.ZERO
	g.players[1].aim=Vector3.RIGHT
	g.players[4].aim=Vector3.LEFT
	g.ball.owner=2
	g.action(1,"tackle")
	g.action(4,"tackle")
	ticks(g,1)
	check(g.tackles==2 and g.players[1].stun>0 and g.players[4].stun>0 and g.players[2].stun==0 and g.ball.owner==2,"A mutual clash downs both divers without chain-tackling a third player")
	g=isolated()
	g.players[1].pos=Vector3.ZERO
	g.players[2].pos=Vector3(2,0,0)
	g.players[3].pos=Vector3(0,0,-8)
	g.players[1].aim=Vector3.FORWARD
	g.ball.owner=1
	g.action(1,"pass")
	check(g.ball.pass_target==3 and g.ball.owner==0,"Pass target follows aim instead of always nearest teammate")
	ticks(g,80)
	check(g.ball.owner==3,"Targeted pass travels and catches at teammate")
	g=isolated()
	g.players[1].pos=Vector3.ZERO
	g.ball.pos=Vector3(0,1.3,-3)
	g.ball.vel=Vector3(0,0,8)
	g.action(1,"catch")
	ticks(g,12)
	check(g.ball.owner==1,"Catch timing window can intercept an incoming ball")
	g=isolated()
	g.scores={0:4,1:1}
	goal(g)
	check(g.winner==0 and g.scores[0]==5,"Four-point lead ends team match")
	g=isolated()
	g.scores={0:2,1:1}
	g.time_left=.01
	ticks(g,1)
	check(g.winner==0,"Highest score wins at full time")
	g=isolated()
	g.time_left=.01
	ticks(g,2)
	check(g.winner==-1,"Tied clock enters sudden death")
	goal(g)
	check(g.winner==0,"Next goal breaks a full-time tie")
	g=Sim.new()
	g.reset("teams",{"active_humans":[1,2,3],"teams":{1:0,2:0,3:1},"bots":{0:0,1:1}})
	check(g.players.size()==4 and g.team(3)==1 and g.team(4)==1,"Two humans versus one human plus optional bot")
	check(g.hoop(3)==Sim.SOUTH and g.hoop(1)==Sim.NORTH,"Each configured team attacks the correct hoop")
	g.reset("teams",{"active_humans":[1,2,3],"teams":{1:0,2:0,3:1},"bots":{0:0,1:0}})
	check(g.players.size()==3,"Two versus one works with balancing disabled")
	g.reset("teams",{"active_humans":[1,2],"teams":{1:0,2:1},"bots":{0:0,1:0}})
	check(g.players.size()==2,"Two people can play genuine one versus one")
	check(g.add_human(3,0) and g.players.size()==3 and g.team(3)==0,"Late join adds a human to requested team")
	check(g.has_method("ensure_balanced_teams"),"Live teams expose balancing without resetting the match")
	if g.has_method("ensure_balanced_teams"):
		g.players[1].pos=Vector3(3,2,-6)
		g.ball.owner=1
		g.scores={0:2,1:1}
		g.clock=37.0
		g.ensure_balanced_teams()
		check(g.players.size()==4 and g.team(4)==1,"Third human joining one-versus-one creates opposing balancing bot")
		check(g.players[1].pos==Vector3(3,2,-6) and g.ball.owner==1 and g.scores=={0:2,1:1} and g.clock==37.0,"Balancing preserves ongoing positions, possession, score and clock")
		g.ensure_balanced_teams()
		check(g.players.size()==4,"Repeated balancing cannot duplicate bots")
		g.reset("teams",{"active_humans":[1,2,3],"teams":{1:1,2:1,3:1},"bots":{0:0,1:0}})
		g.ensure_balanced_teams()
		check(g.players.size()==6 and g.team(4)==0 and g.team(5)==0 and g.team(6)==0,"Balancing fills opposite side up to three bots")
	g.reset("teams",{"active_humans":[1,2],"teams":{1:0,2:1},"bots":{0:0,1:1}})
	g.ball.owner=4
	check(g.add_human(3,1) and g.players.size()==3 and g.ball.owner==3,"Joining takes over a bot and its possession without duplicating players")
	g.reset("teams",{"active_humans":[1,3],"teams":{1:0,3:0},"bots":{0:0,1:1}})
	g.reset_time=0
	g.players[3].hype=100
	g.action(3,"hype")
	check(g.power_balls.size()==1,"Homing projectile exists before a late join")
	g.add_human(2,1)
	check(g.power_balls[0].target==2,"Replacing a bot preserves incoming projectile target")
	g=isolated()
	for id in [1,2,3]: g.players[id].hype=100
	g.action(1,"hype")
	check(g.players[1].giant>0 and g.players[1].hype==0,"Giant consumes Hype once")
	g.action(1,"hype")
	check(g.players[1].hype==0,"Hype cannot repeat while empty")
	g.action(2,"hype")
	check(g.power_pads.size()==1,"Launch-pad Hype creates a physical pad")
	g.players[2].pos=Vector3(Sim.HALF_WIDTH-.5,2,0)
	g.players[2].aim=Vector3.RIGHT
	g.players[2].hype=100
	g.action(2,"hype")
	check(g.power_pads.back().pos.x<=Sim.HALF_WIDTH-1.25,"Hype launch pad stays reachable inside the court")
	g.players[3].pos=Vector3.ZERO
	g.players[4].pos=Vector3(0,0,-4)
	g.action(3,"hype")
	check(g.power_balls.size()==1,"Blast Hype creates an actual moving projectile")
	ticks(g,30)
	check(g.players[4].stun>0 and g.power_balls.is_empty(),"Homing blast reaches and knocks opponent")
	for id in [1,4]:
		for distance in [5.0,9.0,14.0,20.0]:
			g=isolated()
			var target=g.hoop(id)
			var approach=Vector3.BACK if target.z<0 else Vector3.FORWARD
			g.players[id].pos=target+approach*distance-Vector3.UP*Sim.HOOP_Y
			g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
			g.players[id].aim=-approach
			g.ball.owner=id
			g.action(id,"throw",preload("res://tests/shot_fixture.gd").aimed_charge(g,id))
			ticks(g,180)
			check(g.scores[g.team(id)]==1,"Aimed %dm shot clears the front rim for team%d" %[distance,g.team(id)])
	var v=Sim.launch_velocity(Vector3(0,2,0),Sim.NORTH,1.2)
	var arrival=Vector3(0,2,0)+v*1.2+Vector3.DOWN*Sim.BALL_GRAVITY*.5*1.2*1.2
	check(arrival.distance_to(Sim.NORTH)<.001,"Ballistic preview uses the same gravity equation")
	print("SIM_RESULT %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
