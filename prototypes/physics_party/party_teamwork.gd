extends Node3D
## Authoritative physical teamwork tail. Operators hold E; a distinct runner latches.
const CARGO_ID: String = "team_cargo"
const MINT := Color("43d6cf")
const GOLD := Color("f2c355")
const DECK := Color("536878")
const NAVY := Color("243d52")
var world: Node3D
var course_id: String = "crossing"
var stages: Array[Dictionary] = []
var _origin: Vector3
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
var _goal: Vector3
var _crossers: Dictionary = {}
var _rider: String = ""
var _rider_instance: int = 0
var _ride_height: float = 0.0
var _ride_last_amount: float = -1.0
var _carriers: Dictionary = {}

func _ready() -> void:
	_origin = world.spawn_point(1, 2) - Vector3(0, 3, 0)
	if world.has_method("route_points"):
		var route: Array = world.route_points()
		_origin = route[-1]
		_forward = (route[-1] - route[-2]) * Vector3(1, 0, 1)
		_forward = _forward.normalized()
	elif course_id == "counterweight": _forward = Vector3.RIGHT
	_right = _forward.cross(Vector3.UP).normalized()
	_walkway("TeamApproach", _origin, _point(20), 5.0)
	for index in 3: _build_stage(index)
	_walkway("RelayConnection", stages[0].far, stages[1].near, 5.0)
	_walkway("FreightConnection", stages[1].far, stages[2].near, 5.0)
	_goal = _point(158, 0, 8)
	_walkway("FinalCrossing", stages[2].far, _goal, 4.5)
	var extraction := _box("TeamExtraction", _goal - Vector3(0, 0.4, 0), Vector3(12, 0.8, 12), DECK)
	world._dress_deck(extraction, Vector3(12, 0.8, 12), MINT)
	_label("ALL THREE / EXTRACTION", _goal + Vector3(0, 3.4, 0), 38)
	for side: float in [-4.8, 4.8]:
		_box("FinishPost" + str(side), _goal + _right * side + Vector3(0, 2, 0), Vector3(0.4, 4, 0.4), GOLD)
	preload("res://prototypes/physics_party/party_mesh_batch.gd").merge_tree(self)
	reset()
	world.clear_background_obstructions()

func _point(distance: float, side: float = 0, height: float = 0) -> Vector3:
	return _origin + _forward * distance + _right * side + Vector3.UP * height

func _build_stage(index: int) -> void:
	var distance: float = 20.0 + float(index) * 44.0
	var height: float = 8.0 if index == 2 else 0.0
	var near: Vector3 = _point(distance, 0, height)
	var far: Vector3 = _point(distance + 30, 0, 8.0 if index > 0 else 0.0)
	var near_body := _box("TeamNear" + str(index), near - Vector3(0, 0.4, 0), Vector3(12, 0.8, 12), DECK)
	var far_body := _box("TeamFar" + str(index), far - Vector3(0, 0.4, 0), Vector3(12, 0.8, 12), DECK)
	world._dress_deck(near_body, Vector3(12, 0.8, 12), GOLD)
	world._dress_deck(far_body, Vector3(12, 0.8, 12), MINT)
	var pads: Array[Vector3] = [near - _right * 4.0 - _forward, near + _right * 4.0 - _forward]
	for side in 2:
		world._box_visual(near_body, Vector3(2.6, 0.025, 2.6), near_body.to_local(pads[side] + Vector3(0, 0.02, 0)), MINT if side == 0 else GOLD)
		_label("HOLD E\n" + ("LEFT" if side == 0 else "RIGHT"), pads[side] + Vector3(0, 2.2, 0), 24)
	var latch: Vector3 = far + _right * 3.0
	_box("LatchBase" + str(index), latch + Vector3(0, 0.35, 0), Vector3(0.65, 0.7, 0.65), GOLD)
	_label("RUNNER / E TO LOCK", latch + Vector3(0, 2.4, 0), 25)
	var mover := AnimatableBody3D.new()
	mover.name = ["RelayDrawbridge", "FreightLift", "CargoDrawbridge"][index]
	mover.sync_to_physics = false
	mover.add_to_group("party_grabbable")
	add_child(mover)
	var size := Vector3(5.5, 0.36, 18.4) if index != 1 else Vector3(6, 0.36, 6)
	world._box_visual(mover, size, Vector3.ZERO, world.PETROL)
	world._dress_walkway(mover, size, MINT)
	world._add_box_collision(mover, size)
	var heading: String = ["01 / BRIDGE RELAY", "02 / FREIGHT LIFT", "03 / CARGO RELAY"][index]
	var sign := _label(heading, near + Vector3(0, 4.5, 0), 40)
	var stage: Dictionary = {"kind": ["bridge", "lift", "cargo"][index], "near": near, "far": far, "pads": pads, "latch": latch, "mover": mover, "near_body": near_body, "far_body": far_body, "sign": sign, "heading": heading, "latched": false, "amount": 0.0}
	if index == 1:
		# Boarding stops at the lift edge; no fixed floor under its travel path.
		_walkway("LiftBoardingLip", near + _forward * 5, near + _forward * 7.1, 5.0)
		_walkway("UpperFreightWalk", near + _forward * 12.9 + Vector3(0, 8, 0), far, 5.0)
		var ramp := _walkway("FreightEscapeRamp", near + _right * 8 - _forward * 3, far + _right * 8 + _forward * 3, 5.0)
		stage.ramp = ramp
		for side: float in [-3.2, 3.2]:
			_box("LiftRail" + str(side), near + _forward * 10 + _right * side + Vector3(0, 4, 0), Vector3(0.25, 9, 0.25), GOLD)
	if index == 2:
		var cargo: RigidBody3D = world._prop_box(CARGO_ID, near + _forward * 2 + Vector3(0, 0.8, 0), Vector3.ONE * 1.4, 1.4, GOLD)
		cargo.contact_monitor = true
		cargo.max_contacts_reported = 16
		world._dress_crate(cargo, Vector3.ONE * 1.4, "TEAM")
		stage.receiver = far - _forward * 1.8
		world._box_visual(far_body, Vector3(4.5, 0.025, 4.5), far_body.to_local(stage.receiver + Vector3(0, 0.02, 0)), GOLD)
		_label("DELIVER CRATE", stage.receiver + Vector3(0, 2.8, 0), 24)
	stages.append(stage)

