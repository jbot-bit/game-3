extends SceneTree

const Sim = preload("res://sim.gd")
var checks: Array = []
var samples: Array = []
var output := "C:/game-3/build/crown-court-evidence/v9-ball-mechanics"

func expect(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	print("PASS " if ok else "FAIL ",label," ",JSON.stringify(detail))

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players.keys():
		if id not in [1,2]: g.players.erase(id)
	for id in g.players:
		g.players[id].pos = Vector3.ZERO
		g.players[id].vel = Vector3.ZERO
		g.players[id].move = Vector3.ZERO
		g.players[id].guard = 0
		g.players[id].grounded = true
	return g

func moving_pass(label: String, direction: Vector3, distance: float, initial_velocity: Vector3 = Vector3.INF, airborne: bool = false) -> void:
	var g = fresh()
	g.players[1].pos = Vector3(8-distance,0,0)
	g.players[2].pos = Vector3(8,0,0)
	# An unobstructed flank lane, beyond the newly introduced midfield rotors.
	for id in g.players: g.players[id].pos.z=Sim.HALF_LENGTH*.54
	for id in g.players: g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
	g.players[1].aim = Vector3.RIGHT
	g.players[2].move = direction
	g.players[2].vel = direction*Sim.SPEED if initial_velocity == Vector3.INF else initial_velocity
	if airborne: g.action(2,"jump")
	g.ball.owner = 1
	g.action(1,"pass")
	var accepted: bool = g.ball.owner == 0 and g.ball.pass_target == 2
	var closest := INF
	var received := false
	var elapsed := 0.0
	var trace: Array = []
	# After release, only the actual simulation advances. Receiver maintains
	# the initial, unobstructed movement input; no pose/ball writes or catch assist.
	for frame in 180:
		g.step(1.0/60)
		elapsed += 1.0/60
		closest = minf(closest,g.ball.pos.distance_to(g.players[2].pos+Vector3.UP*1.1))
		if frame%3 == 0: trace.append({"time":elapsed,"ball":g.ball.pos,"receiver":g.players[2].pos,"owner":g.ball.owner})
		if g.ball.owner == 2:
			received = true
			break
	expect(accepted and received,label,{"accepted":accepted,"received":received,"closest_m":closest,"elapsed_s":elapsed})
	samples.append({"case":label,"trace":trace})

func interception() -> void:
	var g = fresh()
	var opponent = Sim.new()
	opponent.reset("coop")
	g.players[4] = opponent.players[4].duplicate(true)
	g.players[1].pos = Vector3(-8,0,0)
	g.players[2].pos = Vector3(8,0,0)
	g.players[4].pos = Vector3.ZERO
	g.players[4].vel = Vector3.ZERO
	g.players[1].aim = Vector3.RIGHT
	g.ball.owner = 1
	g.action(1,"pass")
	var horizontal: Vector3 = Vector3(g.ball.vel.x,0,g.ball.vel.z)
	var changed := false
	for frame in 120:
		g.action(4,"catch")
		g.step(1.0/60)
		if g.ball.owner > 0: break
		if Vector3(g.ball.vel.x,0,g.ball.vel.z).distance_to(horizontal)>.001: changed=true
	expect(g.ball.owner == 4,"Opponent active catch intercepts a targeted pass",{"owner":g.ball.owner})
	expect(not changed,"Pass flight has no horizontal homing after release")

func long_court_pass() -> void:
	if Sim.PASS_RANGE<69: return
	var g=fresh()
	g.players[1].pos=Vector3(0,0,48)
	g.players[2].pos=Vector3(0,0,-21)
	for id in g.players: g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
	g.players[2].vel=Vector3.RIGHT*Sim.SPEED
	g.players[2].move=Vector3.RIGHT
	g.players[1].aim=Vector3.FORWARD
	g.ball.owner=1
	g.action(1,"pass")
	var accepted: bool=g.ball.owner==0 and g.ball.pass_target==2
	var elapsed:=0.0
	for frame in 240:
		g.step(1.0/60)
		elapsed+=1.0/60
		if g.ball.owner==2: break
	expect(accepted and g.ball.owner==2,"Long69m pass reaches running receiver across the enlarged court",{"accepted":accepted,"owner":g.ball.owner,"elapsed_s":elapsed})

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	moving_pass("Stationary16m receiver receives selected unobstructed pass",Vector3.ZERO,16)
	moving_pass("Forward-running16m receiver receives selected unobstructed pass",Vector3.FORWARD,16)
	moving_pass("Backward-running16m receiver receives selected unobstructed pass",Vector3.BACK,16)
	moving_pass("Forward-running24m receiver receives selected unobstructed pass",Vector3.FORWARD,24)
	moving_pass("Braking16m receiver receives selected unobstructed pass",Vector3.ZERO,16,Vector3.FORWARD*Sim.SPEED)
	moving_pass("Airborne16m receiver receives selected unobstructed pass",Vector3.FORWARD,16,Vector3.INF,true)
	if Sim.HALF_WIDTH>=28: moving_pass("Long36m moving receiver receives a full-flight pass",Vector3.FORWARD,36)
	interception()
	long_court_pass()
	DirAccess.make_dir_recursive_absolute(output)
	var failed := checks.filter(func(c): return not c.passed).size()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failed,"samples":samples},"  "))
	print("BALL_MECHANICS_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failed}))
	quit(0 if failed == 0 else 1)
