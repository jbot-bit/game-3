extends SceneTree
## Three actual ENet processes; only staging uses files. Positions/night are
## explicitly authored host fixtures; every battery action uses Session RPC.
var game: Node3D
var role: String=""
var output: String=""
var run_key: String=""
var port: int=24631
var checks: int=0
var sequence: int=0

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
	game.save_path="user://tests/battery_network_"+run_key+".json"
	game._host("Battery Host")
	if not _check(game.session.is_host(),"real_host"):return
	_stage("listen")
	if not await _wait(func() -> bool:return game.session.roster.snapshot().size()==3,"three_real_peers"):return
	if not await _acks("joined"):return
	_place("crew_1",game.world.markers.vote)
	_place("crew_2",game.world.markers.beacon)
	_send("open_vote")
	if not _check(game.controller.choice.opened_at>=0,"battery_available"):return
	_stage("far")
	if not await _wait(func() -> bool:return _has("client1_far_attempt"),"remote_far_rpc_sent"):return
	if not await _wait(func() -> bool:return _has_note("Return to battery"),"far_rpc_rejected_by_host_range_check"):return
	if not _check(game.controller.choice.committed=="" and game.controller.lights.station_until.reeds==240,"far_attempt_does_not_allocate_reserve"):return
	_place("crew_2",game.world.markers.vote+Vector3(-1,0,0))
	_stage("near")
	if not await _wait(func() -> bool:return game.controller.choice.committed=="reeds","nonhost_single_pull_commits_without_majority"):return
	if not _check(game.controller.choice.decided_by=="crew_2" and game.controller.choice.votes.size()==1 and game.controller.lights.station_until.reeds==390 and game.controller.lights.station_until.jetty==240,"one_remote_player_selects_only_one_150_second_reserve"):return
	_stage("committed")
	if not await _acks("committed"):return
	_place("crew_3",game.world.markers.vote+Vector3(1,0,0))
	_stage("reverse")
	if not await _acks("reverse"):return
	if not await _wait(func() -> bool:return _has_note("Already committed"),"second_remote_cannot_override_first_pull"):return
	if not _check(game.controller.choice.committed=="reeds","irreversible_night_allocation"):return
	# Explicit time/position fixture demonstrates consequences for other players.
	game.controller.run.elapsed_s=250
	game.controller.run.phase="night"
	_place("crew_1",game.world.markers.jetty+Vector3(-1,0,0))
	_place("crew_3",game.world.markers.reeds+Vector3(-1,0,0))
	if not _check(not game.controller._safe(game.controller.avatars.crew_1.global_position) and game.controller._safe(game.controller.avatars.crew_3.global_position),"remote_choice_removes_host_jetty_cover_and_protects_other_client_at_reeds"):return
	_send("pause",{"paused":true})
	_stage("night")
	if not await _acks("night"):return
	_stage("done")
	if not await _acks("done"):return
	await _finish()

func _client() -> void:
	if not await _wait(func() -> bool:return _has("listen"),"host_listening"):return
	game._join("127.0.0.1",1 if role=="client1" else 2,"Battery "+role)
	if not await _wait(func() -> bool:return game.session.status=="connected" and game.controller.avatars.size()==3,"client_connected"):return
	_ack("joined")
	if role=="client1":
		if not await _wait(func() -> bool:return _has("far"),"far_stage"):return
		_send("vote",{"choice":"reeds"})
		_ack("far_attempt")
		if not await _wait(func() -> bool:return _has("near"),"near_stage"):return
		_send("vote",{"choice":"reeds"})
	if not await _wait(func() -> bool:return _has("committed") and _snapshot().get("choice",{}).get("decided_by","")=="crew_2","remote_commit_mirrored"):return
	var choice: Dictionary=_snapshot().choice
	if not _check(choice.committed=="reeds" and choice.votes.size()==1 and _snapshot().lights.station_until.reeds==390 and _snapshot().lights.station_until.jetty==240,"client_observes_single_player_consequence"):return
	_ack("committed")
	if not await _wait(func() -> bool:return _has("reverse"),"reverse_stage"):return
	if role=="client2":_send("vote",{"choice":"jetty"})
	_ack("reverse")
	if not await _wait(func() -> bool:return _has("night") and _snapshot().get("run",{}).get("elapsed_s",0)>=250,"night_state_mirrored"):return
	if not _check(_snapshot().choice.committed=="reeds" and not game.world._station_states.jetty and game.world._station_states.reeds and _snapshot().run.paused,"both_clients_render_correct_dark_and_lit_routes"):return
	_ack("night")
	if not await _wait(func() -> bool:return _has("done"),"done_stage"):return
	_ack("done")
	await create_timer(0.2).timeout
	await _finish()

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
	game.session.submit_intent(action,payload,"battery_"+role+"_"+str(sequence))
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
func _wait(condition: Callable,label: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+12000
	while not condition.call() and Time.get_ticks_msec()<deadline:await create_timer(0.05).timeout
	return _check(condition.call(),label)
func _check(value: bool,label: String) -> bool:
	checks+=1
	print(JSON.stringify({"role":role,"check":label,"ok":value}))
	if not value:
		_write(role+"_fail",{"ready":true,"check":label,"snapshot":_snapshot() if game!=null else {}})
		quit(1)
	return value
func _finish() -> void:
	var result: Dictionary={"ready":true,"role":role,"checks":checks,"scope":"Three real ENet processes, remote physical battery intents; authored player positions and night clock; no human or separate-PC playtest claim."}
	game.controller.active=false
	game.session.close()
	game.queue_free()
	await process_frame
	_write(role+"_pass",result)
	quit(0)
