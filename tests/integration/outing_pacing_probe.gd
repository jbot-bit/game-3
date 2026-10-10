extends SceneTree
## Earned, deterministic controller/physics outing. No injected coins/unlocks.
## Authored RNG selects ordinary/oversized examples; night may skip waiting only.
const Game = preload("res://game/main.gd")
var game: Node3D
var checks: int=0
var sequence: int=0
var failed: bool=false
var output: String="res://logs/compact-outing.json"
var timings: Dictionary={"travel":0.0,"fishing":0.0,"menu":0.0,"cargo":0.0,"crossing":0.0,"other":0.0}
var timing_category: String="other"
var catches: Array[Dictionary]=[]
var stages: Array[Dictionary]=[]
var hunter_states: Dictionary={}
var path_metres: float=0.0
var wall_start: int=0
var night_skip: float=0.0
var counterplay: Array[Dictionary]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	wall_start=Time.get_ticks_msec()
	Engine.time_scale=4.0
	Engine.physics_ticks_per_second=240
	Engine.max_physics_steps_per_frame=32
	physics_frame.connect(_record_tick)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	game=Game.new()
	var fixture: String="user://tests/outing_"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	game.save_path=fixture+"/household.json"
	game.settings_path=fixture+"/settings.json"
	game.game_port=24629
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game._host("Outing probe")
	await _delay(0.2,"menu")
	if not _check(game.session.is_host() and _saved().coins==0,"fresh_household_zero_coins"): return
	# The first ordinary catch and its return use actual movement/collision.
	if not await _walk("jetty"): return
	if not await _fish("penny_perch",false): return
	if not await _fish("bellgill",false): return
	if not await _walk("boat"): return
	_send("bank")
	if not _check(_saved().coins==30,"two_ordinary_catches_earn_30"): return
	_stage("first_bank")
	if not await _walk("lens_cache"): return
	_send("open_cache",{"cache_id":"lido_workshop_cache"})
	if not _check("surveyor_lantern" in _saved().known_recipes,"recipe_found_by_travel"): return
	if not await _walk("boat"): return
	game.hud.update_view(game.controller.snapshot(),"crew_1","")
	game.hud.toggle_panel("workshop")
	game.hud._workshop_page("make")
	await _delay(0.5,"menu")
	var craft: Button=game.hud._recipe_buttons.surveyor_lantern
	if not _check(craft.is_visible_in_tree() and not craft.disabled,"earned_recipe_craft_button_available"): return
	craft.pressed.emit()
	game.hud.update_view(game.controller.snapshot(),"crew_1","")
	game.hud._workshop_page("gear")
	await _delay(0.5,"menu")
	game.hud._gear_buttons.surveyor.pressed.emit()
	game.hud._outfit_buttons.angler.pressed.emit()
	game.hud.toggle_panel("workshop")
	if not _check(_saved().coins==0 and _saved().profiles.crew_1.lamp_id=="surveyor" and _saved().profiles.crew_1.outfit_id=="angler","earned_craft_and_two_species_outfit_equipped"): return
	_stage("first_equipment")
	# Select an oversized example, but still land it through the complete minigame.
	if not await _walk("jetty"): return
	if not await _fish("bellgill",true): return
	var whole_id: String=str(catches.back().id)
	_send("grab_fish",{"catch_id":whole_id})
	if not _check(game.controller.cargo.held_by("crew_1")==whole_id,"landed_whole_fish_grabbed"): return
	if not await _walk_point(game.world.markers.jetty+Vector3(0,0,8),0.8,"open_throw_lane"):return
	# Throw across open ground, recover it, then carry home and bank whole.
	# The workshop is deliberate solid clutter, not a safe throwing lane.
	_send("move",{"direction":Vector2.ZERO,"yaw":PI/2})
	_send("toss_fish",{"strength":0.0})
	if not _check(game.controller.cargo.held_by("crew_1")=="" and game.controller.fish_bodies[whole_id].linear_velocity.length()>1.0,"whole_fish_has_real_throw_velocity",_carry_evidence(whole_id)): return
	await _delay(1.4,"cargo")
	if game.controller.cargo.snapshot()[whole_id].state!="banked":
		var loose: Vector3=game.controller.fish_bodies[whole_id].global_position
		if not await _walk_point(loose,1.2,"thrown_fish"): return
		_send("grab_fish",{"catch_id":whole_id})
		if not _check(game.controller.cargo.held_by("crew_1")==whole_id,"throw_recoverable"): return
		if not await _walk("boat"): return
		_send("bank")
	if not _check(_saved().coins==40 and game.controller.cargo.snapshot()[whole_id].state=="banked","whole_delivery_earns_40_not_packed_25"): return
	_stage("whole_delivery")
	# Actual refuge crossing starts a fresh clock while preserving earned equipment.
	_send("ready",{"ready":true})
	var old_run: String=game.controller.run.run_id
	if not await _wait(func() -> bool:return game.controller.run.run_id!=old_run,35,"crossing","refuge_returns_at_dawn"): return
	if not _check(_saved().coins==40 and _saved().profiles.crew_1.lamp_id=="surveyor","earned_gear_survives_return"): return
	# Four ordinary Bellgill fund the remaining 80 essential repair coins.
	if not await _walk("jetty"): return
	for i in range(4):
		if not await _fish("bellgill",false): return
	if not await _walk("boat"): return
	_send("bank")
	if not _check(_saved().coins==120,"essential_120_budget_earned_only_from_fish"): return
	_send("arm_escape")
	if not _check(not game.controller.mission.armed,"escape_rejects_missing_repairs_even_with_money"): return
	if not await _walk("beacon_parts_cache"): return
	_send("open_cache",{"cache_id":"beacon_parts_cache"})
	if not await _walk("beacon_repair"): return
	_send("repair",{"repair_id":"beacon"})
	if not _check(_saved().repairs.get("beacon",false) and _saved().coins==80,"earned_beacon_repair_costs_40"): return
	if not await _walk("engine_cache"): return
	_send("open_cache",{"cache_id":"tide_engine_cache"})
	if not await _walk("boat"): return
	_send("repair",{"repair_id":"moth_engine"})
	if not _check(_saved().repairs.get("moth_engine",false) and _saved().coins==0 and game.controller.snapshot().campaign.can_escape,"earned_engine_costs_80_and_optional_repairs_not_required"): return
	_stage("escape_repaired")
	# Explicit clock fixture avoids claiming idle waiting as measured gameplay.
	if game.controller.run.elapsed_s<240:
		night_skip=240.0-game.controller.run.elapsed_s
		game.controller.run.elapsed_s=240.0
		game.controller.run.phase="night"
	_send("arm_escape")
	if not _check(game.controller.mission.armed,"repaired_night_escape_armed"): return
	if not await _walk("beacon_repair"): return
	_send("signal_escape")
	if not _check(game.controller.mission.signalled,"signal_requires_actual_beacon_travel"): return
	_stage("night_signal")
	if not await _walk("boat"): return
	if not _check(not game.controller.run.players.crew_1.downed and game.controller._safe(_actor().global_position),"actual_night_return_reaches_safe_boat"): return
	if not _check(hunter_states.has("warn") and hunter_states.has("chase"),"night_journey_observed_warning_and_chase",hunter_states): return
	_stage("night_return")
	_send("ready",{"ready":true})
	if not await _wait(func() -> bool:return game.controller.mission.completed,24,"crossing","earned_campaign_crossing_completes"): return
	var saved_disk: Dictionary=SaveStore.new(game.save_path).load_or_recover()
	if not _check(saved_disk.ok and saved_disk.state.campaign_flags.get("escaped",false) and saved_disk.state.lifetime_banked==150 and saved_disk.state.profiles.crew_1.lamp_id=="surveyor","escape_and_equipment_durable_without_reward_injection"): return
	_finish(true)

