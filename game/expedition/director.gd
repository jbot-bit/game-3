class_name Director
extends RefCounted
var active: String = ""
var expires: float = 0.0
var ready_at: float = 0.0
func request(kind: String, now_s: float, context: Dictionary) -> Dictionary:
	if not context.get("is_host",false): return {"ok":false,"code":"not_host"}
	if kind in ["clear_event","safe_return"]:
		active=""
		return {"ok":true,"code":kind}
	if kind not in ["fog","odd_catch","sighting"]: return {"ok":false,"code":"invalid_event"}
	if active!="" or now_s<ready_at: return {"ok":false,"code":"cooldown"}
	if kind=="sighting" and context.get("rescuing",false): return {"ok":false,"code":"rescue_active"}
	active=kind
	expires=now_s+15.0
	ready_at=now_s+45.0
	return {"ok":true,"code":kind}
func tick(now_s: float, _context: Dictionary) -> Dictionary:
	if active!="" and active!="odd_catch" and now_s>=expires: active=""
	return {"active":active}
