class_name AbilityRules
extends RefCounted
var ready_at: Dictionary = {}
var keeper_until: float = 0.0
func use(profile_id: String, role_id: String, target: Dictionary, now_s: float) -> Dictionary:
	if role_id not in ["scout","keeper","rigger"] or not is_finite(now_s): return {"ok":false,"code":"invalid_ability"}
	if now_s < float(ready_at.get(profile_id,0.0)): return {"ok":false,"code":"cooldown"}
	if role_id == "keeper" and now_s < keeper_until: return {"ok":false,"code":"already_protected"}
	if role_id == "rigger" and (not target.get("valid_path",false) or float(target.get("distance",999)) > 5.0): return {"ok":false,"code":"invalid_path"}
	ready_at[profile_id] = now_s + 30.0
	if role_id == "keeper": keeper_until = now_s + 4.0
	return {"ok":true,"code":role_id,"duration":5.0 if role_id=="scout" else 4.0,"ready_at":now_s+30.0}
func snapshot() -> Dictionary:
	return {"ready_at":ready_at.duplicate(true),"keeper_until":keeper_until}
