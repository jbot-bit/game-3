extends SceneTree
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var court
var sim
var checks: Array = []
var captures := {}
var evidence := "C:/game-3/build/crown-court-evidence/v9-world-visibility-after"
var capture_enabled := false
var pack_source := ""
var unchanged := true
var face_cache := {}
var camera_unchanged := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"pass":ok,"label":label,"details":details})
	print("VISIBILITY_CHECK ",label," ",ok)

func capture(label: String) -> void:
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func prepare(at: Vector3, giant: bool, camera_at: Vector3, look_at: Vector3) -> void:
	# Preserve the old repro's offsets relative to the actual basket after any
	# canonical arena resize; an empty old hoop location would be a false pass.
	var goal_shift := Sim.NORTH.z+31.0
	at.z += goal_shift
	camera_at.z += goal_shift
	look_at.z += goal_shift
	if is_equal_approx(camera_at.z,-32.25+goal_shift): camera_at.z = -Sim.BACKBOARD_Z
	sim.reset("coop")
	sim.players = {1:sim.players[1]}
	sim.reset_time = 0
	sim.players[1].pos = at
	sim.players[1].vel = Vector3.ZERO
	sim.players[1].aim = Vector3.FORWARD
	sim.players[1].facing = Vector3.FORWARD
	sim.players[1].giant = 6.0 if giant else 0.0
	sim.ball.owner = 1
	if court.actors.has(1): court.actors[1].initialized = false
	court.camera_ready = false
	for i in 60:
		sim.ball.pos = sim.hand_position(1)
		var state: Dictionary = sim.snapshot()
		var before := var_to_bytes(state)
		court.present(state,1,1.0/60,PI+.34,.43)
		unchanged = unchanged and before == var_to_bytes(state)
	court.camera.position = camera_at
	court.camera_target = look_at
	court.camera.look_at(look_at)
	court.camera.h_offset = 0
	court.camera.v_offset = 0
	var camera_transform: Transform3D = court.camera.transform
	for i in 45: court._update_occluders(true,1.0/60)
	camera_unchanged = camera_unchanged and camera_transform == court.camera.transform

func faces_for(mesh: Mesh) -> PackedVector3Array:
	var key := mesh.get_instance_id()
	if not face_cache.has(key): face_cache[key] = mesh.get_faces()
	return face_cache[key]

func geometry() -> Array:
	var result: Array = []
	var hoop: Node3D = court.arena.get_node("NorthHoop")
	for node in hoop.find_children("*","GeometryInstance3D",true,false):
		var material = node.material_override
		if material is StandardMaterial3D and material.albedo_color.a < .25: continue
		if node is MeshInstance3D:
			result.append({"faces":faces_for(node.mesh),"transform":node.global_transform})
		elif node is MultiMeshInstance3D:
			var mesh: MultiMesh = node.multimesh
			for index in mesh.instance_count:
				result.append({"faces":faces_for(mesh.mesh),"transform":node.global_transform*mesh.get_instance_transform(index)})
	return result

func blocked_rays(target: Vector3) -> int:
	var parts := geometry()
	var blocked := 0
	for x in [-.15,0.0,.15]:
		for y in [-.15,0.0,.15]:
			var end: Vector3 = target + court.camera.global_basis.x*x + court.camera.global_basis.y*y
			var hit := false
			for part in parts:
				var transform: Transform3D = part.transform
				var a: Vector3 = transform.affine_inverse()*court.camera.position
				var b: Vector3 = transform.affine_inverse()*end
				var faces: PackedVector3Array = part.faces
				for index in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2]) != null:
						hit = true
						break
				if hit: break
			if hit: blocked += 1
	return blocked

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	court = World.new()
	root.add_child(court)
	court.build("coop")
	sim = Sim.new()
	# Recorded 0.7 rear-rim view at about 98.4 driver seconds motivates this
	# controlled static view. It is a reproduction fixture, not a replay.
	prepare(Vector3(-.53,1.48,-27.63),false,Vector3(-2.36,6.91,-33.71),Vector3(.03,3.66,-27.03))
	var body: Vector3 = court.actors[1].body.global_position
	var body_blocks := blocked_rays(body)
	var ball_blocks := blocked_rays(court.ball_root.global_position)
	check(body_blocks <= 1,"rear-rim structure does not hide the followed player's torso",{"blocked_of_9":body_blocks})
	check(ball_blocks <= 1,"rear-rim structure does not hide the carried ball",{"blocked_of_9":ball_blocks})
	var solid_faces := 0
	var total_faces := 0
	for part in court.hoop_lights:
		if part.global_position.z >= 0: continue
		var count: int = faces_for(part.mesh).size()
		total_faces += count
		if part.material_override.albedo_color.a > .95: solid_faces += count
	check(total_faces > 0 and float(solid_faces)/total_faces >= .25,"clearing the view retains a solid portion of the rim",{"opaque_triangle_fraction":float(solid_faces)/maxi(1,total_faces)})
	await capture("01-rear-rim")
	prepare(Vector3(0,.7,-28.5),true,Vector3(-.6,6.5,-34.4),Vector3(0,3.2,-27.7))
	body_blocks = blocked_rays(court.actors[1].body.global_position)
	ball_blocks = blocked_rays(court.ball_root.global_position)
	check(body_blocks <= 1 and ball_blocks <= 1,"Giant carry remains readable through foreground rim and net",{"body_blocked_of_9":body_blocks,"ball_blocked_of_9":ball_blocks})
	await capture("02-giant-rear-rim")
	prepare(Vector3(0,1,-27.5),false,Vector3(0,5.4,-32.25),Vector3(0,2,-27))
	check(blocked_rays(court.actors[1].body.global_position) <= 1,"backboard camera intersection keeps the player readable")
	await capture("03-through-backboard")
	prepare(Vector3(0,0,-23),false,Vector3(0,5,-16),Vector3(0,1.6,-24))
	var opaque := 0
	for node in court.arena.get_node("NorthHoop").find_children("*","GeometryInstance3D",true,false):
		if node.material_override is StandardMaterial3D and node.material_override.albedo_color.a > .95: opaque += 1
	check(opaque > 4,"unobstructed goal retains solid aiming structure",{"opaque_parts":opaque})
	await capture("04-clear-approach")
	for i in 60: court._update_occluders(false,1.0/60)
	var restored := true
	for entry in court.occluders: restored = restored and float(entry.opacity) > .995
	check(restored,"overview restores all arena structure")
	check(camera_unchanged,"visibility leaves camera position and aim unchanged")
	check(unchanged,"visibility never mutates input snapshots")
	var report := {"fixtures":true,"checks":checks,"failures":checks.filter(func(c):return not c.pass),"captures":captures,"probe_sha256":FileAccess.get_sha256(get_script().resource_path),"world_sha256":"" if not pack_source.is_empty() else FileAccess.get_sha256("res://world.gd"),"pack_sha256":FileAccess.get_sha256(pack_source) if not pack_source.is_empty() else ""}
	var file := FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("WORLD_VISIBILITY_RESULT ",JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