func _actor() -> Angler: return game.controller.avatars.crew_1
func _saved() -> Dictionary: return game.controller.progression.snapshot()
func _send(action: String,payload: Dictionary={}) -> void:
	sequence+=1
	game.session.submit_intent(action,payload,"outing:"+str(sequence))

func _walk(marker: String) -> bool:
	return await _walk_point(game.world.markers[marker],1.1,marker)

func _walk_point(goal: Vector3,tolerance: float,label: String) -> bool:
	var started: float=game.controller.run.elapsed_s
	var expected_cargo: String=game.controller.cargo.held_by("crew_1")
	var waypoint: Vector3=goal
	var next_plan: float=-1.0
	var limit: int=Time.get_ticks_msec()+45000
	var evading: bool=false
	var evade_goal: Vector3=goal
	while Vector2(_actor().position.x-goal.x,_actor().position.z-goal.z).length()>tolerance:
		if failed:return false
		if Time.get_ticks_msec()>limit or game.controller.run.elapsed_s-started>100 or game.controller.run.terminal:
			return _check(false,("hunter_down_during_" if game.controller.run.players.crew_1.downed else "travel_blocked_")+label,{"position":_actor().position,"goal":goal,"waypoint":waypoint,"phase":game.controller.run.phase,"hunter":game.controller.hunter_rules.state})
		var pressure: String=game.controller.hunter_rules.state
		var to_hunter: Vector3=game.controller.hunter.global_position-_actor().global_position
		var toward_goal: Vector3=waypoint-_actor().global_position
		if evading and pressure=="recover":
			evading=false
			next_plan=-1
			counterplay.append({"action":"resume_while_hunter_recovers","run_elapsed_s":game.controller.run.elapsed_s,"distance_m":to_hunter.length()})
		if game.controller.run.elapsed_s>=240 and pressure in ["warn","chase"] and not evading and to_hunter.length()<12 and (toward_goal.normalized().dot(to_hunter.normalized())>0.15 or to_hunter.length()<4):
			evading=true
			evade_goal=_choose_evade_goal()
			next_plan=-1
			counterplay.append({"action":"retreat_from_approaching_hunter","run_elapsed_s":game.controller.run.elapsed_s,"distance_m":to_hunter.length(),"goal":evade_goal})
		if evading and _actor().global_position.distance_to(evade_goal)<2:
			evade_goal=_choose_evade_goal()
			next_plan=-1
		if game.controller.run.elapsed_s>=next_plan or _actor().position.distance_to(waypoint)<0.3:
			waypoint=game.world.route_step(_actor().global_position,evade_goal if evading else goal)
			next_plan=game.controller.run.elapsed_s+0.25
		var direction: Vector2=Vector2(waypoint.x-_actor().position.x,waypoint.z-_actor().position.z).normalized()
		_send("move",{"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		var previous: Vector3=_actor().global_position
		await _delay(0.05,"travel")
		path_metres+=previous.distance_to(_actor().global_position)
		if expected_cargo!="" and game.controller.cargo.held_by("crew_1")!=expected_cargo:
			return _check(false,"whole_carry_lost_on_route_"+label,_carry_evidence(expected_cargo))
	_send("move",{"direction":Vector2.ZERO,"yaw":_actor().rotation.y})
	await _delay(0.15,"travel")
	return _check(true,"walk_"+label,{"game_s":game.controller.run.elapsed_s-started,"position":_actor().global_position})

func _choose_evade_goal() -> Vector3:
	# Ordinary counterplay: retrace/widen the route while chased, then pass during
	# the existing recovery window. Uses supported authored route points only.
	var at: Vector3=_actor().global_position
	var hunter_at: Vector3=game.controller.hunter.global_position
	var away: Vector3=(at-hunter_at).normalized()
	var best: Vector3=at
	var best_score: float=-INF
	for candidate: Vector3 in IslandWorld.ROUTE_POINTS:
		var travel: float=at.distance_to(candidate)
		if travel<8 or travel>45:continue
		var step: Vector3=game.world.route_step(at,candidate)-at
		step.y=0
		if step.length()<0.4 or step.normalized().dot(away)<-0.15:continue
		if candidate.distance_to(hunter_at)<at.distance_to(hunter_at)+3:continue
		var score: float=step.normalized().dot(away)*10.0+candidate.distance_to(hunter_at)*0.3-travel*0.05
		if score>best_score:
			best_score=score
			best=candidate
	return best

func _carry_evidence(id: String) -> Dictionary:
	var result: Dictionary={"player":_actor().global_position,"cargo":game.controller.cargo.snapshot().get(id,{}),"notes":game.controller.notes}
	if not game.controller.fish_bodies.has(id):return result
	var body: PhysicalFish=game.controller.fish_bodies[id]
	result.body_position=body.global_position
	result.body_velocity=body.linear_velocity
	result.held=body.held
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=body._shape
	query.transform=_actor().carry_transform()
	query.collision_mask=1
	var hit_names: Array[String]=[]
	for hit in body.get_world_3d().direct_space_state.intersect_shape(query,8):hit_names.append(str(hit.collider.get_path()))
	result.carry_endpoint_colliders=hit_names
	query.transform=body.global_transform
	query.motion=_actor().carry_transform().origin-body.global_position
	var sweep: PackedFloat32Array=body.get_world_3d().direct_space_state.cast_motion(query)
	result.carry_sweep_fractions=Array(sweep)
	if sweep.size()>1 and sweep[0]<0.999:
		query.transform.origin+=query.motion*minf(1.0,sweep[1]+0.005)
		query.motion=Vector3.ZERO
		var sweep_names: Array[String]=[]
		for hit in body.get_world_3d().direct_space_state.intersect_shape(query,8):sweep_names.append(str(hit.collider.get_path()))
		result.carry_sweep_colliders=sweep_names
	return result

func _fish(species: String,oversized: bool) -> bool:
	var habitat: String=game.world.fishing_habitat(_actor().global_position)
	var seed_value: int=-1
	for candidate in range(10000):
		var random:=RandomNumberGenerator.new()
		random.seed=candidate
		var roll: Dictionary=CatchTable.roll(habitat,game.controller.run.phase,0,random.randf(),random.randf(),random.randf())
		if roll.species_id==species and (roll.trait_id=="oversized")==oversized:
			seed_value=candidate
			break
	if not _check(seed_value>=0,"authored_rng_example_found"):return false
	game.controller.rng.seed=seed_value
	_send("cast")
	if not _check(game.controller.fishing.casts.has("crew_1"),"real_cast_started"): return false
	var id: String=game.controller.fishing.casts.crew_1.catch_id
	var started: float=game.controller.run.elapsed_s
	var held: bool=true
	var wall_deadline: int=Time.get_ticks_msec()+30000
	while game.controller.fishing.casts.has("crew_1") and game.controller.run.elapsed_s-started<50 and Time.get_ticks_msec()<wall_deadline:
		var fish: Dictionary=game.controller.fishing.casts.crew_1
		held=float(fish.get("fish_position",0.5))>float(fish.get("bar_position",0.5))
		_send("reel",{"held":held,"pull":0.0})
		await _delay(0.1,"fishing")
	_send("reel",{"held":false,"pull":0.0})
	var elapsed: float=game.controller.run.elapsed_s-started
	catches.append({"id":id,"species":species,"oversized":oversized,"game_s":elapsed,"authored_rng_seed":seed_value})
	return _check(id in _saved().landed_catch_ids,"actual_fishing_landed_"+species,{"game_s":elapsed,"seed":seed_value})

func _delay(seconds: float,category: String) -> void:
	var prior: String=timing_category
	timing_category=category
	await create_timer(seconds,false,true).timeout
	timing_category=prior
	if is_instance_valid(game) and game.controller.active:
		hunter_states[game.controller.hunter_rules.state]=true

func _record_tick() -> void:
	if is_instance_valid(game) and game.controller!=null and game.controller.active:
		timings[timing_category]+=Engine.time_scale/float(Engine.physics_ticks_per_second)

func _wait(condition: Callable,seconds: float,category: String,label: String) -> bool:
	var remaining: float=seconds
	while not condition.call() and remaining>0:
		await _delay(0.1,category)
		remaining-=0.1
	return _check(condition.call(),label)

func _stage(label: String) -> void:
	var item: Dictionary={"label":label,"run_elapsed_s":game.controller.run.elapsed_s,"timings":timings.duplicate(),"coins":_saved().coins,"lifetime_banked":_saved().lifetime_banked}
	stages.append(item)
	var progress:=FileAccess.open(output.get_base_dir().path_join("progress.json"),FileAccess.WRITE)
	if progress!=null:progress.store_string(JSON.stringify(item,"  "))
	print("OUTING_STAGE "+JSON.stringify(item))

func _check(value: bool,label: String,evidence: Dictionary={}) -> bool:
	checks+=1
	print(JSON.stringify({"check":label,"ok":value,"evidence":evidence}))
	if not value:
		failed=true
		_finish(false,label,evidence)
	return value

func _finish(ok: bool,label: String="",evidence: Dictionary={}) -> void:
	var result: Dictionary={"ok":ok,"checks":checks,"failure":label,"evidence":evidence,"stages":stages,"catches":catches,"timings_game_s":timings,"path_metres":path_metres,"wall_s":(Time.get_ticks_msec()-wall_start)/1000.0,"night_wait_skipped_s":night_skip,"hunter_states":hunter_states,"counterplay":counterplay,"save_path":ProjectSettings.globalize_path(game.save_path),"scope":"One local host, real Session intents and engine physics, ideal automated fishing and threat-aware route retreat; seeded catch examples and optional night clock skip; no money/unlock/position injections. Menu uses visible enabled HUD button signals with fixed 0.5s scripted dwell, not human timing. Not family fun or three-PC evidence."}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  "))
	print("OUTING_RESULT "+JSON.stringify(result))
	game.controller.active=false
	game.session.close()
	game.queue_free()
	call_deferred("_quit_cleanly",ok)

func _quit_cleanly(ok: bool) -> void:
	await process_frame
	quit(0 if ok else 1)
