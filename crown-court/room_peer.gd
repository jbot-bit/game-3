extends MultiplayerPeerExtension

# Outbound-only room transport. WebSocket/TCP provides reliable delivery beneath
# the preserved Godot channel metadata; it does not provide UDP latency semantics.
signal room_ready(code: String)
signal room_error(message: String)

const PROTOCOL = 1
const MAX_PACKET_BYTES = 131072
const MAX_BUFFER_BYTES = 262144
const SOFT_BUFFER_BYTES = 32768
const MAX_INCOMING_PACKETS = 512
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var room_code = ""
var failure_text = ""
var room_endpoint = ""
var is_room_host = false
var dropped_disposable_packets = 0
var _socket = WebSocketPeer.new()
var _status: MultiplayerPeer.ConnectionStatus = CONNECTION_DISCONNECTED
var _peer_id = 0
var _target_peer = 0
var _channel = 0
var _mode: MultiplayerPeer.TransferMode = TRANSFER_MODE_RELIABLE
var _refuse = false
var _registered = false
var _registration_sent = false
var _intentional_close = false
var _deadline = 0
var _version = ""
var _peers: Dictionary = {}
var _incoming: Array = []
var _incoming_bytes = 0
var _last_packet: Dictionary = {"sender":0,"channel":0,"mode":TRANSFER_MODE_RELIABLE}

func configure(url: String, create_room: bool, code: String = "", game_version: String = "") -> Error:
	if _status != CONNECTION_DISCONNECTED: return ERR_ALREADY_IN_USE
	var clean_url = url.strip_edges()
	var expression = RegEx.new()
	expression.compile("^wss://[A-Za-z0-9.-]+(?::[0-9]{1,5})?/rooms$")
	var local_expression = RegEx.new()
	local_expression.compile("^ws://(?:127\\.0\\.0\\.1|localhost|\\[::1\\])(?::[0-9]{1,5})?/rooms$")
	if expression.search(clean_url) == null and local_expression.search(clean_url) == null:
		failure_text = "Use a secure room service URL. Plain WebSocket is allowed only on loopback."
		return ERR_INVALID_PARAMETER
	room_code = code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if not create_room:
		if room_code.length() != 26:
			failure_text = "Paste the complete room code."
			return ERR_INVALID_PARAMETER
		for character in room_code:
			if not character in CODE_ALPHABET:
				failure_text = "Check the room code and try again."
				return ERR_INVALID_PARAMETER
	_version = game_version if not game_version.is_empty() else str(ProjectSettings.get_setting("application/config/version", "development"))
	is_room_host = create_room
	room_endpoint = clean_url
	failure_text = ""
	_peer_id = 0
	_registered = false
	_registration_sent = false
	_intentional_close = false
	_peers.clear()
	_incoming.clear()
	_incoming_bytes = 0
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = MAX_BUFFER_BYTES
	_socket.outbound_buffer_size = MAX_BUFFER_BYTES
	_socket.max_queued_packets = MAX_INCOMING_PACKETS
	_socket.heartbeat_interval = 10.0
	var error = _socket.connect_to_url(clean_url)
	if error != OK:
		failure_text = "Could not open the room connection."
		return error
	_deadline = Time.get_ticks_msec() + 12000
	_status = CONNECTION_CONNECTING
	return OK

func _poll() -> void:
	if _intentional_close or _status == CONNECTION_DISCONNECTED: return
	_socket.poll()
	# A server can send a useful error and close in the same TCP read. Drain
	# those messages before converting STATE_CLOSED into a generic failure.
	var processed = 0
	while _socket.get_available_packet_count() > 0 and processed < MAX_INCOMING_PACKETS:
		processed += 1
		var packet = _socket.get_packet()
		if _socket.was_string_packet():
			if packet.size() > 4096:
				_fail("The room service sent an invalid response.")
				return
			_control(JSON.parse_string(packet.get_string_from_utf8()))
		else:
			_receive_packet(packet)
		if _status == CONNECTION_DISCONNECTED: return
	var socket_state = _socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_CLOSED:
		_fail(_socket.get_close_reason() if not _socket.get_close_reason().is_empty() else "The room connection closed. Create or join a new room.")
		return
	if not _registered and Time.get_ticks_msec() > _deadline:
		_fail("The room service did not answer. Try again.")
		return
	if socket_state != WebSocketPeer.STATE_OPEN: return
	if not _registration_sent:
		_registration_sent = true
		var request = {"protocol":PROTOCOL,"version":_version,"type":"create" if is_room_host else "join"}
		if not is_room_host: request["code"] = room_code
		if _socket.send_text(JSON.stringify(request)) != OK:
			_fail("Could not register this room.")
			return
