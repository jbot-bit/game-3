extends "res://main.gd"
var delayed_large_state := PackedByteArray()
var drop_snapshots = false:
	set(value):
		drop_snapshots = value
		if not value and not delayed_large_state.is_empty():
			var delayed := delayed_large_state
			delayed_large_state = PackedByteArray()
			super.receive_large_state(delayed)
var dropped_snapshots = 0
var drop_round_starts = false
var dropped_round_starts = 0

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_state(packet: PackedByteArray) -> void:
	if drop_snapshots:
		dropped_snapshots += 1
		return
	super.receive_state(packet)

@rpc("authority", "call_remote", "reliable", 4)
func receive_large_state(packet: PackedByteArray) -> void:
	if drop_snapshots:
		dropped_snapshots += 1
		# Hold delivery rather than permanently discarding the application's ACK.
		delayed_large_state = packet
		return
	super.receive_large_state(packet)

@rpc("authority", "call_remote", "reliable", 0)
func begin_match(mode: String, round_id: String = "") -> void:
	if drop_round_starts:
		dropped_round_starts += 1
		return
	super.begin_match(mode,round_id)
