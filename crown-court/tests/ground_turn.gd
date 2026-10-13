extends SceneTree
const Sim = preload("res://sim.gd")
var checks = []

func check(ok: bool, label: String, detail = {}) -> void:
	checks.append({"check":label,"passed":ok,"detail":detail})
	if not ok: printerr("FAIL "+label+" "+str(detail))

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players.keys():
		if id!=1: g.players.erase(id)
	g.players[1].pos = Vector3.ZERO
	g.players[1].guard = 0
	# Contact pickup would otherwise hand the centre ball to this runner.
	g.ball.pos = Vector3(30,1.5,30)
	return g

func measure(initial: Vector3, intent: Vector3, angle: float) -> Dictionary:
	var g = fresh()
	g.players[1].vel = initial
	g.move_input(1,intent,intent if intent.length()>.1 else Vector3.FORWARD)
	var old_direction = initial.normalized()
	var stopped_at = -1.0
	var reached_at = -1.0
	var turn_at = -1.0
	var peak_old_distance = 0.0
	var rows = []
	for frame in 60:
		g.step(1.0/60)
		var elapsed = (frame+1)/60.0
		var v: Vector3 = g.players[1].vel
		v.y = 0
		var speed = v.length()
		if stopped_at<0 and (v.dot(old_direction)<=0.01 or (intent==Vector3.ZERO and speed<=.01)): stopped_at=elapsed
		if reached_at<0 and intent.length()>.1 and v.dot(intent)>=Sim.SPEED*.9: reached_at=elapsed
		if turn_at<0 and intent.length()>.1 and speed>.1 and v.normalized().dot(intent)>.985: turn_at=elapsed
		peak_old_distance=maxf(peak_old_distance,g.players[1].pos.dot(old_direction))
		if frame in [0,2,5,11,17,23,35,59]: rows.append({"t":elapsed,"velocity":v,"position":g.players[1].pos})
	return {"angle":angle,"stop_old_direction_s":stopped_at,"reach90_s":reached_at,"within10deg_s":turn_at,"slip_m":peak_old_distance,"samples":rows}

func _initialize() -> void:
	var start = measure(Vector3.ZERO,Vector3.FORWARD,0)
	var turn90 = measure(Vector3.FORWARD*Sim.SPEED,Vector3.RIGHT,90)
	var turn180 = measure(Vector3.FORWARD*Sim.SPEED,Vector3.BACK,180)
	var release = measure(Vector3.FORWARD*Sim.SPEED,Vector3.ZERO,0)
	check(start.samples[0].velocity.length()>0,"Ground input responds on the first physics tick")
	check(start.reach90_s>=.30 and start.reach90_s<=.55,"Starting feet build traction before full running speed",start)
	check(turn180.stop_old_direction_s>=.30 and turn180.stop_old_direction_s<=.55,"Hard reversal retains readable old-direction momentum",turn180)
	check(turn180.reach90_s>=.60 and turn180.reach90_s<=1.0,"Full reversal brakes then drives back within one second",turn180)
	check(turn180.slip_m>1.2 and turn180.slip_m<3,"A running reversal has bounded physical skid distance",turn180)
	check(turn90.within10deg_s>.25 and turn90.within10deg_s<.65,"A right-angle cut has a readable planted turn",turn90)
	check(release.stop_old_direction_s>.20 and release.stop_old_direction_s<.5,"Releasing movement has a short controlled coast",release)
	var a = fresh()
	var b = fresh()
	a.move_input(1,Vector3.FORWARD,Vector3.FORWARD)
	var diagonal = Vector3(1,0,-1).normalized()
	b.move_input(1,diagonal,diagonal)
	var max_speed_gap = 0.0
	for i in 20:
		a.step(1.0/60)
		b.step(1.0/60)
		max_speed_gap=maxf(max_speed_gap,a.players[1].vel.length()-b.players[1].vel.length())
		max_speed_gap=maxf(max_speed_gap,b.players[1].vel.length()-a.players[1].vel.length())
	check(max_speed_gap<.001,"Diagonal starts have the same traction as cardinal starts",{"max_speed_gap":max_speed_gap})
	var rotated = measure(Vector3(1,0,-1).normalized()*Sim.SPEED,Vector3(-1,0,1).normalized(),180)
	check(absf(rotated.reach90_s-turn180.reach90_s)<.02 and absf(rotated.slip_m-turn180.slip_m)<.02,"Diagonal reversal time and distance are rotation invariant",rotated)
	var g = fresh()
	g.move_input(1,Vector3.FORWARD*.5,Vector3.FORWARD)
	for i in 60: g.step(1.0/60)
	check(absf(Vector2(g.players[1].vel.x,g.players[1].vel.z).length()-4.75)<.01,"Partial analog input retains half running speed")
	var passed=checks.all(func(row): return row.passed)
	print("GROUND_TURN_RESULT "+JSON.stringify({"passed":passed,"checks":checks,"profiles":{"start":start,"turn90":turn90,"turn180":turn180,"release":release,"diagonal180":rotated},"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"scope":"60Hz authoritative simulation, authored acceptance bounds; no original-game timing claim"}))
	quit(0 if passed else 1)
