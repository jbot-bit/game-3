extends RefCounted
## Hand-authored deck routes. All coordinates are deck-top positions in metres.
## Links are broad ramps, loose physical bridges, or two lips around a 1.4 m gap.
## The route is also a deterministic, ordinary-movement playtest itinerary.


static func course(id: String) -> Dictionary:
	var data: Dictionary = {}
	match id:
		"dogleg":
			data = _layout([Vector3(0, 0, 3), Vector3(0, 0, -9), Vector3(13, 0, -9), Vector3(13, 0, -23), Vector3(27, 0, -23)], 2,
				[4.4, 3.6, 4.4, 3.6], ["walk", "walk", "walk", "walk"],
				"Follow the dock around both corners. The hooks can cut the bend.")
		"stepping_stones":
			data = _layout([Vector3(0, 0, 3), Vector3(0, 0, -7), Vector3(-7, 0, -15), Vector3(0, 0, -23), Vector3(7, 0, -31), Vector3(0, 0, -40)], 3,
				[3.8, 3.4, 3.8, 3.4, 3.8], ["hop", "hop", "walk", "hop", "hop"],
				"Small gaps, big landings. Jump from the striped edge.")
		"high_walk":
			data = _layout([Vector3(0, 1, 3), Vector3(0, 2.4, -10), Vector3(11, 3.8, -19), Vector3(11, 5.2, -33), Vector3(-2, 6.6, -43)], 2,
				[4.2, 3.2, 3.2, 4.2], ["walk", "walk", "walk", "walk"],
				"Keep climbing. The broad landings give the whole crew a breather.")
		"cargo_maze":
			data = _layout([Vector3(0, 0, 4), Vector3(-8, 0, -6), Vector3(7, 0, -16), Vector3(-8, 0, -27), Vector3(7, 0, -38), Vector3(0, 0, -49)], 3,
				[5.4, 5.4, 5.4, 5.4, 5.4], ["walk", "walk", "walk", "walk", "walk"],
				"Thread the cargo stacks. Loose crates can move; steel containers cannot.")
			data.obstacles = [
				_box(Vector3(0, 1.5, -6), Vector3(9, 3, 3)),
				_box(Vector3(-1, 1.5, -17), Vector3(9, 3, 3)),
				_box(Vector3(0, 1.5, -28), Vector3(9, 3, 3)),
				_box(Vector3(-1, 1.5, -39), Vector3(9, 3, 3))]
			data.extra_decks = [_deck(Vector3(0, 0, -22), Vector2(25, 51))]
		"twin_bridges":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 0, -11), Vector3(14, 0, -11), Vector3(14, 0, -27), Vector3(0, 0, -27)], 2,
				[3.8, 4.4, 3.8, 4.4], ["bridge", "walk", "bridge", "walk"],
				"Two loose bridges turn the corner. Steady them with a hand, or hook over.")
		"switchback":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 1.2, -10), Vector3(17, 2.4, -10), Vector3(17, 3.6, 4), Vector3(32, 4.8, 4), Vector3(32, 6, -11)], 3,
				[4.2, 3.4, 3.4, 3.4, 4.2], ["walk", "walk", "walk", "walk", "walk"],
				"Climb the switchback. Turn on the landings before the next ramp.")
		"crosswind":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 0, -10), Vector3(16, 0, -10), Vector3(16, 0, -26), Vector3(32, 0, -26)], 2,
				[4.2, 3.6, 4.2, 3.6], ["walk", "walk", "walk", "walk"],
				"The fan pushes across the catwalk. Reverse it at the checkpoint.")
			data.winds = [_wind(Vector3(8, 2, -10), Vector3(14, 7, 7), Vector3(0, 0, 1.8)), _wind(Vector3(24, 2, -26), Vector3(14, 7, 7), Vector3(0, 0, -1.8))]
		"rooftop_hop":
			data = _layout([Vector3(0, 3, 4), Vector3(0, 3.4, -8), Vector3(10, 3.8, -18), Vector3(10, 4.2, -31), Vector3(-2, 4.6, -41)], 2,
				[4.4, 4.4, 4.4, 4.4], ["hop", "hop", "hop", "hop"],
				"Jump between the rooftops. Each striped gap has a wide landing.")
		"balance_beam":
			data = _layout([Vector3(0, 2, 4), Vector3(0, 2, -12), Vector3(-14, 2, -12), Vector3(-14, 2, -29), Vector3(3, 2, -29)], 2,
				[2.8, 2.8, 2.8, 2.8], ["walk", "walk", "walk", "walk"],
				"Stay centered on the beams. The checkpoint is a safe place to regroup.")
		"freight_spiral":
			data = _layout([Vector3(0, 0, 4), Vector3(-13, 1, 4), Vector3(-13, 2, -14), Vector3(8, 3, -14), Vector3(8, 4, 4), Vector3(21, 5, 4), Vector3(21, 6, -16)], 3,
				[4.2, 3.6, 3.6, 3.6, 3.6, 4.2], ["walk", "walk", "walk", "walk", "walk", "walk"],
				"Spiral around the freight tower. Look up for a grapple shortcut.")
			data.obstacles = [_box(Vector3(-2.5, 4, -5), Vector3(9, 8, 8))]
		"split_decision":
			data = _layout([Vector3(0, 0, 4), Vector3(-11, 0, -9), Vector3(0, 0, -23), Vector3(11, 0, -36), Vector3(0, 0, -49)], 2,
				[3.6, 3.6, 3.6, 3.6], ["walk", "bridge", "walk", "bridge"],
				"Take either side of the split. Meet at the checkpoint, then split again.")
			data.extra_decks = [_deck(Vector3(11, 0, -9), Vector2(6, 6)), _deck(Vector3(-11, 0, -36), Vector2(6, 6))]
			data.extra_links = [_link(Vector3(0, 0, 4), Vector3(11, 0, -9), 3.6), _link(Vector3(11, 0, -9), Vector3(0, 0, -23), 3.6), _link(Vector3(0, 0, -23), Vector3(-11, 0, -36), 3.6), _link(Vector3(-11, 0, -36), Vector3(0, 0, -49), 3.6)]
		"zigzag":
			data = _layout([Vector3(0, 1, 4), Vector3(-10, 1, -8), Vector3(10, 1, -20), Vector3(-10, 1, -32), Vector3(10, 1, -44), Vector3(0, 1, -56)], 3,
				[3.2, 3.2, 3.2, 3.2, 3.2], ["walk", "hop", "walk", "hop", "walk"],
				"Brake before each turn. The long diagonals hide two broken sections.")
		"crane_yard":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 0.6, -13), Vector3(17, 1.2, -13), Vector3(17, 1.8, -31), Vector3(-2, 2.4, -31), Vector3(-2, 3, -49)], 3,
				[4.6, 4.2, 4.6, 4.2, 4.6], ["walk", "walk", "walk", "walk", "walk"],
				"The crane beams are all hookable. Pull up, then switch to swing for the corner.")
			data.gantry_indices = [1, 2, 3, 4, 5]
		"windy_steps":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 0.5, -7), Vector3(-9, 1, -17), Vector3(0, 1.5, -28), Vector3(9, 2, -39), Vector3(0, 2.5, -50)], 3,
				[4.2, 3.8, 4.2, 3.8, 4.2], ["walk", "hop", "walk", "hop", "walk"],
				"Read the breeze before jumping. Reverse the fan to change the drift.")
			data.winds = [_wind(Vector3(-4.5, 3, -12), Vector3(16, 9, 12), Vector3(1.5, 0, 0)), _wind(Vector3(4.5, 4, -33), Vector3(16, 9, 12), Vector3(-1.5, 0, 0))]
		"narrow_escape":
			data = _layout([Vector3(0, 1, 4), Vector3(0, 1, -14), Vector3(14, 1, -14), Vector3(14, 1, -32), Vector3(0, 1, -32), Vector3(0, 1, -49)], 3,
				[2.6, 2.6, 2.6, 2.6, 2.6], ["walk", "walk", "bridge", "walk", "walk"],
				"Single file on the narrow rails. Keep the loose middle bridge steady.")
		"round_trip":
			data = _layout([Vector3(0, 0, 4), Vector3(-15, 0, 4), Vector3(-15, 0, -16), Vector3(5, 0, -16), Vector3(22, 0, -16), Vector3(22, 0, 4), Vector3(12, 0, 17)], 3,
				[4, 4.4, 4, 3.8, 4.4, 3.8], ["walk", "bridge", "walk", "walk", "bridge", "walk"],
				"Circle the yard to the exit behind you. Both long sides have loose bridges.")
			# The longest loose boards need an intermediate bearing for a crew.
			data.links[1].trestle = true
			data.links[4].trestle = true
		"skybridge":
			data = _layout([Vector3(0, 6, 4), Vector3(0, 6.6, -15), Vector3(17, 7.2, -26), Vector3(17, 7.8, -45), Vector3(-1, 8.4, -56)], 2,
				[3.4, 3.4, 3.4, 3.4], ["walk", "hop", "walk", "hop"],
				"The highest walkways in the yard. Hook the beams if a jump goes wrong.")
			data.winds = [_wind(Vector3(17, 9, -36), Vector3(7, 10, 16), Vector3(1.2, 0, 0))]
		"final_shift":
			data = _layout([Vector3(0, 0, 4), Vector3(0, 0, -11), Vector3(-15, 0, -11), Vector3(-15, 1.2, -28), Vector3(1, 2.4, -28), Vector3(17, 2.4, -28), Vector3(17, 3.6, -45), Vector3(1, 4.2, -58)], 4,
				[4.2, 3.2, 3.4, 3.4, 3.2, 3.4, 4.2], ["bridge", "walk", "walk", "walk", "bridge", "walk", "hop"],
				"One last shift: loose bridges, high ramps, wind, and a final rooftop jump.")
			data.winds = [_wind(Vector3(17, 4.8, -37), Vector3(8, 10, 14), Vector3(-1.5, 0, 0))]
	if data.is_empty():
		return {}
	data.id = id
	return data


