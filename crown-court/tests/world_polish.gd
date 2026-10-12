extends SceneTree

const Court = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var court
var sim
var captures: Dictionary = {}
var checks: Array = []
var telemetry: Array = []
var evidence = "C:/game-3/build/crown-court-evidence/v6-world-headless"
var capture_enabled = false
var unchanged = true
var yaw = 0.0
var pitch = .43
var pack_source = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"pass":ok,"label":label,"details":details})

func present(step = false) -> void:
	if step: sim.step(1.0 / 60)
	if sim.ball.owner > 0: sim.ball.pos = sim.hand_position(sim.ball.owner)
	var state: Dictionary = sim.snapshot()
	state.names = {1:"LOCAL PLAYER",2:"ALEX TEAMMATE",3:"SAM TEAMMATE",4:"RIVAL ONE",5:"RIVAL TWO",6:"RIVAL THREE"}
	var before = var_to_bytes(state)
	court.present(state,1,1.0 / 60,yaw,pitch)
	unchanged = unchanged and before == var_to_bytes(state)

func reset(at: Vector3) -> void:
	sim.reset("coop")
	sim.reset_time = 0.0
	sim.ball.lock = 0.0
	sim.ball.owner = 0
	for id in sim.players: sim.players[id].pos = Vector3(15,Sim.floor_height(15,id*3),id*3)
	sim.players[1].pos = at
	sim.players[1].aim = Vector3.FORWARD
	sim.players[1].facing = Vector3.FORWARD
	sim.ball.pos = at + Vector3(2,.8,-2)
	court.camera_ready = false
	yaw = 0
	pitch = .43
	for i in 45: present()

func capture(label: String) -> void:
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path = evidence.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	captures[label] = FileAccess.get_sha256(path)

