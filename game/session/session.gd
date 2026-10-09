class_name Session
extends Node

signal intent_received(peer_id: int, action: String, payload: Dictionary, request_id: String)
signal snapshot_received(data: Dictionary)
signal poses_received(data: Dictionary)
signal roster_changed(data: Dictionary)
signal status_changed(status: String, message: String)
signal peer_left(profile_id: String)
signal intent_rejected(request_id: String, code: String)

const RosterModel = preload("res://game/session/roster.gd")
const GateModel = preload("res://game/session/intent_gate.gd")
const BUILD_ID: String = "0.2.0-campaign"
const PROTOCOL: int = 1
var roster = RosterModel.new()
var local_profile_id: String = ""
var status: String = "offline"
var preferred_slot: int = -1
var display_name: String = ""
var admission_locked: bool=false
var gate = GateModel.new()
var _hosting: bool = false
var _requests: Dictionary = {}
var _pending_peers: Dictionary = {}
var _latest_snapshot: Dictionary = {}
var _pose_sequence: int = 0
var _last_pose_sequence: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every game message goes through the host; the authoritative roster already
	# tells clients who is present. Disable redundant peer-to-peer relay before
	# connecting, including its sends inside ENet's disconnect-poll callbacks.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func _process(_delta: float) -> void:
	if not _hosting:
		return
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _pending_peers.keys():
		if now - int(_pending_peers[peer_id]) > 5000:
			_pending_peers.erase(peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)

func host(port: int = 24563) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, 2)
	if error != OK:
		_set_status("offline", "Unable to host on port %d (error %d)." % [port, error])
		return error
	multiplayer.multiplayer_peer = peer
	_hosting = true
	roster.assign(1, 0, BUILD_ID)
	local_profile_id = "crew_1"
	_set_status("hosting", "Hosting for two crew members on port %d." % port)
	roster_changed.emit(roster.snapshot())
	return OK