func tick(actors: Dictionary, controls: Dictionary, delta: float) -> void:
	if not world.authoritative or not is_finite(delta) or delta <= 0.0: return
	_prune_proofs(actors)
	var active: int = _cleared()
	if active >= 3: return
	var stage: Dictionary = stages[active]
	var operators: Array[String] = _operators(stage, actors, controls)
	var powered: bool = operators.size() == 2 and _distinct_count(actors) >= 3
	if active == 1 and powered and _rider.is_empty():
		powered = false
		if stage.amount <= 0.01:
			for id: String in actors:
				if not id in operators and actors[id] != actors[operators[0]] and actors[id] != actors[operators[1]] and _supported_by(actors[id], stage.mover): powered = true
	stage.amount = move_toward(float(stage.amount), 1.0 if powered else 0.0, minf(delta, 0.05) * (0.175 if active == 1 else 0.30))
	_apply_geometry(active)
	if not powered:
		if stage.amount <= 0.01:
			_crossers.clear()
			_rider = ""
			_rider_instance = 0
			_ride_height = 0.0
			_ride_last_amount = -1.0
			_carriers.clear()
		return
	for key: Variant in actors:
		var id: String = str(key)
		var actor: Node3D = actors[key]
		if not is_instance_valid(actor) or id in operators: continue
		if actor == actors[operators[0]] or actor == actors[operators[1]]: continue
		if active == 0 and _supported_by(actor, stage.mover): _crossers[id] = actor.get_instance_id()
		if active == 1:
			var supported: bool = _supported_by(actor, stage.mover)
			if stage.amount < 0.08 and supported and _rider.is_empty():
				_rider = id
				_rider_instance = actor.get_instance_id()
			if _rider == id:
				if supported and _ride_last_amount >= 0: _ride_height += maxf(0, float(stage.amount) - _ride_last_amount) * 8.0
				_ride_last_amount = float(stage.amount) if supported else -1.0
		if active == 2 and (actor.get("_left_target") == world.props[CARGO_ID] or actor.get("_right_target") == world.props[CARGO_ID]): _carriers[id] = actor.get_instance_id()
		if not _held(controls, id) or not _standing_at(actor, stage.latch, 2.2) or stage.amount < 0.995: continue
		var earned: bool = _crossers.get(id, 0) == actor.get_instance_id() if active == 0 else (_rider == id and _ride_height >= 6.5 if active == 1 else _carriers.get(id, 0) == actor.get_instance_id() and _cargo_received(stage))
		if earned:
			stage.latched = true
			stage.amount = 1.0
			_apply_geometry(active)
			_crossers.clear()
			_rider = ""
			_rider_instance = 0
			_ride_height = 0.0
			_ride_last_amount = -1.0
			_carriers.clear()
			break