func _control(value: Variant) -> void:
	if not value is Dictionary:
		_fail("The room service sent an invalid response.")
		return
	var kind = str(value.get("type", ""))
	if kind in ["error", "room_closed"]:
		_fail(str(value.get("message", "The room is unavailable.")))
		return
	if kind == "ready" and not _registered:
		var assigned = int(value.get("id", 0))
		if int(value.get("protocol", 0)) != PROTOCOL or str(value.get("version", "")) != _version or (assigned != 1 if is_room_host else assigned < 2):
			_fail("The room service returned an incompatible identity.")
			return
		var returned_code = str(value.get("code", ""))
		if returned_code.length() != 26 or (not is_room_host and returned_code != room_code):
			_fail("The room service returned an invalid room.")
			return
		room_code = returned_code
		_peer_id = assigned
		_registered = true
		_status = CONNECTION_CONNECTED
		room_ready.emit(room_code)
		# The owner must initialize seats before SceneMultiplayer invokes welcome.
		if not is_room_host and _status == CONNECTION_CONNECTED:
			_peers[1] = true
			peer_connected.emit(1)
		return
	if not _registered:
		_fail("Room traffic arrived before registration.")
		return
	var id = int(value.get("id", 0))
	if kind == "peer_joined" and is_room_host and id >= 2 and not _peers.has(id) and _peers.size() < 2:
		_peers[id] = true
		peer_connected.emit(id)
	elif kind == "peer_left" and is_room_host and _peers.has(id):
		# Discard that session's queued inputs before SceneMultiplayer removes its ID.
		for index in range(_incoming.size() - 1, -1, -1):
			if int(_incoming[index].sender) == id:
				_incoming_bytes -= _incoming[index].payload.size()
				_incoming.remove_at(index)
		_peers.erase(id)
		peer_disconnected.emit(id)
	else:
		_fail("The room service sent an invalid peer event.")

func _receive_packet(packet: PackedByteArray) -> void:
	if not _registered or packet.size() < 13 or packet.size() > MAX_PACKET_BYTES + 12 or packet[0] != 1 or packet[1] > 4 or packet[2] > 2 or packet[3] != 0:
		_fail("The room service sent an invalid game packet.")
		return
	var sender = int(packet.decode_u32(4))
	var target = int(packet.decode_s32(8))
	if not _peers.has(sender) or (is_room_host and target not in [0, 1]) or (not is_room_host and (sender != 1 or (target > 0 and target != _peer_id) or target == -_peer_id)):
		_fail("The room service sent an invalid packet route.")
		return
	var payload = packet.slice(12)
	if _incoming.size() >= MAX_INCOMING_PACKETS or _incoming_bytes + payload.size() > MAX_BUFFER_BYTES:
		_fail("The connection is receiving game data too slowly. Rejoin the room.")
		return
	_incoming.append({"sender":sender,"channel":int(packet[1]),"mode":int(packet[2]),"payload":payload})
	_incoming_bytes += payload.size()

func _fail(message: String) -> void:
	if _intentional_close or _status == CONNECTION_DISCONNECTED: return
	failure_text = message.substr(0, 200)
	_close()
	room_error.emit(failure_text)

func _close() -> void:
	_intentional_close = true
	_status = CONNECTION_DISCONNECTED
	_registered = false
	_socket.close(1000, "Leaving room")
	_socket.poll()
	# close() must release the transport even if an owner retains this peer.
	_socket = WebSocketPeer.new()
	_incoming.clear()
	_incoming_bytes = 0
	var old_peers = _peers.keys()
	_peers.clear()
	for id in old_peers: peer_disconnected.emit(int(id))

func _disconnect_peer(peer: int, _force: bool) -> void:
	if not _registered: return
	if is_room_host and _peers.has(peer):
		_socket.send_text(JSON.stringify({"type":"kick","id":peer}))
	elif not is_room_host and peer == 1: _close()

func _get_available_packet_count() -> int:
	return _incoming.size()

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status

func _get_max_packet_size() -> int:
	return MAX_PACKET_BYTES

func _get_packet_channel() -> int:
	return int(_incoming[0].channel) if not _incoming.is_empty() else int(_last_packet.channel)

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return int(_incoming[0].mode) if not _incoming.is_empty() else int(_last_packet.mode)

func _get_packet_peer() -> int:
	return int(_incoming[0].sender) if not _incoming.is_empty() else int(_last_packet.sender)

func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty(): return PackedByteArray()
	_last_packet = _incoming.pop_front()
	var payload: PackedByteArray = _last_packet.payload
	_incoming_bytes -= payload.size()
	return payload

func _get_transfer_channel() -> int:
	return _channel

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode

func _get_unique_id() -> int:
	return _peer_id

func _is_refusing_new_connections() -> bool:
	return _refuse

func _is_server() -> bool:
	return is_room_host

func _is_server_relay_supported() -> bool:
	return false

func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable
	if _registered and is_room_host: _socket.send_text(JSON.stringify({"type":"refuse","value":enable}))

func _set_target_peer(peer: int) -> void:
	_target_peer = peer

func _set_transfer_channel(channel: int) -> void:
	_channel = channel

func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if not _registered or _status != CONNECTION_CONNECTED: return ERR_UNCONFIGURED
	if buffer.is_empty() or buffer.size() > MAX_PACKET_BYTES or _channel < 0 or _channel > 4: return ERR_INVALID_PARAMETER
	if not is_room_host and _target_peer not in [0, 1]: return ERR_INVALID_PARAMETER
	var queued = _socket.get_current_outbound_buffered_amount()
	if _mode != TRANSFER_MODE_RELIABLE and queued > SOFT_BUFFER_BYTES:
		dropped_disposable_packets += 1
		return OK
	if queued + buffer.size() + 12 > MAX_BUFFER_BYTES:
		_fail("The connection is sending game data too slowly. Rejoin the room.")
		return ERR_OUT_OF_MEMORY
	var frame = PackedByteArray()
	frame.resize(12)
	frame[0] = 1
	frame[1] = _channel
	frame[2] = int(_mode)
	frame[3] = 0
	frame.encode_u32(4, _peer_id)
	frame.encode_s32(8, _target_peer)
	frame.append_array(buffer)
	return _socket.send(frame)




