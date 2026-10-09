class_name Species
extends RefCounted

static func catalog() -> Dictionary:
	return {
		"penny_perch": {"value": 10, "behavior": "dart", "name": "Penny Perch"},
		"bellgill": {"value": 20, "behavior": "heavy", "name": "Bellgill"},
		"lantern_eel": {"value": 40, "behavior": "dart", "name": "Lantern Eel"}
	}
