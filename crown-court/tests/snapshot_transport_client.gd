extends "res://main.gd"

var hold_large = false
var held_packets: Array[PackedByteArray] = []
var hold_begin = false
var held_begin: Dictionary = {}

@rpc("authority", "call_remote", "reliable", 4)
func receive_large_state(packet: PackedByteArray) -> void:
	if hold_large:
		held_packets.append(packet)
		return
	super.receive_large_state(packet)

func deliver_held() -> void:
	if held_packets.is_empty(): return
	super.receive_large_state(held_packets.pop_front())

@rpc("authority", "call_remote", "reliable", 0)
func begin_match(mode: String, round_id: String = "") -> void:
	if hold_begin:
		held_begin = {"mode":mode,"round_id":round_id}
		return
	super.begin_match(mode,round_id)

func deliver_begin() -> void:
	if held_begin.is_empty(): return
	super.begin_match(held_begin.mode,held_begin.round_id)
	held_begin.clear()
