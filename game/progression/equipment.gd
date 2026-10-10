class_name Equipment
extends RefCounted

static func lamp(lamp_id: String) -> Dictionary:
	return lamps_all().get(lamp_id,{})

static func rod(rod_id: String) -> Dictionary:
	return rods_all().get(rod_id,{})

static func rods_all() -> Dictionary:
	return {
		"starter": _rod("Harbour Rod","Balanced control bar and landing speed for every fish.","Starter",1.0,1.0,1.0,1.0),
		"soft_tip": _rod("Soft-tip Rod","20% wider control bar; heavy fish land 15% slower.","Shore cache",1.20,1.0,0.85,1.0),
		"braced_reel": _rod("Braced Reel","Heavy fish land 30% faster; 15% narrower control bar.","Craft at workshop",0.85,1.0,1.30,1.0),
		"drift_rod": _rod("Drift Rod","Darting fish land 25% faster; heavy fish land 15% slower.","Discover 6 species",1.0,1.25,0.85,1.0)
	}

static func _rod(title: String, description: String, acquisition: String, width: float, dart: float, heavy: float, surge: float) -> Dictionary:
	return {"name":title,"description":description,"acquisition":acquisition,"bar_width_multiplier":width,"dart_progress_multiplier":dart,"heavy_progress_multiplier":heavy,"surge_progress_multiplier":surge}

static func lamps_all() -> Dictionary:
	return {
		"flood":{"name":"Flood Lantern","description":"Wide 70 degree beam, 8 m reach, 90 seconds of light.","acquisition":"Starter","angle_deg":70.0,"reach_m":8.0,"active_seconds":90.0},
		"surveyor":{"name":"Surveyor Lantern","description":"Narrow 30 degree beam, 12 m reach, 45 seconds of light.","acquisition":"Craft at workshop","angle_deg":30.0,"reach_m":12.0,"active_seconds":45.0}
	}

static func outfits_all() -> Dictionary:
	return {
		"harbour":{"name":"Harbour Crew","description":"Your everyday island kit. Balanced movement, fishing and light.","acquisition":"Starter","bar_width_multiplier":1.0,"carry_speed":4.25,"lamp_drain_multiplier":1.0},
		"angler":{"name":"Angler's Kit","description":"10% wider control bar while fishing.","acquisition":"Discover 2 fish species","bar_width_multiplier":1.1,"carry_speed":4.25,"lamp_drain_multiplier":1.0},
		"deckhand":{"name":"Deckhand Kit","description":"Carry whole fish and spare cells faster: 4.6 m/s.","acquisition":"Repair the return walkway","bar_width_multiplier":1.0,"carry_speed":4.6,"lamp_drain_multiplier":1.0},
		"stormwatch":{"name":"Stormwatch Kit","description":"Your handheld lantern lasts 20% longer.","acquisition":"Discover 4 fish species","bar_width_multiplier":1.0,"carry_speed":4.25,"lamp_drain_multiplier":1.0/1.2}
	}

static func outfit(outfit_id: String) -> Dictionary:
	return outfits_all().get(outfit_id,{})

static func outfit_unlocked(state: Dictionary, outfit_id: String) -> bool:
	match outfit_id:
		"harbour": return true
		"angler": return state.get("discoveries",[]).size()>=2
		"deckhand": return bool(state.get("repairs",{}).get("return_walkway",false))
		"stormwatch": return state.get("discoveries",[]).size()>=4
	return false
