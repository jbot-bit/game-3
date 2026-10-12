extends SceneTree
## Controlled art/clearance probe. Same script/cameras run against preserved0.9
## and candidate0.10. Explicit scene fixtures; no gameplay or GPU-timing claim.
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var court
var sim
var evidence = "res://tests/arena-review"
var capture_enabled = false
var expect_scenery = false
var pack_source = ""
var checks: Array = []
var captures: Dictionary = {}
var metrics: Dictionary = {}
var face_cache: Dictionary = {}
var unchanged = true
var multimesh_transforms_available = true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
		if arg == "--capture": capture_enabled = true
		if arg == "--expect-scenery": expect_scenery = true
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed":ok,"check":label,"details":details})
	print("PASS " if ok else "FAIL ",label," ",details)

func faces_for(mesh: Mesh) -> PackedVector3Array:
	var id = mesh.get_instance_id()
	if not face_cache.has(id): face_cache[id] = mesh.get_faces()
	return face_cache[id]

func parts_under(branch: Node) -> Array:
	var parts: Array = []
	if branch == null: return parts
	for node in branch.find_children("*","GeometryInstance3D",true,false):
		if node is MeshInstance3D and node.mesh != null:
			parts.append({"node":node,"mesh":node.mesh,"transform":node.global_transform,"transform_known":true})
		elif node is MultiMeshInstance3D and node.multimesh != null:
			for index in node.multimesh.instance_count:
				parts.append({"node":node,"mesh":node.multimesh.mesh,"transform":node.global_transform*node.multimesh.get_instance_transform(index),"transform_known":multimesh_transforms_available})
	return parts

func probe_multimesh_readback() -> void:
	var mesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = BoxMesh.new()
	mesh.instance_count = 1
	var expected = Transform3D(Basis.IDENTITY,Vector3(91,37,-82))
	mesh.set_instance_transform(0,expected)
	var actual = mesh.get_instance_transform(0)
	multimesh_transforms_available = actual.is_equal_approx(expected)
	metrics["multimesh_readback"] = {"available":multimesh_transforms_available,"expected":str(expected),"actual":str(actual),"display":DisplayServer.get_name(),"limitation":"MultiMesh clearance is unavailable when the renderer does not retain transform readback. Native capture requires it."}
	if capture_enabled: check(multimesh_transforms_available,"Native renderer exposes actual MultiMesh transforms",metrics.multimesh_readback)

func asset_counts() -> Dictionary:
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var instances = 0
	var triangles = 0
	for part in parts_under(court):
		instances += 1
		meshes[part.mesh.get_instance_id()] = true
		triangles += faces_for(part.mesh).size()/3
		if part.node.material_override != null: materials[part.node.material_override.get_instance_id()] = true
	return {"scene_nodes":court.find_children("*","",true,false).size(),"mesh_instances_including_multimesh":instances,"unique_meshes":meshes.size(),"unique_override_materials":materials.size(),"instanced_triangles":triangles}

