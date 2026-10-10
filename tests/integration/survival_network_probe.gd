extends SceneTree
## Three real ENet peers; files coordinate stages, never replicate game state.
## Host-authored position/down/night fixtures isolate gameplay RPC assertions.
var game: Node3D
var role: String=""
var output: String=""
var run_key: String=""
var port: int=24623
var checks: int=0
var request_sequence: int=0
var pose_packets: int=0
var last_poses: Dictionary={}
var rejections: Array[String]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-role="): role=argument.trim_prefix("--probe-role=")
		if argument.begins_with("--probe-output="): output=argument.trim_prefix("--probe-output=")
		if argument.begins_with("--probe-key="): run_key=argument.trim_prefix("--probe-key=")
		if argument.begins_with("--probe-port="): port=int(argument.trim_prefix("--probe-port="))
	if not _check(role in ["host","client1","client2"] and not output.is_empty() and not run_key.is_empty(),"arguments"): return
	var scene: PackedScene=load("res://game/main.tscn")
	game=scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.game_port=port
	game.session.poses_received.connect(func(data: Dictionary) -> void: last_poses=data; pose_packets+=1)
	game.session.intent_rejected.connect(func(_id: String,code: String) -> void: rejections.append(code))
	if role=="host": await _host()
	else: await _client()

