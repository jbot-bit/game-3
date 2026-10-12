extends SceneTree
const Court = preload("res://world.gd")
var checks: Array = []
func _initialize():
	run.call_deferred()
func run():
	root.size=Vector2i(1280,800)
	var court = Court.new()
	root.add_child(court)
	court.camera = Camera3D.new()
	court.add_child(court.camera)
	var players = {1:{"pos":Vector3(17,16,-55.3),"vel":Vector3(0,-20,0)}}
	var peak = 0.0
	var previous = Vector3.ZERO
	for i in 180:
		players[1].pos.y = maxf(0,16-float(i)/60*12)
		court._update_camera(players,1,1.0/60,PI+.24,.43)
		if i > 0:
			var jump = court.camera.position.distance_to(previous)
			if jump > 1: print('JUMP ',i,' ',previous,' -> ',court.camera.position, ' target ',court.camera_target)
			peak = maxf(peak,jump)
		previous = court.camera.position
	checks.append({"label":"back-wall descent retracts without a tier cut","pass":peak<1.0,"max_step_m":peak})
	var violations = 0
	for height in range(1,34):
		for angle in 72:
			var target = Vector3(17,height,-55)
			var wanted = target+Vector3(sin(angle*TAU/72),.45,cos(angle*TAU/72))*10
			var clear = court._clear_stadium_boom(target,wanted)
			for step in range(1,41):
				var point = target.lerp(clear,float(step)/40)
				var outside = Vector2(maxf(0,absf(point.x)-Court.Simulation.HALF_WIDTH),maxf(0,absf(point.z)-Court.Simulation.HALF_LENGTH)).length()
				var envelope = .30
				if point.y>10.9: envelope=8.3
				if point.y>19.4: envelope=16.3
				if point.y>29.5: envelope=1000
				if outside>envelope+.001: violations+=1
	checks.append({"label":"swept booms stay inside stadium envelope","pass":violations==0,"violations":violations})
	players[1].pos = Vector3.ZERO
	players[1].vel = Vector3.ZERO
	court.camera_ready=false
	court._update_camera(players,1,1.0/60,0,.43)
	court._update_camera(players,1,1.0/60,PI/2,.43)
	var direction = court.camera.position-court.camera_target
	checks.append({"label":"manual yaw remains immediate","pass":direction.x>0 and absf(direction.z)<.001})
	var focus = Vector3(0,18,-1)
	court.camera_ready=false
	for i in 90: court._update_camera(players,1,1.0/60,0,.43,{"ball_camera":true,"camera_focus":focus})
	var feet = court.camera.unproject_position(Vector3.ZERO)
	var ball = court.camera.unproject_position(focus)
	checks.append({"label":"ball camera frames feet and an 18m ball","pass":feet.y>32 and feet.y<768 and ball.y>32 and ball.y<768,"feet_y":feet.y,"ball_y":ball.y})
	players[1].pos=Vector3(5,7.5,54)
	court._update_camera(players,1,1.0/60,0,.43)
	checks.append({"label":"long kickoff relocation still snaps to new seat","pass":court.camera_target.distance_to(players[1].pos)<2.1})
	print("CAMERA_V14_RESULT ",JSON.stringify(checks))
	quit(0 if checks.all(func(c):return c.pass) else 1)
