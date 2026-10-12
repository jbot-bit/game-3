extends SceneTree

class Probe extends Node:
	const Peer = preload("res://room_peer.gd")
	var room_peer
	var role = "host"
	var received: Dictionary = {}
	var done: Dictionary = {}
	var sent_result = false
	var quitting = false
	var elapsed = 0.0
	var ready_seen = false

	func _ready() -> void:
		var args: Dictionary = {}
		for argument in OS.get_cmdline_user_args():
			var parts = argument.split("=", true, 1)
			if parts.size() == 2: args[parts[0]] = parts[1]
		role = str(args.get("role", "host"))
		var invalid = Peer.new()
		check(invalid.configure("ws://example.com/rooms", true) == ERR_INVALID_PARAMETER, "remote plaintext rejected")
		check(invalid.configure("ws://127.0.0.1:30220/rooms", false, "bad") == ERR_INVALID_PARAMETER, "bad code rejected")
		room_peer = Peer.new()
		room_peer.room_ready.connect(func(code: String):
			ready_seen = true
			check(room_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "ready state")
			if role == "host": print("ROOM_TEST_CODE " + code)
		)
		room_peer.room_error.connect(func(message: String): fail(message))
		room_peer.peer_connected.connect(func(_id: int): check(ready_seen, "room_ready precedes peer_connected"))
		multiplayer.server_relay = false
		multiplayer.connected_to_server.connect(connected)
		var error = room_peer.configure(str(args.get("url", "ws://127.0.0.1:30220/rooms")), role == "host", str(args.get("code", "")), "room-test-v1")
		check(error == OK, "configure accepted")
		check(room_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING, "not connected before registration")
		multiplayer.multiplayer_peer = room_peer

	func connected() -> void:
		if role == "host": return
		check(multiplayer.get_unique_id() >= 2 and not multiplayer.is_server(), "client identity")
		var small = PackedByteArray([1, 2, 3, 255])
		var large = PackedByteArray()
		large.resize(8192)
		large.fill(77)
		channel_zero.rpc_id(1, small)
		channel_one.rpc_id(1, small)
		channel_two.rpc_id(1, small)
		channel_three.rpc_id(1, small)
		channel_four.rpc_id(1, large)

	func _process(dt: float) -> void:
		elapsed += dt
		if elapsed > 15: fail("RPC test timed out")
		if role != "host" or quitting: return
		if received.size() == 2 and not sent_result:
			var count = 0
			for channels in received.values(): count += channels.size()
			if count == 10:
				sent_result = true
				for peer in received: result.rpc_id(int(peer), {"blue":2,"orange":1}, 5)
		if done.size() == 2 and multiplayer.get_peers().is_empty():
			quitting = true
			print("ROOM_RPC_PASS host: ten RPCs, five channels, two identities, shared result, graceful leaves")
			room_peer.close()
			get_tree().quit(0)

	func got(channel: int, payload: PackedByteArray) -> void:
		check(role == "host" and multiplayer.is_server(), "host authority")
		var sender = multiplayer.get_remote_sender_id()
		check(sender >= 2, "validated remote identity")
		check(payload.size() == (8192 if channel == 4 else 4), "opaque payload length")
		if not received.has(sender): received[sender] = {}
		received[sender][channel] = true

	@rpc("any_peer", "call_remote", "reliable", 0)
	func channel_zero(payload: PackedByteArray) -> void: got(0, payload)
	@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
	func channel_one(payload: PackedByteArray) -> void: got(1, payload)
	@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
	func channel_two(payload: PackedByteArray) -> void: got(2, payload)
	@rpc("any_peer", "call_remote", "reliable", 3)
	func channel_three(payload: PackedByteArray) -> void: got(3, payload)
	@rpc("any_peer", "call_remote", "reliable", 4)
	func channel_four(payload: PackedByteArray) -> void: got(4, payload)
	@rpc("authority", "call_remote", "reliable", 0)
	func result(scores: Dictionary, count: int) -> void:
		check(multiplayer.get_remote_sender_id() == 1 and scores.blue == 2 and scores.orange == 1 and count == 5, "authoritative shared result")
		finished.rpc_id(1)
		await get_tree().create_timer(0.2).timeout
		print("ROOM_RPC_PASS " + role + ": five channels and shared result")
		room_peer.close()
		await get_tree().create_timer(0.2).timeout
		get_tree().quit(0)
	@rpc("any_peer", "call_remote", "reliable", 0)
	func finished() -> void: done[multiplayer.get_remote_sender_id()] = true

	func check(condition: bool, message: String) -> void:
		if not condition: fail(message)
	func fail(message: String) -> void:
		push_error("ROOM_RPC_FAIL " + role + ": " + message)
		get_tree().quit(1)

func _initialize() -> void:
	var probe = Probe.new()
	probe.name = "RoomRpcProbe"
	root.add_child.call_deferred(probe)
