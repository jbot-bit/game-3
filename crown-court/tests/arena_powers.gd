extends SceneTree
const Sim = preload("res://sim.gd")
var checks = 0
var failures = 0

func check(ok: bool, label: String, detail = "") -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label+" "+str(detail))

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	g.players = {1:g.players[1],4:g.players[4]}
	g.players[1].pos = Vector3.ZERO
	g.players[4].pos = Vector3(25,0,35)
	g.players[4].pos.y = Sim.floor_height(25,35)
	g.players[4].guard = 0
	g.ball.pos = Vector3(0,1,30)
	return g

func _initialize() -> void:
	check(Sim.HALF_WIDTH*2>=64 and Sim.HALF_LENGTH*2>=112,"Expanded playable area is at least64x112",[Sim.HALF_WIDTH*2,Sim.HALF_LENGTH*2])
	check(Sim.NORTH.distance_to(Sim.SOUTH)>=96,"Basket separation creates a full-length team field",Sim.NORTH.distance_to(Sim.SOUTH))
	check(Sim.BACKBOARD_Z-absf(Sim.NORTH.z)>Sim.RIM_RADIUS+Sim.RIM_TUBE,"Backboard no longer intersects the rim torus")
	for index in Sim.HAZARDS.size():
		var g = fresh()
		var direction = Vector3(cos(Sim.hazard_angle(index,0)),0,sin(Sim.hazard_angle(index,0)))
		g.players[1].pos = Sim.HAZARDS[index]+direction*2
		g.players[1].pos.y = Sim.floor_height(g.players[1].pos.x,g.players[1].pos.z)
		g.ball.owner = 1
		g.ball.pos = g.hand_position(1)
		g.step(1.0/60)
		check(g.players[1].stun>0 and g.ball.owner==0 and g.players[1].vel.y>0,"Rotating hazard physically knocks carrier and drops ball "+str(index))
		var guard = g.players[1].hazard_cooldown
		g.resolve_hazards()
		check(g.players[1].hazard_cooldown==guard and g.tackles==0 and g.players[1].hype==0,"Hazard contact cannot farm tackle/Hype or retrigger every frame "+str(index))
	var g = fresh()
	g.players[1].pos = Sim.HAZARDS[0]+Vector3(2,2.5,0)
	g.players[1].grounded = false
	g.players[1].jump_count = 1
	g.step(1.0/60)
	check(g.players[1].stun==0,"Jump clears the padded sweeper")
	g.players[1].pos = Sim.HAZARDS[0]+Vector3(2,0,0)
	g.players[1].giant = 4
	g.step(1.0/60)
	check(g.players[1].stun==0,"Giant can stride through ground sweepers")
	var ends = Sim.hazard_endpoints(0,g.clock)
	var middle: Vector3 = (ends[0]+ends[1])*.5
	g.ball.pos = middle+Vector3(2,0,.6)
	g.ball.vel = Vector3(0,0,-12)
	g.resolve_hazard_ball()
	check(g.ball.vel.z>0 and g.ball.pos.is_finite(),"Sweeper physically rebounds loose balls",g.ball.vel)
	g = fresh()
	g.players[1].hype = 99
	g.action(1,"hype")
	check(g.players[1].giant==0 and g.players[1].hype==99,"Power requires a full earned meter")
	g.players[1].hype = 100
	g.players[1].power = "giant"
	g.action(1,"hype")
	check(g.players[1].giant==7 and g.players[1].hype==0,"Giant activates and spends Hype once")
	for i in 430: g.step(1.0/60)
	check(g.players[1].giant==0,"Giant expires through real simulation")
	g = fresh()
	g.players[1].power = "pad"
	g.players[1].hype = 100
	g.action(1,"hype")
	g.move_input(1,Vector3.FORWARD,Vector3.FORWARD)
	var launched = false
	for i in 90:
		g.step(1.0/60)
		launched = launched or g.players[1].vel.y>20
	check(launched and g.players[1].hype==0,"Deployed power pad launches its owner through normal movement")
	for i in 900: g.step(1.0/60)
	check(g.power_pads.is_empty(),"Deployed pad expires instead of accumulating indefinitely")
	g = fresh()
	g.players[1].power = "blast"
	g.players[1].hype = 100
	g.players[1].aim = Vector3.RIGHT
	g.players[4].pos = Vector3(8,0,0)
	g.action(1,"hype")
	var hit = false
	for i in 120:
		g.step(1.0/60)
		hit = hit or g.players[4].stun>0
	check(hit and g.power_balls.is_empty() and g.players[1].hype<100,"Homing power travels, hits enemy and clears its projectile")
	g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	g.players = {1:g.players[1],2:g.players[2]}
	for id in g.players:
		g.players[id].pos = Sim.NORTH+Vector3(0,-Sim.HOOP_Y,18 if id==1 else 9)
		g.players[id].pos.y = Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
		g.players[id].aim = Vector3.FORWARD
	g.ball.owner = 1
	g.ball.pos = g.hand_position(1)
	g.action(1,"pass")
	for i in 180:
		g.step(1.0/60)
		if g.ball.owner==2: break
	check(g.ball.owner==2 and g.assist_player==1,"Completed physical pass registers one potential assist")
	check(g.ball.pos.distance_to(g.hand_position(2))<.001,"Possession transaction immediately places ball at receiver hand")
	g.action(2,"throw",preload("res://tests/shot_fixture.gd").aimed_charge(g,2))
	for i in 300:
		g.step(1.0/60)
		if g.baskets>0: break
	check(g.baskets==1 and g.players[1].hype==Sim.HYPE_PASS+Sim.HYPE_ASSIST,"Pass then physical basket awards pass plus assist Hype",[g.baskets,g.players[1].hype])
	check(g.assist_player==0,"Assist clears after score and cannot award twice")
	print("ARENA_POWERS_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