func forget_actor(id: String) -> void:
	# Recovery and a new occupant of a crew slot cannot inherit a physical feat.
	_crossers.erase(id)
	_carriers.erase(id)
	if _rider == id:
		_rider = ""
		_rider_instance = 0
		_ride_height = 0.0
		_ride_last_amount = -1.0

func _prune_proofs(actors: Dictionary) -> void:
	for proofs: Dictionary in [_crossers, _carriers]:
		for id: String in proofs.keys():
			if not actors.has(id) or not is_instance_valid(actors[id]) or actors[id].get_instance_id() != proofs[id]: proofs.erase(id)
	if not _rider.is_empty() and (not actors.has(_rider) or not is_instance_valid(actors[_rider]) or actors[_rider].get_instance_id() != _rider_instance): forget_actor(_rider)

func _operators(stage: Dictionary, actors: Dictionary, controls: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for pad: Vector3 in stage.pads:
		for key: Variant in actors:
			var id: String = str(key)
			var actor: Node3D = actors[key]
			if id in result or not _held(controls, id) or not _standing_at(actor, pad, 1.6): continue
			if not result.is_empty() and actor == actors[result[0]]: continue
			result.append(id)
			break
	return result

func _distinct_count(actors: Dictionary) -> int:
	var seen: Array[int] = []
	for actor: Variant in actors.values():
		if is_instance_valid(actor) and actor is Node3D and not actor.get_instance_id() in seen: seen.append(actor.get_instance_id())
	return seen.size()

func _held(controls: Dictionary, id: String) -> bool:
	var data: Variant = controls.get(id, {})
	return data is Dictionary and data.get("interact", false) is bool and data.get("interact", false)

func _standing_at(actor: Node3D, at: Vector3, radius: float) -> bool:
	if not is_instance_valid(actor) or not actor.has_method("body_position"): return false
	# The ragdoll's feet can briefly lift while its torso stays on a pad. Reuse
	# its existing grounded grace; released/stale E and leaving the pad still stop it.
	if actor.get("is_on_floor") != true and float(actor.get("_floor_grace")) <= 0.0: return false
	var offset: Vector3 = actor.body_position() - at
	return offset.is_finite() and Vector2(offset.x, offset.z).length() < radius and offset.y > 0.55 and offset.y < 3.0

func _supported_by(actor: Node3D, body: PhysicsBody3D) -> bool:
	for cast: ShapeCast3D in [actor.left_floor, actor.right_floor]:
		for index in cast.get_collision_count():
			if cast.get_collider(index) == body and cast.get_collision_normal(index).y > 0.5: return true
	return false

func _cargo_received(stage: Dictionary) -> bool:
	var cargo: RigidBody3D = world.props[CARGO_ID]
	var offset: Vector3 = cargo.global_position - stage.receiver
	return Vector2(offset.x, offset.z).length() < 2.1 and offset.y > 0.35 and offset.y < 1.3 and stage.far_body in cargo.get_colliding_bodies()

func _apply_geometry(index: int) -> void:
	var stage: Dictionary = stages[index]
	var amount: float = stage.amount
	var mover: AnimatableBody3D = stage.mover
	if index == 1:
		mover.global_position = stage.near + _forward * 10 + Vector3(0, amount * 8 - 0.18, 0)
		mover.basis = Basis.looking_at(_forward, Vector3.UP)
		stage.ramp.visible = stage.latched
		stage.ramp.collision_layer = 1 if stage.latched else 0
		stage.ramp.collision_mask = 1 if stage.latched else 0
	else:
		var rotation := Basis(_right, (1.0 - amount) * deg_to_rad(78.0))
		mover.global_position = stage.near + _forward * 5.9 + rotation * (_forward * 9.2) - Vector3(0, 0.18, 0)
		mover.basis = rotation * Basis.looking_at(_forward, Vector3.UP)
	var text: String = stage.heading + ("\nLOCKED OPEN / CHECKPOINT" if stage.latched else "\nTWO HOLD E / ONE RUNNER")
	if stage.sign.text != text: stage.sign.text = text

func reset() -> void:
	_crossers.clear()
	_rider = ""
	_rider_instance = 0
	_ride_height = 0.0
	_ride_last_amount = -1.0
	_carriers.clear()
	for index in stages.size():
		stages[index].latched = false
		stages[index].amount = 0.0
		_apply_geometry(index)
	if world.props.has(CARGO_ID): world._reset_prop(CARGO_ID)

func capture() -> Dictionary:
	var latched: Array[bool] = []
	var amounts: Array[float] = []
	for stage: Dictionary in stages:
		latched.append(stage.latched)
		amounts.append(stage.amount)
	return {"version": 1, "latched": latched, "amounts": amounts}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 3 or data.get("version") != 1: return false
	if not data.get("latched") is Array or not data.get("amounts") is Array: return false
	if data.latched.size() != 3 or data.amounts.size() != 3: return false
	var closed: bool = false
	for index in 3:
		if not data.latched[index] is bool: return false
		if not data.amounts[index] is float and not data.amounts[index] is int: return false
		var amount: float = data.amounts[index]
		if not is_finite(amount) or amount < 0.0 or amount > 1.0: return false
		if data.latched[index] and (closed or amount != 1.0): return false
		closed = closed or not data.latched[index]
	return true

static func interpolate(before: Dictionary, after: Dictionary, blend: float) -> Dictionary:
	if not valid_snapshot(after): return before.duplicate(true) if valid_snapshot(before) else {}
	if not valid_snapshot(before) or not is_finite(blend): return after.duplicate(true)
	for index in 3:
		if before.latched[index] and not after.latched[index]: return after.duplicate(true)
	var result: Dictionary = before.duplicate(true)
	var weight: float = clampf(blend, 0, 1)
	for index in 3:
		result.amounts[index] = lerpf(before.amounts[index], after.amounts[index], weight)
		if weight >= 1.0: result.latched[index] = after.latched[index]
	return result

func present(data: Dictionary) -> void:
	if world.authoritative or not valid_snapshot(data): return
	for index in 3:
		stages[index].latched = data.latched[index]
		stages[index].amount = float(data.amounts[index])
		_apply_geometry(index)

func _cleared() -> int:
	var result: int = 0
	for stage: Dictionary in stages:
		if not stage.latched: break
		result += 1
	return result

func completed() -> bool: return _cleared() == 3

func checkpoint_number() -> int:
	return _cleared() + 2 if _cleared() > 0 else 0

func _checkpoint() -> Vector3:
	return stages[_cleared() - 1].far if _cleared() > 0 else _origin

func checkpoint_spawn(slot: int) -> Vector3:
	return _checkpoint() + _right * float(clampi(slot, 0, 2) - 1) * 2.8 + Vector3(0, 3, 0)

func goal_spawn(slot: int) -> Vector3:
	return _goal + _right * float(clampi(slot, 0, 2) - 1) * 2.8 + Vector3(0, 3, 0)

func _contains(at: Vector3, center: Vector3) -> bool:
	var offset: Vector3 = at - center
	return offset.is_finite() and absf(offset.dot(_right)) < 5.5 and absf(offset.dot(_forward)) < 5.5 and offset.y > 0.2 and offset.y < 5.0

func checkpoint_contains(at: Vector3) -> bool: return _contains(at, _checkpoint())
func goal_contains(at: Vector3) -> bool: return completed() and _contains(at, _goal)

func status_text(player_count: int) -> String:
	if player_count < 3: return "3 players required for the team obstacles / solo practice is open"
	if completed(): return "ALL STAGES LOCKED / bring all three to extraction"
	return "TEAM STAGE %d / 3 — %s" % [_cleared() + 1, ["BRIDGE RELAY", "FREIGHT LIFT", "CARGO RELAY"][_cleared()]]

func hint_text() -> String:
	if completed(): return "Follow the final crossing. All three must reach extraction."
	return ["Two stand on the colored pads and hold E. The third crosses the bridge and presses E at the far latch.", "Runner: board the lowered lift first. Two players hold E to raise it; the rider presses E at the upper latch. Early controls wait for the rider.", "Two hold E to lower the cargo bridge. The third grabs the marked crate, brings it onto the far square, then presses E at the latch."][_cleared()]

func _box(id: String, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.position = at
	body.basis = Basis.looking_at(_forward, Vector3.UP)
	body.add_to_group("party_grabbable")
	add_child(body)
	world._box_visual(body, size, Vector3.ZERO, color)
	world._add_box_collision(body, size)
	return body

func _walkway(id: String, from: Vector3, to: Vector3, width: float) -> StaticBody3D:
	var span: Vector3 = to - from
	var body := _box(id, (from + to) * 0.5 - Vector3(0, 0.14, 0), Vector3(width, 0.28, span.length() + 0.2), DECK)
	body.basis = Basis.looking_at(span.normalized(), Vector3.UP)
	world._dress_walkway(body, Vector3(width, 0.28, span.length() + 0.2), MINT)
	return body

func _label(text: String, at: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("eee8dc")
	add_child(label)
	return label
