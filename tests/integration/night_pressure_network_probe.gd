extends SceneTree
## Controlled night encounter, three real ENet processes. Authored starts,
## 0.8-second lamp charge and hunter position; all subsequent motion/attacks,
## cell drops and teammate rescue use ordinary physics and Session intents.
var game: Node3D
var role: String=""
var output: String=""
var run_key: String=""
var port: int=24633
var checks: int=0
var sequence: int=0
var measurements: Dictionary={}
var encounter_start: Vector3

func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-role="):role=argument.trim_prefix("--probe-role=")
		if argument.begins_with("--probe-output="):output=argument.trim_prefix("--probe-output=")
		if argument.begins_with("--probe-key="):run_key=argument.trim_prefix("--probe-key=")
		if argument.begins_with("--probe-port="):port=int(argument.trim_prefix("--probe-port="))
	if not _check(role in ["host","client1","client2"] and not output.is_empty(),"arguments"):return
	game=load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.game_port=port
	if role=="host":await _host()
	else:await _client()

func _host() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	game.save_path="user://tests/night_pressure_"+run_key+".json"
	game._host("Night Host")
	if not _check(game.session.is_host(),"real_host"):return
	_stage("listen")
	if not await _wait(func() -> bool:return game.session.roster.snapshot().size()==3,"three_real_peers"):return
	if not await _acks("joined"):return
	encounter_start=game.world.markers.jetty+Vector3(0,0,-5)
	# Same ground and input duration isolates the actual carry speed cost.
	_place("crew_1",encounter_start)
	var free_distance: float=await _stride(2.0)
	_place("crew_1",encounter_start)
	_place_cell(encounter_start+Vector3(0,0.8,-0.7))
	_send("grab_cell",{"cell_id":"cell_1"})
	if not _check(game.controller.supplies.held_by("crew_1")=="cell_1","physical_cell_grab"):return
	var loaded_distance: float=await _stride(2.0)
	measurements.unburdened_2s_metres=free_distance
	measurements.loaded_2s_metres=loaded_distance
	print("NIGHT_MEASUREMENTS "+JSON.stringify(measurements))
	if not _check(free_distance>9.0 and loaded_distance>7.7 and loaded_distance<free_distance-0.7,"same_route_two_seconds_has_measured_carry_penalty"):return
	_send("drop_cell")
	# First encounter: keep the load after the warning with an exhausted lamp.
	_setup_encounter()
	_place_cell(encounter_start+Vector3(0,0.8,-0.7))
	_send("grab_cell",{"cell_id":"cell_1"})
	if not await _approach_threat():return
	_stage("loaded_chase")
	var began: float=game.controller.run.elapsed_s
	while not game.controller.run.players.crew_1.downed and game.controller.run.elapsed_s-began<9:
		_send("move",{"direction":Vector2.DOWN,"yaw":PI})
		await create_timer(0.05).timeout
	_send("move",{"direction":Vector2.ZERO,"yaw":PI})
	measurements.loaded_chase_until_down_s=game.controller.run.elapsed_s-began
	if not _check(game.controller.run.players.crew_1.downed and game.controller.supplies.held_by("crew_1")=="","real_hunter_catches_loaded_player_and_releases_cell"):return
	_stage("down")
	if not await _acks("down"):return
	# Rescuer starts nearby as a labelled fixture, then carries all the way home.
	_place("crew_2",game.controller.avatars.crew_1.global_position+Vector3(-1.1,0,0))
	_stage("rescue")
	if not await _wait(func() -> bool:return game.controller.run.carried_by("crew_1")=="crew_2","remote_client_shoulders_actually_downed_host"):return
	if not await _wait(func() -> bool:return _has("client1_home"),"remote_carrier_walks_to_boat"):return
	if not _check(game.controller._safe(game.controller.avatars.crew_1.global_position) and game.controller.avatars.crew_1.global_position.distance_to(game.controller.avatars.crew_2.rescue_transform().origin)<0.2,"carried_host_arrives_attached_in_safe_cover"):return
	_stage("home")
	if not await _wait(func() -> bool:return not game.controller.run.players.crew_1.downed,"remote_drop_and_three_second_revive_restores_host"):return
	if not _check(game.controller.run.carried_by("crew_1")=="" and game.controller.run.players.crew_1.protection>0,"rescued_player_released_and_protected"):return
	_stage("revived")
	if not await _acks("revived"):return
	# Identical threat, but drop the same load when the hunter approaches.
	_setup_encounter()
	_place_cell(encounter_start+Vector3(0,0.8,-0.7))
	_send("grab_cell",{"cell_id":"cell_1"})
	if not await _approach_threat():return
	_send("drop_cell")
	if not _check(game.controller.supplies.held_by("crew_1")=="","discard_load_restores_free_movement"):return
	began=game.controller.run.elapsed_s
	if not await _walk_home("crew_1",9):return
	measurements.dropped_load_return_s=game.controller.run.elapsed_s-began
	if not _check(not game.controller.run.players.crew_1.downed and game.controller._safe(game.controller.avatars.crew_1.global_position),"same_low_lamp_chase_survived_by_dropping_load"):return
	_stage("survived")
	if not await _acks("survived"):return
	_stage("done")
	if not await _acks("done"):return
	await _finish()

