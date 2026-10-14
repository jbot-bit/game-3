extends RefCounted
# Session-only rivalry. Match rewards remain keyed by their existing match IDs.
var active = false
var wins = {0: 0, 1: 0}
var recorded: Array[String] = []

func clear() -> void:
	active = false
	wins = {0: 0, 1: 0}
	recorded.clear()

func finished() -> bool:
	return int(wins[0]) >= 2 or int(wins[1]) >= 2

func record(round_id: String, winner: int) -> void:
	if not active or finished() or round_id.is_empty() or winner not in [0, 1] or round_id in recorded: return
	recorded.append(round_id)
	wins[winner] += 1

func snapshot() -> Dictionary:
	return {"active": active, "wins": wins.duplicate(), "round": mini(3, recorded.size() + 1), "finished": finished()}
