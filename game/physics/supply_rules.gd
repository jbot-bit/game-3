class_name SupplyRules
extends RefCounted
## Two outing resources. They never enter catch rewards or household saves.

const CELL_IDS: Array[String]=["cell_1","cell_2"]
const PROFILES: Array[String]=["crew_1","crew_2","crew_3"]
var _cells: Dictionary={}
var _paused: bool=false

func _init() -> void:
	for id: String in CELL_IDS:
		_cells[id]={"cell_id":id,"state":"free","carrier_id":"","sequence":0}

func grab(id: String, profile_id: String, context: Dictionary = {}) -> Dictionary:
	if _paused: return _failure("paused")
	if not _cells.has(id): return _failure("unknown_cell")
	if profile_id not in PROFILES: return _failure("invalid_profile")
	if _cells[id].state!="free": return _failure("unavailable")
	if not held_by(profile_id).is_empty() or not context.get("hands_free",true): return _failure("hands_full")
	if not context.get("active",false): return _failure("inactive")
	var distance: float=float(context.get("distance_m",INF))
	if not is_finite(distance) or distance<0.0 or distance>2.0: return _failure("out_of_range")
	if not context.get("line_of_sight",false): return _failure("blocked")
	_cells[id].state="held"
	_cells[id].carrier_id=profile_id
	_cells[id].sequence+=1
	return _result(id,"grabbed")

func release(profile_id: String, kind: String = "drop") -> Dictionary:
	if _paused: return _failure("paused")
	if kind not in ["drop","toss"]: return _failure("invalid_action")
	var id: String=held_by(profile_id)
	if id.is_empty(): return _failure("not_holding")
	_free(id)
	var result: Dictionary=_result(id,"released")
	result.kind=kind
	return result

func consume(id: String) -> Dictionary:
	if _paused: return _failure("paused")
	if not _cells.has(id): return _failure("unknown_cell")
	if _cells[id].state=="consumed": return _failure("already_consumed")
	_cells[id].state="consumed"
	_cells[id].carrier_id=""
	_cells[id].sequence+=1
	return _result(id,"consumed")

func disconnect_profile(profile_id: String) -> Dictionary:
	var released: Array[String]=[]
	var id: String=held_by(profile_id)
	if not id.is_empty():
		_free(id)
		released.append(id)
	return {"ok":true,"code":"disconnected","released_ids":released}

func held_by(profile_id: String) -> String:
	for id: String in _cells:
		if _cells[id].state=="held" and _cells[id].carrier_id==profile_id: return id
	return ""

func set_paused(value: bool) -> void:
	_paused=value

func snapshot() -> Dictionary:
	return _cells.duplicate(true)

func _free(id: String) -> void:
	_cells[id].state="free"
	_cells[id].carrier_id=""
	_cells[id].sequence+=1

func _result(id: String, code: String) -> Dictionary:
	var result: Dictionary=_cells[id].duplicate(true)
	result.ok=true
	result.code=code
	return result

func _failure(code: String) -> Dictionary:
	return {"ok":false,"code":code}
