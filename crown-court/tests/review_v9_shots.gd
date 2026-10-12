extends SceneTree

const Sim = preload("res://sim.gd")
var results: Array = []
var output := "C:/game-3/build/crown-court-evidence/v9-shots"

func check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	results.append({"passed":ok,"check":label,"detail":detail})
	print("PASS " if ok else "FAIL ",label," ",JSON.stringify(detail))

func fresh(id: int = 1):
	var g = Sim.new()
	g.reset("coop")
	g.reset_time=0
	g.ball.lock=0
	for other in g.players.keys():
		if other != id: g.players.erase(other)
	g.players[id].guard=0
	g.players[id].vel=Vector3.ZERO
	g.players[id].move=Vector3.ZERO
	g.ball.owner=id
	return g

func velocity_at(g, distance: float, angle: float, charge: float) -> Vector3:
	var aim = Vector3.FORWARD.rotated(Vector3.UP,angle)
	# Keep release XZ fixed while changing aim, so the tested difference is
	# the gate itself rather than the overhead hand's forward displacement.
	g.players[1].aim=aim
	g.players[1].pos=Sim.NORTH+Vector3.BACK*distance-Vector3.UP*Sim.HOOP_Y-aim*.7
	g.players[1].pos.y=Sim.floor_height(g.players[1].pos.x,g.players[1].pos.z)
	return g.throw_velocity(1,charge)

func actual_shot(id: int, distance: float, charge: float, angle: float = 0) -> Dictionary:
	var g=fresh(id)
	var back=Vector3.BACK if g.hoop(id).z<0 else Vector3.FORWARD
	g.players[id].pos=g.hoop(id)+back*distance-Vector3.UP*Sim.HOOP_Y
	g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
	g.players[id].aim=(-back).rotated(Vector3.UP,angle)
	if charge < 0: charge=preload("res://tests/shot_fixture.gd").aimed_charge(g,id,angle)
	g.action(id,"throw",charge)
	var initial: Vector3=g.ball.vel
	var peak: float=g.ball.pos.y
	var max_step:=0.0
	var last: Vector3=g.ball.pos
	var events: Array=[]
	for frame in 360:
		g.step(1.0/60)
		peak=maxf(peak,g.ball.pos.y)
		max_step=maxf(max_step,g.ball.pos.distance_to(last))
		last=g.ball.pos
		if g.event_kind == "bounce" and (events.is_empty() or events.back()!=g.message): events.append(g.message)
		if g.baskets>0: break
	return {"score":g.baskets,"velocity":initial,"peak":peak,"max_step":max_step,"events":events}

func physical_contacts() -> void:
	var g=fresh()
	g.players[1].pos=Vector3.ZERO
	g.ball.owner=0
	g.ball.last_touch=1
	g.ball.pos=Sim.NORTH+Vector3(Sim.RIM_RADIUS+Sim.RIM_TUBE+Sim.BALL_RADIUS-.10,1,0)
	g.ball.vel=Vector3.DOWN*8
	var contact:=false
	for frame in 45:
		g.step(1.0/60)
		if g.message=="RIM RATTLE": contact=true
	check(contact and g.baskets==0,"Outside-rim contact deflects a genuine near miss without awarding points",{"rim_contact":contact,"baskets":g.baskets,"ball":g.ball.pos})
	for side in [-1,1]:
		g=fresh()
		g.ball.owner=0
		g.ball.last_touch=1
		g.ball.pos=Vector3(0,Sim.HOOP_Y+1,Sim.BACKBOARD_Z+side*1.2)
		g.ball.vel=Vector3(0,0,-side*24)
		for frame in 6: g.step(1.0/60)
		check(g.ball.vel.z*side>0 and absf(g.ball.pos.z-Sim.BACKBOARD_Z)>=Sim.BALL_RADIUS+.119,"Backboard face%d produces a bounded physical rebound"%side,{"position":g.ball.pos,"velocity":g.ball.vel})
	g=fresh()
	g.players[1].pos=Sim.NORTH+Vector3(0,-Sim.HOOP_Y,14)
	g.players[1].aim=Vector3.FORWARD
	g.action(1,"throw",.55)
	var interceptor=Sim.new()
	interceptor.reset("coop")
	g.players[4]=interceptor.players[4].duplicate(true)
	var t=.3
	g.players[4].pos=g.ball.pos+g.ball.vel*t+Vector3.DOWN*.5*Sim.BALL_GRAVITY*t*t-Vector3.UP*1.1+Vector3.UP*.5*Sim.PLAYER_GRAVITY*t*t
	g.players[4].vel=Vector3.ZERO
	g.players[4].grounded=false
	g.players[4].jump_count=1
	for frame in 45:
		g.action(4,"catch")
		g.step(1.0/60)
		if g.ball.owner==4: break
	check(g.ball.owner==4 and g.baskets==0,"Opponent catches an manually aimed shot in flight before the hoop",{"owner":g.ball.owner,"baskets":g.baskets})