func label_rect(actor: Dictionary) -> Rect2:
	var label: Label3D = actor.label
	var center: Vector2 = court.camera.unproject_position(label.global_position)
	var width = ThemeDB.fallback_font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x * label.pixel_size * label.scale.x
	var half_world = court.camera.global_basis.x * width * .5
	var left = court.camera.unproject_position(label.global_position-half_world)
	var right = court.camera.unproject_position(label.global_position+half_world)
	var pixels = maxf(10,absf(right.x-left.x))
	var font_edge: Vector2 = court.camera.unproject_position(label.global_position-court.camera.global_basis.y*label.font_size*label.pixel_size*label.scale.y)
	var height = maxf(14,font_edge.distance_to(center))
	return Rect2(center-Vector2(pixels*.5,height*.5),Vector2(pixels,height))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	court = Court.new()
	root.add_child(court)
	court.build("coop")
	sim = Sim.new()
	reset(Vector3(0,0,8))
	sim.ball.owner = 1
	for i in 60: present()
	sim.players[2].pos = Vector3(-3,0,3)
	sim.players[3].pos = Vector3(3,0,3)
	for i in 45: present()
	check(court.actors[2].label.visible and court.actors[3].label.visible,"separated nearby teammates retain visible names")
	var minimum_label_height := 1000.0
	for id in [2,3]:
		var label: Label3D = court.actors[id].label
		var center: Vector2 = court.camera.unproject_position(label.global_position)
		var font_edge: Vector2 = court.camera.unproject_position(label.global_position-court.camera.global_basis.y*label.font_size*label.pixel_size*label.scale.y*.75)
		minimum_label_height = minf(minimum_label_height,font_edge.distance_to(center))
	check(minimum_label_height >= 14.0,"visible nearby teammate names meet 14-pixel capital-height target",{"minimum_height_pixels":minimum_label_height})
	await capture("01-court-carry")
	check(not court.actors[1].label.visible,"local ring replaces redundant name above held ball")
	reset(Sim.NORTH+Vector3(0,-2,4))
	sim.players[1].grounded = false
	sim.players[1].vel = Vector3(0,6,-7)
	sim.ball.owner = 1
	sim.players[2].pos = sim.players[1].pos+Vector3(.35,0,-.45)
	sim.players[3].pos = sim.players[1].pos+Vector3(-.35,.10,-.7)
	for i in 40: present()
	var blocked = 0
	var visible_labels = 0
	var rects: Array[Rect2] = []
	var ball_center: Vector2 = court.camera.unproject_position(court.ball_root.global_position)
	var ball_radius = absf(court.camera.unproject_position(court.ball_root.global_position+court.camera.global_basis.x*Sim.BALL_RADIUS).x-ball_center.x)+7
	var ball_rect = Rect2(ball_center-Vector2.ONE*ball_radius,Vector2.ONE*ball_radius*2)
	for id in [2,3]:
		var label: Label3D = court.actors[id].label
		if not label.visible or label.modulate.a < .1: continue
		visible_labels += 1
		var rect = label_rect(court.actors[id])
		if rect.intersects(ball_rect): blocked += 1
		for other in rects:
			if rect.intersects(other): blocked += 1
		rects.append(rect)
	check(blocked == 0 and visible_labels > 0,"crowded labels avoid ball and retain useful identification",{"overlaps":blocked,"visible_remote_labels":visible_labels})
	await capture("02-crowded-rim")
	for id in sim.players.keys():
		if id != 1: sim.players.erase(id)
	sim.action(1,"dunk")
	var max_gap = 0.0
	for i in 105:
		present(true)
		if sim.ball.owner == 1:
			for key in ["left_hand","right_hand"]: max_gap = maxf(max_gap,court.actors[1][key].global_position.distance_to(court.ball_root.global_position))
		if i == 20: await capture("03-dunk-rise")
		if i == 44: await capture("04-dunk-hold")
		if i == 75: await capture("05-dunk-release")
	check(sim.baskets == 1 and max_gap < .82,"physical dunk and held hands survive pose pass",{"baskets":sim.baskets,"max_hand_center_gap":max_gap})
	reset(Sim.NORTH+Vector3(0,-Sim.HOOP_Y,8))
	sim.players[1].catch_time = .30
	sim.players[1].grounded = false
	sim.players[1].pos.y = 1.5
	sim.players[1].vel = Vector3(0,4,-3)
	for i in 15: present()
	check(court.actors[1].left_hand.position.z < -.45,"air catch extends hands toward play")
	await capture("06-air-catch")
	sim.players[1].catch_time = 0
	sim.players[1].dive = .40
	sim.players[1].vel = Vector3(0,0,-14)
	for i in 15: present()
	await capture("07-tackle")
	reset(Vector3(0,Sim.KICKOFF_Y,-Sim.KICKOFF_Z))
	sim.players[1].aim = Vector3.BACK
	sim.players[1].facing = Vector3.BACK
	yaw = PI
	court.camera_ready = false
	for i in 45: present()
	var previous: Vector3 = court.camera.position
	var max_step = 0.0
	for i in 170:
		sim.move_input(1,Vector3.BACK,Vector3.BACK)
		yaw = PI + (sin((i-90)/50.0*TAU)*.30 if i >= 90 and i <= 140 else 0.0)
		present(true)
		max_step = maxf(max_step,court.camera.position.distance_to(previous))
		previous = court.camera.position
		telemetry.append({"frame":i,"yaw":yaw,"pitch":pitch,"dt":1.0/60,"position":sim.players[1].pos,"camera":court.camera.position,"target":court.camera_target,"distance":court.camera_distance})
		if i == 85: await capture("08-deck-drop")
	check(max_step < 1.0,"fixed-pitch deck descent has no unexplained camera cut",{"maximum_per_frame_m":max_step})
	check(unchanged,"presentation leaves authoritative input bytes unchanged")
	var report = {"fixtures":true,"checks":checks,"failures":checks.filter(func(c):return not c.pass),"captures":captures,"telemetry":telemetry,"world_sha256":FileAccess.get_sha256("res://world.gd") if FileAccess.file_exists("res://world.gd") else "","sim_sha256":FileAccess.get_sha256("res://sim.gd") if FileAccess.file_exists("res://sim.gd") else "","probe_sha256":FileAccess.get_sha256(get_script().resource_path)}
	if not pack_source.is_empty(): report["pack_sha256"] = FileAccess.get_sha256(pack_source)
	var file = FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("WORLD_POLISH_RESULT ",JSON.stringify({"checks":checks,"failures":report.failures.size(),"captures":captures}))
	quit(0 if report.failures.is_empty() else 1)
