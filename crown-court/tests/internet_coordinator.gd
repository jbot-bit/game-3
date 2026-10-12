extends "res://tests/network_actions_coordinator.gd"

@rpc("any_peer", "call_remote", "unreliable", 1)
func latency_probe(sent_usec: int) -> void:
	if multiplayer.is_server(): latency_reply.rpc_id(multiplayer.get_remote_sender_id(),sent_usec)

@rpc("authority", "call_remote", "unreliable", 1)
func latency_reply(sent_usec: int) -> void:
	driver.round_trips.append(float(Time.get_ticks_usec()-sent_usec)/1000.0)
