extends SceneTree
## Production-surface probes for the shared0.11 geometry. No rendered or
## household-play claim; movement/rebounds run the actual authoritative Sim.
const Layout = preload("res://arena_layout.gd")
const Sim = preload("res://sim.gd")
var checks: Array = []
var evidence = "C:/game-3/build/crown-court-evidence/terrain-v11"

func check(ok: bool, label: String, detail = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+JSON.stringify(detail))

func fresh(id: int = 1):
	var game = Sim.new()
	game.reset("coop")
	game.players = {id:game.players[id]}
	game.reset_time = 0
	game.ball.pos = Vector3(0,12,0)
	game.ball.vel = Vector3.ZERO
	game.ball.lock = 0
	var player: Dictionary = game.players[id]
	player.vel = Vector3.ZERO
	player.grounded = true
	player.guard = 0
	player.pad_cooldown = 0
	game.reset_movement_state(player)
	return game

func walk(start: Vector3, direction: Vector3, frames: int) -> Dictionary:
	var game = fresh()
	var player: Dictionary = game.players[1]
	player.pos = start
	player.pos.y = Sim.floor_height(start.x,start.z)
	game.move_input(1,direction,direction)
	var clearance = 0.0
	var airborne = 0
	for tick in frames:
		game.step(1.0/60)
		clearance = maxf(clearance,absf(player.pos.y-Sim.floor_height(player.pos.x,player.pos.z)))
		if not player.grounded: airborne += 1
	return {"end":str(player.pos),"clearance":clearance,"airborne":airborne}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	var valid = true
	var agreement = 0.0
	var symmetry = 0.0
	var max_height = 0.0
	var min_normal_y = 1.0
	var lower_turf = 0
	var interior = 0
	for ix in 129:
		for iz in 225:
			var x = ix*.5-32
			var z = iz*.5-56
			var height = Layout.floor_height(x,z)
			var normal = Layout.floor_normal(x,z)
			valid = valid and is_finite(height) and height>=0 and height<=1.65001 and normal.is_finite() and absf(normal.length()-1)<.0001
			max_height = maxf(max_height,height)
			min_normal_y = minf(min_normal_y,normal.y)
			agreement = maxf(agreement,absf(height-Sim.floor_height(x,z)))
			symmetry = maxf(symmetry,absf(height-Layout.floor_height(-x,-z)))
			if absf(x)<28 and absf(z)<50:
				interior += 1
				if height<.08: lower_turf += 1
	check(valid and symmetry<.00001,"Shared shallow terrain remains finite bounded and mirrored",{"max_height":max_height,"minimum_normal_y":min_normal_y,"symmetry_error":symmetry})
	check(agreement<.00001,"Production simulation consumes the same arena surface",{"max_height_error":agreement})
	check(min_normal_y>.59,"Rounded physical shoulders avoid the old steep cliffs",{"minimum_normal_y":min_normal_y})
	var turf_fraction = float(lower_turf)/interior
	check(turf_fraction>.58,"Broad low green playfield remains between the narrowed connected routes",{"low_turf_fraction_inside_banks":turf_fraction})
	var crowns = true
	for at in [Vector2(21,0),Vector2(22,10),Vector2(20,21),Vector2(21,29),Vector2(12,43),Vector2(0,22),Vector2(0,38.5)]:
		crowns = crowns and absf(Layout.floor_height(at.x,at.y)-1.15)<.00001
	check(crowns,"Side routes crossing and rounded goal approaches retain1.15m crowns")
	var rotor_clear = true
	for center in Sim.HAZARDS:
		for i in 64:
			var at: Vector3 = center+Vector3(cos(i*TAU/64),0,sin(i*TAU/64))*Sim.HAZARD_RADIUS
			rotor_clear = rotor_clear and Layout.floor_height(at.x,at.z)<.00001
	check(rotor_clear,"All unchanged rotating hazard footprints remain on flat lower turf")
	for route in [[Vector3(14,0,0),Vector3.RIGHT,65],[Vector3(27,0,0),Vector3.LEFT,65],[Vector3(0,0,16),Vector3.BACK,65],[Vector3(22,0,33),Vector3.BACK,70],[Vector3(19,0,31),Vector3(1,0,1).normalized(),55]]:
		var movement = walk(route[0],route[1],route[2])
		check(movement.clearance<.025 and movement.airborne==0,"Ordinary running follows traversable shoulder "+str(route[0]),movement)
	var bounce = true
	for side in [-1,1]:
		var game = fresh()
		game.players.clear()
		var x = side*24.2
		game.ball.pos = Vector3(x,Sim.floor_height(x,0)+Sim.BALL_RADIUS-.02,0)
		game.ball.vel = Vector3(-5*side,-6,0)
		game.ball_step(1.0/180)
		bounce = bounce and game.ball.vel.dot(Sim.floor_normal(game.ball.pos.x,game.ball.pos.z))>0 and game.ball.pos.y>=Sim.floor_height(game.ball.pos.x,game.ball.pos.z)+Sim.BALL_RADIUS-.001
	check(bounce,"Physical ball rebounds from both shallow shoulders without penetration")
	var launch = true
	for pad in Sim.PADS:
		var game = fresh()
		game.players[1].pos = Vector3(pad.x,Sim.floor_height(pad.x,pad.z),pad.z)
		game.step(1.0/60)
		launch = launch and not game.players[1].grounded and game.players[1].vel.y>25 and game.players[1].jump_count==1
	check(launch,"All four unchanged launchers work on shared physical surface")
	for id in [1,4]:
		var game = fresh(id)
		var hoop: Vector3 = game.hoop(id)
		game.players[id].pos = hoop+Vector3(0,-Sim.HOOP_Y,-signf(hoop.z)*3)
		game.players[id].pos.y = Sim.floor_height(game.players[id].pos.x,game.players[id].pos.z)
		game.secure_ball(id)
		game.action(id,"jump")
		for tick in 12: game.step(1.0/60)
		game.action(id,"dunk")
		for tick in 150:
			game.step(1.0/60)
			if game.baskets: break
		check(game.dunks==1 and game.baskets==1,"Real jumping dunk keeps actual hoop opening accessible "+str(id),{"dunks":game.dunks,"baskets":game.baskets})
	var start = Time.get_ticks_usec()
	var checksum = 0.0
	for i in 10000: checksum += Layout.floor_height(float(i%65)-32,float((i*17)%113)-56)
	var elapsed = Time.get_ticks_usec()-start
	var report = {"passed":checks.all(func(row):return row.passed),"checks":checks,"layout_sha256":FileAccess.get_sha256("res://arena_layout.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd"),"probe_sha256":FileAccess.get_sha256(get_script().resource_path),"height_query_us_each":float(elapsed)/10000,"query_checksum":checksum,"physical_household_verified":false}
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_V11_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
