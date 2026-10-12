extends SceneTree

const PORT = 28993
var apps: Array = []
var apis: Array = []
var profiles: Array[String] = []
var results: Array = []
var failed = false
var host
var first
var second
var first_peer = 0
var second_peer = 0
var wire_sizes: Dictionary = {}
var measured_transport: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func wait_until(condition: Callable, seconds: float = 3.0) -> bool:
	var started = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started < seconds*1000: await process_frame
	return condition.call()

func check(ok: bool, name: String, details: Dictionary = {}) -> void:
	failed = failed or not ok
	var row = {"case":name,"pass":ok}
	row.merge(details)
	results.append(row)
	if not ok: printerr("FAIL: "+name)

func make_app(name: String, script: String):
	var branch = Node.new()
	branch.name = name
	root.add_child(branch)
	var api = SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app = load(script).new()
	app.name = "App"
	app.manual_input_enabled = false
	branch.add_child(app)
	app.muted = true
	app.nickname = name
	var path = "user://snapshot_transport_%s_%d.json" % [name,Time.get_ticks_usec()]
	profiles.append(path)
	app.profile = load("res://profile.gd").new(path)
	apps.append(app)
	apis.append(api)
	return app

func run() -> void:
	host = make_app("SnapshotHost","res://main.gd")
	var server = ENetMultiplayerPeer.new()
	if server.create_server(PORT,2,host.NETWORK_CHANNELS) != OK:
		check(false,"bind isolated test port")
		await finish()
		return
	host.multiplayer.multiplayer_peer = server
	host.selected_mode = "coop"
	host.show_lobby()
	for index in 2:
		var client = make_app("SnapshotClient%d"%index,"res://tests/snapshot_transport_client.gd")
		var peer = ENetMultiplayerPeer.new()
		peer.create_client("127.0.0.1",PORT,host.NETWORK_CHANNELS)
		client.multiplayer.multiplayer_peer = peer
		client.local_seat = 0
		client.seats.clear()
		client.names.clear()
		client.phase = "connecting"
		client.connect_time = client.ui_clock
	if not await wait_until(func(): return host.seats.size()==3 and apps[1].local_seat>0 and apps[2].local_seat>0):
		check(false,"three-peer handshake")
		await finish()
		return
	first = apps[1]
	second = apps[2]
	first_peer = first.multiplayer.get_unique_id()
	second_peer = second.multiplayer.get_unique_id()
	host.start_match()
	host.set_physics_process(false)
	await wait_until(func(): return first.phase=="match" and second.phase=="match")
	var small: Dictionary = host.state.duplicate(true)
	var packet: PackedByteArray = host.encode_snapshot()
	wire_sizes.normal = packet.size()
	check(packet.size()<=host.UNRELIABLE_SNAPSHOT_BYTES,"ordinary snapshot stays below unreliable threshold",wire_sizes)
	host.send_snapshot(first_peer,packet)
	var sequence: int = host.snapshot_serial
	check(await wait_until(func(): return first.snapshot_received_sequence==sequence),"ordinary snapshot uses real unreliable RPC")
	check(first.state==small,"ordinary decoded fields are preserved")
	# A plausible six-player power/collision snapshot with varied floating fields
	# reproduces the size class seen in the completed active-match recording.
	var rng = RandomNumberGenerator.new()
	rng.seed = 532861
	for id in host.sim.players:
		var p: Dictionary = host.sim.players[id]
		p.pos = Vector3(rng.randf_range(-17,17),rng.randf_range(0,12),rng.randf_range(-32,32))
		p.vel = Vector3(rng.randf_range(-18,18),rng.randf_range(-20,26),rng.randf_range(-18,18))
		p.aim = Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
		p.facing = -p.aim
		p.dunk_start = p.pos + Vector3(2.32,1.45,-1.34)
		p.dunk_target = p.pos + Vector3(-1.75,.85,2.08)
		p.dunk_velocity = p.vel*.73
		p.hype = rng.randf_range(0,100)
		p.guard = rng.randf_range(0,1.6)
		p.cooldown = rng.randf_range(0,.85)
		p.catch_time = rng.randf_range(0,.32)
		p.request_time = rng.randf_range(0,2.5)
		p.boost_time = rng.randf_range(0,1.3)
	host.sim.power_pads = [{"pos":Vector3(4.32,.5,-12.87),"time":7.53,"owner":1},{"pos":Vector3(-7.63,0,9.43),"time":9.23,"owner":5}]
	host.sim.power_balls = [{"id":1,"pos":Vector3(3.85,4.32,-11.35),"vel":Vector3(7.54,2.33,-9.73),"target":4,"owner":1,"time":2.81}]
	host.state = host.sim.snapshot()
	host.state.match_id = host.match_id
	host.state.cosmetics = {1:{"outfit":"space","accessory":"crown"},2:{"outfit":"gold","accessory":"headphones"},3:{"outfit":"stripes","accessory":"horns"}}
	host.state.reward_peers = []
	host.state.reward_seats = []
	var large: Dictionary = host.state.duplicate(true)
	packet = host.encode_snapshot()
	wire_sizes.large = packet.size()
	check(packet.size()>1392,"regression snapshot exceeds observed ENet MTU",{"bytes":packet.size()})
	sequence = host.snapshot_serial
	host.send_snapshot(first_peer,packet)
	host.send_snapshot(second_peer,packet)
	check(await wait_until(func(): return first.snapshot_received_sequence==sequence and second.snapshot_received_sequence==sequence and host.pending_snapshots.is_empty()),"large snapshots arrive and acknowledge on both real peers")
	check(first.state==large and second.state==large,"large decoded fields survive reliable fallback intact")
	first.hold_large = true
	packet = host.encode_snapshot()
	var delayed_sequence: int = host.snapshot_serial
	host.send_snapshot(first_peer,packet)
	await wait_until(func(): return first.held_packets.size()==1)
	var before_reliable: int = host.snapshot_transport.reliable
	for index in 12:
		host.state.clock = 20.0+index*.05
		packet = host.encode_snapshot()
		host.send_snapshot(first_peer,packet)
	host.send_snapshot(second_peer,packet)
	sequence = host.snapshot_serial
	check(await wait_until(func(): return second.snapshot_received_sequence==sequence and not host.pending_snapshots.has(second_peer)),"one delayed peer does not block another")
	var held_window_delivered = await wait_until(func(): return first.held_packets.size()==host.MAX_PENDING_SNAPSHOTS)
	check(held_window_delivered and first.held_packets.size()==host.MAX_PENDING_SNAPSHOTS and host.pending_snapshots.size()==1 and host.pending_snapshots[first_peer].sequences.size()==host.MAX_PENDING_SNAPSHOTS and host.snapshot_transport.reliable==before_reliable+host.MAX_PENDING_SNAPSHOTS and host.snapshot_transport.coalesced==13-host.MAX_PENDING_SNAPSHOTS,"reliable queue is bounded to four packets per peer",{"held":first.held_packets.size(),"coalesced":host.snapshot_transport.coalesced})
	host.state = small.duplicate(true)
	host.state.clock = 42.0
	# Prove that an actual small state crosses channel 1 while all reliable slots
	# remain held. Accept any sample from this stream: requiring the newest ID
	# every 50 ms races legitimate datagram loss and delayed frame polling.
	var first_small_sequence: int = host.snapshot_serial + 1
	var count_before_small: int = first.snapshot_count
	var small_started: int = Time.get_ticks_msec()
	var small_delivered = false
	var small_wire_ok = true
	var small_attempts: Array = []
	while not small_delivered and Time.get_ticks_msec() - small_started < 2000:
		packet = host.encode_snapshot()
		sequence = host.snapshot_serial
		small_wire_ok = small_wire_ok and packet.size() <= host.UNRELIABLE_SNAPSHOT_BYTES
		host.send_snapshot(first_peer,packet)
		small_delivered = await wait_until(func(): return first.snapshot_received_sequence >= first_small_sequence and first.snapshot_count > count_before_small and first.state.get("clock",-1)==42.0,.05)
		small_attempts.append({"sent":sequence,"received":first.snapshot_received_sequence,"clock":first.state.get("clock",-1),"elapsed_ms":Time.get_ticks_msec()-small_started,"enet_throttle":host.multiplayer.multiplayer_peer.get_peer(first_peer).get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),"enet_rtt_ms":host.multiplayer.multiplayer_peer.get_peer(first_peer).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)})
	var accepted_small_sequence: int = first.snapshot_received_sequence
	var still_held: int = host.pending_snapshots.get(first_peer,{}).get("sequences",[]).size()
	check(small_delivered and small_wire_ok and first.held_packets.size()==host.MAX_PENDING_SNAPSHOTS and still_held==host.MAX_PENDING_SNAPSHOTS,"newer small snapshots continue while reliable ACK is delayed",{"first_small_sequence":first_small_sequence,"accepted_sequence":accepted_small_sequence,"pending":still_held,"attempts":small_attempts})
	var stale_before: int = first.snapshot_transport.stale
	var no_rewind = small_delivered
	for held in host.MAX_PENDING_SNAPSHOTS:
		first.deliver_held()
		no_rewind = no_rewind and first.snapshot_received_sequence >= accepted_small_sequence and first.state.get("clock",-1)==42.0
	check(await wait_until(func(): return not host.pending_snapshots.has(first_peer)),"stale reliable fallback is acknowledged")
	check(no_rewind and first.snapshot_received_sequence>=accepted_small_sequence and first.state.get("clock",-1)==42.0 and first.snapshot_transport.stale-stale_before==host.MAX_PENDING_SNAPSHOTS,"late reliable fallback cannot rewind newer state",{"old_sequence":delayed_sequence,"accepted_sequence":accepted_small_sequence,"received_sequence":first.snapshot_received_sequence,"stale_delta":first.snapshot_transport.stale-stale_before})
	host.state = large.duplicate(true)
	packet = host.encode_snapshot()
	var pending_sequence: int = host.snapshot_serial
	host.send_snapshot(first_peer,packet)
	await wait_until(func(): return first.held_packets.size()==1)
	first.acknowledge_snapshot.rpc_id(1,host.match_id,pending_sequence+1)
	first.acknowledge_snapshot.rpc_id(1,"old-round",pending_sequence)
	second.acknowledge_snapshot.rpc_id(1,host.match_id,pending_sequence)
	await create_timer(.1).timeout
	check(host.pending_snapshots.has(first_peer),"wrong sequence, round, and peer cannot release a pending snapshot")
	measured_transport = host.snapshot_transport.duplicate()
	var old_round: String = host.match_id
	host.start_match()
	await wait_until(func(): return first.match_id==host.match_id)
	check(host.pending_snapshots.is_empty() and first.snapshot_received_sequence==-1,"rematch clears pending transport and receive ordering")
	host.state = large.duplicate(true)
	host.state.match_id = host.match_id
	packet = host.encode_snapshot()
	sequence = host.snapshot_serial
	host.send_snapshot(first_peer,packet)
	await wait_until(func(): return first.held_packets.size()==2)
	first.acknowledge_snapshot.rpc_id(1,old_round,sequence)
	first.deliver_held()
	await create_timer(.1).timeout
	check(host.pending_snapshots.has(first_peer) and first.snapshot_received_sequence==-1,"old-round packet and overlapping ACK cannot alter new round")
	first.deliver_held()
	check(await wait_until(func(): return first.snapshot_received_sequence==sequence and not host.pending_snapshots.has(first_peer)),"new-round fallback still completes")
	var accepted_before: int = first.snapshot_count
	first.receive_state(var_to_bytes(first.state).compress(FileAccess.COMPRESSION_DEFLATE))
	check(first.snapshot_count==accepted_before,"snapshot sequence metadata is required")
	first.hold_large = false
	first.hold_begin = true
	old_round = first.match_id
	host.start_match()
	await wait_until(func(): return not first.held_begin.is_empty())
	host.state = large.duplicate(true)
	host.state.match_id = host.match_id
	packet = host.encode_snapshot()
	host.send_snapshot(first_peer,packet)
	check(await wait_until(func(): return not host.pending_snapshots.has(first_peer)),"early new-round reliable snapshot is acknowledged before begin notification")
	check(first.match_id==old_round,"early new-round snapshot is not applied to old match")
	first.deliver_begin()
	packet = host.encode_snapshot()
	sequence = host.snapshot_serial
	host.send_snapshot(first_peer,packet)
	check(await wait_until(func(): return first.snapshot_received_sequence==sequence and not host.pending_snapshots.has(first_peer)),"oversized state resumes after delayed begin notification")
	first.hold_large = true
	packet = host.encode_snapshot()
	host.send_snapshot(first_peer,packet)
	await wait_until(func(): return first.held_packets.size()==1)
	first.close_session("")
	check(await wait_until(func(): return not host.seats.has(first_peer) and not host.pending_snapshots.has(first_peer)),"leaving releases pending transport state")
	var sent_before: int = host.snapshot_transport.reliable
	host.send_snapshot(first_peer,packet)
	check(host.snapshot_transport.reliable==sent_before,"removed seats never receive another fallback")
	await finish()

func finish() -> void:
	var summary = {"passed":not failed,"cases":results,"wire_bytes":wire_sizes,"transport":measured_transport}
	var file = FileAccess.open("res://tests/snapshot-transport-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	file.close()
	print("SNAPSHOT_TRANSPORT_RESULT "+JSON.stringify(summary))
	for app in apps:
		app.phase="closed"
		app._closing=true
	for api in apis:
		if api.multiplayer_peer: api.multiplayer_peer.close()
		api.multiplayer_peer=OfflineMultiplayerPeer.new()
	for suffix in ["", ".bak", ".tmp"]:
		for path in profiles:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	await process_frame
	quit(1 if failed else 0)


