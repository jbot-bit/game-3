extends Node
## Separate protocol and port: this experiment cannot join the fishing game.
signal players_changed(data: Dictionary)
signal status_changed(message: String)
signal controls_received(id: String, data: Dictionary)
signal action_received(id: String, action: String, value: String)
signal state_received(data: Dictionary)
signal poses_received(data: Dictionary)

const BUILD = "hands-full-0.2.0"
const PORT = 24573
const CHUNK_BYTES = 900
const RAW_LIMIT = 32768
var hosting = false
var connected = false
var local_id = ""
var players: Dictionary = {}
var display_name = "Player"
var latest_state: Dictionary = {}
var pending: Dictionary = {}
var rates: Dictionary = {}
var send_sequence = 0
var received_sequence = -1
var incoming_sequence = -1
var incoming_part = 0
var incoming_total = 0
var incoming_size = 0
var incoming_bytes = PackedByteArray()

func _ready() -> void:
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.peer_connected.connect(func(peer):
		if hosting: pending[peer] = Time.get_ticks_msec())
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(func(): _hello.rpc_id(1, BUILD, display_name))
	multiplayer.connection_failed.connect(func(): close(); status_changed.emit("Could not connect. Check the host address."))
	multiplayer.server_disconnected.connect(func(): close(); status_changed.emit("The host left."))

func _process(_delta: float) -> void:
	if not hosting: return
	for peer in pending.keys():
		if Time.get_ticks_msec() - int(pending[peer]) > 5000:
			pending.erase(peer)
			multiplayer.multiplayer_peer.disconnect_peer(peer)

func host(player_name: String, port: int = PORT) -> Error:
	close()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error != OK:
		status_changed.emit("Could not host. Port %d is busy." % port)
		return error
	multiplayer.multiplayer_peer = peer
	hosting = true
	connected = true
	local_id = "crew_1"
	players[local_id] = {"peer": 1, "slot": 0, "name": clean_name(player_name)}
	players_changed.emit(players.duplicate(true))
	return OK

func join(address: String, player_name: String, port: int = PORT) -> Error:
	close()
	if address.strip_edges().is_empty():
		status_changed.emit("Enter the host PC's LAN address.")
		return ERR_INVALID_PARAMETER
	display_name = clean_name(player_name)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(), port)
	if error != OK:
		status_changed.emit("Could not connect. Check the host address.")
		return error
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connecting…")
	return OK

func close() -> void:
	hosting = false
	connected = false
	local_id = ""
	if is_inside_tree() and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	pending.clear()
	rates.clear()
	latest_state.clear()
	send_sequence = 0
	received_sequence = -1
	incoming_sequence = -1
	incoming_bytes.clear()
	players_changed.emit({})

static func clean_name(value: String) -> String:
	var cleaned = ""
	for letter in value.strip_edges():
		if letter.unicode_at(0) >= 32 and letter.unicode_at(0) != 127: cleaned += letter
	return cleaned.left(20) if not cleaned.is_empty() else "Player"

func _profile(peer: int) -> String:
	for id in players:
		if int(players[id].peer) == peer: return id
	return ""

func _peer_left(peer: int) -> void:
	pending.erase(peer)
	rates.erase(peer)
	if not hosting: return
	players.erase(_profile(peer))
	players_changed.emit(players.duplicate(true))
	_broadcast_roster.call_deferred()

func _broadcast_roster() -> void:
	if hosting: _roster.rpc(players)

@rpc("any_peer", "call_remote", "reliable")
func _hello(build: String, player_name: String) -> void:
	if not hosting: return
	var peer = multiplayer.get_remote_sender_id()
	if peer <= 1 or not pending.has(peer): return
	if build != BUILD:
		_rejected.rpc_id(peer, "Different game version.")
		return
	var id = ""
	var slot = -1
	for candidate in range(3):
		if not players.has("crew_%d" % (candidate + 1)):
			slot = candidate
			id = "crew_%d" % (candidate + 1)
			break
	if slot < 0:
		_rejected.rpc_id(peer, "Three players are already here.")
		return
	pending.erase(peer)
	players[id] = {"peer": peer, "slot": slot, "name": clean_name(player_name)}
	players_changed.emit(players.duplicate(true))
	_accepted.rpc_id(peer, id, players)
	if not latest_state.is_empty(): _state.rpc_id(peer, latest_state)
	_broadcast_roster.call_deferred()