func terrain_agreement() -> void:
	var terrain: MeshInstance3D = null
	var largest = 0
	for node in court.arena.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		var bounds: AABB = node.get_aabb()
		if absf(bounds.size.x-64) > .01 or absf(bounds.size.z-112) > .01: continue
		var count = faces_for(node.mesh).size()
		if count > largest: terrain = node; largest = count
	if not check_terrain_exists(terrain): return
	var faces = faces_for(terrain.mesh)
	var max_vertex_error = 0.0
	var max_centroid_error = 0.0
	var worst = Vector3.ZERO
	var wrong_fronts = 0
	for index in range(0,faces.size(),3):
		# Godot uses clockwise front faces. An upward walkable front therefore
		# has a downward cross product, regardless of separately authored normals.
		var a: Vector3 = terrain.to_global(faces[index])
		var b: Vector3 = terrain.to_global(faces[index+1])
		var c: Vector3 = terrain.to_global(faces[index+2])
		if (b-a).cross(c-a).y >= 0: wrong_fronts += 1
		var center = Vector3.ZERO
		for offset in 3:
			var point: Vector3 = terrain.to_global(faces[index+offset])
			max_vertex_error = maxf(max_vertex_error,absf(point.y-Sim.floor_height(point.x,point.z)))
			center += point/3.0
		var error = absf(center.y-Sim.floor_height(center.x,center.z))
		if error > max_centroid_error: max_centroid_error = error; worst = center
	metrics["terrain"] = {"triangles":faces.size()/3,"wrong_front_faces":wrong_fronts,"max_vertex_error_m":max_vertex_error,"max_triangle_centroid_error_m":max_centroid_error,"worst_centroid":str(worst)}
	check(max_vertex_error < .001,"Actual terrain mesh vertices agree with physics",metrics.terrain)
	check(wrong_fronts == 0,"Walkable terrain fronts face upward with clockwise winding",{"wrong_front_faces":wrong_fronts,"triangles":faces.size()/3})
	# Interpolated facets need not equal a curved analytic surface. Record the
	# difference instead of hiding it inside an arbitrary art-change threshold.

func check_terrain_exists(terrain) -> bool:
	check(terrain != null,"Playable terrain mesh is found by actual court extent")
	return terrain != null

func clip_polygon(points: Array[Vector2], axis: int, boundary: float, keep_greater: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if points.is_empty(): return out
	var previous = points[-1]
	var previous_inside = previous[axis] >= boundary if keep_greater else previous[axis] <= boundary
	for point in points:
		var inside = point[axis] >= boundary if keep_greater else point[axis] <= boundary
		if inside != previous_inside:
			var weight = (boundary-previous[axis])/(point[axis]-previous[axis])
			out.append(previous.lerp(point,weight))
		if inside: out.append(point)
		previous = point
		previous_inside = inside
	return out

func scenery_clearance() -> void:
	var scenery = court.arena.get_node_or_null("StadiumScenery")
	if expect_scenery: check(scenery != null,"Candidate has the intended stadium scenery root")
	if scenery == null: metrics["scenery"] = {"present":false}; return
	var intrusions: Dictionary = {}
	var inspected = 0
	var degenerate = 0
	var unknown_instances = 0
	for part in parts_under(scenery):
		if not part.transform_known:
			unknown_instances += 1
			continue
		var bounds: AABB = part.transform*part.mesh.get_aabb()
		if bounds.end.x <= -32 or bounds.position.x >= 32 or bounds.end.z <= -56 or bounds.position.z >= 56: continue
		var faces = faces_for(part.mesh)
		for index in range(0,faces.size(),3):
			inspected += 1
			var a: Vector3 = part.transform*faces[index]
			var b: Vector3 = part.transform*faces[index+1]
			var c: Vector3 = part.transform*faces[index+2]
			# Primitive poles can contain zero-area triangles. They are not
			# visible surfaces; retain nondegenerate vertical faces in the test.
			if (b-a).cross(c-a).length_squared() < 0.000000000001:
				degenerate += 1
				continue
			var polygon: Array[Vector2] = []
			for offset in 3:
				var point: Vector3 = part.transform*faces[index+offset]
				polygon.append(Vector2(point.x,point.z))
			polygon = clip_polygon(polygon,0,-31.999,true)
			polygon = clip_polygon(polygon,0,31.999,false)
			polygon = clip_polygon(polygon,1,-55.999,true)
			polygon = clip_polygon(polygon,1,55.999,false)
			# A vertical wall projects to a line, but still intrudes into play.
			# The inset clip excludes mere contact with the outer boundary.
			if not polygon.is_empty():
				intrusions[str(part.node.get_path())] = {"triangle":[str(a),str(b),str(c)],"clipped":str(polygon),"instance_origin":str(part.transform.origin)}
				break
	var collision_nodes = scenery.find_children("*","CollisionObject3D",true,false).size()
	metrics["scenery"] = {"present":true,"possible_boundary_triangles_checked":inspected,"degenerate_triangles_skipped":degenerate,"unavailable_multimesh_instances":unknown_instances,"intruding_nodes":intrusions.keys(),"intrusions":intrusions,"collision_nodes":collision_nodes}
	check(intrusions.is_empty(),"Inspectable new scenery stays outside playable rectangle",metrics.scenery)
	check(collision_nodes == 0,"New scenery adds no hidden collision bodies")

func blocks_segment(start: Vector3, end: Vector3, parts: Array) -> bool:
	for part in parts:
		if not part.transform_known: continue
		var node: GeometryInstance3D = part.node
		if not node.is_visible_in_tree(): continue
		if node.material_override is StandardMaterial3D and node.material_override.albedo_color.a < .25: continue
		var inverse: Transform3D = part.transform.affine_inverse()
		var a: Vector3 = inverse*start
		var b: Vector3 = inverse*end
		if part.mesh.get_aabb().intersects_segment(a,b) == null: continue
		var faces = faces_for(part.mesh)
		for index in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2]) != null: return true
	return false

