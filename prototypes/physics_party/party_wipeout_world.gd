extends "res://prototypes/physics_party/party_arena_world.gd"
## A continuous 130m obstacle run with physical tipping beams and padded sweepers.
## The host moves collision bodies; clients only display the shared pose timeline.

const CHECKPOINTS: Array[Vector3] = [Vector3(0, 4, 0), Vector3(0, 4, -29), Vector3(0, 4, -57), Vector3(0, 4, -90)]
const GOAL := Vector3(0, 4, -130)
var movers: Dictionary = {}
var mover_specs: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
	if _built: return
	_built = true
	_build_lighting()
	_deck("StartPad", CHECKPOINTS[0], Vector2(10, 12), PAD_BLUE)
	_balance_beam("balance_pitch", Vector3(0, 3.82, -15), Vector3(3.8, 0.36, 17), false)
	_deck("Checkpoint1", CHECKPOINTS[1], Vector2(10, 10), PAD_YELLOW)
	_pad("SweeperDeck", Vector3(0, 3.4, -43), 9.0, 1.2, PAD_PINK)
	_sweeper("SweepOne", Vector3(0, 4.62, -43), 14.8, 0.65, 0.45)
	_deck("Checkpoint2", CHECKPOINTS[2], Vector2(10, 10), PAD_YELLOW)
	for index in 4:
		var positions: Array[Vector3] = [Vector3(0, 3.4, -65.4), Vector3(1.6, 3.4, -71), Vector3(-1.6, 3.4, -77), Vector3(0, 3.4, -83)]
		_pad("HopPodium" + str(index), positions[index], 2.5 if index < 3 else 2.6, 1.2, PAD_BLUE if index % 2 == 0 else PAD_PINK)
	_deck("Checkpoint3", CHECKPOINTS[3], Vector2(10, 9), PAD_YELLOW)
	_balance_beam("balance_roll", Vector3(0, 3.82, -102.5), Vector3(2.9, 0.36, 16), true)
	_pad("FinalSweeperDeck", Vector3(0, 3.4, -117.5), 7.0, 1.2, PAD_PINK)
	_sweeper("SweepFinal", Vector3(0, 4.68, -117.5), 11.8, -0.8, 1.8)
	_deck("FinishPad", GOAL, Vector2(12, 11), MINT)
	_label("WIPEOUT", Vector3(0, 4.08, 2.2), 65, CREAM, true)
	_label("TILT  /  TIME YOUR JUMPS  /  STAY ON", Vector3(0, 4.085, 0.2), 23, CREAM, true)
	for index in range(1, 4):
		_label("CHECKPOINT  " + str(index) + " / 3", CHECKPOINTS[index] + Vector3(0, 0.07, 1.8), 32, NAVY, true)
	_label("FINISH", GOAL + Vector3(0, 0.07, -1), 60, NAVY, true)
	_prop_ids.sort()
	preload("res://prototypes/physics_party/party_mesh_batch.gd").merge_tree(self)


func spawn_point(slot: int, checkpoint: int = 0) -> Vector3:
	return CHECKPOINTS[clampi(checkpoint, 0, 3)] + Vector3(float(clampi(slot, 0, 2) - 1) * 2.5, 3.0, 1.4)


func checkpoint_index(at: Vector3) -> int:
	if not at.is_finite(): return 0
	for index in range(3, 0, -1):
		if _inside_pad(at, CHECKPOINTS[index], Vector2(9.0, 7.5)): return index
	return 0


func checkpoint_contains(at: Vector3) -> bool: return checkpoint_index(at) > 0
func goal_contains(at: Vector3) -> bool: return _inside_pad(at, GOAL, Vector2(10.8, 9.8))
func goal_spawn(slot: int) -> Vector3: return GOAL + Vector3(float(clampi(slot, 0, 2) - 1) * 2.5, 3, 0)
func arena_contains(at: Vector3) -> bool: return at.is_finite() and absf(at.x) < 16.0 and at.z < 10.0 and at.z > -143.0 and at.y >= ELIMINATION_Y and at.y < 35.0
func wind_at(_at: Vector3) -> Vector3: return Vector3.ZERO


func route_points() -> Array[Vector3]:
	return [Vector3(0, 4, 0), Vector3(0, 4, -5), Vector3(0, 4, -15), CHECKPOINTS[1], Vector3(3.4, 4, -37.5), Vector3(3.4, 4, -48.5), CHECKPOINTS[2], Vector3(0, 4, -61), Vector3(0, 4, -65.4), Vector3(1.6, 4, -71), Vector3(-1.6, 4, -77), Vector3(0, 4, -83), CHECKPOINTS[3], Vector3(0, 4, -102.5), Vector3(0, 4, -112.5), Vector3(3.0, 4, -114), Vector3(3.0, 4, -121), GOAL]