func _host() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	game.save_path="user://tests/survival_network_"+run_key+".json"
	game._host("Survival Host")
	if not _check(game.session.is_host() and game.controller.active,"real_host_started"): return
	_stage("listen")
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==3,"three_real_peers"): return
	if not await _acks("joined"): return
	# Explicit fixture: late-night selected station has exhausted its 150 s reserve.
	game.controller.run.elapsed_s=400.0
	game.controller.run.phase="night"
	game.controller.lights.set_reserve("jetty")
	game.controller.hunter.global_position=game.world.markers.reeds
	_place("crew_1",game.world.layout_point(Vector3(-76,2.05,25)))
	_place("crew_2",game.world.layout_point(Vector3(-70,2.05,25)))
	_place("crew_3",game.world.layout_point(Vector3(-70,2.05,21.5)),PI)
	_place_cell("cell_1",game.world.layout_point(Vector3(-70,3.05,24.5)))
	_stage("fixture")
	if not await _acks("fixture_seen"): return
	_stage("grab")
	if not await _wait(func() -> bool: return _cell("cell_1").get("carrier_id","")=="crew_2" and game.controller.supply_bodies.cell_1.held,"remote_cell_grab_authoritative"): return
	_stage("held")
	if not await _acks("held_seen"): return
	_send("pause",{"paused":true})
	var paused_elapsed: float=game.controller.run.elapsed_s
	var paused_pose: Transform3D=game.controller.supply_bodies.cell_1.global_transform
	_stage("pause")
	if not await _acks("pause_checked"): return
	if not _check(game.controller.run.elapsed_s==paused_elapsed and game.controller.supply_bodies.cell_1.global_transform.is_equal_approx(paused_pose) and _cell("cell_1").carrier_id=="crew_2","pause_freezes_clock_and_held_cell"): return
	_send("pause",{"paused":false})
	_stage("receive")
	if not await _wait(func() -> bool: return _has("client2_receiving"),"receiver_ready_through_real_intents"): return
	_stage("toss")
	if not await _wait(func() -> bool: return _cell("cell_1").get("carrier_id","")=="crew_3","remote_toss_received_by_other_remote"): return
	_stage("received")
	if not await _acks("received_seen"): return
	# The recipient walks the received cell to the pole through real move RPCs.
	_stage("deliver")
	if not await _wait(func() -> bool: return _cell("cell_1").get("state","")=="consumed","remote_station_delivery_consumes_cell"): return
	var first_until: float=game.controller.lights.station_until.jetty
	if not _check(game.controller.lights.station_powered("jetty",game.controller.run.elapsed_s) and first_until-game.controller.run.elapsed_s>88.0 and first_until-game.controller.run.elapsed_s<=90.0,"expired_station_relit_for_one_cell_budget"): return
	_stage("fed")
	if not await _acks("fed_seen"): return
	if not _check(game.controller.lights.station_until.jetty==first_until and not game.controller.supply_bodies.has("cell_1") and game.controller.progression.snapshot().coins==0,"duplicate_delivery_cannot_extend_power_or_award_coins"): return
	# Explicit injury fixture. Pickup, moving, dropping and healing use real RPCs.
	_place("crew_1",game.world.layout_point(Vector3(-76,2.05,30)))
	_place("crew_2",game.world.layout_point(Vector3(-70,2.05,30)))
	_place("crew_3",game.world.layout_point(Vector3(-71,2.05,30)))
	game.controller.run.players.crew_3.protection=0.0
	if not _check(game.controller.run.down("crew_3").ok,"authored_injury_fixture"): return
	_stage("rescue")
	if not await _wait(func() -> bool: return game.controller.run.carried_by("crew_3")=="crew_2","remote_carries_downed_remote"): return
	_stage("carried")
	if not await _acks("carried_seen"): return
	var initial: Vector3=game.controller.avatars.crew_2.global_position
	_stage("carry_move")
	if not await _wait(func() -> bool: return _has("client1_moved"),"carrier_sent_movement"): return
	await create_timer(0.3).timeout
	var helper: Node3D=game.controller.avatars.crew_2
	var passenger: Node3D=game.controller.avatars.crew_3
	if not _check(helper.global_position.distance_to(initial)>2.0 and passenger.global_position.distance_to(helper.rescue_transform().origin)<0.15,"host_moves_attached_passenger_with_carrier"): return
	_stage("moved")
	if not await _acks("moved_seen"): return
	_stage("drop")
	if not await _wait(func() -> bool: return game.controller.run.carried_by("crew_3")=="" and game.controller.run.players.crew_3.downed,"remote_drop_releases_still_injured_teammate"): return
	_stage("dropped")
	if not await _acks("dropped_seen"): return
	_stage("revive")
	if not await _wait(func() -> bool: return not game.controller.run.players.crew_3.downed,"remote_three_second_revive_succeeds"): return
	_stage("revived")
	if not await _acks("revived_seen"): return
	# Two simultaneous ownership cleanups: one client carries host; another cell2.
	_place("crew_1",game.world.layout_point(Vector3(-71,2.05,35)))
	_place("crew_2",game.world.layout_point(Vector3(-70,2.05,35)))
	_place("crew_3",game.world.layout_point(Vector3(-74,2.05,35)))
	_place_cell("cell_2",game.world.layout_point(Vector3(-74,3.05,34.5)))
	game.controller.run.players.crew_1.protection=0.0
	if not _check(game.controller.run.down("crew_1").ok,"authored_disconnect_injury_fixture"): return
	_stage("disconnect_fixture")
	if not await _wait(func() -> bool: return game.controller.run.carried_by("crew_1")=="crew_2" and _cell("cell_2").get("carrier_id","")=="crew_3","both_remote_ownerships_acquired_before_disconnect"): return
	_send("pause",{"paused":true})
	_stage("disconnect_pause")
	if not await _acks("disconnect_pause_seen"): return
	_stage("disconnect")
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==1,"both_remote_peers_disconnected_while_paused"): return
	if not _check(game.controller.run.carried_by("crew_1")=="" and game.controller.run.players.crew_1.downed and not game.controller.avatars.crew_1.being_carried,"disconnect_detaches_passenger_during_pause"): return
	if not _check(_cell("cell_2").state=="free" and _cell("cell_2").carrier_id=="" and not game.controller.supply_bodies.cell_2.held and game.controller.supply_bodies.cell_2.freeze,"disconnect_releases_cell_without_unpausing_physics"): return
	if not _check(game.controller.avatars.crew_1.global_position.distance_to(game.controller.avatars.crew_1.last_dry)<0.1,"released_passenger_is_on_supported_dry_position"): return
	_stage("rejoin")
	if not await _wait(func() -> bool: return game.session.roster.snapshot().size()==3,"all_real_peers_rejoined"): return
	if not await _acks("rejoined_seen"): return
	_send("pause",{"paused":false})
	_stage("resume")
	if not await _acks("resumed_seen"): return
	var previous_run: String=game.controller.run.run_id
	var delayed_old_pose: Dictionary=game.controller._poses().duplicate(true)
	# Use the real recovery control and every peer's ready RPC to reach dawn.
	_send("host_event",{"event_id":"safe_return"})
	_stage("refuge_ready")
	_send("ready",{"ready":true})
	if not await _wait(func() -> bool: return game.controller.run.phase=="refuge","three_rpc_votes_begin_real_refuge_crossing"): return
	_stage("refuge_crossing")
	if not await _acks("refuge_seen"): return
	if not await _wait(func() -> bool: return game.controller.run.run_id!=previous_run and game.controller.run.phase=="day","refuge_crossing_and_recap_reach_real_new_outing",45000): return
	_stage("dawn")
	if not await _acks("dawn_seen"): return
	_send("pause",{"paused":true})
	_stage("dawn_pause")
	if not await _acks("dawn_pause_seen"): return
	# Deliver a genuine captured old-run payload over ENet after the new snapshot.
	# Disable only automatic publishing so no fresh packet masks a bad application.
	game.controller.set_physics_process(false)
	game.session.publish_poses(delayed_old_pose)
	_write("delayed_old_pose",{"ready":true,"pose_sequence":game.session._pose_sequence})
	if not await _acks("old_epoch_checked"): return
	game.controller.set_physics_process(true)
	_send("pause",{"paused":false})
	if not _check(game.controller.progression.snapshot().coins==0 and game.controller.progression.snapshot().banked_catch_ids.is_empty(),"survival_supplies_never_enter_saved_fish_rewards"): return
	_stage("host_exit")
	await _finish()

