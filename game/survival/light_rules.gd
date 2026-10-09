class_name LightRules
extends RefCounted
var reserve: String = ""
var batteries: Dictionary = {}
var slow_ready: Dictionary = {}
func set_reserve(station_id: String) -> Dictionary:
	if reserve != "" or station_id not in ["jetty","reeds"]: return {"ok":false,"code":"already_committed"}
	reserve = station_id
	return {"ok":true,"code":"powered"}
func station_powered(station_id: String, elapsed_s: float) -> bool:
	return station_id in ["jetty","reeds"] and (elapsed_s < 240.0 or (reserve == station_id and elapsed_s < 630.0))
func handheld_effect(hunter_id: String, now_s: float) -> Dictionary:
	if now_s < float(slow_ready.get(hunter_id,0.0)): return {"ok":false,"code":"immune"}
	slow_ready[hunter_id] = now_s + 8.0
	return {"ok":true,"code":"slowed","until":now_s+2.0}
func drain(profile_id: String, lamp_id: String, enabled: bool, delta_s: float) -> Dictionary:
	if not batteries.has(profile_id): recharge(profile_id,lamp_id)
	if enabled and is_finite(delta_s) and delta_s > 0: batteries[profile_id] = maxf(0.0,float(batteries[profile_id])-delta_s)
	return {"remaining":float(batteries[profile_id])}
func recharge(profile_id: String, lamp_id: String) -> void:
	batteries[profile_id] = 45.0 if lamp_id == "surveyor" else 90.0
func snapshot() -> Dictionary:
	return {"reserve":reserve,"batteries":batteries.duplicate(true)}