func goal_clearance() -> void:
	var scenery = parts_under(court.arena.get_node_or_null("StadiumScenery"))
	for goal in [Sim.NORTH,Sim.SOUTH]:
		var parts = scenery+parts_under(court.arena.get_node("NorthHoop" if goal.z < 0 else "SouthHoop"))
		var hits = 0
		for x in [-.3,0.0,.3]:
			for z in [-.3,0.0,.3]:
				if blocks_segment(goal+Vector3(x,1.2,z),goal+Vector3(x,-1.0,z),parts): hits += 1
		check(hits == 0,"Goal opening remains clear " + ("north" if goal.z < 0 else "south"),{"blocked_of_9":hits})

func set_camera(from: Vector3, target: Vector3) -> void:
	court.camera.position = from
	court.camera.look_at(target)
	court.camera_target = target
	court.camera.fov = 72.0
	court.camera.h_offset = 0
	court.camera.v_offset = 0

func shot(label: String, from: Vector3, target: Vector3) -> void:
	set_camera(from,target)
	var pose = str(court.camera.transform)
	if capture_enabled:
		await process_frame
		await RenderingServer.frame_post_draw
		var path = evidence.path_join(label+".png")
		root.get_texture().get_image().save_png(path)
		captures[label] = {"path":path,"sha256":FileAccess.get_sha256(path),"from":str(from),"target":str(target),"fov":72}
	check(pose == str(court.camera.transform),"Capture keeps prescribed camera " + label)

func prepare_actor(at: Vector3, giant: bool) -> void:
	sim.reset("coop")
	sim.reset_time = 0
	sim.players = {1:sim.players[1]}
	sim.players[1].pos = at
	sim.players[1].pos.y = maxf(at.y,Sim.floor_height(at.x,at.z))
	sim.players[1].vel = Vector3.ZERO
	sim.players[1].aim = Vector3.FORWARD
	sim.players[1].facing = Vector3.FORWARD
	sim.players[1].giant = 6.0 if giant else 0.0
	sim.ball.owner = 1
	sim.ball.pos = sim.hand_position(1)
	if court.actors.has(1): court.actors[1].initialized = false
	court.camera_ready = false
	for frame in 60:
		var state: Dictionary = sim.snapshot()
		var before = var_to_bytes(state)
		court.present(state,1,1.0/60,0,.43)
		unchanged = unchanged and before == var_to_bytes(state)
	check(court.actors.has(1) and court.camera_ready,"Actor and followed camera actually initialized")