func _client() -> void:
	if not await _wait(func() -> bool: return _has("listen"),"host_listening"): return
	var slot: int=1 if role=="client1" else 2
	var expected: String="crew_2" if role=="client1" else "crew_3"
	game._join("127.0.0.1",slot,role)
	if not await _wait(func() -> bool: return game.session.status=="connected" and game.session.local_profile_id==expected and game.session.roster.snapshot().size()==3,"real_client_joined"): return
	if not _check(not game.session.is_host() and game.get_multiplayer().get_unique_id()>1,"remote_peer_identity"): return
	_ack("joined")
	if not await _stage_seen("fixture"): return
	if not await _wait(func() -> bool: return game.controller.supply_bodies.size()==2 and _snapshot().get("run",{}).get("elapsed_s",0.0)>=400.0,"night_fixture_and_two_supplies_replicated"): return
	if not _check(_cell("cell_1").get("state","")=="free" and _snapshot().lights.station_until.jetty==390.0,"selected_station_expired_in_received_state"): return
	if not await _cell_pose("cell_1"): return
	_ack("fixture_seen")
	if not await _stage_seen("grab"): return
	if role=="client1": _send("grab_cell",{"cell_id":"cell_1"})
	if not await _wait(func() -> bool: return _has("held") and _cell("cell_1").get("carrier_id","")=="crew_2","remote_cell_holder_replicated"): return
	if not await _cell_pose("cell_1"): return
	_ack("held_seen")
	if not await _wait(func() -> bool: return _has("pause") and _snapshot().run.paused,"host_pause_received"): return
	var before: float=_snapshot().run.elapsed_s
	_send("toss_cell",{"strength":1.0})
	if not await _wait(func() -> bool: return "paused" in rejections,"paused_remote_action_rejected_by_authority"): return
	await create_timer(0.35).timeout
	if not _check(_snapshot().run.elapsed_s==before and _cell("cell_1").carrier_id=="crew_2" and game.controller.supply_bodies.cell_1.freeze,"client_sees_frozen_cell_and_clock"): return
	_ack("pause_checked")
	if not await _wait(func() -> bool: return _has("receive") and not _snapshot().run.paused,"unpaused_pass_stage"): return
	if role=="client2":
		_send("move",{"direction":Vector2.ZERO,"yaw":PI})
		_send("receive_fish",{"held":true})
		await create_timer(0.3).timeout
		_ack("receiving")
		var deadline: int=Time.get_ticks_msec()+10000
		while _cell("cell_1").get("carrier_id","")!="crew_3" and Time.get_ticks_msec()<deadline:
			_send("move",{"direction":Vector2.ZERO,"yaw":PI})
			_send("receive_fish",{"held":true})
			await create_timer(0.05).timeout
		_send("receive_fish",{"held":false})
	else:
		if not await _stage_seen("toss"): return
		_send("toss_cell",{"strength":0.4})
	if not await _wait(func() -> bool: return _has("received") and _cell("cell_1").get("carrier_id","")=="crew_3","passed_cell_has_one_new_remote_holder"): return
	if not await _cell_pose("cell_1"): return
	_ack("received_seen")
	if not await _stage_seen("deliver"): return
	if role=="client2":
		if not await _walk_cell_to(game.world.layout_point(Vector3(-66,2.0,21.5))): return
		if not await _walk_cell_to(game.world.markers.jetty): return
		game.session.submit_intent("feed_station",{"station_id":"jetty"},"survival_feed_once")
		game.session.submit_intent("feed_station",{"station_id":"jetty"},"survival_feed_once")
	if not await _wait(func() -> bool: return _has("fed") and _cell("cell_1").get("state","")=="consumed" and not game.controller.supply_bodies.has("cell_1"),"consumed_cell_disappears_on_both_clients"): return
	if not _check(_snapshot().lights.station_until.jetty>_snapshot().run.elapsed_s and _snapshot().lights.station_until.jetty-_snapshot().run.elapsed_s<=90.0,"relit_station_budget_received"): return
	if role=="client2" and not await _wait(func() -> bool: return "duplicate" in rejections,"duplicate_feed_rpc_explicitly_rejected"): return
	_ack("fed_seen")
	if not await _wait(func() -> bool: return _has("rescue") and _player("crew_3").get("downed",false),"authored_injury_received"): return
	if role=="client1": _send("carry_teammate",{"target_id":"crew_3"})
	if not await _wait(func() -> bool: return _has("carried") and _player("crew_3").get("carried_by","")=="crew_2","rescue_carry_replicated"): return
	if not _check(game.controller.avatars.crew_3.being_carried and game.controller.avatars.crew_2.carrying_teammate,"remote_carry_visual_flags_match_authority"): return
	_ack("carried_seen")
	if not await _stage_seen("carry_move"): return
	if role=="client1":
		for tick: int in range(20):
			_send("move",{"direction":Vector2(0,1),"yaw":PI})
			await create_timer(0.05).timeout
		_send("move",{"direction":Vector2.ZERO,"yaw":PI})
		_ack("moved")
	if not await _stage_seen("moved"): return
	if not await _pose_barrier("moved"): return
	if not _check_player_pose("crew_2") or not _check_player_pose("crew_3"): return
	if not _check(_player("crew_3").carried_by=="crew_2" and game.controller.avatars.crew_3.global_position.distance_to(game.controller.avatars.crew_2.rescue_transform().origin)<0.3,"remote_passenger_follows_moving_shoulder"): return
	_ack("moved_seen")
	if not await _stage_seen("drop"): return
	if role=="client1": _send("drop_teammate",{})
	if not await _wait(func() -> bool: return _has("dropped") and _player("crew_3").get("carried_by","")=="","remote_drop_replicated"): return
	if not _check(_player("crew_3").downed and not game.controller.avatars.crew_3.being_carried,"put_down_does_not_silently_heal"): return
	_ack("dropped_seen")
	if not await _stage_seen("revive"): return
	if role=="client1":
		var deadline: int=Time.get_ticks_msec()+5000
		while _player("crew_3").get("downed",true) and Time.get_ticks_msec()<deadline:
			_send("revive",{"target_id":"crew_3"})
			await create_timer(0.1).timeout
	if not await _wait(func() -> bool: return _has("revived") and not _player("crew_3").get("downed",true),"completed_revive_replicated"): return
	_ack("revived_seen")
	if not await _wait(func() -> bool: return _has("disconnect_fixture") and _player("crew_1").get("downed",false),"second_explicit_injury_fixture_received"): return
	if role=="client1": _send("carry_teammate",{"target_id":"crew_1"})
	else: _send("grab_cell",{"cell_id":"cell_2"})
	if not await _wait(func() -> bool: return _has("disconnect_pause") and _snapshot().run.paused and _player("crew_1").get("carried_by","")=="crew_2" and _cell("cell_2").get("carrier_id","")=="crew_3","both_owned_objects_replicated_before_paused_disconnect"): return
	_ack("disconnect_pause_seen")
	if not await _stage_seen("disconnect"): return
	game.session.close()
	game.controller.active=false
	if not await _stage_seen("rejoin"): return
	game._join("127.0.0.1",slot,role)
	if not await _wait(func() -> bool: return game.session.status=="connected" and game.session.local_profile_id==expected and game.session.roster.snapshot().size()==3 and _player("crew_1").get("carried_by","stale")=="" and _cell("cell_2").get("state","")=="free","rejoin_receives_cleaned_ownership"): return
	if not _check(_snapshot().run.paused and _cell("cell_1").state=="consumed" and _cell("cell_2").carrier_id=="" and game.controller.supply_bodies.size()==1,"rejoin_does_not_duplicate_consumed_cells_or_restore_old_holds"): return
	if not await _cell_pose("cell_2"): return
	_ack("rejoined_seen")
	if not await _wait(func() -> bool: return _has("resume") and not _snapshot().run.paused,"resume_after_disconnect_cleanup_received"): return
	_ack("resumed_seen")
	var previous_run: String=_snapshot().run.run_id
	var previous_cell_position: Vector3=game.controller.supply_bodies.cell_2.global_position
	if not await _stage_seen("refuge_ready"): return
	_send("ready",{"ready":true})
	if not await _wait(func() -> bool: return _has("refuge_crossing") and _snapshot().run.phase=="refuge","actual_refuge_departure_replicated"): return
	_ack("refuge_seen")
	if not await _wait(func() -> bool: return _has("dawn") and _snapshot().run.run_id!=previous_run and _snapshot().run.phase=="day","real_new_outing_replicated",45000): return
	if not await _wait(func() -> bool: return game.controller.supply_bodies.size()==2 and last_poses.get("run_id","")==_snapshot().run.run_id,"new_run_supply_bodies_and_pose_epoch_received"): return
	if not _check(_cell("cell_1").state=="free" and _cell("cell_2").state=="free" and _cell("cell_1").carrier_id=="" and _cell("cell_2").carrier_id=="","new_outing_replenishes_exactly_two_unclaimed_cells"): return
	if not await _cell_pose("cell_1") or not await _cell_pose("cell_2"): return
	if not _check(game.controller.supply_bodies.cell_2.global_position.distance_to(previous_cell_position)>100.0*IslandWorld.LAYOUT_SCALE,"reused_cell_id_accepts_new_outing_low_sequence_pose"): return
	if not _check(_snapshot().lights.station_until.jetty==240.0 and _snapshot().lights.station_until.reeds==240.0,"new_outing_does_not_reuse_previous_cell_power"): return
	_ack("dawn_seen")
	if not await _wait(func() -> bool: return _has("dawn_pause") and _snapshot().run.paused,"new_outing_pause_replicated"): return
	var current_cell_position: Vector3=game.controller.supply_bodies.cell_2.global_position
	var current_player_position: Vector3=game.controller.avatars.crew_2.global_position
	_ack("dawn_pause_seen")
	if not await _wait(func() -> bool: return _has("delayed_old_pose") and game.session._last_pose_sequence>=int(_read("delayed_old_pose").get("pose_sequence",999999)) and last_poses.get("run_id","")==previous_run,"captured_old_epoch_packet_arrived_over_real_enet"): return
	if not _check(game.controller.supply_bodies.cell_2.global_position.distance_to(current_cell_position)<0.01 and game.controller.avatars.crew_2.global_position.distance_to(current_player_position)<0.01,"old_epoch_pose_cannot_rewind_current_cells_or_players"): return
	_ack("old_epoch_checked")
	if not await _wait(func() -> bool: return _has("host_exit") and game.session.status=="offline","actual_host_exit_received"): return
	if not _check(not game.controller.active and game.session.local_profile_id.is_empty(),"host_exit_stops_survival_simulation_on_client"): return
	await _finish()

