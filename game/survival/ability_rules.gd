class_name AbilityRules
extends RefCounted
var ready_at: Dictionary = {}
var keeper_until: float = 0.0
var keeper_radius: float=4.5
var active: Dictionary={}
func use(profile_id: String, role_id: String, target: Dictionary, now_s: float) -> Dictionary:
	if role_id not in ["scout","keeper","rigger"] or not is_finite(now_s): return {"ok":false,"code":"invalid_ability"}
	if now_s < float(ready_at.get(profile_id,0.0)): return {"ok":false,"code":"cooldown"}
	if role_id == "keeper" and now_s < keeper_until: return {"ok":false,"code":"already_protected"}
	var alternate: bool=target.get("tool_mode","standard")=="alternate"
	if role_id == "rigger" and (not target.get("valid_path",false) or float(target.get("distance",999)) > (8.0 if alternate else 5.0)): return {"ok":false,"code":"invalid_path"}
	var cooldown: float=40.0 if alternate else 30.0
	var duration: float=(10.0 if alternate else 5.0) if role_id=="scout" else (7.0 if alternate else 4.0)
	ready_at[profile_id] = now_s + cooldown
	active[profile_id]={"role":role_id,"mode":"alternate" if alternate else "standard","until":now_s+duration}
	if role_id == "keeper":
		keeper_until = now_s + duration
		keeper_radius=2.5 if alternate else 4.5
	return {"ok":true,"code":role_id,"duration":duration,"ready_at":now_s+cooldown}
func snapshot() -> Dictionary:
	return {"ready_at":ready_at.duplicate(true),"keeper_until":keeper_until,"keeper_radius":keeper_radius,"active":active.duplicate(true)}
