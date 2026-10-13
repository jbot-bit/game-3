extends SceneTree
const Sim = preload("res://sim.gd")
var checks = []
var cases = 0
var violations = []
func check(ok: bool, label: String, detail = {}):
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: printerr("FAIL ",label," ",detail)
func fresh(pos: Vector3):
	var g=Sim.new()
	g.reset("coop")
	g.reset_time=0
	g.ball.lock=100
	g.players={1:g.players[1]}
	var p=g.players[1]
	p.pos=pos
	p.vel=Vector3.ZERO
	p.guard=100
	p.pad_cooldown=100
	p.hazard_cooldown=100
	return g
func air_probe(angle: float, intent_kind: int):
	var g=fresh(Vector3(0,30,0))
	var p=g.players[1]
	var direction=Vector3(cos(angle),0,sin(angle))
	p.grounded=false
	p.vel=direction*9.5
	p.move=[Vector3.ZERO,-direction,direction.rotated(Vector3.UP,PI/2)][intent_kind]
	for frame in 30:g.step(1.0/60)
	return {"speed":Vector2(p.vel.x,p.vel.z).length(),"distance":Vector2(p.pos.x,p.pos.z).length()}
func _initialize():
	# Axis-wise air drag/steering breaks rotational invariance with identical inputs.
	for intent in 3:
		var cardinal=air_probe(0,intent)
		var diagonal=air_probe(PI/4,intent)
		check(absf(cardinal.speed-diagonal.speed)<.001 and absf(cardinal.distance-diagonal.distance)<.001,"Air motion is rotationally equivalent, intent "+str(intent),{"cardinal":cardinal,"diagonal":diagonal})
	# Clamping position while keeping outward speed stores fictitious wall momentum.
	for axis in [Vector3.RIGHT,Vector3.BACK]:
		var start=axis*(31.5 if axis.x!=0 else 55.5)
		start.y=Sim.floor_height(start.x,start.z)
		var g=fresh(start)
		var p=g.players[1]
		p.vel=axis*9.5
		p.move=axis
		g.step(1.0/60)
		var wall_speed=p.vel.dot(axis)
		p.move=-axis
		g.step(1.0/60)
		check(wall_speed<=.001 and (p.pos-start).dot(axis)<0,"Wall contact removes blocked velocity and permits immediate retreat "+str(axis),{"outward_speed":wall_speed,"retreat":(p.pos-start).dot(axis)})
	for side in [-1,1]:
		var start=Vector3(side*31.49,Sim.floor_height(side*31.49,30),30)
		var g=fresh(start)
		var p=g.players[1]
		p.vel=Vector3(side*12,0,5)
		p.dive=.34
		p.slide_time=.85
		var forecast=g.pass_receive_position(1,.5)
		g.step(1.0/60)
		check(absf(p.vel.x)<.001 and absf(p.vel.z-5)<.001,"Wall collision preserves committed dive tangent "+str(side),{"velocity":p.vel})
		for frame in 29:g.step(1.0/60)
		check(forecast.distance_to(p.pos+Vector3.UP*1.25)<.001,"Receiver forecast matches real wall slide "+str(side),{"error":forecast.distance_to(p.pos+Vector3.UP*1.25)})
	if '--focused-only' in OS.get_cmdline_user_args():
		print("MOVEMENT_STRESS_V15_RESULT ",JSON.stringify({"checks":checks}))
		quit(0 if checks.all(func(c):return c.passed) else 1)
		return
	# End-to-end integration matrix: real actions, landings, terrain and recovery.
	for hz in [30,60,120]:
		for heading in 8:
			var direction=Vector3(cos(heading*PI/4),0,sin(heading*PI/4))
			for intent_kind in 4:
				for terrain in [Vector3.ZERO,Vector3(28,0,15),Vector3(31.4,0,35)]:
					for airborne in [false,true]:
						for giant in [false,true]:
							for kind in ["run","dive","impact","boost"]:
								cases+=1
								var start=terrain
								start.y=Sim.floor_height(start.x,start.z)+(3.0 if airborne else 0.0)
								var g=fresh(start)
								var p=g.players[1]
								p.grounded=not airborne
								p.giant=10 if giant else 0
								p.aim=direction
								p.vel=direction*9.5
								if kind=="dive":g.action(1,"tackle")
								if kind=="impact":
									var attacker=p.duplicate(true)
									attacker.pos=p.pos-direction
									g.players[4]=attacker
									g.hit(4,1)
									g.players.erase(4)
								if kind=="boost":
									p.boost_time=1.0
									p.boost_direction=direction
									p.vel=direction*18
								# Carrying avoids unrelated loose-ball collider work in this motor matrix.
								g.ball.owner=1
								p.move=[Vector3.ZERO,-direction,direction.rotated(Vector3.UP,PI/2),direction][intent_kind]
								var valid=true
								for frame in hz*3:
									g.step(1.0/hz)
									valid=valid and p.pos.is_finite() and p.vel.is_finite() and absf(p.pos.x)<=31.501 and absf(p.pos.z)<=55.501 and p.pos.y>=Sim.floor_height(p.pos.x,p.pos.z)-.001 and p.vel.length()<40
								if intent_kind==0:valid=valid and p.vel.length()<.01 and p.grounded
								if not valid:violations.append({"hz":hz,"heading":heading,"intent":intent_kind,"terrain":terrain,"airborne":airborne,"giant":giant,"kind":kind,"pos":p.pos,"vel":p.vel})
	check(violations.is_empty(),"Matrix stays finite, bounded, above terrain; released momentum settles",{"cases":cases,"violations":violations.slice(0,20),"violation_count":violations.size()})
	print("MOVEMENT_STRESS_V15_RESULT ",JSON.stringify({"checks":checks,"cases":cases}))
	quit(0 if checks.all(func(c):return c.passed) else 1)
