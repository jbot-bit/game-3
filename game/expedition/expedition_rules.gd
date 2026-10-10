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
	for p in profiles: players[p]={"downed":false,"down_left":25.0,"protection":0.0,"aboard":false,"ready":false,"carried_by":""}
func advance(delta_s: float) -> Dictionary:
	var result: Dictionary = {"ok":true,"code":"tick","returned":[],"released_ids":[]}
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
		result.released_ids=_clear_carries()
		terminal=true
		phase="retreat"
		result.code="settle"
		return result
	elapsed_s = minf(630.0,elapsed_s+delta_s)
	phase = "storm" if elapsed_s>=570 else ("night" if elapsed_s>=240 else ("dusk" if elapsed_s>=180 else "day"))
	if elapsed_s >= 630:
		result.released_ids=_clear_carries()
		terminal=true
		result.code="settle"
		return result
	for p in players:
		var s: Dictionary = players[p]
		s.protection=maxf(0.0,s.protection-delta_s)
		if s.downed:
			s.down_left-=delta_s
			if s.down_left<=0:
				if not carried_by(p).is_empty():
					_detach(p)
					result.released_ids.append(p)
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
	var released: Array[String]=_detach_profile(profile_id)
	return {"ok":true,"code":"down","released_ids":released}
func revive(helper_id: String, target_id: String, held_s: float) -> Dictionary:
	if paused or terminal or helper_id==target_id or not players.has(helper_id) or not players.has(target_id): return {"ok":false,"code":"invalid_revive"}
	if players[helper_id].downed or not players[target_id].downed or not is_finite(held_s) or held_s<3.0: return {"ok":false,"code":"reviving"}
	var released: Array[String]=_detach_profile(target_id)
	players[target_id].downed=false
	players[target_id].protection=3.0
	return {"ok":true,"code":"revived","released_ids":released}

func pickup_teammate(helper_id: String, target_id: String, context: Dictionary = {}) -> Dictionary:
	if paused or terminal or crossing_left>=0: return {"ok":false,"code":"paused"}
	if helper_id==target_id or not players.has(helper_id) or not players.has(target_id): return {"ok":false,"code":"invalid_target"}
	if players[helper_id].downed or not players[target_id].downed: return {"ok":false,"code":"invalid_rescue"}
	if not carried_by(target_id).is_empty(): return {"ok":false,"code":"already_carried"}
	if not carrying_teammate(helper_id).is_empty() or not context.get("hands_free",true): return {"ok":false,"code":"hands_full"}
	var distance: float=float(context.get("distance_m",0.0))
	if not context.get("active",true) or not context.get("line_of_sight",true) or not is_finite(distance) or distance<0.0 or distance>2.0: return {"ok":false,"code":"out_of_range"}
	players[target_id].carried_by=helper_id
	players[target_id].aboard=false
	players[target_id].ready=false
	players[helper_id].ready=false
	return {"ok":true,"code":"carrying_teammate","helper_id":helper_id,"target_id":target_id}

func release_teammate(helper_id: String) -> Dictionary:
	if paused or terminal or crossing_left>=0: return {"ok":false,"code":"paused"}
	var target_id: String=carrying_teammate(helper_id)
	if target_id.is_empty(): return {"ok":false,"code":"not_carrying"}
	_detach(target_id)
	return {"ok":true,"code":"teammate_released","helper_id":helper_id,"target_id":target_id,"released_ids":[target_id]}

func carried_by(target_id: String) -> String:
	return str(players.get(target_id,{}).get("carried_by",""))

func carrying_teammate(helper_id: String) -> String:
	if helper_id.is_empty(): return ""
	for target_id: String in players:
		if carried_by(target_id)==helper_id: return target_id
	return ""

func _detach(target_id: String) -> void:
	if players.has(target_id): players[target_id].carried_by=""

func _detach_profile(profile_id: String) -> Array[String]:
	var released: Array[String]=[]
	var passenger: String=carrying_teammate(profile_id)
	if not passenger.is_empty():
		_detach(passenger)
		released.append(passenger)
	if not carried_by(profile_id).is_empty():
		_detach(profile_id)
		released.append(profile_id)
	return released

func _clear_carries() -> Array[String]:
	var released: Array[String]=[]
	for target_id: String in players:
		if not carried_by(target_id).is_empty():
			_detach(target_id)
			released.append(target_id)
	return released
func set_aboard(profile_id: String, value: bool) -> void:
	if players.has(profile_id) and not terminal and crossing_left<0:
		players[profile_id].aboard=value
		if not value: players[profile_id].ready=false
func set_ready(profile_id: String, value: bool) -> void:
	if players.has(profile_id) and not terminal: players[profile_id].ready=value
func disconnect_profile(profile_id: String) -> Dictionary:
	var released: Array[String]=_detach_profile(profile_id)
	players.erase(profile_id)
	return {"ok":true,"code":"disconnected","released_ids":released}
func snapshot() -> Dictionary:
	return {"run_id":run_id,"elapsed_s":elapsed_s,"players":players.duplicate(true),"phase":phase,"paused":paused,"terminal":terminal,"crossing_left":crossing_left}
