extends SceneTree

const Sim = preload("res://sim.gd")
const App = preload("res://main.gd")
var checks: Array = []
var evidence = "C:/game-3/build/crown-court-evidence/dunk-aim"
var pack_source = ""

func check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+JSON.stringify(detail))

func probe(id: int, angle: float, giant: bool, action_input: bool) -> void:
	var app = App.new()
	var g = app.sim
	g.reset("coop")
	g.players = {id:g.players[id]}
	g.reset_time = 0
	g.ball.lock = 0
	var p: Dictionary = g.players[id]
	var target: Vector3 = g.hoop(id)
	var outward = Vector3(sin(angle),0,cos(angle))
	p.pos = target+outward*4
	p.pos.y = Sim.floor_height(p.pos.x,p.pos.z)+2
	p.vel = -outward*8+Vector3.UP*3
	p.aim = -outward
	p.grounded = false
	p.jump_count = 1
	p.guard = 0
	p.giant = 7.0 if giant else 0.0
	g.secure_ball(id)
	g.action(id,"dunk")
	var started: bool = p.dunk>0
	var locked_axis: Vector3 = p.aim
	var max_hand_shift = 0.0
	var max_axis_error = 0.0
	var release_radius = -1.0
	var release_time = -1.0
	var score = 0
	for tick in 180:
		var held: bool = g.ball.owner==id
		var old_hand: Vector3 = g.hand_position(id)
		# Reproduce camera-facing traffic: an opposing yaw followed by continual
		# changes, including the reliable action path which carries fresh aim.
		var input_aim = -locked_axis.rotated(Vector3.UP,tick*.07)
		if action_input: app.host_action(id,"catch",.5,input_aim,Vector3.RIGHT)
		else: g.move_input(id,Vector3.RIGHT,input_aim)
		if p.dunk>0:
			max_hand_shift=maxf(max_hand_shift,old_hand.distance_to(g.hand_position(id)))
			max_axis_error=maxf(max_axis_error,locked_axis.distance_to(p.aim))
		g.step(1.0/60)
		if held and g.ball.owner==0 and release_radius<0:
			release_radius=g.flat_distance(g.ball.pos,target)
			release_time=(tick+1)/60.0
		if g.baskets>0: score=g.baskets
		if p.dunk<=0 and (score>0 or tick>120): break
	var label="team%d angle%.0f giant%s via%s"%[g.team(id),rad_to_deg(angle),giant,"action" if action_input else "move"]
	check(started and score==1 and release_radius>=0 and release_radius<.41 and max_hand_shift<.001 and max_axis_error<.001,"Dunk stays aligned and physically scores despite input "+label,{"started":started,"score":score,"release_radius":release_radius,"release_seconds":release_time,"input_only_hand_shift":max_hand_shift,"axis_error":max_axis_error})
	g.move_input(id,Vector3.LEFT,Vector3.LEFT)
	check(p.dunk<=0 and p.aim.distance_to(Vector3.LEFT)<.001,"Ordinary aim resumes after dunk "+label)
	app.free()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source=arg.trim_prefix("--pack-source=")
	for id in [1,4]:
		for angle in [0.0,PI*.5,PI,PI*1.5]:
			for giant in [false,true]:
				for action_input in [false,true]: probe(id,angle,giant,action_input)
	var report={"passed":checks.all(func(row):return row.passed),"checks":checks}
	if pack_source.is_empty(): report["sim_sha256"]=FileAccess.get_sha256("res://sim.gd")
	else:
		report["pack_source"]=pack_source
		report["pack_sha256"]=FileAccess.get_sha256(pack_source)
	DirAccess.make_dir_recursive_absolute(evidence)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DUNK_AIM_RESULT "+JSON.stringify({"passed":report.passed,"checks":checks.size(),"failed":checks.filter(func(row):return not row.passed).size()}))
	quit(0 if report.passed else 1)
