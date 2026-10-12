extends SceneTree

var failures := 0
var checks := 0
var profile_path := ""

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label," ",detail if detail != null else "")

func run() -> void:
	var app = load("res://main.gd").new()
	profile_path = "user://review_v7_presentation_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.players = {1:app.sim.players[1]}
	var player: Dictionary = app.sim.players[1]
	player.pos = Vector3.ZERO
	player.vel = Vector3.ZERO
	player.move = Vector3.ZERO
	player.grounded = true
	player.boost_time = 0
	player.stun = 0
	player.dive = 0
	player.dunk = 0
	app.sim.ball.owner = 0
	app.sim.ball.pos = Vector3(8,1,0)
	app.local_direction = Vector3.RIGHT
	app.state = app.sim.snapshot()
	var immutable := var_to_bytes(app.state)
	var shown: Dictionary = app.predict_render_state(.05)
	expect(shown.players[1].pos.x > .01,"Local startup already predicts displacement",shown.players[1].pos)
	expect(shown.players[1].move == Vector3.RIGHT,"Local startup intent reaches the rendered rig before input acknowledgment",shown.players[1].move)
	app.sim.move_input(1,Vector3.RIGHT,Vector3.RIGHT)
	for frame in 3: app.sim.step(1.0/60)
	expect(shown.players[1].vel.distance_to(app.sim.players[1].vel) < .001,"Rendered startup velocity agrees with the predicted displacement",{"shown":shown.players[1].vel,"physical":app.sim.players[1].vel})
	expect(var_to_bytes(app.state) == immutable,"Presentation leaves snapshot intent and velocity immutable")
	app.world.present(shown,1,1.0/60,0,.43)
	expect(float(app.world.actors[1].get("scramble",0)) > .1,"Predicted client startup produces foot scramble immediately",app.world.actors[1].get("scramble",0))
	player.pos = Vector3.ZERO
	player.vel = Vector3.RIGHT*app.Sim.SPEED
	player.move = Vector3.RIGHT
	app.local_direction = Vector3.LEFT
	app.state = app.sim.snapshot()
	shown = app.predict_render_state(.05)
	app.world.present(shown,1,1.0/60,0,.43)
	expect(float(app.world.actors[1].get("skid",0)) > .1,"Predicted client reversal produces skid before input acknowledgment",app.world.actors[1].get("skid",0))
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	print("REVIEW V7 PRESENTATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
