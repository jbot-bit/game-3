class_name IslandContent
extends RefCounted

static func cache(cache_id: String) -> Dictionary:
	match cache_id:
		"lido_workshop_cache":
			return {"recipes": ["surveyor_lantern"], "salvage": {"glass_lens": 1}}
		"shore_rod_cache":
			return {"rods": ["soft_tip"]}
		"walkway_parts_cache":
			return {"salvage": {"brass_fitting": 1}}
	return {}

static func repair(repair_id: String) -> Dictionary:
	if repair_id == "return_walkway":
		return {"coins": 0, "salvage": {"brass_fitting": 1}}
	return {}