func join(address: String, port: int = 24563) -> Error:
	close()
	if address.strip_edges().is_empty():
		_set_status("offline", "Enter the host computer's LAN address.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address.strip_edges(), port)
	if error != OK:
		_set_status("offline", "Unable to connect (error %d)." % error)
		return error
	multiplayer.multiplayer_peer = peer
	_set_status("connecting", "Connecting to %s:%d..." % [address, port])
	return OK

func close() -> void:
	_hosting = false
	admission_locked=false
	if is_inside_tree() and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = RosterModel.new()
	gate = GateModel.new()
	local_profile_id = ""
	_requests.clear()
	_pending_peers.clear()
	_latest_snapshot.clear()
	_pose_sequence = 0
	_last_pose_sequence = -1
	status = "offline"

func is_host() -> bool:
	return _hosting

func set_paused(value: bool) -> void:
	gate.set_paused(value)

func submit_intent(action: String, payload: Dictionary, request_id: String) -> void:
	if _hosting:
		_dispatch(1, action, payload, request_id)
	elif status == "connected":
		_receive_intent.rpc_id(1, action, payload, request_id)

func publish_snapshot(data: Dictionary) -> void:
	if not _hosting:
		return
	_latest_snapshot = data.duplicate(true)
	_receive_snapshot.rpc(data)
	snapshot_received.emit(data.duplicate(true))

func publish_poses(data: Dictionary) -> void:
	if not _hosting:
		return
	_pose_sequence += 1
	_receive_poses.rpc(_pose_sequence, data)

func _dispatch(peer_id: int, action: String, payload: Dictionary, request_id: String) -> void:
	if request_id.is_empty() or request_id.length() > 128:
		_reject_intent(peer_id, request_id, "invalid_request")
		return
	var allowed: Dictionary = gate.authorize(peer_id, action, payload, roster)
	if not allowed.ok:
		_reject_intent(peer_id, request_id, allowed.code)
		return
	if not _requests.has(peer_id):
		_requests[peer_id] = {}
	if _requests[peer_id].has(request_id):
		_reject_intent(peer_id, request_id, "duplicate")
		return
	_requests[peer_id][request_id] = true
	intent_received.emit(peer_id, action, payload.duplicate(true), request_id)

func _reject_intent(peer_id: int, request_id: String, code: String) -> void:
	if peer_id == 1:
		intent_rejected.emit(request_id, code)
	elif peer_id in multiplayer.get_peers():
		_intent_rejection.rpc_id(peer_id, request_id, code)

func _peer_connected(peer_id: int) -> void:
	if _hosting:
		_pending_peers[peer_id] = Time.get_ticks_msec()

func _peer_disconnected(peer_id: int) -> void:
	if not _hosting:
		return
	_pending_peers.erase(peer_id)
	_requests.erase(peer_id)
	var profile_id: String = roster.disconnect_peer(peer_id)
	if not profile_id.is_empty():
		peer_left.emit(profile_id)
		_broadcast_roster()

func _connected_to_server() -> void:
	_join_request.rpc_id(1, BUILD_ID, PROTOCOL, preferred_slot)

func _connection_failed() -> void:
	close()
	_set_status("offline", "Connection failed. Check the host address and Private-network firewall access.")

func _server_disconnected() -> void:
	close()
	_set_status("offline", "The host left. Confirmed household progress remains saved on the host.")

func _broadcast_roster() -> void:
	roster_changed.emit(roster.snapshot())
	# A second disconnect may already have cleared its ENet channels while its
	# callback is still queued. Send only after the transport finishes polling.
	_send_roster.call_deferred()

func _send_roster() -> void:
	if _hosting:
		_roster_update.rpc(roster.snapshot())

func _set_status(value: String, message: String) -> void:
	status = value
	status_changed.emit(value, message)

@rpc("any_peer", "call_remote", "reliable")
func _join_request(build_id: String, protocol: int, slot: int) -> void:
	if not _hosting:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= 1:
		return
	if protocol != PROTOCOL or build_id != BUILD_ID:
		_join_rejected.rpc_id(peer_id, "Build mismatch. Expected %s / protocol %d." % [BUILD_ID, PROTOCOL])
		return
	if admission_locked:
		_join_rejected.rpc_id(peer_id,"Moth is sailing. Join after the next dawn, or after the host chooses Continue Island.")
		return
	if slot == -1:
		for candidate: int in range(3):
			if not roster.snapshot().has("crew_%d" % (candidate + 1)):
				slot = candidate
				break
	var result: Dictionary = roster.assign(peer_id, slot, build_id)
	if not result.ok:
		_join_rejected.rpc_id(peer_id, "Cannot join: %s." % result.code)
		return
	_pending_peers.erase(peer_id)
	_join_accepted.rpc_id(peer_id, result.profile_id, roster.snapshot())
	if not _latest_snapshot.is_empty():
		_receive_snapshot.rpc_id(peer_id, _latest_snapshot)
	_broadcast_roster()

@rpc("authority", "call_remote", "reliable")
func _join_accepted(profile_id: String, data: Dictionary) -> void:
	if _hosting:
		return
	local_profile_id = profile_id
	_roster_update(data)
	_set_status("connected", "Joined as %s. Disconnected pouch cargo is forfeited; shared whole fish remain." % profile_id)

@rpc("authority", "call_remote", "reliable")
func _join_rejected(message: String) -> void:
	close()
	_set_status("rejected", message)

@rpc("authority", "call_remote", "reliable")
func _roster_update(data: Dictionary) -> void:
	if _hosting:
		return
	roster = RosterModel.new()
	for profile_id: String in data:
		var entry: Dictionary = data[profile_id]
		roster.assign(int(entry.peer_id), int(entry.slot), BUILD_ID)
	roster_changed.emit(roster.snapshot())

@rpc("any_peer", "call_remote", "reliable")
func _receive_intent(action: String, payload: Dictionary, request_id: String) -> void:
	if _hosting:
		_dispatch(multiplayer.get_remote_sender_id(), action, payload, request_id)

@rpc("authority", "call_remote", "reliable")
func _intent_rejection(request_id: String, code: String) -> void:
	intent_rejected.emit(request_id, code)

@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(data: Dictionary) -> void:
	if not _hosting:
		snapshot_received.emit(data)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_poses(sequence: int, data: Dictionary) -> void:
	if not _hosting and sequence > _last_pose_sequence:
		_last_pose_sequence = sequence
		poses_received.emit(data)
