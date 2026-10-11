extends "res://prototypes/physics_party/party_world.gd"
## The additional eighteen courses use the same host-owned prop simulation.
## Set course_id before adding this node; data never chooses a resource path.

const LevelData = preload("res://prototypes/physics_party/party_level_data.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const HOP_GAP: float = 1.4

var course_id: String = "dogleg"
var _level: Dictionary = {}


func _ready() -> void:
	_level = LevelData.course(course_id)
	assert(not _level.is_empty(), "A level world needs a known level ID")
	var checkpoint: Vector3 = _level.route[_level.checkpoint_index]
	switch_position = checkpoint + Vector3(-4.1, 1.0, 2.2) if not _level.winds.is_empty() else Vector3(999, 999, 999)
	super._ready()


func route_points() -> Array[Vector3]:
	# Y denotes the surface, not the puppet root: steer horizontally and stand.
	var result: Array[Vector3] = []
	for point: Vector3 in _level.route:
		result.append(point)
	return result


func route_jumps() -> Array[int]:
	var result: Array[int] = []
	for index: int in _level.route_jumps:
		result.append(index)
	return result


func required_route_supports() -> Array[String]:
	var result: Array[String] = []
	for index in _level.links.size():
		if _level.links[index].kind == "bridge":
			result.append("plank_" + str(index + 1))
	return result


func intro_text() -> String:
	return _level.get("intro", "Follow the marked decks to extraction.")


func spawn_point(slot: int, checkpoint: int = 0) -> Vector3:
	var index: int = 0
	if checkpoint >= 2:
		index = _level.route.size() - 1
	elif checkpoint == 1:
		index = _level.checkpoint_index
	return _level.route[index] + Vector3(float(clampi(slot, 0, 2) - 1) * 2.8, 3, 0)


func checkpoint_contains(at: Vector3) -> bool:
	return _contains_deck(at, _level.checkpoint_index)


func goal_contains(at: Vector3) -> bool:
	return _contains_deck(at, _level.route.size() - 1)


func _contains_deck(at: Vector3, index: int) -> bool:
	var deck: Dictionary = _level.decks[index]
	var local: Vector3 = at - deck.top
	return absf(local.x) < deck.size.x * 0.5 - 0.4 and absf(local.z) < deck.size.y * 0.5 - 0.4 and local.y > 0.2 and local.y < 8.0


func wind_at(at: Vector3) -> Vector3:
	for wind: Dictionary in _level.get("winds", []):
		var local: Vector3 = at - wind.at
		var half: Vector3 = wind.size * 0.5
		if absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z:
			return wind.push * float(wind_direction)
	return Vector3.ZERO


func set_wind(direction: int) -> void:
	super.set_wind(direction)
	if is_instance_valid(_wind_arrow) and not _level.winds.is_empty():
		var push: Vector3 = _level.winds[0].push
		_wind_arrow.rotation.y = atan2(-push.z, push.x) + (0.0 if wind_direction > 0 else PI)


func _build_platforms() -> void:
	for index in _level.decks.size():
		var id: String = "Landing" + str(index)
		if index == 0:
			id = "Start"
		elif index == _level.decks.size() - 1:
			id = "Finish"
		elif index == _level.checkpoint_index:
			id = "Middle"
		_make_deck(id, _level.decks[index])
	for index in _level.extra_decks.size():
		_make_deck("AuxDeck" + str(index), _level.extra_decks[index])
	for index in _level.links.size():
		var link: Dictionary = _level.links[index]
		if link.kind == "bridge":
			continue
		if link.kind == "hop":
			_make_hop(index, link)
		else:
			_make_walkway("Walkway" + str(index), link["from"], link.to, link.width)
	for index in _level.extra_links.size():
		var link: Dictionary = _level.extra_links[index]
		_make_walkway("Alternative" + str(index), link["from"], link.to, link.width)
	for index in _level.obstacles.size():
		var obstacle: Dictionary = _level.obstacles[index]
		var body := _static_box("CargoStack" + str(index), obstacle.at, obstacle.size, STEEL)
		_box_visual(body, Vector3(obstacle.size.x + 0.04, 0.15, obstacle.size.z + 0.04), Vector3(0, obstacle.size.y * 0.5 - 0.15, 0), GOLD)


func _make_deck(id: String, deck: Dictionary) -> void:
	var size := Vector3(deck.size.x, 0.7, deck.size.y)
	var body := _static_box(id, deck.top - Vector3(0, 0.35, 0), size, DECK)
	if id not in ["Start", "Middle", "Finish"]:
		_dress_deck(body, size, GOLD)


func _make_walkway(id: String, from: Vector3, to: Vector3, width: float) -> StaticBody3D:
	var span: Vector3 = to - from
	var size := Vector3(width, 0.28, span.length() + 0.16)
	var body := _static_box(id, (from + to) * 0.5 - Vector3(0, 0.14, 0), size, DECK)
	body.basis = Basis.looking_at(span.normalized(), Vector3.UP)
	_dress_walkway(body, size, GOLD)
	return body


func _make_hop(index: int, link: Dictionary) -> void:
	var from: Vector3 = link["from"]
	var to: Vector3 = link.to
	var direction: Vector3 = (to - from).normalized()
	var center: Vector3 = (from + to) * 0.5
	var first_edge: Vector3 = center - direction * HOP_GAP * 0.5
	var second_edge: Vector3 = center + direction * HOP_GAP * 0.5
	_make_walkway("JumpLip" + str(index) + "A", from, first_edge, link.width)
	_make_walkway("JumpLip" + str(index) + "B", second_edge, to, link.width)
	for edge: Vector3 in [first_edge, second_edge]:
		var mark := _box_visual(self, Vector3(link.width, 0.025, 0.35), edge + Vector3(0, 0.025, 0), GOLD)
		mark.basis = Basis.looking_at(direction, Vector3.UP)


func _build_props() -> void:
	for index in 4:
		var deck_index: int = 0 if index < 2 else _level.checkpoint_index
		var deck: Vector3 = _level.route[deck_index]
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_prop_box("block_" + str(index + 1), deck + Vector3(side * 4.1, 0.66, -2.4), Vector3.ONE * 1.25, 1.8, GOLD if index % 2 == 0 else CORAL)
	for index in _level.links.size():
		var link: Dictionary = _level.links[index]
		if link.kind != "bridge":
			continue
		var from: Vector3 = link["from"]
		var to: Vector3 = link.to
		var span: Vector3 = to - from
		var id: String = "plank_" + str(index + 1)
		var size := Vector3(link.width, 0.24, span.length() + 0.4)
		if link.get("trestle", false):
			var bearing := _static_box("BridgeTrestle" + str(index), (from + to) * 0.5 - Vector3(0, 0.65, 0), Vector3(link.width + 0.6, 1.3, 2.2), STEEL)
			bearing.basis = Basis.looking_at(span.normalized(), Vector3.UP)
			_box_visual(bearing, Vector3(link.width + 1, 0.22, 2.5), Vector3(0, 0.4, 0), GOLD)
			for side: float in [-1.0, 1.0]:
				_box_visual(bearing, Vector3(0.8, 18, 0.8), Vector3(side * link.width * 0.4, -9, 0), STEEL)
		var board := _prop_box(id, (from + to) * 0.5 + Vector3(0, 0.125, 0), size, 8.0, PETROL)
		board.basis = Basis.looking_at(span.normalized(), Vector3.UP)
		board.angular_damp = 1.8
		board.physics_material_override.friction = 0.7
		_initial_prop_poses[id] = board.global_transform


func _build_seesaw() -> void:
	# These layouts use loose bridge boards; the first two courses retain seesaws.
	pass


func _build_switch_and_fan() -> void:
	if _level.winds.is_empty():
		return
	_static_box("WindSwitchBase", switch_position - Vector3(0, 0.5, 0), Vector3(1.1, 1, 1.1), NAVY)
	_switch_handle = Node3D.new()
	_switch_handle.name = "RedLever"
	_switch_handle.position = switch_position
	add_child(_switch_handle)
	_box_visual(_switch_handle, Vector3(0.16, 1, 0.16), Vector3(0, 0.5, 0), CREAM)
	_box_visual(_switch_handle, Vector3(0.48, 0.3, 0.48), Vector3(0, 1, 0), CORAL)
	_wind_label = _label("WIND  >", switch_position + Vector3(0, 2.1, 0), 34, CREAM)
	var wind: Dictionary = _level.winds[0]
	var turned: bool = absf(wind.push.z) > absf(wind.push.x)
	var edge := Vector3(0, 0, wind.size.z * 0.5 + 1.5) if turned else Vector3(-wind.size.x * 0.5 - 1.5, 0, 0)
	var fan_at: Vector3 = wind.at + edge
	_fan_housing(fan_at, turned)
	_static_box("FanStand", fan_at - Vector3(0, 2, 0), Vector3(0.8, 4, 0.8), STEEL)
	var fan_frame := Node3D.new()
	fan_frame.position = fan_at + (Vector3(0, 0, -0.64) if turned else Vector3(0.64, 0, 0))
	fan_frame.rotation.y = PI * 0.5 if turned else 0.0
	add_child(fan_frame)
	_fan_rotor = Node3D.new()
	_fan_rotor.name = "FanBlades"
	fan_frame.add_child(_fan_rotor)
	_box_visual(_fan_rotor, Vector3(0.12, 2.8, 0.4), Vector3.ZERO, CORAL)
	_box_visual(_fan_rotor, Vector3(0.12, 0.4, 2.8), Vector3.ZERO, CORAL)
	_wind_arrow = Node3D.new()
	_wind_arrow.position = _level.route[_level.checkpoint_index] + Vector3(0, 0.045, 2.9)
	add_child(_wind_arrow)
	_box_visual(_wind_arrow, Vector3(2, 0.025, 0.18), Vector3.ZERO, CREAM)
	for side: float in [-1.0, 1.0]:
		var head := _box_visual(_wind_arrow, Vector3(0.7, 0.025, 0.18), Vector3(0.7, 0, side * 0.2), CREAM)
		head.rotation.y = side * PI * 0.25


func _build_finish() -> void:
	var finish: Vector3 = _level.route.back()
	var gate: Vector3 = finish + Vector3(0, 4, -3)
	for side: float in [-1.0, 1.0]:
		_static_box("FinishPost" + str(side), gate + Vector3(side * 3.4, -2, 0), Vector3(0.55, 4, 0.55), STEEL)
	_extraction_gate(gate)


func _build_signs() -> void:
	var start: Vector3 = _level.route.front()
	var checkpoint: Vector3 = _level.route[_level.checkpoint_index]
	_label("%02d / %s" % [Courses.number(course_id), Courses.course_name(course_id).to_upper()], start + Vector3(0, 0.055, 3.5), 46, CREAM, true)
	_label("CHECKPOINT", checkpoint + Vector3(0, 0.055, 3.3), 30, MINT, true)
	for index in range(_level.route.size() - 1):
		var at: Vector3 = _level.route[index]
		var toward: Vector3 = _level.route[index + 1] - at
		var direction := Vector3(toward.x, 0, toward.z).normalized()
		var marker := Node3D.new()
		marker.position = at + direction * 2.1 + Vector3(0, 0.04, 0)
		marker.basis = Basis.looking_at(direction, Vector3.UP)
		add_child(marker)
		_box_visual(marker, Vector3(0.15, 0.025, 1.1), Vector3.ZERO, MINT)
		for side: float in [-1.0, 1.0]:
			var tip := _box_visual(marker, Vector3(0.15, 0.025, 0.7), Vector3(side * 0.18, 0, -0.35), MINT)
			tip.rotation.y = -side * PI * 0.25


func _build_grapple_anchors() -> void:
	for index: int in _level.gantry_indices:
		var from: Vector3 = _level.route[index - 1]
		var to: Vector3 = _level.route[index]
		var center: Vector3 = (from + to) * 0.5
		var turned: bool = absf(to.x - from.x) > absf(to.z - from.z)
		_grapple_gantry("RouteGrapple" + str(index), center + Vector3(0, 9, 0), 16, minf(from.y, to.y) - 0.5, turned)
