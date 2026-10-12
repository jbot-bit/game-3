extends "res://main.gd"

var test_port = 30180
var test_observer
var test_saturated = false
var test_entropy = PackedByteArray()
var test_encoded_sizes: Array = []
var test_single_slot = false

func send_snapshot(peer: int, packet: PackedByteArray) -> void:
	if not test_single_slot:
		super.send_snapshot(peer,packet)
		return
	# Retained old single-slot policy for an explicit transport A/B fixture only.
	if _closing or not seats.has(peer) or packet.size()>MAX_SNAPSHOT_BYTES:return
	if packet.size()<=UNRELIABLE_SNAPSHOT_BYTES:
		snapshot_transport.unreliable+=1
		snapshot_transport.max_unreliable_bytes=maxi(snapshot_transport.max_unreliable_bytes,packet.size())
		receive_state.rpc_id(peer,packet)
	elif not pending_snapshots.has(peer):
		pending_snapshots[peer]={"round_id":match_id,"sequence":snapshot_serial}
		snapshot_transport.reliable+=1
		snapshot_transport.max_reliable_bytes=maxi(snapshot_transport.max_reliable_bytes,packet.size())
		receive_large_state.rpc_id(peer,packet)
	else:snapshot_transport.coalesced+=1

@rpc("any_peer", "call_remote", "reliable", 4)
func acknowledge_snapshot(round_id: String, sequence: int) -> void:
	if not test_single_slot:
		super.acknowledge_snapshot(round_id,sequence)
		return
	if _closing or not multiplayer_active() or not multiplayer.is_server() or round_id!=match_id:return
	var peer=multiplayer.get_remote_sender_id()
	if not seats.has(peer) or not pending_snapshots.has(peer):return
	var pending: Dictionary=pending_snapshots[peer]
	if str(pending.round_id)==round_id and int(pending.sequence)==sequence:pending_snapshots.erase(peer)

func encode_snapshot() -> PackedByteArray:
	if test_saturated:
		if test_entropy.is_empty():
			var rng=RandomNumberGenerator.new()
			rng.seed=90210
			for index in 384:test_entropy.append(rng.randi_range(0,255))
		# Explicit transport fixture, never used by gameplay. Forces all six-player packets large.
		state["_internet_transport_fixture"]=test_entropy
	var packet=super.encode_snapshot()
	test_encoded_sizes.append(packet.size())
	return packet

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_state(packet: PackedByteArray) -> void:
	var before=snapshot_count
	super.receive_state(packet)
	if test_observer: test_observer.record_packet(packet.size(),false,snapshot_count>before)

@rpc("authority", "call_remote", "reliable", 4)
func receive_large_state(packet: PackedByteArray) -> void:
	var before=snapshot_count
	super.receive_large_state(packet)
	if test_observer: test_observer.record_packet(packet.size(),true,snapshot_count>before)

func host_game(mode: String) -> void:
	# Test-only isolated bind. All subsequent lifecycle, inputs and snapshots are production code.
	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")
	var error = peer.create_server(test_port, 2, NETWORK_CHANNELS)
	if error != OK:
		push_error("Internet test could not bind isolated UDP port %d" % test_port)
		return
	multiplayer.multiplayer_peer = peer
	selected_mode = mode if mode in ["coop", "versus", "teams"] else "coop"
	seats = {1:1}
	names = {1:clean_name(nickname,1)}
	cosmetics = {1:profile.outfit()}
	powers = {1:clean_power(selected_power)}
	local_seat = 1
	team_choices.clear()
	show_lobby()
