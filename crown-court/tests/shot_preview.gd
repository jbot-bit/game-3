extends SceneTree

var app
var checks = 0
var failures = 0
var maximum_preview_ms = 0.0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	app = load("res://main.gd").new()
	app.manual_input_enabled = false
	app.selected_mode = "coop"
	app.local_seat = 1
	app.sim.reset("coop")
	app.sim.reset_time = 0
	app.sim.ball.owner = 1
	app.last_aim = Vector3.FORWARD
	app.charging = true
	for height in [0.0,18.0]:
		for power in [0.0,1.0]:
			verify("14m height%.0f charge%.0f" % [height,power],app.Sim.NORTH+Vector3(0,height-app.Sim.HOOP_Y,14),Vector3.FORWARD,power)
	verify("Full-court lob",Vector3(0,0,app.Sim.SOUTH.z),Vector3.FORWARD,1)
	verify("Airborne full-court lob",Vector3(0,25,app.Sim.SOUTH.z),Vector3.FORWARD,1)
	verify("Own-basket crossing",app.Sim.SOUTH+Vector3(0,-app.Sim.HOOP_Y,-14),Vector3.BACK,(14.0-.7-6.0)/(app.Sim.HALF_LENGTH*2-10))
	verify("Behind backboard",Vector3(0,1.5,-app.Sim.BACKBOARD_Z-1.2),Vector3.BACK,0)
	verify("Low shot into front rim",app.Sim.NORTH+Vector3(0,-2.0,3.1),Vector3.FORWARD,0)
	if app.Sim.get_script_constant_map().has("HAZARDS"):
		verify("Descending shot toward sweeper",app.Sim.HAZARDS[0]+Vector3(0,0,10),Vector3.FORWARD,0)
	app.free()
	print("SHOT PREVIEW: %d checks, %d failures, maximum forecast %.3f ms" % [checks,failures,maximum_preview_ms])
	quit(1 if failures else 0)

func verify(label: String, position: Vector3, aim: Vector3, power: float) -> void:
	app.sim.reset("coop")
	app.sim.reset_time = 0
	app.sim.players = {1:app.sim.players[1]}
	position.y = maxf(position.y,app.Sim.floor_height(position.x,position.z))
	app.sim.players[1].pos = position
	app.sim.players[1].aim = aim
	app.sim.ball.owner = 1
	app.last_aim = aim
	app.state = app.sim.snapshot()
	app.charge_time = power*1.15
	var before: PackedByteArray = var_to_bytes(app.state)
	var started = Time.get_ticks_usec()
	var points: PackedVector3Array = app.trajectory_preview()
	var preview_ms = float(Time.get_ticks_usec()-started)/1000
	maximum_preview_ms = maxf(maximum_preview_ms,preview_ms)
	# Execute an actual throw then its real three substeps per tick. Stop on the
	# first real collision or goal event; compare the preview to this recorded path.
	app.sim.action(1,"throw",power)
	var initial_event = app.sim.event_id
	var path = PackedVector3Array()
	for step in 720:
		if step%3 == 0: app.sim.clock += 1.0/60
		app.sim.ball_step(1.0/180)
		path.append(app.sim.ball.pos)
		if app.sim.event_id != initial_event: break
	var error = 0.0
	for point in points:
		var nearest = INF
		for recorded in path: nearest = minf(nearest,point.distance_to(recorded))
		error = maxf(error,nearest)
	check(not points.is_empty() and points[-1].distance_to(path[-1])<.002,label+": stops at actual first contact or scoring crossing")
	check(error<.002 and points.size()<=36 and var_to_bytes(app.state)==before,label+": samples actual throw path without mutating received state")
	print("PREVIEW_DETAIL ",JSON.stringify({"case":label,"error_m":error,"forecast_end":points[-1] if not points.is_empty() else Vector3.ZERO,"actual_end":path[-1],"event":app.sim.event_kind,"duration":path.size()/180.0,"dots":points.size(),"preview_ms":preview_ms}))
