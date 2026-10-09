class_name Crafting
extends RefCounted

static func recipes_all() -> Dictionary:
	return {
		"surveyor_lantern": {"name": "Surveyor Lantern", "coins": 30, "salvage": {"glass_lens": 1}, "output_kind": "lamp", "output_id": "surveyor", "hint": "Glass lens: lido workshop cache"},
		"braced_reel": {"name": "Braced Reel", "coins": 35, "salvage": {"cord_spool": 1}, "output_kind": "rod", "output_id": "braced_reel", "hint": "Cord spool and recipe: reel kit cache on the south-east shore"}}

static func recipe(recipe_id: String) -> Dictionary:
	return recipes_all().get(recipe_id, {})
