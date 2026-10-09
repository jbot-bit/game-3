class_name ExpeditionRules
extends RefCounted
var elapsed_s: float = 0.0
var players: Dictionary = {}
var paused: bool = false
var phase: String = "day"
var run_id: String = ""
var terminal: bool = false
var crossing_left: float = -1.0
func start(id: String, profiles: Array[String]) -> void:
	run_id=id
	elapsed_s=0.0
	players.clear()
	paused=false
	phase="day"
	terminal=false
	crossing_left=-1
	for p in profiles: players[p]={"downed":false,"down_left":25.0,"protection":0.0,"aboard":false,"ready":false}
func advance(delta_s: float) -> Dictionary:
	var result: Dictionary = {"ok":true,"code":"tick","returned":[]}
	if paused or terminal or not is_finite(delta_s) or delta_s < 0: return result
	if crossing_left >= 0:
		crossing_left -= delta_s
		if crossing_left <= 0:
			terminal=true
			result.code="settle"
		return result
	var all_down: bool = not players.is_empty()
	var all_ready: bool = not players.is_empty()
	for p in players:
		all_down = all_down and players[p].downed
		all_ready = all_ready and players[p].aboard and players[p].ready and not players[p].downed
	if all_down:
		terminal=true
		phase="retreat"
		result.code="settle"
		return result
	elapsed_s = minf(630.0,elapsed_s+delta_s)
	phase = "storm" if elapsed_s>=570 else ("night" if elapsed_s>=240 else ("dusk" if elapsed_s>=180 else "day"))
	if elapsed_s >= 630:
		terminal=true
		result.code="settle"
		return result
	for p in players:
		var s: Dictionary = players[p]
		s.protection=maxf(0.0,s.protection-delta_s)
		if s.downed:
			s.down_left-=delta_s
			if s.down_left<=0:
				s.downed=false
				s.protection=3.0
				s.aboard=true
				s.ready=false
				result.returned.append(p)
	if all_ready:
		crossing_left=20.0
		phase="refuge"
		result.code="depart"
	return result
func set_paused(value: bool) -> void: paused=value
func down(profile_id: String) -> Dictionary:
	if paused or terminal or not players.has(profile_id) or players[profile_id].downed or players[profile_id].protection>0: return {"ok":false,"code":"protected"}
	players[profile_id].downed=true
	players[profile_id].down_left=25.0
	players[profile_id].ready=false
	return {"ok":true,"code":"down"}
func revive(helper_id: String, target_id: String, held_s: float) -> Dictionary:
	if paused or terminal or helper_id==target_id or not players.has(helper_id) or not players.has(target_id): return {"ok":false,"code":"invalid_revive"}
	if players[helper_id].downed or not players[target_id].downed or held_s<3.0: return {"ok":false,"code":"reviving"}
	players[target_id].downed=false
	players[target_id].protection=3.0
	return {"ok":true,"code":"revived"}
func set_aboard(profile_id: String, value: bool) -> void:
	if players.has(profile_id) and not terminal and crossing_left<0:
		players[profile_id].aboard=value
		if not value: players[profile_id].ready=false
func set_ready(profile_id: String, value: bool) -> void:
	if players.has(profile_id) and not terminal: players[profile_id].ready=value
func disconnect_profile(profile_id: String) -> void: players.erase(profile_id)
func snapshot() -> Dictionary:
	return {"run_id":run_id,"elapsed_s":elapsed_s,"players":players.duplicate(true),"phase":phase,"paused":paused,"terminal":terminal,"crossing_left":crossing_left}
