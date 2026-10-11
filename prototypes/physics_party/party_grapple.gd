extends Node3D
## A unilateral rope: it can pull, never push. Only the host changes body velocity.
const RANGE: float = 28.0
const MIN_LENGTH: float = 1.8
const REEL_SPEED: float = 12.0
var active: bool = false
var mode: String = "pull"
var anchor: Vector3 = Vector3.ZERO
var rope_length: float = 0.0
var _held: bool = false
var _target: StaticBody3D
var _rope: MeshInstance3D
var _hook: MeshInstance3D
var _material: StandardMaterial3D
var actor: Node3D

func _ready() -> void:
	actor = get_parent()
	process_priority = -9
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.035
	cylinder.bottom_radius = 0.035
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	_rope.mesh = cylinder
	_rope.material_override = _material
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	_hook = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	ball.radial_segments = 12
	ball.rings = 6
	_hook.mesh = ball
	_hook.material_override = _material
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hook)
	_rope.hide()
	_hook.hide()

func target_at(aim: Vector3) -> Dictionary:
	if not aim.is_finite() or not is_instance_valid(actor): return {}
	var origin: Vector3 = actor.body_position()
	var direction: Vector3 = aim - origin
	if direction.length() < MIN_LENGTH: return {}
	var ray = PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * minf(RANGE, direction.length() + 0.2))
	var exclusions: Array[RID] = []
	for bone in actor.physics_bones: exclusions.append(bone.get_rid())
	ray.exclude = exclusions
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	# Movable props/teammates block the shot, but cannot become fixed world anchors.
	if hit.is_empty() or not hit.collider is StaticBody3D: return {}
	if origin.distance_to(hit.position) < MIN_LENGTH: return {}
	return hit

func tick(delta: float, controls: Dictionary) -> void:
	if not actor.authoritative: return
	var wanted: bool = bool(controls.get("grapple", false)) and not bool(controls.get("limp", false))
	var requested: String = str(controls.get("grapple_mode", "pull"))
	if requested not in ["pull", "swing"]: requested = "pull"
	if requested != mode:
		mode = requested
		if active: rope_length = maxf(MIN_LENGTH, actor.body_position().distance_to(anchor))
	if not wanted:
		cancel()
		return
	if not _held:
		var aim: Variant = controls.get("aim", Vector3.ZERO)
		var hit: Dictionary = target_at(aim) if aim is Vector3 else {}
		if not hit.is_empty():
			_target = hit.collider
			anchor = hit.position
			rope_length = actor.body_position().distance_to(anchor)
			active = true
	_held = true
	if not active: return
	if not is_instance_valid(_target):
		active = false
		return
	var offset: Vector3 = actor.body_position() - anchor
	var distance: float = offset.length()
	if not is_finite(distance) or distance > RANGE + 5.0:
		active = false
		return
	if distance < 0.01: return
	var outward: Vector3 = offset / distance
	var velocity: Vector3 = actor.physical_bone_body.linear_velocity
	var radial: float = velocity.dot(outward)
	var change: float = 0.0
	if mode == "pull":
		rope_length = maxf(MIN_LENGTH, rope_length - REEL_SPEED * delta)
		var desired: float = -minf(REEL_SPEED, maxf(0.0, distance - MIN_LENGTH) * 6.0)
		change = clampf(desired - radial, -45.0 * delta, 45.0 * delta)
	elif distance >= rope_length - 0.08:
		# Remove outward motion and correct solver drift without damping the arc.
		var desired: float = -minf(16.0, maxf(0.0, distance - rope_length) * 18.0)
		change = minf(0.0, desired - radial)
	# Move the entire ragdoll together, rather than stretching one shoulder joint.
	for bone in actor.physics_bones:
		bone.linear_velocity += outward * change

func cancel() -> void:
	active = false
	_held = false
	_target = null
	rope_length = 0.0

func capture() -> Dictionary:
	return {"active": active, "mode": mode, "anchor": anchor, "length": rope_length}

func present(data: Dictionary) -> void:
	if actor.authoritative: return
	if not data.get("active", false):
		cancel()
		return
	if data.get("mode") not in ["pull", "swing"] or not data.get("anchor") is Vector3: return
	if not data.anchor.is_finite(): return
	active = true
	mode = data.mode
	anchor = data.anchor
	rope_length = float(data.get("length", 0.0))

func _process(_delta: float) -> void:
	_rope.visible = active and actor.visible
	_hook.visible = _rope.visible
	if not _rope.visible: return
	_material.albedo_color = Color("f08b72") if mode == "pull" else Color("a9e4c7")
	var start: Vector3 = actor.visual_position() + Vector3.UP * 0.2
	var direction: Vector3 = anchor - start
	var distance: float = direction.length()
	if distance < 0.001: return
	# Stretch the cylinder along its own Y axis before rotating it onto the rope.
	var rope_basis: Basis = Basis(Quaternion(Vector3.UP, direction / distance)) * Basis.from_scale(Vector3(1, distance, 1))
	_rope.global_transform = Transform3D(rope_basis, (start + anchor) * 0.5)
	_hook.global_position = anchor
