extends SceneTree
## Actual controller flow with accelerated manual ticks and authored travel fixtures.
## Timing/poses are test inputs; this is not hands-on play or a balance measurement.
const Game=preload("res://game/main.gd")
var app: Node3D
var checks: int=0
var sequence: int=0

func _initialize() -> void: call_deferred("_run")

func _check(value: bool,label: String) -> bool:
	checks+=1
	if not value:
		push_error("CONTROLLER_FLOW_FAIL "+label)
		quit(1)
		return false
	return true

func _send(action: String,payload: Dictionary={}) -> void:
	sequence+=1
	app.session.submit_intent(action,payload,"flow-"+str(sequence))

func _travel(marker: String) -> void:
	app.controller.avatars.crew_1.global_position=app.world.markers[marker]
	app.controller.avatars.crew_1.last_dry=app.world.markers[marker]
	app.controller.avatars.crew_1.velocity=Vector3.ZERO
	await physics_frame

func _run() -> void:
	app=Game.new()
	root.add_child(app)
	app.game_port=24641
	app.save_path="user://tests/flow-"+str(Time.get_ticks_usec())+".json"
	app._host("Flow")
	app.set_physics_process(false)
	app.set_process(false)
	var c=app.controller
	c.set_physics_process(false)
	c.rng.seed=23517
	for attempt in range(5):
		await _travel("jetty")
		_send("cast")
		if not _check(c.fishing.casts.has("crew_1"),"cast starts"): return
		var id: String=c.fishing.casts.crew_1.catch_id
		for tick in range(600):
			if not c.fishing.casts.has("crew_1"): break
			var cast: Dictionary=c.fishing.casts.crew_1
			var held: bool=float(cast.get("fish_position",0.5))>float(cast.get("bar_position",0.5))
			_send("reel",{"held":held,"pull":0.0})
			c._physics_process(0.1)
			await physics_frame
		if not _check(c.cargo.snapshot().has(id),"real reel input lands one fish"): return
		if c.cargo.snapshot()[id].state=="whole_loose":
			c.apply_intent(1,"grab_fish",{"catch_id":id},"flow-grab")
		await _travel("boat")
		_send("bank")
		if not _check(c.cargo.snapshot()[id].state=="banked","bank commits caught fish"): return
		if c.progression.snapshot().coins>=30: break
	if not _check(c.progression.snapshot().coins>=30,"earned crafting cost"): return
	await _travel("lens_cache")
	_send("open_cache",{"cache_id":"lido_workshop_cache"})
	await _travel("rod_cache")
	_send("open_cache",{"cache_id":"shore_rod_cache"})
	await _travel("repair_cache")
	_send("open_cache",{"cache_id":"walkway_parts_cache"})
	await _travel("repair")
	_send("repair",{"repair_id":"return_walkway"})
	await _travel("boat")
	_send("craft",{"recipe_id":"surveyor_lantern"})
	_send("equip_lamp",{"lamp_id":"surveyor"})
	_send("equip_rod",{"rod_id":"soft_tip"})
	var saved: Dictionary=c.progression.snapshot()
	if not _check(saved.repairs.get("return_walkway",false) and saved.profiles.crew_1.lamp_id=="surveyor" and saved.profiles.crew_1.rod_id=="soft_tip","crafted found repaired through actual intents"): return
	var before: int=saved.coins
	await _travel("vote")
	_send("open_vote")
	_send("vote",{"choice":"reeds"})
	if not _check(c.lights.reserve=="reeds","crew choice commits"): return
	await _travel("boat")
	_send("ready",{"ready":true})
	c._physics_process(0.1)
	if not _check(c.run.phase=="refuge","normal ready starts departure"): return
	c._physics_process(20.0)
	if not _check(c.run.terminal and c.progression.snapshot().day_index==1,"departure settles once"): return
	c._physics_process(8.1)
	if not _check(c.run.phase=="day" and c.progression.snapshot().coins==before,"new day preserves earned gear and balance"): return
	var reloaded=SaveStore.new(app.save_path).load_or_recover()
	if not _check(reloaded.ok and reloaded.state.repairs.return_walkway and reloaded.state.day_index==1,"independent disk reload"): return
	app.session.close()
	print("CONTROLLER_FLOW_OK checks=%d banked=%d coins=%d"%[checks,reloaded.state.lifetime_banked,reloaded.state.coins])
	quit(0)
