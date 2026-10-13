extends SceneTree
var failures = 0
var checks = 0
func check(ok: bool, label: String, details = null):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label," ",details)
func _initialize(): run.call_deferred()
func run():
	var app = load("res://main.gd").new()
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	for outward in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		for state_kind in ["running","sliding","airborne","stunned"]:
			for age in [1.0/60,.05,.08]:
				app.sim.reset("coop")
				app.sim.reset_time = 0
				app.sim.players = {1:app.sim.players[1]}
				var p = app.sim.players[1]
				p.pos = outward*(app.Sim.HALF_WIDTH-.5 if outward.x != 0 else app.Sim.HALF_LENGTH-.5)
				p.pos.y = app.Sim.floor_height(p.pos.x,p.pos.z)
				p.vel = outward*9
				p.move = outward
				p.pad_cooldown = 10
				p.hazard_cooldown = 10
				if state_kind == "sliding": p.slide_time = .4
				if state_kind in ["airborne","stunned"]:
					p.pos.y += 5
					p.grounded = false
					p.vel.y = 3
				if state_kind == "stunned": p.stun = .3
				app.local_direction = outward
				app.state = app.sim.snapshot()
				app.player_render_history.clear()
				app.visual_jump_started = -1
				app.visual_y_correction = 0
				var before = var_to_bytes(app.state)
				var shown = app.predict_render_state(age)
				check(shown.players[1].vel.dot(outward) <= .001,"Wall prediction removes blocked outward velocity",[outward,state_kind,age,shown.players[1].vel])
				check(var_to_bytes(app.state) == before,"Wall prediction leaves authority immutable")
	# Remote airborne copies keep wall-tangent and inward motion while blocking penetration.
	app.local_seat = 2
	for outward in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var tangent = Vector3(-outward.z,0,outward.x)
		for direction in [outward,-outward]:
			app.sim.reset("coop")
			app.sim.reset_time = 0
			app.sim.players = {1:app.sim.players[1]}
			var p = app.sim.players[1]
			p.pos = outward*(app.Sim.HALF_WIDTH-.5 if outward.x != 0 else app.Sim.HALF_LENGTH-.5)+Vector3.UP*12
			p.vel = direction*9+tangent*4+Vector3.UP*3
			p.grounded = false
			app.state = app.sim.snapshot()
			app.player_render_history.clear()
			var before = var_to_bytes(app.state)
			var shown = app.predict_render_state(.05)
			check(absf(shown.players[1].vel.dot(tangent)-4)<.001,"Remote wall glide preserves tangent speed")
			check(absf(shown.players[1].vel.dot(outward)-(0.0 if direction==outward else -9.0))<.001,"Remote wall contact preserves inward escape")
			check(var_to_bytes(app.state)==before,"Remote wall prediction leaves authority immutable")
	app.local_seat = 1
	# Local turn reaches a wall on its first substep, then should move away.
	for outward in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		app.sim.reset("coop")
		app.sim.reset_time = 0
		app.sim.players = {1:app.sim.players[1]}
		var p = app.sim.players[1]
		p.pos = outward*(app.Sim.HALF_WIDTH-.51 if outward.x != 0 else app.Sim.HALF_LENGTH-.51)
		p.pos.y = app.Sim.floor_height(p.pos.x,p.pos.z)
		p.vel = outward*2
		p.pad_cooldown = 10
		p.hazard_cooldown = 10
		app.local_direction = -outward
		app.sim.move_input(1,-outward,-outward)
		app.state = app.sim.snapshot()
		app.player_render_history.clear()
		var shown = app.predict_render_state(.05)
		for i in 3: app.sim.step(1.0/60)
		check(Vector2(shown.players[1].pos.x-p.pos.x,shown.players[1].pos.z-p.pos.z).length()<.001,"Prediction handles boundary in each traction substep",[shown.players[1].pos,p.pos])
		check(shown.players[1].vel.distance_to(p.vel)<.001,"Wall departure velocity agrees with authority")
	app.queue_free()
	print("CLIENT_WALL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