func _setup_encounter() -> void:
	game.controller.run.elapsed_s=400
	game.controller.run.phase="night"
	_place("crew_1",encounter_start)
	_place("crew_2",game.world.markers.boat+Vector3(-1,0,0))
	_place("crew_3",game.world.markers.boat+Vector3(0,0,1))
	game.controller.run.players.crew_1.protection=0
	game.controller.hunter.global_position=encounter_start+Vector3(0,0,-5)
	game.controller.hunter.velocity=Vector3.ZERO
	game.controller.hunter_rules=HunterRules.new()
	game.controller.hunter_target=""
	game.controller._hunter_route_left=0
	game.controller.hunter_slow_until=0
	game.controller.lights.batteries.crew_1=0.8
	_send("toggle_lamp",{"enabled":true})
	_send("move",{"direction":Vector2.ZERO,"yaw":PI})

func _approach_threat() -> bool:
	if not await _wait(func() -> bool:return game.controller.hunter_rules.state=="warn","natural_warning_before_attack"):return false
	if not _check(not game.controller.run.players.crew_1.downed,"warning_does_not_attack"):return false
	if not await _wait(func() -> bool:return game.controller.hunter_rules.state=="chase" and game.controller.hunter.global_position.distance_to(game.controller.avatars.crew_1.global_position)<2.45,"actual_hunter_approaches_during_chase"):return false
	return _check(game.controller.lights.batteries.crew_1==0 and not game.controller.avatars.crew_1.lamp.visible,"short_charge_exhausted_before_escape_decision")

func _stride(seconds: float) -> float:
	var initial: Vector3=game.controller.avatars.crew_1.global_position
	var began: float=game.controller.run.elapsed_s
	while game.controller.run.elapsed_s-began<seconds:
		_send("move",{"direction":Vector2.DOWN,"yaw":PI})
		await create_timer(0.05).timeout
	_send("move",{"direction":Vector2.ZERO,"yaw":PI})
	return Vector2(game.controller.avatars.crew_1.position.x-initial.x,game.controller.avatars.crew_1.position.z-initial.z).length()

