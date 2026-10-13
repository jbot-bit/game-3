extends SceneTree
var app
var checks=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks.append({"passed":ok,"check":label})
	if not ok:printerr("FAIL ",label," prompt=",app.prompt_label.text)
func refresh():
	app.state=app.sim.snapshot()
	app.update_hud(.016)
func fixture():
	app.paused=false
	app._winner_shown=false
	app.sim.reset_time=0
	app.sim.winner=-1
	var p=app.sim.players[1]
	p.pos=Vector3(0,0,46)
	p.stun=0
	p.dunk=0
	p.dive=0
	p.cooldown=0
	p.jump_count=0
	p.grounded=true
	var q=app.sim.players[4]
	q.pos=Vector3(0,2,48)
	q.dunk=.95
	q.dunk_duration=.95
	q.guard=0
	q.team=1
	app.sim.ball.owner=4
func run():
	app=load("res://main.gd").new()
	app.manual_input_enabled=false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.muted=true
	app.practice_game("coop")
	fixture()
	refresh()
	check(app.prompt_label.visible and "block" in app.prompt_label.text and "Space" in app.prompt_label.text and "RMB" in app.prompt_label.text,"Nearby committed enemy dunk teaches keyboard counterplay")
	app.controller_device=7
	refresh()
	check("block" in app.prompt_label.text and "Bottom" in app.prompt_label.text and app.hud_key("RMB","RT") in app.prompt_label.text and not "Space" in app.prompt_label.text,"Controller counterplay uses active input glyphs")
	app.controller_device=-1
	for unavailable in ["stun","dunk","cooldown","dive","jumps","reset","paused","winner","ownball","teammate","far","high","late","guard"]:
		fixture()
		var p=app.sim.players[1]
		var q=app.sim.players[4]
		match unavailable:
			"stun":p.stun=.5
			"dunk":p.dunk=.5
			"cooldown":p.cooldown=.2
			"dive":p.dive=.2
			"jumps":
				p.grounded=false
				p.jump_count=2
			"reset":app.sim.reset_time=2
			"paused":app.paused=true
			"winner":app.sim.winner=0
			"ownball":app.sim.ball.owner=1
			"teammate":q.team=0
			"far":q.pos.x=10
			"high":q.pos.y=20
			"late":q.dunk=.3
			"guard":q.guard=1
		refresh()
		check(not app.prompt_label.visible or not "block" in app.prompt_label.text,"No impossible counterplay cue: "+unavailable)
		if unavailable=="stun":check(app.prompt_label.text=="Recovering","Recovery cue retains priority")
	fixture()
	app.sim.players[1].grounded=false
	app.sim.players[1].jump_count=1
	refresh()
	check("block" in app.prompt_label.text,"Available extra jump permits counterplay cue")
	fixture()
	app.sim.players[1].pos=Vector3(0,0,44)
	app.sim.players[4].pos=Vector3(0,2,46)
	app.sim.players[4].grounded=false
	app.sim.players[4].dunk=0
	app.sim.players[4].stun=0
	app.sim.action(4,"dunk")
	refresh()
	check(app.sim.players[4].dunk>0 and "block" in app.prompt_label.text,"Real opponent dunk action exposes counterplay opportunity")
	var note=app.pause_panel.find_child("Note",true,false)
	check("block" in note.text.to_lower() and "tackle" in note.text.to_lower(),"Controls panel teaches dunk counterplay")
	print("DUNK_COUNTER_HINT_RESULT ",JSON.stringify({"checks":checks,"failures":checks.filter(func(c):return not c.passed).size()}))
	app.queue_free()
	quit(0 if checks.all(func(c):return c.passed) else 1)
