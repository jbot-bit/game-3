extends SceneTree
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var world
var sim
var evidence := "C:/game-3/build/crown-court-evidence/v9-court-render"
var captures := {}
var checks: Array = []
var capture_enabled := false
var pack_source := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func shot(label: String, from: Vector3, target: Vector3) -> void:
	if not capture_enabled: return
	world.camera.position = from
	world.camera.look_at(target)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	sim = Sim.new()
	sim.reset("coop")
	sim.reset_time = 0
	sim.players[1].pos = Vector3(0,0,9)
	sim.players[1].grounded = true
	sim.ball.owner = 1
	sim.ball.pos = sim.hand_position(1)
	var endpoint_error := 0.0
	var immutable := true
	for time in [0.0,.7,2.5,8.0]:
		sim.clock = time
		var snapshot: Dictionary = sim.snapshot()
		var bytes := var_to_bytes(snapshot)
		for frame in 35: world.present(snapshot,1,1.0/60,0,.43)
		immutable = immutable and bytes == var_to_bytes(snapshot)
		for index in Sim.HAZARDS.size():
			var node: Node3D = world.hazard_visuals[index].node
			var endpoints: Array[Vector3] = Sim.hazard_endpoints(index,time)
			endpoint_error = maxf(endpoint_error,node.to_global(Vector3(-Sim.HAZARD_RADIUS,0,0)).distance_to(endpoints[0]))
			endpoint_error = maxf(endpoint_error,node.to_global(Vector3(Sim.HAZARD_RADIUS,0,0)).distance_to(endpoints[1]))
	checks.append({"pass":endpoint_error<.001,"name":"visible rotating bar centerline matches simulated contact segment over four clock samples","max_endpoint_error_m":endpoint_error})
	checks.append({"pass":immutable,"name":"presentation leaves authority snapshot unchanged"})
	checks.append({"pass":world.booster_visuals.size()==Sim.PADS.size()+Sim.SPEED_PADS.size(),"name":"all canonical launchers and speed strips are visible"})
	checks.append({"pass":Sim.HALF_WIDTH==32 and Sim.HALF_LENGTH==56 and absf(Sim.NORTH.z)==48,"name":"agreed64x112court and96m goal separation"})
	var opening_hits := 0
	for node in world.arena.get_node("NorthHoop/PaddedBackboard").find_children("*","MeshInstance3D",true,false):
		var faces: PackedVector3Array = node.mesh.get_faces()
		for x in [-.1,0.0,.1]:
			for z in [-.2,0.0,.2]:
				var top: Vector3 = node.to_local(Sim.NORTH+Vector3(x,1,z))
				var bottom: Vector3 = node.to_local(Sim.NORTH+Vector3(x,-1,z))
				for index in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(top,bottom,faces[index],faces[index+1],faces[index+2])!=null:
						opening_hits += 1
						break
	checks.append({"pass":opening_hits==0,"name":"visible backboard supports leave the scoring opening clear","vertical_opening_ray_hits":opening_hits})
	await shot("01-overview",Vector3(77,77,98),Vector3(0,0,0))
	await shot("02-raised-routes",Vector3(8,8,29),Vector3(21,1,-4))
	await shot("03-padded-rotor",Vector3(-4,3.1,-3),Vector3(-11,.8,-10))
	await shot("04-open-basket",Vector3(7,6,-40),Sim.NORTH)
	var result := {"fixture":true,"checks":checks,"failures":checks.filter(func(row):return not row.pass),"captures":captures,"world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd")}
	if not pack_source.is_empty():
		result["pack_sha256"] = FileAccess.get_sha256(pack_source)
		result["world_sha256"] = ""
		result["sim_sha256"] = ""
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COURT_V9 ",JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
