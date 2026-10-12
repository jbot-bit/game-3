extends SceneTree

const Sim = preload("res://sim.gd")
var checks: Array = []
var evidence = "C:/game-3/build/crown-court-evidence/terrain-v10"
var pack_source = ""

func check(ok: bool, label: String, detail = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+JSON.stringify(detail))

func fresh(id: int = 1):
	var g = Sim.new()
	g.reset("coop")
	g.players = {id:g.players[id]}
	g.reset_time = 0
	g.ball.pos = Vector3(25,8,42)
	g.ball.vel = Vector3.ZERO
	g.ball.lock = 0
	var p: Dictionary = g.players[id]
	p.pos = Vector3.ZERO
	p.vel = Vector3.ZERO
	p.grounded = true
	p.guard = 0
	p.pad_cooldown = 0
	g.reset_movement_state(p)
	return g

func walk(start: Vector3, direction: Vector3, frames: int) -> Dictionary:
	var g = fresh()
	var p: Dictionary = g.players[1]
	p.pos = start
	p.pos.y = Sim.floor_height(start.x,start.z)
	g.move_input(1,direction,direction)
	var clearance = 0.0
	var vertical_step = 0.0
	var airborne = 0
	for tick in frames:
		var old_y: float = p.pos.y
		g.step(1.0/60)
		clearance = maxf(clearance,absf(p.pos.y-Sim.floor_height(p.pos.x,p.pos.z)))
		vertical_step = maxf(vertical_step,absf(p.pos.y-old_y))
		if not p.grounded: airborne += 1
	return {"end":p.pos,"clearance":clearance,"max_vertical_step":vertical_step,"airborne":airborne}

