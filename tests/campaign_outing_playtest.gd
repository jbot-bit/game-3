extends "res://tests/full_outing_playtest.gd"
## A normal-clock automated journey following the same derived goals as the HUD.
## Only movement/fishing/cargo/repair intents; no teleports or granted progress.
const Guide = preload("res://game/ui/outing_guide.gd")
var failures: PackedStringArray=[]
var previous_goal: String=""

func _run() -> void:
	label="campaign-041-aware"
	report.flee_policy="Replan traversable marker routes away from the hunter; ordinary movement only."
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	root.gui_disable_input=true
	Engine.max_fps=60
	app=Game.new()
	app.game_port=24957
	var fixture: String="user://tests/campaign-outing-"+str(Time.get_ticks_usec())
	app.settings_path=fixture+"-settings.json"
	app.save_path=fixture+"-household.json"
	root.add_child(app)
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.set_physics_process(false)
	app.hud.set_process_input(false)
	app.hud.set_process_unhandled_input(false)
	AudioServer.set_bus_mute(0,true)
	app.hud.host_requested.emit("Harbour")
	app.controller.rng.seed=1607
	started=Time.get_ticks_msec()
	active=true
	await create_timer(0.5).timeout
	await capture("start")
	while not terminal() and Time.get_ticks_msec()-started<660000:
		if threatened() and not app.controller._safe(app.controller.avatars.crew_1.global_position):
			await take_cover()
			continue
		var at: Vector3=app.controller.avatars.crew_1.global_position
		var goal: Dictionary=Guide.next_step(app.controller.snapshot(),"crew_1",{"position":at,"habitat":app.world.fishing_habitat(at),"markers":app.world.markers,"interact":"E","workshop":"K","ready":"B"})
		var goal_key: String=JSON.stringify(goal)
		if goal_key!=previous_goal:
			log_event("goal",goal)
			previous_goal=goal_key
		var kind: String=str(goal.get("action",""))
		if kind=="cast":
			var marker: String=str(goal.get("marker","jetty"))
			var habitat: String="reeds" if marker=="reeds_cast" else marker
			await fish_at(habitat)
		elif not kind.is_empty():
			var marker: String=str(goal.get("marker","boat"))
			if not await walk_to(app.world.markers[marker]):
				failures.append("Could not reach goal: "+marker)
				break
			var result: Dictionary=action(kind,goal.get("payload",{}))
			if not result.get("ok",false):
				failures.append("Goal action failed: "+kind+" "+str(result))
				break
			await create_timer(0.3).timeout
			await capture("goal-"+kind+"-"+str(sequence))
		elif app.controller.run.crossing_left>=0.0:
			await create_timer(0.2).timeout
		elif app.controller.mission.signalled:
			await create_timer(0.2).timeout
		elif now()<232.0:
			# Once repairs are ready, use spare daytime for optional fish.
			await fish_at("jetty")
			await bank()
		else:
			await walk_to(app.world.markers.boat)
			await create_timer(0.2).timeout
	await create_timer(0.5).timeout
	await capture("outcome")
	report.final=app.controller.snapshot()
	report.wall_seconds=float(Time.get_ticks_msec()-started)/1000.0
	report.completed=terminal()
	report.escaped=app.controller.progression.snapshot().campaign_flags.get("escaped",false)
	if not report.escaped: failures.append("Normal outing did not complete escape")
	report.failures=failures
	active=false
	write_report()
	print("CAMPAIGN_OUTING_", "PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify({"elapsed":now(),"wall_seconds":report.wall_seconds,"casts":report.casts.size(),"escaped":report.escaped,"failures":failures}))
	app.session.close()
	quit(0 if failures.is_empty() else 1)

func take_cover() -> void:
	# The first run chose the nearest light even when its route led into the
	# pursuer. This bot now changes route; it gains no speed, aim or immunity.
	var actor: Node3D=app.controller.avatars.crew_1
	var deadline: int=Time.get_ticks_msec()+22000
	var next_plan: int=0
	var destination: Vector3=actor.global_position
	var previous_marker: String=""
	action("cancel_cast",{})
	while threatened() and not terminal() and Time.get_ticks_msec()<deadline:
		if app.controller._safe(actor.global_position):
			action("move",{"direction":Vector2.ZERO,"yaw":actor.rotation.y})
			await create_timer(0.05).timeout
			continue
		if Time.get_ticks_msec()>=next_plan or actor.global_position.distance_to(destination)<1.0:
			next_plan=Time.get_ticks_msec()+350
			var best_score: float=-INF
			var best_marker: String=""
			var hunter_at: Vector3=app.controller.hunter.global_position
			var away: Vector2=Vector2(actor.global_position.x-hunter_at.x,actor.global_position.z-hunter_at.z).normalized()
			for marker: String in ["boat","jetty","reeds","beacon","terraces","tidepools","rod_cache","lens_cache","engine_cache","reel_cache","spawn"]:
				var target: Vector3=app.world.markers[marker]
				if actor.global_position.distance_to(target)<1.0: continue
				var waypoint: Vector3=app.world.route_step(actor.global_position,target)
				var toward: Vector2=Vector2(waypoint.x-actor.global_position.x,waypoint.z-actor.global_position.z)
				if toward.length()<0.15: continue
				var alignment: float=toward.normalized().dot(away)
				var safe_target: bool=marker=="boat" or (marker in ["jetty","reeds"] and app.controller.lights.station_powered(marker,now()))
				var score: float=alignment*8.0-actor.global_position.distance_to(target)*0.005
				if safe_target and alignment>=-0.05: score+=2.0
				if score>best_score:
					best_score=score
					best_marker=marker
					destination=target
			if best_marker!=previous_marker:
				log_event("evade_route",{"marker":best_marker,"score":best_score,"hunter_distance":actor.global_position.distance_to(hunter_at),"at":actor.global_position,"hunter_at":hunter_at})
				previous_marker=best_marker
		var waypoint: Vector3=app.world.route_step(actor.global_position,destination)
		var direction: Vector2=Vector2(waypoint.x-actor.global_position.x,waypoint.z-actor.global_position.z).normalized()
		action("move",{"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		await create_timer(0.05).timeout
	action("move",{"direction":Vector2.ZERO,"yaw":actor.rotation.y})
	log_event("evade_finished",{"hunter":app.controller.hunter_rules.state,"safe":app.controller._safe(actor.global_position),"terminal":terminal(),"bounded_out":threatened() and not terminal()})
	await create_timer(0.15).timeout
