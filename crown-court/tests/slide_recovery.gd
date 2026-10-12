extends SceneTree
const Sim = preload("res://sim.gd")
var checks = []
func check(ok: bool, label: String, detail = {}):
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: printerr("FAIL ",label," ",detail)
func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 10
	for id in g.players.keys():
		if id not in [1,4]: g.players.erase(id)
	g.players[1].pos = Vector3(0,0,1)
	g.players[4].pos = Vector3.ZERO
	g.players[4].guard = 0
	return g
func impact(direction: Vector3, intent: Vector3, hz: int = 60):
	var g = fresh()
	g.players[1].pos = -direction
	g.hit(1,4)
	g.players.erase(1)
	g.move_input(4,intent,Vector3.FORWARD)
	var landed = -1.0
	var landing_pos = Vector3.ZERO
	var recovered_speed = 0.0
	var after_speed = 0.0
	var stop = -1.0
	var after_forward = 0.0
	for frame in hz*2:
		g.step(1.0/hz)
		var p = g.players[4]
		var elapsed = float(frame+1)/hz
		if p.grounded and landed<0:
			landed=elapsed
			landing_pos=p.pos
		if frame+1==int(.65*hz): recovered_speed=Vector2(p.vel.x,p.vel.z).length()
		if frame+1==int(.85*hz):
			after_speed=Vector2(p.vel.x,p.vel.z).length()
			after_forward=p.vel.dot(direction)
		if stop<0 and Vector2(p.vel.x,p.vel.z).length()<.01: stop=elapsed
	return {"landed_s":landed,"recovered_speed":recovered_speed,"after_speed":after_speed,"stop_s":stop,"after_forward":after_forward,"distance":g.players[4].pos.dot(direction),"ground_distance":(g.players[4].pos-landing_pos).dot(direction)}
func _initialize():
	var cardinal=impact(Vector3.FORWARD,Vector3.ZERO)
	var diagonal=impact(Vector3(1,0,-1).normalized(),Vector3.ZERO)
	check(cardinal.after_speed>5,"Knockback retains a visible skid after control recovery",cardinal)
	check(cardinal.stop_s>.95 and cardinal.stop_s<1.6,"Knockback coasts then comes fully to rest",cardinal)
	check(absf(cardinal.distance-diagonal.distance)<.04,"Diagonal and cardinal impact travel equally",diagonal)
	check(cardinal.ground_distance>2.5 and cardinal.ground_distance<5,"Knockback landing has a bounded ground slide",cardinal)
	var reverse=impact(Vector3.FORWARD,Vector3.BACK)
	check(reverse.after_forward>4,"Opposing held input cannot erase the recovery slide instantly",reverse)
	var thirty=impact(Vector3.FORWARD,Vector3.ZERO,30)
	check(absf(thirty.distance-cardinal.distance)<.35,"Slide distance remains stable at 30 and 60 Hz",thirty)
	var g=fresh()
	g.players.erase(4)
	g.players[1].pos=Vector3.ZERO
	g.action(1,"tackle")
	var end_dive=Vector3.ZERO
	var dive_speed=0.0
	for frame in 120:
		g.step(1.0/60)
		if frame==20: end_dive=g.players[1].pos
		if frame==41: dive_speed=Vector2(g.players[1].vel.x,g.players[1].vel.z).length()
	check(dive_speed>7,"Missed dive carries momentum through belly-slide recovery",{"speed_at_0_7":dive_speed})
	check(g.players[1].vel.length()<.01 and g.players[1].pos.distance_to(end_dive)<7,"Missed dive stops without indefinite skating")
	g=fresh()
	g.players.erase(4)
	g.players[1].pos=Vector3.ZERO
	g.players[1].vel=Vector3.FORWARD*Sim.SPEED
	for frame in 24:g.step(1.0/60)
	check(g.players[1].vel.length()>.1,"Run release retains a brief readable coast at 0.4 seconds",{"speed":g.players[1].vel.length(),"distance":g.players[1].pos.length()})
	for frame in 36:g.step(1.0/60)
	check(g.players[1].vel.length()<.01,"Run release settles within one second")
	# A receiver forecast must use the same slide state and timer as authority.
	for kind in ["dive","impact"]:
		g=fresh()
		g.players[1].pos=Vector3.ZERO
		g.players.erase(4)
		if kind=="dive":g.action(1,"tackle")
		else:
			g.players[1].slide_time=1.15
			g.players[1].stun=.65
			g.players[1].vel=Vector3(0,5.2,-11.5)
			g.players[1].grounded=false
		var expected=g.pass_receive_position(1,1.0)
		for frame in 60:g.step(1.0/60)
		check(expected.distance_to(g.players[1].pos+Vector3.UP*1.25)<.001,"Pass forecast follows actual "+kind+" recovery",{"error":expected.distance_to(g.players[1].pos+Vector3.UP*1.25)})
	g=fresh()
	g.hit(1,4)
	var snapshot=g.snapshot()
	check(snapshot.players[4].slide_time==1.15 and snapshot.players[4].slide_kind=="impact","Snapshots carry authored recovery presentation state")
	check(g.players[4].guard==1.4 and g.players[4].stun==.65,"Recovery slide preserves existing anti-chain-stun guard")
	g.spawn_players()
	check(g.players[4].slide_time==0 and g.players[4].slide_kind=="","Respawn clears slide state")
	print("SLIDE_RECOVERY_RESULT ",JSON.stringify({"checks":checks,"cardinal":cardinal,"diagonal":diagonal,"reverse":reverse,"thirty_hz":thirty}))
	quit(0 if checks.all(func(c):return c.passed) else 1)
