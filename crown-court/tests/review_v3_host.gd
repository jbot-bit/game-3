extends "res://main.gd"
var drop_moves = false
var dropped_moves = 0

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func receive_move(direction: Vector3, aim: Vector3, round_id: String = "") -> void:
	if drop_moves:
		dropped_moves += 1
		return
	super.receive_move(direction,aim,round_id)