func bot_pickup(start: Vector3, loose_ball: Vector3) -> Dictionary:
	var g = fresh()
	var p: Dictionary = g.players[1]
	p.pos = start
	p.pos.y = Sim.floor_height(start.x,start.z)
	g.ball.pos = loose_ball
	g.ball.vel = Vector3.ZERO
	var initial: Dictionary = g.bot_command(1)
	var jumps = 0
	var caught_at = -1.0
	var peak_above_ground = 0.0
	for tick in 120:
		var command: Dictionary = g.bot_command(1)
		g.move_input(1,command.move,command.aim)
		if command.action == "jump": jumps += 1
		g.action(1,command.action,command.charge)
		g.step(1.0/60)
		peak_above_ground = maxf(peak_above_ground,p.pos.y-Sim.floor_height(p.pos.x,p.pos.z))
		if g.ball.owner == 1:
			caught_at = (tick+1)/60.0
			break
	return {"first_action":initial.action,"jumps":jumps,"caught_at":caught_at,"peak_above_ground":peak_above_ground}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source=arg.trim_prefix("--pack-source=")
	var crown_error = 0.0
	for at in [Vector2(21,0),Vector2(22,10),Vector2(18,20),Vector2(21,29),Vector2(17.5,35.5),Vector2(14,42)]:
		for offset in [-2.5,0,2.5]: crown_error=maxf(crown_error,absf(Sim.floor_height(at.x+offset,at.y)-3.0))
	check(crown_error<.001,"Winding routes have broad3m flat crowns",{"max_error":crown_error})
	var junction_error = 0.0
	for at in [Vector2(0,24),Vector2(18,20),Vector2(0,37),Vector2(11,48)]: junction_error=maxf(junction_error,absf(Sim.floor_height(at.x,at.y)-3))
	check(junction_error<.001,"Curved crossings and goal approaches join raised routes",{"max_error":junction_error})
	var shoulder = Sim.floor_height(25.2,0)
	check(shoulder>.3 and shoulder<2.7,"Road shoulders descend to the lower play surface",{"height":shoulder})
	var max_rotor_height=0.0
	for center in Sim.HAZARDS:
		for i in 32:
			var at: Vector3 = center+Vector3(cos(i*TAU/32),0,sin(i*TAU/32))*Sim.HAZARD_RADIUS
			max_rotor_height=maxf(max_rotor_height,absf(Sim.floor_height(at.x,at.z)))
	check(max_rotor_height<.001,"Every central sweeper footprint remains flat lower turf",{"max_height":max_rotor_height})
	var bounds_ok=true
	var symmetry_error=0.0
	var max_height=0.0
	var min_normal_y=1.0
	for ix in 65:
		for iz in 113:
			var x=float(ix)-32
			var z=float(iz)-56
			var h=Sim.floor_height(x,z)
			max_height=maxf(max_height,h)
			bounds_ok=bounds_ok and is_finite(h) and h>=0 and h<=3.5001
			symmetry_error=maxf(symmetry_error,absf(h-Sim.floor_height(-x,-z)))
			var normal=Sim.floor_normal(x,z)
			min_normal_y=minf(min_normal_y,normal.y)
			bounds_ok=bounds_ok and normal.is_finite() and absf(normal.length()-1)<.0001
	check(bounds_ok and symmetry_error<.0001,"Terrain and normals are finite bounded and team-symmetric",{"max_height":max_height,"symmetry_error":symmetry_error,"min_normal_y":min_normal_y})
	var normal=Sim.floor_normal(25.2,0)
	check(normal.x>0 and normal.y<.75,"Steep road bank exposes the real outward contact normal",{"normal":normal})
	var goal_clear=true
	for target in [Sim.NORTH,Sim.SOUTH]:
		for offset in [Vector3.ZERO,Vector3(4,0,0),Vector3(-4,0,0)]:
			var at: Vector3=target+offset
			goal_clear=goal_clear and Sim.floor_height(at.x,at.z)<Sim.HOOP_Y-Sim.BALL_RADIUS-1
	check(goal_clear,"Both lower goal pockets retain clearance beneath the hoop opening")
	var downhill_pickup = bot_pickup(Vector3(23.5,0,0),Vector3(25.2,Sim.floor_height(25.2,0)+Sim.BALL_RADIUS,0))
	check(downhill_pickup.first_action!="jump" and downhill_pickup.jumps==0 and downhill_pickup.caught_at>0 and downhill_pickup.caught_at<.5,"Bot walks down bank to collect lower loose ball without jumping away",downhill_pickup)
	var high_pickup = bot_pickup(Vector3.ZERO,Vector3(0,3.6,0))
	check(high_pickup.first_action=="jump" and high_pickup.jumps>0 and high_pickup.peak_above_ground>.1 and high_pickup.caught_at>0 and high_pickup.caught_at<.5,"Bot still physically jumps and catches a ball above its reach",high_pickup)
	for route in [[Vector3(11,0,0),Vector3.RIGHT,90],[Vector3(26,0,0),Vector3.LEFT,90],[Vector3(0,0,15),Vector3.BACK,80],[Vector3(22,0,35),Vector3.BACK,55],[Vector3(20,0,32),Vector3(1,0,1).normalized(),55]]:
		var movement=walk(route[0],route[1],route[2])
		check(movement.clearance<.025 and movement.airborne==0,"Ordinary grounded walking follows bank/crossing "+str(route[0]),movement)
	var bounced=true
	for side in [-1,1]:
		var g=fresh()
		g.players.clear()
		var x=25.2*side
		g.ball.pos=Vector3(x,Sim.floor_height(x,0)+Sim.BALL_RADIUS-.02,0)
		g.ball.vel=Vector3(-5*side,-6,0)
		g.ball_step(1.0/180)
		bounced=bounced and g.ball.vel.dot(Sim.floor_normal(g.ball.pos.x,g.ball.pos.z))>0 and g.ball.pos.y>=Sim.floor_height(g.ball.pos.x,g.ball.pos.z)+Sim.BALL_RADIUS-.001
	check(bounced,"Ball rebounds from both real sloped road banks without penetration")
	var launched=true
	for pad in Sim.PADS:
		var g=fresh()
		g.players[1].pos=Vector3(pad.x,Sim.floor_height(pad.x,pad.z),pad.z)
		g.step(1.0/60)
		launched=launched and not g.players[1].grounded and g.players[1].vel.y>25 and g.players[1].jump_count==1
	check(launched,"All four unchanged boosters launch from raised physical terrain")
	for id in [1,4]:
		var g=fresh(id)
		var target: Vector3=g.hoop(id)
		g.players[id].pos=target+Vector3(0,-Sim.HOOP_Y,-signf(target.z)*3)
		g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
		g.secure_ball(id)
		g.action(id,"jump")
		for tick in 12: g.step(1.0/60)
		g.action(id,"dunk")
		for tick in 120:
			g.step(1.0/60)
			if g.baskets: break
		check(g.dunks==1 and g.baskets==1 and g.scores[g.team(id)]==1,"Real jumping dunk scores at hoop "+str(id),{"scores":g.scores,"dunks":g.dunks})
	var g=fresh()
	g.action(1,"jump")
	var peak=0.0
	for tick in 90:
		g.step(1.0/60)
		peak=maxf(peak,g.players[1].pos.y)
	check(peak>3.5 and peak<3.8 and g.players[1].grounded,"Ordinary center-court jump remains unchanged",{"apex":peak})
	var clear_count=0
	var false_clear=0
	var rng=RandomNumberGenerator.new()
	rng.seed=101064112
	g=fresh()
	g.players.clear()
	for i in 2000:
		var at=Vector3(rng.randf_range(-32,32),rng.randf_range(-1,10),rng.randf_range(-56,56))
		if not Sim.ball_clear_of_static_colliders(at): continue
		clear_count+=1
		g.ball={"pos":at,"vel":Vector3.ZERO,"owner":0,"last_touch":0,"pass_target":0,"lock":0.0}
		g.clock=rng.randf_range(0,8)
		g.ball_step(0)
		if g.ball.pos.distance_to(at)>.0001: false_clear+=1
	check(clear_count>500 and false_clear==0,"Forecast broad phase never skips a terrain/static contact",{"admitted":clear_count,"false_clear":false_clear})
	var began=Time.get_ticks_usec()
	var accumulator=0.0
	for i in 10000: accumulator+=Sim.floor_height(float(i%65)-32,float((i*17)%113)-56)
	var elapsed=Time.get_ticks_usec()-began
	var report={"passed":checks.all(func(row):return row.passed),"checks":checks,"height_query_microseconds_each":float(elapsed)/10000,"query_checksum":accumulator}
	if pack_source.is_empty():
		report["sim_sha256"]=FileAccess.get_sha256("res://sim.gd")
	else:
		report["pack_source"]=pack_source
		report["pack_sha256"]=FileAccess.get_sha256(pack_source)
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_V10_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