@rpc("authority", "call_remote", "reliable")
func _accepted(id: String, data: Dictionary) -> void:
	local_id = id
	connected = true
	_roster(data)
	status_changed.emit("")

@rpc("authority", "call_remote", "reliable")
func _rejected(message: String) -> void:
	close()
	status_changed.emit(message)

@rpc("authority", "call_remote", "reliable")
func _roster(data: Dictionary) -> void:
	if hosting: return
	players = data.duplicate(true)
	players_changed.emit(players.duplicate(true))

static func valid_controls(data: Dictionary) -> bool:
	if data.size() != 8: return false
	if not data.get("move") is Vector2 or not data.move.is_finite() or data.move.length() > 1.01: return false
	for key in ["yaw", "pitch"]:
		if not data.get(key) is float and not data.get(key) is int: return false
		if not is_finite(float(data[key])) or absf(float(data[key])) > 100.0: return false
	for key in ["jump", "left", "right", "limp"]:
		if not data.get(key) is bool: return false
	if not data.get("tick") is int: return false
	return true

func controls(data: Dictionary) -> void:
	if not connected or not valid_controls(data): return
	if hosting: controls_received.emit(local_id, data)
	else: _controls.rpc_id(1, data)

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _controls(data: Dictionary) -> void:
	if not hosting or not valid_controls(data): return
	var peer = multiplayer.get_remote_sender_id()
	var id = _profile(peer)
	if id.is_empty(): return
	var previous: Dictionary = rates.get(peer, {"tick": -1, "time": -100})
	if int(data.tick) <= int(previous.tick): return
	if Time.get_ticks_msec() - int(previous.time) < 8: return
	rates[peer] = {"tick": data.tick, "time": Time.get_ticks_msec()}
	controls_received.emit(id, data)

func act(action: String, value: String = "") -> void:
	if not connected: return
	if hosting: _dispatch(local_id, action, value)
	else: _action.rpc_id(1, action, value)

@rpc("any_peer", "call_remote", "reliable")
func _action(action: String, value: String) -> void:
	if hosting: _dispatch(_profile(multiplayer.get_remote_sender_id()), action, value)

func _dispatch(id: String, action: String, value: String) -> void:
	if id.is_empty() or value.length() > 32: return
	if action not in ["power", "switch", "recover", "restart", "next_course"]: return
	if action in ["restart", "next_course"] and id != "crew_1": return
	action_received.emit(id, action, value)

func publish_state(data: Dictionary) -> void:
	if not hosting: return
	latest_state = data.duplicate(true)
	_state.rpc(data)
	state_received.emit(data)

@rpc("authority", "call_remote", "reliable")
func _state(data: Dictionary) -> void:
	if not hosting: state_received.emit(data)

func publish_poses(data: Dictionary) -> void:
	if not hosting: return
	var raw = var_to_bytes(data)
	if raw.size() > RAW_LIMIT: return
	var packed = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var total = ceili(float(packed.size()) / CHUNK_BYTES)
	send_sequence += 1
	for index in range(total):
		_pose_chunk.rpc(send_sequence, index, total, raw.size(), packed.slice(index * CHUNK_BYTES, (index + 1) * CHUNK_BYTES))

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _pose_chunk(sequence: int, part: int, total: int, raw_size: int, bytes: PackedByteArray) -> void:
	if hosting or sequence <= received_sequence or sequence < incoming_sequence: return
	if total < 1 or total > 40 or part < 0 or part >= total or raw_size < 8 or raw_size > RAW_LIMIT or bytes.is_empty() or bytes.size() > CHUNK_BYTES: return
	if sequence != incoming_sequence:
		incoming_sequence = sequence
		incoming_part = 0
		incoming_total = total
		incoming_size = raw_size
		incoming_bytes.clear()
	if part != incoming_part or total != incoming_total or raw_size != incoming_size:
		incoming_part = -1
		incoming_bytes.clear()
		return
	incoming_bytes.append_array(bytes)
	incoming_part += 1
	if incoming_part != total: return
	var raw = incoming_bytes.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE)
	incoming_bytes.clear()
	if raw.size() != raw_size: return
	var data: Variant = bytes_to_var(raw)
	if not data is Dictionary: return
	received_sequence = sequence
	poses_received.emit(data)
