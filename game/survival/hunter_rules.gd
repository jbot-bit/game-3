class_name HunterRules
extends RefCounted
var state: String = "patrol"
var state_time: float = 0.0
func advance(delta_s: float, observations: Dictionary) -> Dictionary:
	if observations.get("paused",false): return _result()
	if not observations.get("night",false):
		state="patrol"
		state_time=0
		return _result()
	state_time+=maxf(0.0,delta_s)
	match state:
		"patrol":
			if observations.get("target_visible",false) and not observations.get("rescuing",false):
				state="warn"
				state_time=0
		"warn":
			if state_time>=2.0:
				state="chase"
				state_time=0
		"chase":
			if state_time>=12.0 or observations.get("caught",false):
				state="recover"
				state_time=0
		"recover":
			if state_time>=12.0:
				state="patrol"
				state_time=0
	return _result()
func _result() -> Dictionary:
	return {"state":state,"can_attack":state=="chase","state_time":state_time}
