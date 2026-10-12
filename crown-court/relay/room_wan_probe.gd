extends SceneTree
class Probe extends Node:
	const Peer = preload("res://room_peer.gd")
	var role = "host"
	var code = ""
	var peer
	var elapsed = 0.0
	var state_clock = 0.0
	var action_clock = 0.0
	var state_seq = 0
	var action_seq = 0
	var pending_states: Dictionary = {}
	var action_seen: Dictionary = {}
	var pending_actions: Dictionary = {}
	var finished_peers: Dictionary = {}
	var state_count = 0
	var ack_count = 0
	var last_state_at = -1
	var max_gap_ms = 0
	var max_action_ms = 0
	var max_pending = 0
	var max_socket_buffer = 0
	var state_frame_count = 0
	var max_state_burst = 0
	var rejoined = false
	var old_id = 0
	var finishing = false
	var payload = PackedByteArray()

	func _ready() -> void:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("role="): role = arg.substr(5)
			if arg.begins_with("code="): code = arg.substr(5)
		payload.resize(8192)
		payload.fill(91)
		multiplayer.server_relay = false
		multiplayer.peer_connected.connect(func(id: int):
			if role == "host": pending_states[id] = []
		)
		multiplayer.peer_disconnected.connect(func(id: int): pending_states.erase(id))
		connect_room()

	func connect_room() -> void:
		peer = Peer.new()
		peer.room_ready.connect(func(value: String):
			code = value
			print("WAN_ID " + role + ":" + str(peer.get_unique_id()))
			if role == "host": print("ROOM_TEST_CODE " + code)
			elif rejoined and peer.get_unique_id() <= old_id: fail("rejoin reused identity")
		)
		peer.room_error.connect(func(message: String): fail(message))
		var err = peer.configure("ws://127.0.0.1:30221/rooms", role == "host", code, "wan-probe-v1")
		if err != OK: fail("configure failed")
		multiplayer.multiplayer_peer = peer

	func _process(dt: float) -> void:
		elapsed += dt
		max_state_burst = maxi(max_state_burst, state_frame_count)
		state_frame_count = 0
		if elapsed > 16: fail("WAN probe timed out")
		if finishing: return
		max_socket_buffer = maxi(max_socket_buffer, peer._socket.get_current_outbound_buffered_amount())
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
		if role == "host":
			state_clock += dt
			if state_clock >= 0.05:
				state_clock = 0
				state_seq += 1
				for id in pending_states:
					if pending_states[id].size() < 4:
						pending_states[id].append(state_seq)
						max_pending = maxi(max_pending, pending_states[id].size())
						snapshot.rpc_id(int(id), state_seq, payload)
			if finished_peers.size() == 2 and multiplayer.get_peers().is_empty():
				if max_pending > 4 or action_seen.size() != 3: fail("snapshot flight window or post-rejoin input failed")
				finish({"role":role,"ok":true,"max_pending_snapshots":max_pending,"max_socket_buffer_bytes":max_socket_buffer,"identities":action_seen.keys()})
		else:
			if role == "client1" and elapsed > 4.2 and not rejoined and pending_actions.is_empty():
				rejoined = true
				old_id = peer.get_unique_id()
				peer.close()
				multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
				connect_room()
				return
			action_clock += dt
			var waiting_for_rejoin = role == "client1" and elapsed > 4.2 and not rejoined
			if elapsed < 7.5 and action_clock >= .2 and not waiting_for_rejoin:
				action_clock = 0
				action_seq += 1
				pending_actions[action_seq] = Time.get_ticks_msec()
				action_request.rpc_id(1, action_seq)
			if elapsed > 8.3 and pending_actions.is_empty():
				if ack_count < 20 or state_count < 30 or max_gap_ms < 600 or max_state_burst > 8 or (role == "client1" and not rejoined):
					fail("coverage, stall, or burst assertion failed")
					return
				finishing = true
				finished.rpc_id(1, role)
				await get_tree().create_timer(.25).timeout
				finish({"role":role,"ok":true,"actions_acked":ack_count,"states":state_count,"max_snapshot_gap_ms":max_gap_ms,"max_action_round_trip_ms":max_action_ms,"max_state_burst_per_frame":max_state_burst,"max_socket_buffer_bytes":max_socket_buffer,"rejoined":rejoined})

	@rpc("authority", "call_remote", "reliable", 4)
	func snapshot(sequence: int, bytes: PackedByteArray) -> void:
		if bytes.size() != 8192 or bytes[0] != 91: fail("snapshot payload changed")
		var now = Time.get_ticks_msec()
		if last_state_at >= 0: max_gap_ms = maxi(max_gap_ms, now - last_state_at)
		last_state_at = now
		state_count += 1
		state_frame_count += 1
		ack_snapshot.rpc_id(1, sequence)
	@rpc("any_peer", "call_remote", "reliable", 4)
	func ack_snapshot(sequence: int) -> void:
		var id = multiplayer.get_remote_sender_id()
		if pending_states.has(id): pending_states[id].erase(sequence)
	@rpc("any_peer", "call_remote", "reliable", 3)
	func action_request(sequence: int) -> void:
		var id = multiplayer.get_remote_sender_id()
		if not action_seen.has(id): action_seen[id] = {}
		if action_seen[id].has(sequence): fail("duplicate action after reconnect")
		action_seen[id][sequence] = true
		action_receipt.rpc_id(id, sequence)
	@rpc("authority", "call_remote", "reliable", 3)
	func action_receipt(sequence: int) -> void:
		if not pending_actions.has(sequence): fail("unexpected action receipt")
		max_action_ms = maxi(max_action_ms, Time.get_ticks_msec() - int(pending_actions.get(sequence, Time.get_ticks_msec())))
		pending_actions.erase(sequence)
		ack_count += 1
	@rpc("any_peer", "call_remote", "reliable", 0)
	func finished(client_role: String) -> void: finished_peers[client_role] = multiplayer.get_remote_sender_id()

	func finish(report: Dictionary) -> void:
		finishing = true
		print("ROOM_WAN_RESULT " + JSON.stringify(report))
		peer.close()
		get_tree().quit(0)
	func fail(message: String) -> void:
		push_error("ROOM_WAN_FAIL " + role + ": " + message)
		get_tree().quit(1)

func _initialize() -> void:
	var probe = Probe.new()
	probe.name = "RoomWanProbe"
	root.add_child.call_deferred(probe)


