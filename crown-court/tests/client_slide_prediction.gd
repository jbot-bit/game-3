extends SceneTree
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run():
	var app=load("res://main.gd").new()
	app.manual_input_enabled=false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	for kind in ["dive","impact"]:
		for intent in [Vector3.ZERO,Vector3.BACK]:
			app.sim.reset_time=0
			app.sim.ball.owner=0
			app.sim.ball.lock=10
			for id in app.sim.players.keys():
				if id!=1:app.sim.players.erase(id)
			var p=app.sim.players[1]
			p.pos=Vector3.ZERO
			p.vel=Vector3.FORWARD*9
			p.grounded=true
			p.boost_time=0
			p.stun=0
			p.dive=0
			p.dunk=0
			p.slide_time=.4
			p.slide_kind=kind
			app.local_direction=intent
			app.state=app.sim.snapshot()
			var before=var_to_bytes(app.state)
			var shown=app.predict_render_state(.05)
			app.sim.move_input(1,intent,Vector3.FORWARD)
			for frame in 3:app.sim.step(1.0/60)
			check(shown.players[1].pos.distance_to(p.pos)<.001,"Client displacement agrees during "+kind+" slide "+str(intent))
			check(shown.players[1].vel.distance_to(p.vel)<.001,"Client velocity agrees during "+kind+" slide")
			check(absf(shown.players[1].slide_time-p.slide_time)<.001,"Client recovery countdown agrees with authority")
			check(var_to_bytes(app.state)==before,"Slide prediction leaves snapshot immutable")
	app.queue_free()
	print("CLIENT_SLIDE_RESULT 16 checks; ",failures," failures")
	quit(0 if failures==0 else 1)
