class_name CrewChoice
extends RefCounted
var voters: Array[String] = []
var votes: Dictionary = {}
var committed: String = ""
var decided_by: String = ""
var opened_at: float = -1.0
func open(eligible: Array[String], now_s: float) -> Dictionary:
	if committed != "" or now_s >= 180.0 or eligible.is_empty(): return {"ok":false,"code":"closed"}
	if opened_at>=0: return {"ok":false,"code":"already_open"}
	voters = eligible.duplicate()
	votes.clear()
	opened_at = now_s
	return {"ok":true,"code":"open"}
func vote(profile_id: String, station_id: String, now_s: float) -> Dictionary:
	if committed != "": return {"ok":false,"code":"already_committed"}
	if opened_at < 0 or now_s >= 180 or profile_id not in voters or station_id not in ["jetty","reeds"]: return {"ok":false,"code":"closed"}
	votes[profile_id] = station_id
	committed = station_id
	decided_by = profile_id
	opened_at = -1
	return {"ok":true,"code":"committed","committed_station":committed,"decided_by":decided_by}
func roster_changed(eligible: Array[String]) -> void:
	if committed == "":
		voters=eligible.duplicate()
		votes.clear()
		opened_at=-1.0
func tick(now_s: float) -> Dictionary:
	if committed != "": return {"ok":true,"code":"unchanged"}
	if now_s >= 180.0:
		committed="jetty"
		opened_at=-1
		return {"ok":true,"code":"fallback","committed_station":"jetty"}
	return {"ok":true,"code":"pending"}
func snapshot() -> Dictionary:
	return {"committed":committed,"votes":votes.duplicate(),"open":opened_at>=0,"decided_by":decided_by}
