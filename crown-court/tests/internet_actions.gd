extends "res://tests/network_actions.gd"

var base_port = 30180
var single_slot = false
var output_dir = ""
var previous_snapshot_count = 0
var previous_snapshot_usec = 0
var arrival_gaps: Array = []
var round_trips: Array = []
var probe_age = 0.0
var live_written = false
var maximum_reliable = 0
var maximum_unreliable = 0
var snapshot_transport = {}
var large_arrival_gaps: Array = []
var large_packets: Array = []
var previous_large_usec = 0
var previous_any_usec = 0
var previous_any_large = false
var consecutive_large_gaps: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): base_port=int(arg.substr(7))
		if arg.begins_with("--output="): output_dir=arg.substr(9)
		if arg=="--single-slot":single_slot=true
	super._initialize()

func boot() -> void:
	coordinator = load("res://tests/internet_coordinator.gd").new()
	coordinator.name = "NetworkActionsCoordinator"
	coordinator.driver = self
	root.add_child(coordinator)
	app = load("res://tests/internet_transport.gd").new()
	app.name = "NetworkActionsApp"
	app.test_port=base_port
	app.test_observer=self
	app.test_single_slot=single_slot
	app.manual_input_enabled=false
	root.add_child(app)
	app.nickname="INTERNET "+role
	app.muted=true
	profile_path="user://internet_actions_%s_%d.json" % [role,Time.get_ticks_usec()]
	app.profile=load("res://profile.gd").new(profile_path)
	app.balance_teams=false
	if role=="host": app.host_game("teams")
	else: app.join_game("127.0.0.1:%d" % (base_port+(1 if role=="client1" else 2)))

func _process(dt: float) -> bool:
	observe_network(dt)
	return super._process(dt)

func observe_network(dt: float) -> void:
	if is_instance_valid(app) and not reported:
		if app.snapshot_count != previous_snapshot_count:
			var now = Time.get_ticks_usec()
			if previous_snapshot_usec>0: arrival_gaps.append(float(now-previous_snapshot_usec)/1000.0)
			previous_snapshot_usec=now
			previous_snapshot_count=app.snapshot_count
		if role=="host":
			snapshot_transport=app.snapshot_transport.duplicate()
			maximum_reliable=maxi(maximum_reliable,int(snapshot_transport.get("max_reliable_bytes",0)))
			maximum_unreliable=maxi(maximum_unreliable,int(snapshot_transport.get("max_unreliable_bytes",0)))
		elif app.phase=="match":
			probe_age+=dt
			if probe_age>.4:
				probe_age=0
				coordinator.latency_probe.rpc_id(1,Time.get_ticks_usec())
		if elapsed>10 and not live_written:
			live_written=true
			write_report(role+"-live",metrics())

func record_packet(size_bytes: int, large: bool, accepted: bool) -> void:
	if not accepted:return
	var now=Time.get_ticks_usec()
	if large and previous_any_large and previous_any_usec>0:consecutive_large_gaps.append(float(now-previous_any_usec)/1000.0)
	previous_any_usec=now
	previous_any_large=large
	if not large:return
	if previous_large_usec>0:large_arrival_gaps.append(float(now-previous_large_usec)/1000.0)
	previous_large_usec=now
	large_packets.append({"time_usec":now,"bytes":size_bytes})

func begin_stage(index: int) -> void:
	if index==0:
		# Inactive distant fixture bots make a genuine six-player snapshot; no fake payload padding.
		var template = app.Sim.new()
		template.reset("coop")
		for id in [4,5,6]:
			app.sim.players[id]=template.players[id].duplicate(true)
			app.sim.players[id].pos=Vector3(-18,app.sim.floor_height(-18,(id-5)*20),float((id-5)*20))
			app.sim.players[id].stun=3600.0+id
			app.sim.players[id].power=["giant","pad","blast"][id-4]
	super.begin_stage(index)

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted=values.duplicate()
	sorted.sort()
	var total=0.0
	for value in sorted: total+=float(value)
	return {"count":sorted.size(),"min":sorted[0],"mean":total/sorted.size(),"p50":sorted[int(sorted.size()*.5)],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1]}

func metrics() -> Dictionary:
	return {"label":"SIMULATED_INTERNET","role":role,"transport_policy":"test_fixture_old_single_slot" if single_slot else "production","snapshot_arrival_gap_ms":stats(arrival_gaps),"large_snapshot_arrival_gap_ms":stats(large_arrival_gaps),"consecutive_large_arrival_gap_ms":stats(consecutive_large_gaps),"encoded_packet_bytes":stats(app.test_encoded_sizes),"large_packets":large_packets,"application_probe_rtt_ms":stats(round_trips),"received_snapshots":app.snapshot_count,"snapshot_transport":snapshot_transport,"maximum_reliable_bytes":maximum_reliable,"maximum_unreliable_bytes":maximum_unreliable,"six_player_snapshot":app.state.get("players",{}).size()==6}

func write_report(name: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file=FileAccess.open(output_dir.path_join(name+".json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(payload,"\t"))

func complete(report: Dictionary) -> void:
	if reported:return
	reported=true
	instruction={}
	var ok=bool(report.get("ok",false)) and local_checkpoints.size()==STAGES.size() and peak_roster==3
	if role!="host":ok=ok and app.snapshot_count>20 and round_trips.size()>2
	else:ok=ok and maximum_reliable>1200 and app.state.players.size()==6
	var output=report.duplicate(true)
	output.merge(metrics())
	output["checkpoints"]=local_checkpoints
	output["submitted_actions"]=submitted_actions
	output["fixture_mutations"]=true
	output["fixture_description"]="Controlled starting positions and three distant stunned bots; actions and scores use production RPC/simulation paths."
	if role=="host":
		await create_timer(2.5).timeout
		output["graceful_disconnect_remaining_seats"]=app.seats.size()
		ok=ok and app.seats.size()==1
	else:await create_timer(.5).timeout
	output["ok"]=ok
	write_report(role,output)
	print("INTERNET_ACTIONS_RESULT "+JSON.stringify(output))
	app.close_session("")
	await create_timer(.4).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if ok else 1)
