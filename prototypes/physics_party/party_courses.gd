extends RefCounted
## Stable LAN identifiers and display names. Saves remain shared across courses.
const IDS: Array[String] = [
	"crossing", "counterweight", "dogleg", "stepping_stones", "high_walk",
	"cargo_maze", "twin_bridges", "switchback", "crosswind", "rooftop_hop",
	"balance_beam", "freight_spiral", "split_decision", "zigzag", "crane_yard",
	"windy_steps", "narrow_escape", "round_trip", "skybridge", "final_shift",
]

const NAMES: Array[String] = [
	"First Crossing", "Counterweight", "Dogleg Docks", "Stepping Stones", "High Walk",
	"Cargo Maze", "Twin Bridges", "Switchback", "Crosswind", "Rooftop Hop",
	"Balance Beam", "Freight Spiral", "Split Decision", "Zigzag", "Crane Yard",
	"Windy Steps", "Narrow Escape", "Round Trip", "Skybridge", "Final Shift",
]

static func valid(id: String) -> bool:
	return id in IDS

static func course_name(id: String) -> String:
	var index: int = IDS.find(id)
	return NAMES[index] if index >= 0 else "Unknown Course"

static func next_id(id: String) -> String:
	var index: int = IDS.find(id)
	return IDS[(index + 1) % IDS.size()] if index >= 0 else IDS[0]


static func number(id: String) -> int:
	return IDS.find(id) + 1
