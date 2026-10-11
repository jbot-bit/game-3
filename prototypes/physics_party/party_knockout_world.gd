extends "res://prototypes/physics_party/party_arena_world.gd"
## One shared pad, two readable physical sweepers, and no rescue platforms.
## Only the host advances collision. Clients display the shared pose timeline.

const PAD_RADIUS := 9.0
const HUB_RADIUS := 1.15
const ROUND_DURATION := 90.0
const MIN_PAD_RADIUS := 6.0
const SHRINK_START := 30.0
const SHRINK_END := 60.0
const SPEED_LEVELS: Array[float] = [1.0, 1.3, 1.7, 2.1, 2.5]
const SPEED_BLEND_SECONDS := 2.0
const RING_TEAL := Color("257f87")
const FOAM_ORANGE := Color("f0a33c")
const FOAM_RED := Color("d85b65")
var movers: Dictionary = {}
var mover_specs: Dictionary = {}
var _round_phase: String = "practice"
var _round_number: int = 0
var _round_elapsed: float = 0.0
var _rotation_elapsed: float = 0.0
var _current_radius: float = PAD_RADIUS
var _pad_body: StaticBody3D
var _pad_shape: CylinderShape3D
var _pad_visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	if _built: return
	_built = true
	_build_lighting()
	var pad := _pad("KnockoutPad", Vector3(0, 3.3, 0), PAD_RADIUS, 1.4, RING_TEAL)
	# Its cap also clears a full jump from the high arm: no stepped route to safe pivot camping.
	var hub := _pad("CenterHub", Vector3(0, 7.2, 0), HUB_RADIUS, 6.4, NAVY)
	_cylinder_visual(hub, HUB_RADIUS + 0.04, 0.25, Vector3(0, 3.05, 0), FOAM_ORANGE)
	_cylinder_visual(hub, HUB_RADIUS + 0.04, 0.17, Vector3(0, -2.62, 0), CREAM)
	_sweeper("SweepLow", Vector3(0, 4.62, 0), 17.6, 0.62, FOAM_ORANGE)
	_sweeper("SweepHigh", Vector3(0, 6.10, 0), 9.6, -0.43, FOAM_RED)
	# A dotted outer safety stripe makes the real circular drop legible.
	for index in 48:
		var angle: float = TAU * float(index) / 48.0
		var stripe := _box_visual(pad, Vector3(0.20, 0.045, 0.50), Vector3(cos(angle) * 8.5, 0.727, sin(angle) * 8.5), CREAM)
		stripe.rotation.y = -angle
	for slot in 3:
		var at: Vector3 = spawn_point(slot) - Vector3.UP * 2.96
		_cylinder_visual(self, 0.77, 0.025, at, [FOAM_ORANGE, MINT, FOAM_RED][slot])
		_label(str(slot + 1), at + Vector3.UP * 0.025, 40, NAVY, true)
	_label("KNOCKOUT", Vector3(0, 4.075, 3.2), 62, CREAM, true)
	_label("JUMP  /  SWING  /  STAY ON", Vector3(0, 4.075, -3.3), 25, CREAM, true)
	# Lower concentric bands give the platform a padded gameshow silhouette.
	_cylinder_visual(pad, PAD_RADIUS + 0.10, 0.30, Vector3(0, -0.46, 0), NAVY)
	_cylinder_visual(pad, PAD_RADIUS + 0.045, 0.12, Vector3(0, -0.18, 0), FOAM_ORANGE)
	preload("res://prototypes/physics_party/party_mesh_batch.gd").merge_tree(self)
	_pad_body = pad
	_pad_shape = (pad.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape
	for visual: Node in pad.get_children():
		if visual is MeshInstance3D: _pad_visuals.append(visual)
	_set_pad_radius(_current_radius)

func spawn_point(slot: int, _checkpoint: int = 0) -> Vector3:
	var angle: float = TAU * float(clampi(slot, 0, 2)) / 3.0 + PI * 0.5
	return Vector3(cos(angle) * 5.4, PLATFORM_TOP + 3.0, sin(angle) * 5.4)

func arena_contains(at: Vector3) -> bool:
	return at.is_finite() and Vector2(at.x, at.z).length() <= _current_radius + 4.0 and at.y >= ELIMINATION_Y and at.y < 35.0

func set_round_phase(phase: String, round_number: int) -> void:
	if phase not in ["practice", "countdown", "fight", "intermission", "complete"]: return
	var next_round: int = clampi(round_number, 0, 9999)
	var restart: bool = next_round != _round_number or (phase == "countdown" and _round_phase != "countdown")
	_round_phase = phase
	_round_number = next_round
	if restart and authoritative: reset_props()

func hazard_speed_scale() -> float:
	var stage: int = clampi(int(floor(_round_elapsed / 15.0)), 0, SPEED_LEVELS.size() - 1)
	if stage == 0: return SPEED_LEVELS[0]
	var blend: float = clampf((_round_elapsed - float(stage) * 15.0) / SPEED_BLEND_SECONDS, 0.0, 1.0)
	return lerpf(SPEED_LEVELS[stage - 1], SPEED_LEVELS[stage], blend)

func arena_radius() -> float:
	return _current_radius

func hazard_status_text() -> String:
	if _round_phase != "fight": return ""
	if _round_elapsed >= 25.0 and _round_elapsed < SHRINK_START:
		return "ARENA SHRINKS IN %ds" % ceili(SHRINK_START - _round_elapsed)
	for warning_at: float in [15.0, 45.0, 60.0]:
		if _round_elapsed >= warning_at - 3.0 and _round_elapsed < warning_at:
			var prefix: String = "ARENA SHRINKING / " if _round_elapsed >= SHRINK_START else ""
			return prefix + "FASTER SWEEPERS IN %ds" % ceili(warning_at - _round_elapsed)
	if _round_elapsed >= SHRINK_END: return "FINAL SPEED"
	if _round_elapsed >= SHRINK_START: return "ARENA SHRINKING"
	if _round_elapsed >= 15.0: return "SWEEPERS FASTER"
	return "ROUND START"

func _set_pad_radius(radius: float) -> void:
	_current_radius = clampf(radius, MIN_PAD_RADIUS, PAD_RADIUS)
	if not is_instance_valid(_pad_body): return
	# Keep the body and collider transform unscaled: only its cylinder radius
	# changes. Visual siblings (including edge stripes) shrink exactly once.
	_pad_shape.radius = _current_radius
	var floor_scale: float = _current_radius / PAD_RADIUS
	for visual: MeshInstance3D in _pad_visuals:
		visual.scale = Vector3(floor_scale, 1.0, floor_scale)

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	super._physics_process(delta)
	if not authoritative or _round_phase not in ["practice", "fight"]: return
	var step: float = minf(delta, 0.1)
	if _round_phase == "fight":
		_round_elapsed = minf(ROUND_DURATION, _round_elapsed + step)
		_set_pad_radius(lerpf(PAD_RADIUS, MIN_PAD_RADIUS, clampf((_round_elapsed - SHRINK_START) / (SHRINK_END - SHRINK_START), 0.0, 1.0)))
	_rotation_elapsed += step * hazard_speed_scale()
	for id: String in movers:
		var spec: Dictionary = mover_specs[id]
		(movers[id] as AnimatableBody3D).rotation.y = wrapf(float(spec.phase) + _rotation_elapsed * float(spec.speed), -PI, PI)

func reset_props() -> void:
	super.reset_props()
	_round_elapsed = 0.0
	_rotation_elapsed = 0.0
	_set_pad_radius(PAD_RADIUS)
	for id: String in movers:
		var body: AnimatableBody3D = movers[id]
		body.transform = Transform3D(Basis(Vector3.UP, float(mover_specs[id].phase)), mover_specs[id].center)
		body.reset_physics_interpolation()

func capture_movers() -> Dictionary:
	var result: Dictionary = {}
	for id: String in movers: result[id] = (movers[id] as AnimatableBody3D).global_transform
	var floor_scale: float = _current_radius / PAD_RADIUS
	result.ArenaFloor = Transform3D(Basis.IDENTITY.scaled(Vector3(floor_scale, 1.0, floor_scale)), to_global(Vector3(0, 3.3, 0)))
	return result

func apply_presented_movers(data: Dictionary) -> void:
	if authoritative: return
	for id: String in movers:
		var pose: Variant = data.get(id)
		if not pose is Transform3D or not pose.origin.is_finite() or not pose.basis.is_finite(): continue
		# Only rigid yaw rotations about the known hub are part of this protocol.
		# Orthonormal alone permits illegal pitch, roll and mirrored arms.
		var expected_center: Vector3 = to_global(mover_specs[id].center)
		if pose.origin.distance_to(expected_center) > 0.001: continue
		if not pose.basis.is_equal_approx(pose.basis.orthonormalized()) or pose.basis.determinant() < 0.999: continue
		if not pose.basis.y.is_equal_approx(Vector3.UP): continue
		(movers[id] as AnimatableBody3D).global_transform = pose
	_apply_presented_floor(data.get("ArenaFloor"))

func _apply_presented_floor(pose: Variant) -> void:
	if not pose is Transform3D or not pose.origin.is_finite() or not pose.basis.is_finite(): return
	if pose.origin.distance_to(to_global(Vector3(0, 3.3, 0))) > 0.001: return
	var floor_scale: float = pose.basis.x.x
	if floor_scale < MIN_PAD_RADIUS / PAD_RADIUS - 0.00001 or floor_scale > 1.00001: return
	var expected := Basis.IDENTITY.scaled(Vector3(floor_scale, 1.0, floor_scale))
	if not pose.basis.is_equal_approx(expected): return
	_set_pad_radius(floor_scale * PAD_RADIUS)

func _sweeper(id: String, at: Vector3, length: float, speed: float, color: Color) -> void:
	var body := AnimatableBody3D.new()
	body.name = id
	body.position = at
	body.collision_layer = 1 if authoritative else 0
	body.collision_mask = 1 if authoritative else 0
	body.sync_to_physics = authoritative
	add_child(body)
	_add_box_collision(body, Vector3(length, 0.8, 0.8))
	_box_visual(body, Vector3(length, 0.8, 0.8), Vector3.ZERO, color)
	for side: float in [-1.0, 1.0]:
		var padding := _cylinder_visual(body, 0.49, length * 0.40, Vector3(side * length * 0.28, 0, 0), color)
		padding.rotation.z = PI * 0.5
		for band: float in [0.19, 0.43]:
			_box_visual(body, Vector3(0.17, 0.94, 0.94), Vector3(side * length * band, 0, 0), CREAM)
	movers[id] = body
	mover_specs[id] = {"center": at, "speed": speed, "phase": 0.0, "length": length}
