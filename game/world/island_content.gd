class_name IslandContent
extends RefCounted

static func cache_markers() -> Dictionary:
	return {"lido_workshop_cache": "lens_cache", "shore_rod_cache": "rod_cache", "walkway_parts_cache": "repair_cache", "terraces_parts_cache": "ridge_parts_cache", "beacon_parts_cache": "beacon_parts_cache", "tide_engine_cache": "engine_cache", "reel_cache": "reel_cache"}

static func repair_markers() -> Dictionary:
	return {"workshop": "workshop_repair", "return_walkway": "repair", "ridge_steps": "ridge_repair", "beacon": "beacon_repair", "moth_engine": "engine_repair"}

static func recipes_all() -> Dictionary:
	return Crafting.recipes_all()

static func cache(cache_id: String) -> Dictionary:
	match cache_id:
		"lido_workshop_cache":
			return {"name": "Lido workshop cache", "recipes": ["surveyor_lantern"], "salvage": {"glass_lens": 1}, "flags": ["workshop_tools"]}
		"shore_rod_cache":
			return {"rods": ["soft_tip"]}
		"walkway_parts_cache":
			return {"salvage": {"brass_fitting": 1}}
		"terraces_parts_cache":
			return {"name": "Terrace braces", "flags": ["ridge_braces"]}
		"beacon_parts_cache":
			return {"name": "Beacon coil", "flags": ["beacon_coil"]}
		"tide_engine_cache":
			return {"name": "Moth engine part", "flags": ["engine_part"]}
		"reel_cache":
			return {"name": "Reel kit", "recipes": ["braced_reel"], "salvage": {"cord_spool": 1}}
	return {}

static func repair(repair_id: String) -> Dictionary:
	match repair_id:
		"workshop":
			return {"name": "Restore the workshop", "coins": 0, "flags": ["workshop_tools"], "prerequisites": [], "location": "Home cove workshop", "requirements": "Workshop tools from the lido cache", "stage": "workshop"}
		"return_walkway":
			return {"name": "Repair the return walkway", "coins": 0, "salvage": {"brass_fitting": 1}, "prerequisites": [], "location": "Broken return walkway", "requirements": "1 brass fitting from the nearby repair cache", "stage": "routes"}
		"ridge_steps":
			return {"name": "Reopen the ridge steps", "coins": 0, "flags": ["ridge_braces"], "prerequisites": [], "location": "Beacon ridge steps", "requirements": "Terrace braces", "stage": "routes"}
		"beacon":
			return {"name": "Restore the beacon", "coins": 40, "flags": ["beacon_coil"], "prerequisites": [], "location": "Beacon ridge", "requirements": "40 coins + beacon coil", "stage": "beacon"}
		"moth_engine":
			return {"name": "Repair Moth's engine", "coins": 80, "flags": ["engine_part"], "prerequisites": [], "location": "Moth at home cove", "requirements": "80 coins + engine part from tide pools", "stage": "engine"}
	return {}
