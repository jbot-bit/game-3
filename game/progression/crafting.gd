class_name Crafting
extends RefCounted

static func recipe(recipe_id: String) -> Dictionary:
	if recipe_id == "surveyor_lantern":
		return {"coins": 30, "salvage": {"glass_lens": 1}, "output_kind": "lamp", "output_id": "surveyor", "hint": "Glass lens: lido workshop cache"}
	return {}
