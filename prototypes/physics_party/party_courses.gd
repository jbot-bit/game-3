extends RefCounted
## Stable LAN identifiers and display names. Saves remain shared across courses.
const IDS: Array[String] = ["crossing", "counterweight"]

static func valid(id: String) -> bool:
	return id in IDS

static func course_name(id: String) -> String:
	return "Counterweight" if id == "counterweight" else "First Crossing"

static func next_id(id: String) -> String:
	return "crossing" if id == "counterweight" else "counterweight"