func forecast_bounds() -> void:
	if not Sim.new().has_method("ball_clear_of_static_colliders"): return
	var g=fresh()
	g.players={}
	g.ball.owner=0
	g.ball.last_touch=0
	g.ball.pass_target=0
	var random=RandomNumberGenerator.new()
	random.seed=908
	var admitted:=0
	var false_clear:=0
	for index in 4000:
		var position=Vector3(random.randf_range(-Sim.HALF_WIDTH-1,Sim.HALF_WIDTH+1),random.randf_range(0,12),random.randf_range(-Sim.HALF_LENGTH-1,Sim.HALF_LENGTH+1))
		if not g.ball_clear_of_static_colliders(position):continue
		admitted+=1
		var velocity=Vector3(random.randf_range(-30,30),random.randf_range(-20,20),random.randf_range(-30,30))
		g.ball.pos=position
		g.ball.vel=velocity
		g.clock=random.randf_range(0,60)
		g.ball_step(0)
		if g.ball.pos!=position or g.ball.vel!=velocity:false_clear+=1
	check(admitted>1000 and false_clear==0,"Forecast broad phase never skips an actual static contact in4000 seeded probes",{"admitted":admitted,"false_clear":false_clear})

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	var g=fresh()
	var angle=acos(.92)
	var angle_delta: float=velocity_at(g,14,angle-.001,.55).distance_to(velocity_at(g,14,angle+.001,.55))
	check(angle_delta<.25,"Small aim change around old dot.92 boundary keeps launch continuous",{"delta_velocity":angle_delta})
	var range_delta: float=velocity_at(g,21.99,0,.55).distance_to(velocity_at(g,22.01,0,.55))
	check(range_delta<.1,"Two-centimetre range change around old22m boundary keeps launch continuous",{"delta_velocity":range_delta})
	var charge_delta: float=velocity_at(g,14,0,.999).distance_to(velocity_at(g,14,0,1.001))
	check(charge_delta<.1,"Charge crossing into overhold preserves continuous launch",{"delta_velocity":charge_delta})
	for id in [1,4]:
		var own_half=absf(Sim.NORTH.z)+10
		var long=actual_shot(id,own_half,-1.0)
		check(long.score==1,"Charged own-half shot can physically reach basket for team%d"%id,long)
		var deep=actual_shot(id,absf(Sim.NORTH.z)*2-3,-1.0)
		check(deep.score==1,"Charged deep-court shot remains physically viable for team%d"%id,deep)
	var under=actual_shot(1,absf(Sim.NORTH.z)+10,0)
	check(under.score==0,"Undercharged own-half shot falls short",under)
	var over=actual_shot(1,14,1.5)
	check(over.score==0,"Overheld close shot can miss",over)
	var away=actual_shot(1,14,.55,PI*.5)
	check(away.score==0,"Aiming away from basket cannot turn into a guaranteed score",away)
	physical_contacts()
	forecast_bounds()
	var failures=results.filter(func(r):return not r.passed).size()
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":results,"failures":failures},"  "))
	print("SHOTS_RESULT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