func _snapshot() -> Dictionary:
	return game.controller.snapshot() if role=="host" else game.controller.snapshot_data

func _cell(id: String) -> Dictionary: return _snapshot().get("supplies",{}).get(id,{})
func _player(id: String) -> Dictionary: return _snapshot().get("run",{}).get("players",{}).get(id,{})

func _place(id: String,at: Vector3,yaw: float=0.0) -> void:
	game.controller.avatars[id].global_position=at
	game.controller.avatars[id].last_dry=at
	game.controller.avatars[id].velocity=Vector3.ZERO
	game.controller.avatars[id].rotation.y=yaw
	game.controller.inputs[id]={"direction":Vector2.ZERO,"yaw":yaw,"updated":Time.get_ticks_msec()/1000.0}

func _place_cell(id: String,at: Vector3) -> void:
	var body: RigidBody3D=game.controller.supply_bodies[id]
	body.global_position=at
	body.last_dry_position=at
	body.linear_velocity=Vector3.ZERO
	body.angular_velocity=Vector3.ZERO

func _cell_pose(id: String) -> bool:
	if not await _wait(func() -> bool: return game.controller.supply_bodies.has(id) and last_poses.get("supplies",{}).has(id),"cell_pose_packet_"+id): return false
	await create_timer(0.15).timeout
	var body: RigidBody3D=game.controller.supply_bodies[id]
	if not _check(body.freeze and body.collision_layer==0 and body.collision_mask==0,"client_cell_never_simulates_"+id): return false
	var newest: Dictionary=last_poses.supplies[id]
	var reliable: Dictionary=_snapshot().get("poses",{}).get("supplies",{}).get(id,{})
	if int(reliable.get("sequence",-1))>int(newest.get("sequence",-1)): newest=reliable
	var pose: Transform3D=newest.transform
	return _check(body.global_position.distance_to(pose.origin)<0.3,"cell_pose_matches_latest_authority_"+id,{"error_m":body.global_position.distance_to(pose.origin)})