func _walk_home(profile: String,seconds: float) -> bool:
	var deadline: int=Time.get_ticks_msec()+int(seconds*1000)
	var goal: Vector3=game.world.markers.boat
	var waypoint: Vector3=goal
	var plan_at: int=0
	while Time.get_ticks_msec()<deadline:
		var actor: Angler=game.controller.avatars[profile]
		if actor.global_position.distance_to(goal)<2.0:
			_send("move",{"direction":Vector2.ZERO,"yaw":actor.rotation.y})
			return _check(true,"physical_walk_home_"+profile)
		if _snapshot().get("run",{}).get("players",{}).get(profile,{}).get("downed",false):return _check(false,"walker_downed_"+profile)
		if Time.get_ticks_msec()>=plan_at or actor.position.distance_to(waypoint)<0.4:
			waypoint=game.world.route_step(actor.global_position,goal)
			plan_at=Time.get_ticks_msec()+250
		var direction: Vector2=Vector2(waypoint.x-actor.position.x,waypoint.z-actor.position.z).normalized()
		_send("move",{"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		await create_timer(0.05).timeout
	return _check(false,"physical_walk_home_timeout_"+profile)

func _client() -> void:
	if not await _wait(func() -> bool:return _has("listen"),"host_listening"):return
	game._join("127.0.0.1",1 if role=="client1" else 2,"Night "+role)
	if not await _wait(func() -> bool:return game.session.status=="connected" and game.controller.avatars.size()==3,"client_connected"):return
	_ack("joined")
	if not await _wait(func() -> bool:return _has("down") and _snapshot().get("run",{}).get("players",{}).get("crew_1",{}).get("downed",false),"actual_hunter_down_mirrored",22000):return
	_ack("down")
	if role=="client1":
		if not await _wait(func() -> bool:return _has("rescue"),"rescue_stage"):return
		_send("carry_teammate",{"target_id":"crew_1"})
		if not await _wait(func() -> bool:return _snapshot().run.players.crew_1.get("carried_by","")=="crew_2","carry_rpc_mirrored"):return
		if not await _walk_home("crew_2",9):return
		_ack("home")
		if not await _wait(func() -> bool:return _has("home"),"home_stage"):return
		_send("drop_teammate")
		var deadline: int=Time.get_ticks_msec()+4500
		while _snapshot().run.players.crew_1.downed and Time.get_ticks_msec()<deadline:
			_send("revive",{"target_id":"crew_1"})
			await create_timer(0.1).timeout
	if not await _wait(func() -> bool:return _has("revived") and not _snapshot().run.players.crew_1.downed,"rescue_mirrored"):return
	_ack("revived")
	if not await _wait(func() -> bool:return _has("survived") and not _snapshot().run.players.crew_1.downed,"dropped_load_survival_mirrored"):return
	_ack("survived")
	if not await _wait(func() -> bool:return _has("done"),"done_stage"):return
	_ack("done")
	await create_timer(0.2).timeout
	await _finish()

func _place_cell(at: Vector3) -> void:
	var cell: PhysicalFish=game.controller.supply_bodies.cell_1
	cell.global_position=at
	cell.last_dry_position=at
	cell.linear_velocity=Vector3.ZERO
	cell.angular_velocity=Vector3.ZERO
	cell.recovering=false

func _snapshot() -> Dictionary:return game.controller.snapshot_data
func _has_note(fragment: String) -> bool:
	for note in game.controller.notes:
		if str(note.text).to_lower().contains(fragment.to_lower()):return true
	return false
func _place(profile: String,at: Vector3) -> void:
	var actor: Angler=game.controller.avatars[profile]
	actor.global_position=at
	actor.last_dry=at
	actor.velocity=Vector3.ZERO
func _send(action: String,payload: Dictionary={}) -> void:
	sequence+=1
	game.session.submit_intent(action,payload,"night_"+role+"_"+str(sequence))
func _stage(tag: String) -> void:
	game.controller._publish()
	_write(tag,{"ready":true})
func _ack(tag: String) -> void:_write(role+"_"+tag,{"ready":true})
func _acks(tag: String) -> bool:return await _wait(func() -> bool:return _has("client1_"+tag) and _has("client2_"+tag),"both_clients_"+tag)
func _has(tag: String) -> bool:
	var path: String=output.path_join(tag+".json")
	if not FileAccess.file_exists(path):return false
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value is Dictionary and value.get("ready",false)
func _write(tag: String,data: Dictionary) -> void:
	var file:=FileAccess.open(output.path_join(tag+".json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(data))
func _wait(condition: Callable,label: String,timeout_ms: int=12000) -> bool:
	var deadline: int=Time.get_ticks_msec()+timeout_ms
	while not condition.call() and Time.get_ticks_msec()<deadline:await create_timer(0.05).timeout
	return _check(condition.call(),label)
func _check(value: bool,label: String) -> bool:
	checks+=1
	print(JSON.stringify({"role":role,"check":label,"ok":value}))
	if not value:
		_write(role+"_fail",{"ready":true,"check":label,"measurements":measurements,"snapshot":_snapshot() if game!=null else {}})
		quit(1)
	return value
func _finish() -> void:
	var result: Dictionary={"ready":true,"role":role,"checks":checks,"measurements":measurements,"scope":"Three real ENet processes; initial positions, night clock and 0.8s lamp are fixtures; actual hunter attack, dropped-load escape and remote carry/drop/revive; no money or rewards; not family fun proof."}
	game.controller.active=false
	game.session.close()
	game.queue_free()
	await process_frame
	_write(role+"_pass",result)
	quit(0)
