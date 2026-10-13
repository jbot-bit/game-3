extends SceneTree
const Court=preload("res://world.gd")
var checks=[]
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(1280,800)
	var court=Court.new()
	root.add_child(court)
	court.camera=Camera3D.new()
	court.add_child(court.camera)
	for side in [-1,1]:
		var hoop=Vector3(0,Court.Simulation.HOOP_Y,side*48)
		var players={1:{"pos":Vector3(0,0,side*43),"vel":Vector3.ZERO}}
		var yaw=0.0 if side<0 else PI
		court.camera_ready=false
		for i in 120: court._update_camera(players,1,1.0/60,yaw,.43)
		var top=court.camera.unproject_position(hoop+Vector3.UP*.28)
		var feet=court.camera.unproject_position(players[1].pos)
		for height in [1.7,2.164]:
			var head=court.camera.unproject_position(players[1].pos+Vector3.UP*height)
			checks.append({"label":"near hoop clears HUD and preserves standing body","side":side,"height":height,"pass":top.y>=130 and feet.y<=700 and head.y>=130,"rim_y":top.y,"feet_y":feet.y,"head_y":head.y})
		var direction=court.camera.position-court.camera_target
		checks.append({"label":"framing preserves manual aim yaw","pass":absf(direction.x)<.001 and signf(direction.z)==-side})
	var players={1:{"pos":Vector3(0,0,-30),"vel":Vector3(0,0,-6)}}
	court.camera_ready=false
	var previous=Vector3.ZERO
	var peak=0.0
	for i in 300:
		players[1].pos.z=-30-float(i)*.05
		court._update_camera(players,1,1.0/60,0,.43)
		if i>0:peak=maxf(peak,court.camera.position.distance_to(previous))
		previous=court.camera.position
	checks.append({"label":"near-hoop approach has no camera cut","pass":peak<.25,"peak_m":peak})
	for mode in ["depart", "turn away"]:
		players[1].pos=Vector3(0,0,-43 if mode=="turn away" else -45)
		court.camera_ready=false
		previous=Vector3.ZERO
		peak=0.0
		for i in 300:
			if mode=="depart":players[1].pos.z=-45+float(i)*.05
			court._update_camera(players,1,1.0/60,float(i)*.01 if mode=="turn away" else 0.0,.43)
			if i>0:peak=maxf(peak,court.camera.position.distance_to(previous))
			previous=court.camera.position
		checks.append({"label":"near-hoop "+mode+" fades without a cut","pass":peak<.25,"peak_m":peak})
	print('HOOP_CAMERA_RESULT ',JSON.stringify(checks))
	quit(0 if checks.all(func(c):return c.pass) else 1)
