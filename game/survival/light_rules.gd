class_name LightRules
extends RefCounted
var reserve: String = ""
var batteries: Dictionary = {}
var slow_ready: Dictionary = {}
var station_until: Dictionary = {"jetty":240.0,"reeds":240.0}
var _fed_cells: Dictionary = {}
func set_reserve(station_id: String) -> Dictionary:
	if reserve != "" or station_id not in ["jetty","reeds"]: return {"ok":false,"code":"already_committed"}
	reserve = station_id
	# A cell delivered before the ballot must not be overwritten by the reserve.
	station_until[station_id]=minf(630.0,maxf(240.0,float(station_until[station_id]))+150.0)
	return {"ok":true,"code":"powered"}
func station_powered(station_id: String, elapsed_s: float) -> bool:
	return station_until.has(station_id) and is_finite(elapsed_s) and elapsed_s>=0.0 and elapsed_s<630.0 and elapsed_s<float(station_until[station_id])
func station_remaining(station_id: String, elapsed_s: float) -> float:
	if not station_until.has(station_id) or not is_finite(elapsed_s) or elapsed_s<0.0: return 0.0
	# Daylight is free. The displayed budget is usable time after sunset.
	return maxf(0.0,minf(630.0,float(station_until[station_id]))-maxf(240.0,elapsed_s))
func feed_station(station_id: String, cell_id: String, elapsed_s: float) -> Dictionary:
	if not station_until.has(station_id): return {"ok":false,"code":"unknown_station"}
	if cell_id.is_empty() or cell_id.length()>128: return {"ok":false,"code":"invalid_cell"}
	if not is_finite(elapsed_s) or elapsed_s<0.0 or elapsed_s>=630.0: return {"ok":false,"code":"station_closed"}
	if _fed_cells.has(cell_id): return {"ok":false,"code":"cell_already_used"}
	if float(station_until[station_id])>=630.0: return {"ok":false,"code":"station_full"}
	station_until[station_id]=minf(630.0,maxf(float(station_until[station_id]),maxf(240.0,elapsed_s))+90.0)
	_fed_cells[cell_id]=station_id
	return {"ok":true,"code":"station_fed","station_until":float(station_until[station_id]),"remaining":station_remaining(station_id,elapsed_s)}
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
	return {"reserve":reserve,"batteries":batteries.duplicate(true),"station_until":station_until.duplicate(true)}
