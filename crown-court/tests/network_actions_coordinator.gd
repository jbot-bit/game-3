extends Node
# Test-only coordinator. Production input still goes through main.gd submit/RPC methods.
var driver

@rpc("authority", "call_remote", "reliable", 0)
func stage(payload: Dictionary) -> void:
	driver.receive_stage(payload)

@rpc("authority", "call_remote", "reliable", 0)
func checkpoint(payload: Dictionary) -> void:
	driver.receive_checkpoint(payload)

@rpc("any_peer", "call_remote", "reliable", 0)
func acknowledge(payload: Dictionary) -> void:
	if multiplayer.is_server(): driver.receive_ack(multiplayer.get_remote_sender_id(), payload)

@rpc("authority", "call_remote", "reliable", 0)
func complete(payload: Dictionary) -> void:
	driver.complete(payload)
