class_name Equipment
extends RefCounted

static func lamp(lamp_id: String) -> Dictionary:
	return lamps_all().get(lamp_id,{})

static func rod(rod_id: String) -> Dictionary:
	return rods_all().get(rod_id,{})

static func rods_all() -> Dictionary:
	return {
		"starter": _rod("Harbour Rod","Balanced tension and landing speed for every fish.","Starter",1.0,1.0,1.0,1.0),
		"soft_tip": _rod("Soft-tip Rod","15% less tension; heavy fish land 15% slower.","Shore cache or workshop",0.85,1.0,0.85,1.0),
		"braced_reel": _rod("Braced Reel","Heavy fish land 30% faster; 18% more tension, darting 10% and surging 15% slower.","Craft at workshop",1.18,0.90,1.30,0.85),
		"drift_rod": _rod("Drift Rod","Darting fish 18% and surging fish 12% faster; 12% more tension, heavy fish 15% slower.","Discover 6 species",1.12,1.18,0.85,1.12)
	}

static func _rod(title: String, description: String, acquisition: String, tension: float, dart: float, heavy: float, surge: float) -> Dictionary:
	return {"name":title,"description":description,"acquisition":acquisition,"tension_gain_multiplier":tension,"dart_progress_multiplier":dart,"heavy_progress_multiplier":heavy,"surge_progress_multiplier":surge}

static func lamps_all() -> Dictionary:
	return {
		"flood":{"name":"Flood Lantern","description":"Wide 70 degree beam, 8 m reach, 90 seconds of light.","acquisition":"Starter","angle_deg":70.0,"reach_m":8.0,"active_seconds":90.0},
		"surveyor":{"name":"Surveyor Lantern","description":"Narrow 30 degree beam, 12 m reach, 45 seconds of light.","acquisition":"Craft at workshop","angle_deg":30.0,"reach_m":12.0,"active_seconds":45.0}
	}
