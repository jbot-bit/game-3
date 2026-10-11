extends RefCounted
## Host-authoritative padded-stick contact; the visible staff never owns physics.
const COOLDOWN: float = 0.65
const SWING_SECONDS: float = 0.42
const HIT_START: float = 0.10
const HIT_END: float = 0.25
const REACH: float = 3.0
const PUSH_SPEED: float = 9.0
const STAFF_HALF_LENGTH: float = 1.55
const CONTACT_RADIUS: float = 0.9 # Foam radius plus torso/shoulder envelope.
var fighters: Dictionary = {}

func reset() -> void:
	fighters.clear()

func tick(actors: Dictionary, controls: Dictionary, eligible: Array, delta: float) -> void:
	for id: String in fighters.keys():
		if not actors.has(id): fighters.erase(id)
	for id: String in actors:
		if not fighters.has(id): fighters[id] = {"cooldown": 0.0, "elapsed": -1.0, "hit": [], "yaw": 0.0, "brace": false}
		var state: Dictionary = fighters[id]
		var input: Dictionary = controls.get(id, {}) if id in eligible else {}
		var yaw: float = float(input.get("yaw", state.yaw))
		state.yaw = wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0
		state.cooldown = maxf(0.0, state.cooldown - delta)
		state.brace = bool(input.get("brace", false)) and state.elapsed < 0.0
		if id not in eligible: state.elapsed = -1.0
		elif state.elapsed >= 0.0:
			state.elapsed += delta
			if state.elapsed > SWING_SECONDS: state.elapsed = -1.0
		elif bool(input.get("attack", false)) and not state.brace and state.cooldown <= 0.0:
			state.elapsed = 0.0
			state.cooldown = COOLDOWN
			state.hit = []
	# Resolve after all brace inputs, so dictionary order cannot alter defence.
	for id: String in eligible:
		if not actors.has(id): continue
		var state: Dictionary = fighters[id]
		if state.elapsed < HIT_START or state.elapsed > HIT_END: continue
		for target_id: String in eligible:
			if target_id == id or target_id in state.hit or not actors.has(target_id): continue
			var source: Node3D = actors[id]
			var target: Node3D = actors[target_id]
			if not contact_possible(source, target, state.yaw, state.elapsed): continue
			var direction: Vector3 = target.body_position() - source.body_position()
			direction.y = 0.0
			if direction.length_squared() < 0.01: direction = Basis(Vector3.UP, state.yaw) * Vector3.FORWARD
			direction = direction.normalized()
			var defense: Dictionary = fighters[target_id]
			var facing: Vector3 = Basis(Vector3.UP, defense.yaw) * Vector3.FORWARD
			var braced: bool = defense.brace and facing.dot(-direction) > 0.25 and target.is_on_floor
			var strength: float = PUSH_SPEED * (0.3 if braced else 1.0)
			target.apply_combat_impact(direction * strength + Vector3.UP * (0.2 if braced else 0.9), 0.12 if braced else 0.34)
			state.hit.append(target_id)
	for id: String in actors:
		var shown: Dictionary = visual_state(id)
		actors[id].set_combat_visual(true, shown.swing, shown.brace, shown.yaw)

func visual_state(id: String) -> Dictionary:
	var state: Dictionary = fighters.get(id, {})
	var elapsed: float = float(state.get("elapsed", -1.0))
	return {"swing": clampf(elapsed / SWING_SECONDS, 0.001, 1.0) if elapsed >= 0.0 else 0.0,
		"brace": bool(state.get("brace", false)), "yaw": float(state.get("yaw", 0.0))}

static func contact_possible(source: Node3D, target: Node3D, yaw: float, elapsed: float = 0.18) -> bool:
	var from: Vector3 = source.body_position()
	var to: Vector3 = target.body_position()
	if not from.is_finite() or not to.is_finite() or absf(from.y - to.y) > 1.5: return false
	var difference: Vector3 = (to - from) * Vector3(1, 0, 1)
	if difference.length() > REACH: return false
	var forward: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	if difference.length() > 0.1 and forward.dot(difference.normalized()) < 0.35: return false
	# Sweep the same padded shaft shown by the puppet. Three samples cover a
	# physics step without allowing a distant opponent anywhere in the arc.
	var touched: bool = false
	var center: Vector3 = from + Vector3.UP * 0.28 + forward * 0.75
	for offset: float in [-1.0 / 60.0, -0.5 / 60.0, 0.0]:
		var progress: float = clampf((elapsed + offset) / SWING_SECONDS, 0.0, 1.0)
		var sweep: float = sin(progress * TAU - 0.4) * 1.05
		var axis: Vector3 = Basis(Vector3.UP, yaw + sweep) * Vector3.RIGHT
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(to + Vector3.UP * 0.2, center - axis * STAFF_HALF_LENGTH, center + axis * STAFF_HALF_LENGTH)
		if closest.distance_to(to + Vector3.UP * 0.2) <= CONTACT_RADIUS:
			touched = true
			break
	if not touched: return false
	var exclusions: Array[RID] = []
	for actor: Node3D in [source, target]:
		for bone: PhysicalBone3D in actor.physics_bones: exclusions.append(bone.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.2, to + Vector3.UP * 0.2, 0xFFFFFFFF, exclusions)
	query.collide_with_areas = false
	return source.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func build_staff(parent: Node3D) -> Node3D:
	var stick := Node3D.new()
	stick.name = "PaddedStick"
	parent.add_child(stick)
	_part(stick, "SoftShaft", 0.065, 2.7, 0.0, Color("e9e3cf"))
	for side: float in [-1.0, 1.0]:
		_part(stick, "FoamEnd" + str(side), 0.26, 0.9, side * 1.2, Color("e66a82") if side < 0 else Color("59cacc"))
		_part(stick, "Grip" + str(side), 0.095, 0.3, side * 0.32, Color("263f54"))
	return stick

static func _part(parent: Node3D, label: String, radius: float, length: float, x: float, color: Color) -> void:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = length
	shape.radial_segments = 12
	shape.rings = 4
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = shape
	mesh.rotation.z = PI / 2.0
	mesh.position.x = x
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	parent.add_child(mesh)
