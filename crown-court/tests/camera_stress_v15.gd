extends SceneTree
var Court = preload("res://world.gd")
var checks: Array=[]
var capture_dir=""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--baseline='): Court=load(arg.trim_prefix('--baseline='))
		if arg.begins_with('--capture-dir='): capture_dir=arg.trim_prefix('--capture-dir=')
	run.call_deferred()
func run():
	root.size=Vector2i(1280,800)
	var court = Court.new()
	root.add_child(court)
	court.camera = Camera3D.new()
	court.add_child(court.camera)
	for position in [Vector3(2,4,-55.5),Vector3(2,4,55.5),Vector3(31.5,4,2),Vector3(-31.5,4,2),Vector3(31.5,4,55.5),Vector3(-31.5,4,-55.5),Vector3(31.5,4,-55.5),Vector3(-31.5,4,55.5)]:
		var players={1:{"pos":position,"vel":Vector3.ZERO}}
		court.camera_ready=false
		var previous=Vector3.ZERO
		var peak=0.0
		var worst={}
		for i in 360:
			var yaw=-25.0-float(i)*.06
			court._update_camera(players,1,1.0/60,yaw,.43)
			var delta=court.camera.position.distance_to(previous)
			if i>0 and delta>peak:
				peak=delta
				worst={"yaw":yaw,"camera":str(court.camera.position),"previous":str(previous)}
			previous=court.camera.position
		checks.append({"label":"stationary wall yaw has no multi-metre collision cut","position":str(position),"pass":peak<1.5,"peak_m":peak,"worst":worst})
	if not capture_dir.is_empty():
		court.camera.free()
		court.build("coop")
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var sim=Court.Simulation.new()
		for scene in [{"name":"wall-grazing","pos":Vector3(2,4,-55.5),"yaw":-26.5},{"name":"wall-outward","pos":Vector3(2,4,-55.5),"yaw":PI},{"name":"corner-grazing","pos":Vector3(31.5,4,55.5),"yaw":-29.26},{"name":"corner-outward","pos":Vector3(31.5,4,55.5),"yaw":.7}]:
			sim.reset("coop")
			sim.players[1].pos=scene.pos
			sim.ball.pos=scene.pos+Vector3(0,1,-2)
			sim.ball.owner=0
			court.camera_ready=false
			for i in 90: court.present(sim.snapshot(),1,1.0/60,scene.yaw,.43)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join(scene.name+'.png'))
	print('CAMERA_STRESS_V15_RESULT ',JSON.stringify(checks))
	quit(0 if checks.all(func(c):return c.pass) else 1)