func _check_player_pose(id: String) -> bool:
	if not _check(last_poses.get("players",{}).has(id),"moving_player_pose_received_"+id): return false
	var difference: float=game.controller.avatars[id].global_position.distance_to(last_poses.players[id].position)
	return _check(difference<0.3,"moving_player_pose_matches_authority_"+id,{"error_m":difference})

func _pose_barrier(stage: String) -> bool:
	var barrier: int=int(_read(stage).get("pose_sequence",-1))
	if not await _wait(func() -> bool: return game.session._last_pose_sequence>barrier,"fresh_pose_barrier_"+stage): return false
	var prior: int=pose_packets
	return await _wait(func() -> bool: return pose_packets>=prior+2,"interpolation_settled_"+stage)

func _send(action: String,payload: Dictionary) -> void:
	request_sequence+=1
	game.session.submit_intent(action,payload,"survival_"+role+"_"+str(request_sequence))

func _walk_cell_to(target: Vector3) -> bool:
	var deadline: int=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		if _cell("cell_1").get("carrier_id","")!="crew_3": return _check(false,"delivered_cell_lost_during_walk")
		var current: Vector3=game.controller.avatars.crew_3.global_position
		var direction: Vector2=Vector2(target.x-current.x,target.z-current.z)
		if direction.length()<0.35:
			_send("move",{"direction":Vector2.ZERO,"yaw":game.controller.avatars.crew_3.rotation.y})
			return _check(true,"remote_walk_reached_delivery_waypoint",{"position":current})
		_send("move",{"direction":direction.normalized(),"yaw":0.0})
		await create_timer(0.05).timeout
	return _check(false,"remote_walk_delivery_timeout",{"position":game.controller.avatars.crew_3.global_position,"target":target})

