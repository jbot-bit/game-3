extends GutTest
const Network=preload("res://game/session/session.gd")

class PacketCapture extends MultiplayerPeerExtension:
	var packets: Array[Dictionary]=[]
	var mode: TransferMode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var channel: int=0
	func _close() -> void: pass
	func _disconnect_peer(_peer: int,_force: bool) -> void: pass
	func _get_available_packet_count() -> int: return 0
	func _get_connection_status() -> ConnectionStatus: return MultiplayerPeer.CONNECTION_CONNECTED
	func _get_max_packet_size() -> int: return 65536
	func _get_packet_channel() -> int: return 0
	func _get_packet_mode() -> TransferMode: return MultiplayerPeer.TRANSFER_MODE_RELIABLE
	func _get_packet_peer() -> int: return 2
	func _get_packet_script() -> PackedByteArray: return PackedByteArray()
	func _get_transfer_channel() -> int: return channel
	func _get_transfer_mode() -> TransferMode: return mode
	func _get_unique_id() -> int: return 1
	func _is_server() -> bool: return true
	func _is_server_relay_supported() -> bool: return false
	func _poll() -> void: pass
	func _put_packet_script(buffer: PackedByteArray) -> Error:
		packets.append({"size":buffer.size(),"mode":mode,"channel":channel})
		return OK
	func _set_target_peer(_peer: int) -> void: pass
	func _set_transfer_channel(value: int) -> void: channel=value
	func _set_transfer_mode(value: TransferMode) -> void: mode=value
	func _set_refuse_new_connections(_enabled: bool) -> void: pass
	func _is_refusing_new_connections() -> bool: return false

func poses() -> Dictionary:
	var data: Dictionary={"run_id":"outing-0123456789abcdef","players":{},"fish":{},"supplies":{},"hunter":Transform3D.IDENTITY}
	for index in range(3): data.players["crew_%d"%index]={"position":Vector3(index*1.4,2.05,8),"yaw":0.7,"velocity":Vector3(3,0,4)}
	var random:=RandomNumberGenerator.new()
	random.seed=23984
	for index in range(40):
		var pose:=Transform3D(Basis.from_euler(Vector3(random.randf(),random.randf(),random.randf())),Vector3(random.randf_range(-80,80),random.randf_range(2,5),random.randf_range(-60,60)))
		data.fish["outing-0123456789abcdef:"+str(index)]={"catch_id":str(index),"sequence":index+10,"transform":pose,"linear_velocity":Vector3(random.randf(),random.randf(),random.randf()),"angular_velocity":Vector3.UP,"held":false,"recovering":false}
	for index in range(2): data.supplies["cell_%d"%index]=data.fish.values()[index].duplicate(true)
	return data

func codec_ready(session: Node) -> bool:
	assert_true(session.has_method("_encode_pose_frame"),"Pose frames must fit bounded unreliable RPC packets")
	return session.has_method("_encode_pose_frame")

func test_large_physics_frame_round_trips_in_bounded_chunks_without_changing_pose_contract() -> void:
	var session: Node=Network.new()
	autofree(session)
	if not codec_ready(session): return
	var original: Dictionary=poses()
	var frame: Dictionary=session._encode_pose_frame(original)
	assert_gt(frame.chunks.size(),1,"Many physical catches exercise splitting rather than only compression")
	watch_signals(session)
	for index in range(frame.chunks.size()):
		assert_lte(frame.chunks[index].size(),960)
		session._receive_poses(1,index,frame.chunks.size(),frame.raw_size,frame.chunks[index])
		assert_signal_emit_count(session,"poses_received",1 if index==frame.chunks.size()-1 else 0)
	assert_eq(get_signal_parameters(session,"poses_received")[0],original)
	assert_eq(session._last_pose_sequence,1)

func test_incomplete_old_frames_cannot_overwrite_a_new_complete_frame() -> void:
	var session: Node=Network.new()
	autofree(session)
	if not codec_ready(session): return
	var frame: Dictionary=session._encode_pose_frame(poses())
	watch_signals(session)
	session._receive_poses(2,0,frame.chunks.size(),frame.raw_size,frame.chunks[0])
	for index in range(1,frame.chunks.size()): session._receive_poses(2,index+1,frame.chunks.size(),frame.raw_size,frame.chunks[index])
	assert_signal_not_emitted(session,"poses_received","A missing packet cannot emit a partial pose dictionary")
	var fresh: Dictionary=session._encode_pose_frame({"run_id":"next-outing","players":{},"fish":{},"supplies":{}})
	session._receive_poses(3,0,1,fresh.raw_size,fresh.chunks[0])
	assert_eq(get_signal_parameters(session,"poses_received")[0].run_id,"next-outing")
	for index in range(frame.chunks.size()): session._receive_poses(2,index,frame.chunks.size(),frame.raw_size,frame.chunks[index])
	assert_signal_emit_count(session,"poses_received",1)
	assert_eq(session._last_pose_sequence,3)

func test_transport_rejects_unbounded_headers_and_expansion_before_decoding() -> void:
	var session: Node=Network.new()
	autofree(session)
	if not codec_ready(session): return
	watch_signals(session)
	var bytes:=PackedByteArray([1,2,3])
	for header in [[1,0,10000,16],[1,0,1,10000000],[1,-1,1,16],[1,0,0,16],[1,0,1,0]]:
		session._receive_poses(header[0],header[1],header[2],header[3],bytes)
	var oversized:=PackedByteArray()
	oversized.resize(961)
	session._receive_poses(1,0,1,16,oversized)
	assert_signal_not_emitted(session,"poses_received")
	assert_eq(session._last_pose_sequence,-1)
	assert_true(session._encode_pose_frame({"unexpected":"x".repeat(70000)}).is_empty())

func test_actual_godot_rpc_envelopes_stay_below_1200_bytes() -> void:
	var scene:=Node.new()
	scene.name="PosePacketBudget"
	add_child_autofree(scene)
	var api:=SceneMultiplayer.new()
	get_tree().set_multiplayer(api,scene.get_path())
	var peer:=PacketCapture.new()
	api.multiplayer_peer=peer
	var session: Node=Network.new()
	session.name="Session"
	scene.add_child(session)
	session._hosting=true
	peer.peer_connected.emit(2)
	api.poll()
	session.publish_poses(poses())
	var count: int=0
	var largest: int=0
	for packet in peer.packets:
		if packet.mode!=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED: continue
		count+=1
		largest=maxi(largest,int(packet.size))
		assert_lt(packet.size,1200,"Budget includes the actual Godot RPC envelope, not just compressed data")
	assert_gt(count,1,"The engine must serialize a complete multi-packet pose frame")
	print("POSE_RPC_WIRE_BYTES max="+str(largest)+" packets="+str(count))
	session.close()
	get_tree().set_multiplayer(null,scene.get_path())
