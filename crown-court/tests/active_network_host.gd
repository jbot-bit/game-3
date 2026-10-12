extends "res://tests/active_network_peer.gd"

func _initialize() -> void:
	role = "host"
	boot.call_deferred()