func _stage(tag: String) -> void:
	game.controller._publish()
	_write(tag,{"ready":true,"pose_sequence":game.session._pose_sequence})

func _ack(tag: String) -> void: _write(role+"_"+tag,{"ready":true})
func _stage_seen(tag: String) -> bool: return await _wait(func() -> bool: return _has(tag),"stage_"+tag)
func _acks(tag: String) -> bool: return await _wait(func() -> bool: return _has("client1_"+tag) and _has("client2_"+tag),"both_clients_"+tag)

func _wait(condition: Callable,label: String,timeout_ms: int=15000) -> bool:
	var deadline: int=Time.get_ticks_msec()+timeout_ms
	while not bool(condition.call()):
		if Time.get_ticks_msec()>deadline:
			var snapshot: Dictionary=_snapshot()
			return _check(false,"timeout_"+label,{"status":game.session.status,"roster":game.session.roster.snapshot(),"rejections":rejections,"notes":snapshot.get("notes",[]),"supplies":snapshot.get("supplies",{}),"poses":snapshot.get("poses",{})})
		await create_timer(0.05).timeout
	return _check(true,label)

func _check(condition: bool,label: String,evidence: Dictionary={}) -> bool:
	checks+=1
	print(JSON.stringify({"role":role,"check":label,"ok":condition,"evidence":evidence}))
	if not condition:
		_write(role+"_fail",{"ready":true,"check":label,"evidence":evidence})
		quit(1)
	return condition

func _write(tag: String,data: Dictionary) -> void:
	var file: FileAccess=FileAccess.open(output.path_join(tag+".json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(data))
		file.close()

func _read(tag: String) -> Dictionary:
	var path: String=output.path_join(tag+".json")
	if not FileAccess.file_exists(path): return {}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary: return {}
	return parser.data

func _has(tag: String) -> bool: return bool(_read(tag).get("ready",false))

func _finish() -> void:
	var result: Dictionary={"ready":true,"role":role,"checks":checks,"pose_packets":pose_packets,"scope":"three real ENet processes on loopback; authored injury/travel/night fixtures; no physical-PC or family-fun claim"}
	game.controller.active=false
	game.session.close()
	game.queue_free()
	await process_frame
	_write(role+"_pass",result)
	print("SURVIVAL_NETWORK_PASS "+JSON.stringify(result))
	quit(0)