static func _layout(points: Array, checkpoint: int, widths: Array, kinds: Array, hint: String) -> Dictionary:
	var route: Array[Vector3] = []
	var decks: Array[Dictionary] = []
	var links: Array[Dictionary] = []
	var jumps: Array[int] = []
	for index in points.size():
		var point: Vector3 = points[index]
		route.append(point)
		var size := Vector2(7, 7)
		if index == 0 or index == points.size() - 1 or index == checkpoint:
			size = Vector2(11, 9)
		decks.append(_deck(point, size))
		if index > 0:
			links.append(_link(points[index - 1], point, widths[index - 1], kinds[index - 1]))
			if kinds[index - 1] == "hop":
				jumps.append(index)
	return {"route": route, "route_jumps": jumps, "decks": decks, "links": links,
		"checkpoint_index": checkpoint, "intro": hint, "obstacles": [], "winds": [],
		"extra_decks": [], "extra_links": [], "gantry_indices": [1, checkpoint, points.size() - 1]}


static func _deck(top: Vector3, size: Vector2) -> Dictionary:
	return {"top": top, "size": size}


static func _link(from: Vector3, to: Vector3, width: float, kind: String = "walk") -> Dictionary:
	return {"from": from, "to": to, "width": width, "kind": kind}


static func _box(at: Vector3, size: Vector3) -> Dictionary:
	return {"at": at, "size": size}


static func _wind(at: Vector3, size: Vector3, push: Vector3) -> Dictionary:
	return {"at": at, "size": size, "push": push}
