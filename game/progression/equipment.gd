class_name Equipment
extends RefCounted

static func lamp(lamp_id: String) -> Dictionary:
	match lamp_id:
		"flood":
			return {"angle_deg": 70.0, "reach_m": 8.0, "active_seconds": 90.0}
		"surveyor":
			return {"angle_deg": 30.0, "reach_m": 12.0, "active_seconds": 45.0}
	return {}

static func rod(rod_id: String) -> Dictionary:
	match rod_id:
		"starter":
			return {"tension_gain_multiplier": 1.0, "heavy_progress_multiplier": 1.0}
		"soft_tip":
			return {"tension_gain_multiplier": 0.85, "heavy_progress_multiplier": 0.85}
	return {}
