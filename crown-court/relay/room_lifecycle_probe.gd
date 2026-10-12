extends SceneTree
const Peer = preload("res://room_peer.gd")
var peers: Array = []
var code = ""
var joined = 0
var fourth_started = false
var full_error = ""
var host_error_count = 0
var elapsed = 0.0
var close_started = false

func _initialize() -> void:
	var host = Peer.new()
	peers.append(host)
	host.room_ready.connect(func(value: String):
		code = value
		for n in 2:
			var client = Peer.new()
			peers.append(client)
			client.room_ready.connect(func(_code: String): joined += 1)
			client.room_error.connect(func(message: String):
				if "host" in message.to_lower(): host_error_count += 1
			)
			client.configure("ws://127.0.0.1:30220/rooms", false, code, "lifecycle-v1")
	)
	host.configure("ws://127.0.0.1:30220/rooms", true, "", "lifecycle-v1")

func _process(dt: float) -> bool:
	elapsed += dt
	for peer in peers.duplicate(): peer.poll()
	if joined == 2 and not fourth_started:
		fourth_started = true
		var fourth = Peer.new()
		peers.append(fourth)
		fourth.room_error.connect(func(message: String): full_error = message)
		fourth.configure("ws://127.0.0.1:30220/rooms", false, code, "lifecycle-v1")
	if not full_error.is_empty() and not close_started:
		if not "three players" in full_error:
			push_error("ROOM_LIFECYCLE_FAIL full-room reason was lost: " + full_error)
			quit(1)
			return true
		print("ROOM_LIFECYCLE_PASS preserved full-room error")
		close_started = true
		peers[0].close()
	if close_started and host_error_count == 2:
		print("ROOM_LIFECYCLE_PASS host departure reason reached both clients")
		quit(0)
		return true
	if elapsed > 5:
		push_error("ROOM_LIFECYCLE_FAIL timeout full_error=" + full_error + " host_closes=" + str(host_error_count))
		quit(1)
		return true
	return false