func sightline(label: String, at: Vector3, giant: bool, from: Vector3, target: Vector3) -> void:
	prepare_actor(at,giant)
	set_camera(from,target)
	var pose = court.camera.transform
	for frame in 45: court._update_occluders(true,1.0/60)
	check(pose == court.camera.transform,"Occlusion never moves the fixed camera " + label)
	var parts = parts_under(court.arena.get_node("NorthHoop"))+parts_under(court.arena.get_node_or_null("StadiumScenery"))
	for kind in ["body","ball"]:
		var center: Vector3 = court.actors[1].body.global_position if kind == "body" else court.ball_root.global_position
		var hits = 0
		for x in [-.15,0.0,.15]:
			for y in [-.15,0.0,.15]:
				if blocks_segment(from,center+court.camera.global_basis.x*x+court.camera.global_basis.y*y,parts): hits += 1
		check(hits <= 1,label+" keeps followed "+kind+" visible",{"blocked_of_9":hits})
	await shot(label,from,target)

func sample_cost() -> void:
	var costs: Array[float] = []
	var gaps: Array[float] = []
	var draws: Array[float] = []
	var before = Time.get_ticks_usec()
	for frame in 90:
		await process_frame
		var now = Time.get_ticks_usec()
		if frame >= 15: gaps.append(float(now-before)/1000)
		before = now
		var start = Time.get_ticks_usec()
		court.present(sim.snapshot(),1,1.0/60,0,.43)
		if frame >= 15:
			costs.append(float(Time.get_ticks_usec()-start)/1000)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for rows in [costs,gaps,draws]: rows.sort()
	metrics["warm_follow"] = {"samples":costs.size(),"present_cpu_median_ms":costs[costs.size()/2],"present_cpu_p95_ms":costs[int(costs.size()*.95)],"frame_gap_median_ms":gaps[gaps.size()/2],"frame_gap_p95_ms":gaps[int(gaps.size()*.95)],"draw_calls_median":draws[draws.size()/2],"display":DisplayServer.get_name(),"scope":"Uncontrolled native CPU timers, process frame gaps and engine draw counters; no GPU timing or scheduling-cause claim. No screenshot readback inside samples."}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	probe_multimesh_readback()
	var start = Time.get_ticks_usec()
	court = World.new()
	root.add_child(court)
	court.build("coop")
	metrics["build_ms"] = float(Time.get_ticks_usec()-start)/1000
	sim = Sim.new()
	metrics["assets"] = asset_counts()
	terrain_agreement()
	scenery_clearance()
	goal_clearance()
	prepare_actor(Vector3(0,0,9),false)
	await shot("01-overview",Vector3(77,77,98),Vector3.ZERO)
	await shot("02-raised-routes",Vector3(8,8,29),Vector3(21,1,-4))
	await shot("03-padded-rotor",Vector3(-4,3.1,-3),Vector3(-11,.8,-10))
	await shot("04-open-basket",Vector3(7,6,-40),Vector3(0,4.6,-48))
	prepare_actor(Vector3(0,0,9),false)
	await shot("05-player-follow",court.camera.position,court.camera_target)
	await sample_cost()
	await sightline("06-rear-rim",Vector3(-.53,1.48,-44.63),false,Vector3(-2.36,6.91,-50.71),Vector3(.03,3.66,-44.03))
	await sightline("07-giant-rear-rim",Vector3(0,.7,-45.5),true,Vector3(-.6,6.5,-51.4),Vector3(0,3.2,-44.7))
	await sightline("08-through-backboard",Vector3(0,1,-44.5),false,Vector3(0,5.4,-50.4),Vector3(0,2,-44))
	await sightline("09-outside-goal-shell",Vector3(0,7.5,-54),false,Vector3(0,12.35,-60),Vector3(0,9.1,-52.9))
	check(unchanged,"Rendering does not mutate authority snapshots")
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"metrics":metrics,"captures":captures,"fixture":true,"physical_hardware_or_human_play":false,"pack_sha256":FileAccess.get_sha256(pack_source) if not pack_source.is_empty() else "","probe_sha256":FileAccess.get_sha256(get_script().resource_path),"version":ProjectSettings.get_setting("application/config/version"),"source_sha256":{"world":FileAccess.get_sha256("res://world.gd"),"sim":FileAccess.get_sha256("res://sim.gd")} if pack_source.is_empty() else {}}
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ARENA_REVIEW ",JSON.stringify(report))
	quit(0 if report.passed else 1)