func route_jumps() -> Array[int]: return [3, 8, 9, 10, 11, 12]
func required_route_supports() -> Array[String]: return ["balance_pitch", "balance_roll", "HopPodium0", "HopPodium1", "HopPodium2", "HopPodium3"]


func _inside_pad(at: Vector3, center: Vector3, size: Vector2) -> bool:
	return at.is_finite() and absf(at.x - center.x) < size.x * 0.5 and absf(at.z - center.z) < size.y * 0.5 and at.y > center.y + 0.45 and at.y < center.y + 3.5


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not authoritative: return
	_elapsed = fmod(_elapsed + clampf(delta, 0.0, 0.1), 10000.0)
	for id: String in movers:
		var spec: Dictionary = mover_specs[id]
		(movers[id] as AnimatableBody3D).rotation.y = wrapf(float(spec.phase) + _elapsed * float(spec.speed), -PI, PI)


func reset_props() -> void:
	super.reset_props()
	_elapsed = 0.0
	for id: String in movers:
		(movers[id] as AnimatableBody3D).rotation.y = float(mover_specs[id].phase)
		(movers[id] as AnimatableBody3D).reset_physics_interpolation()


func capture_movers() -> Dictionary:
	var result: Dictionary = {}
	for id: String in movers: result[id] = (movers[id] as AnimatableBody3D).global_transform
	return result


func apply_presented_movers(data: Dictionary) -> void:
	if authoritative: return
	for id: String in movers:
		var pose: Variant = data.get(id)
		if not pose is Transform3D or not pose.origin.is_finite() or not pose.basis.is_finite(): continue
		# Fixed-center rotation only: a malformed packet cannot move a sweeper across the course.
		if pose.origin.distance_to(mover_specs[id].center) > 0.05 or not pose.basis.is_equal_approx(pose.basis.orthonormalized()) or pose.basis.determinant() < 0.95: continue
		(movers[id] as AnimatableBody3D).global_transform = pose


func _deck(id: String, top: Vector3, size: Vector2, color: Color) -> void:
	var body := _static_box(id, top - Vector3.UP * 0.6, Vector3(size.x, 1.2, size.y), color)
	_box_visual(body, Vector3(size.x - 0.3, 0.035, size.y - 0.3), Vector3(0, 0.61, 0), color.lightened(0.16))
	for side: float in [-1.0, 1.0]:
		_box_visual(body, Vector3(0.12, 0.04, size.y - 0.5), Vector3(side * (size.x * 0.5 - 0.25), 0.64, 0), CREAM)


func _balance_beam(id: String, at: Vector3, size: Vector3, sideways: bool) -> void:
	var pivot := _static_box(id + "Pivot", at - Vector3.UP * 0.9, Vector3(1.0, 1.0, 1.0), PAD_BLUE)
	var board := _prop_box(id, at, size, 24.0, PAD_YELLOW)
	board.angular_damp = 2.4
	board.linear_damp = 0.4
	if not authoritative: return
	var hinge := HingeJoint3D.new()
	hinge.name = id + "Hinge"
	add_child(hinge)
	hinge.position = at
	hinge.rotation.y = 0.0 if sideways else PI * 0.5
	hinge.node_a = hinge.get_path_to(pivot)
	hinge.node_b = hinge.get_path_to(board)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	var limit: float = 14.0 if sideways else 8.0
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-limit))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(limit))


func _sweeper(id: String, at: Vector3, length: float, speed: float, phase: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = id
	body.position = at
	body.rotation.y = phase
	body.collision_layer = 1 if authoritative else 0
	body.collision_mask = 1 if authoritative else 0
	body.sync_to_physics = authoritative
	add_child(body)
	_add_box_collision(body, Vector3(length, 0.8, 0.8))
	_box_visual(body, Vector3(length, 0.8, 0.8), Vector3.ZERO, PAD_BLUE)
	for side: float in [-1.0, 1.0]:
		var pad := _cylinder_visual(body, 0.52, length * 0.45, Vector3(side * length * 0.255, 0, 0), PAD_PINK)
		pad.rotation.z = PI * 0.5
		_box_visual(body, Vector3(0.18, 0.94, 0.94), Vector3(side * length * 0.38, 0, 0), CREAM)
	_pad(id + "Hub", at - Vector3.UP * 0.18, 0.62, 1.18, PAD_YELLOW)
	movers[id] = body
	mover_specs[id] = {"center": at, "speed": speed, "phase": phase, "length": length}
