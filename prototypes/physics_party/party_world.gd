class_name PartyWorld
extends Node3D
## A small toy obstacle course. The host owns the seven movable props.

const CREAM := Color("f4e4be")
const MINT := Color("73c7b0")
const CORAL := Color("ec765e")
const NAVY := Color("233e52")
const SKY := Color("b7d9dd")
const GOLD := Color("f0ba4b")
const PROP_INTERPOLATION_SECONDS := 0.05
const WIND_ACCELERATION := 1.3

var authoritative: bool = true
var props: Dictionary = {}
var switch_position := Vector3(-5.0, 1.0, -19.0)
var wind_direction: int = 1

var _built: bool = false
var _prop_ids: Array[String] = []
var _initial_prop_poses: Dictionary = {}
var _remote_prop_poses: Dictionary = {}
var _uses_remote_timeline: bool = false
var _materials: Dictionary = {}
var _wind_arrow: Node3D
var _fan_rotor: Node3D
var _switch_handle: Node3D
var _wind_label: Label3D
var _contact_sources: Dictionary = {}
var _contact_marks: Dictionary = {}
var _contact_exclusions: Array[RID] = []
var _contact_clock: float = 0.0
var _contact_material: StandardMaterial3D


func setup(is_authoritative: bool) -> void:
	authoritative = is_authoritative
	for body: RigidBody3D in props.values():
		body.freeze = not authoritative


func _ready() -> void:
	if _built:
		return
	_built = true
	_build_lighting()
	_build_platforms()
	_build_props()
	_build_seesaw()
	_build_switch_and_fan()
	_build_finish()
	_build_signs()
	for id: String in ["block_1", "block_2", "block_3", "block_4"]:
		_add_contact("prop:" + id, props[id], 1.15)
	_prop_ids.sort()
	set_wind(wind_direction)


func spawn_point(slot: int, checkpoint: int = 0) -> Vector3:
	var offset: float = float(clampi(slot, 0, 2) - 1) * 3.0
	if checkpoint >= 2:
		return Vector3(offset, 5.0, -33.0)
	if checkpoint == 1:
		return Vector3(offset, 3.0, -16.0)
	return Vector3(offset, 3.0, 3.5)


func checkpoint_contains(at: Vector3) -> bool:
	return absf(at.x) < 7.0 and at.z < -14.0 and at.z > -24.5 and at.y > 0.2 and at.y < 8.0


func goal_contains(at: Vector3) -> bool:
	return absf(at.x) < 6.8 and at.z < -30.0 and at.z > -39.0 and at.y >= 2.0 and at.y < 10.0


func set_wind(direction: int) -> void:
	wind_direction = 1 if direction >= 0 else -1
	if is_instance_valid(_wind_arrow):
		_wind_arrow.rotation.y = 0.0 if wind_direction > 0 else PI
	if is_instance_valid(_switch_handle):
		_switch_handle.rotation.z = -0.48 * float(wind_direction)
	if is_instance_valid(_wind_label):
		_wind_label.text = "WIND  >" if wind_direction > 0 else "<  WIND"


func wind_at(at: Vector3) -> Vector3:
	# Acceleration; callers apply force = acceleration * body.mass.
	if absf(at.x) < 10.0 and at.z < -20.0 and at.z > -30.0 and at.y > -1.0 and at.y < 9.0:
		return Vector3(float(wind_direction) * WIND_ACCELERATION, 0.0, 0.0)
	return Vector3.ZERO


func reset_props() -> void:
	_remote_prop_poses.clear()
	_uses_remote_timeline = false
	for id: String in _prop_ids:
		_reset_prop(id)
	set_wind(1)


func capture_prop_poses() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _prop_ids:
		result[id] = (props[id] as RigidBody3D).global_transform
	return result


func apply_prop_poses(poses: Dictionary) -> void:
	if authoritative:
		return
	for id: String in _prop_ids:
		if not poses.has(id) or not poses[id] is Transform3D:
			continue
		var target: Transform3D = poses[id]
		if not target.origin.is_finite() or not target.basis.is_finite():
			continue
		_remote_prop_poses[id] = target
		var body: RigidBody3D = props[id]
		if body.global_position.distance_squared_to(target.origin) > 144.0:
			body.global_transform = target
			body.reset_physics_interpolation()


func present_prop_poses(poses: Dictionary) -> void:
	# A shared network timeline has already interpolated these transforms.
	if authoritative:
		return
	for id: String in _prop_ids:
		if not poses.has(id) or not poses[id] is Transform3D:
			continue
		var pose: Transform3D = poses[id]
		if not pose.origin.is_finite() or not pose.basis.is_finite():
			continue
		(props[id] as RigidBody3D).global_transform = pose
		_uses_remote_timeline = true


func _process(delta: float) -> void:
	_follow_contacts()
	if is_instance_valid(_fan_rotor):
		_fan_rotor.rotate_x(delta * 5.0 * float(wind_direction))
	if authoritative or _uses_remote_timeline:
		return
	var blend: float = 1.0 - exp(-delta / PROP_INTERPOLATION_SECONDS)
	for id: String in _prop_ids:
		if _remote_prop_poses.has(id):
			var body: RigidBody3D = props[id]
			body.global_transform = body.global_transform.interpolate_with(_remote_prop_poses[id], blend)


func _physics_process(delta: float) -> void:
	_contact_clock += delta
	if _contact_clock >= 0.1:
		_contact_clock = 0.0
		_sample_contacts()
	if not authoritative:
		return
	for id: String in _prop_ids:
		var body: RigidBody3D = props[id]
		if not body.global_position.is_finite() or body.global_position.y < -14.0:
			_reset_prop(id)
			continue
		body.linear_velocity = body.linear_velocity.limit_length(30.0)
		body.angular_velocity = body.angular_velocity.limit_length(10.0)
		if id != "seesaw":
			var wind: Vector3 = wind_at(body.global_position)
			if not wind.is_zero_approx():
				body.apply_central_force(wind * body.mass)


func _reset_prop(id: String) -> void:
	var body: RigidBody3D = props[id]
	# A falling long prop can cross the recovery plane before its carrier.
	# Detach only grips on this body before changing its transform.
	if authoritative:
		for key: String in _contact_sources:
			if not key.begins_with("crew:"):
				continue
			var actor: Node3D = _contact_sources[key].get_ref()
			if is_instance_valid(actor):
				actor.release_grabs_to(body)
	body.global_transform = _initial_prop_poses[id]
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	body.reset_physics_interpolation()


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce8ed")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ToySky"
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SoftSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff7e9")
	sun.light_energy = 0.70
	sun.shadow_enabled = false
	add_child(sun)


func _build_platforms() -> void:
	# A ready bridge teaches walking on real moving props before precise grabs.
	_static_box("Start", Vector3(0.0, -0.5, -0.5), Vector3(16.0, 1.0, 14.0), CREAM)
	_static_box("Middle", Vector3(0.0, -0.5, -19.0), Vector3(16.0, 1.0, 12.0), MINT)
	_static_box("Finish", Vector3(0.0, 1.5, -34.0), Vector3(16.0, 1.0, 10.0), CREAM)
	_box_visual(self, Vector3(15.7, 0.5, 13.7), Vector3(0.0, -1.2, -0.5), CORAL)
	_box_visual(self, Vector3(15.7, 0.5, 11.7), Vector3(0.0, -1.2, -19.0), NAVY)
	_box_visual(self, Vector3(15.7, 0.5, 9.7), Vector3(0.0, 0.8, -34.0), CORAL)
	_static_box("SeesawStep", Vector3(0.0, 0.25, -18.0), Vector3(3.4, 0.5, 1.4), GOLD)
	# The central landing catches a mistimed seesaw exit; it is not a side bypass.
	_static_box("SteppingStone", Vector3(0.0, 0.0, -28.5), Vector3(6.4, 1.8, 3.0), CORAL)


func _build_props() -> void:
	# Two independent bridges give friends room to cross or steady a plank.
	for side: float in [-4.5, 4.5]:
		_static_box("PlankRestFront" + str(side), Vector3(side, 0.125, -14.4), Vector3(2.5, 0.25, 0.8), NAVY)
		_static_box("PlankRestBack" + str(side), Vector3(side, 0.125, -6.1), Vector3(2.5, 0.25, 0.8), NAVY)
	var left_plank := _prop_box("plank_left", Vector3(-4.5, 0.45, -10.25), Vector3(2.0, 0.35, 11.0), 1.0, MINT)
	var right_plank := _prop_box("plank_right", Vector3(4.5, 0.45, -10.25), Vector3(2.0, 0.35, 11.0), 1.0, CORAL)
	# These now start as bridges: grip the rests during a running crossing,
	# while the light, unconstrained bodies remain movable by either hand.
	left_plank.physics_material_override.friction = 0.55
	right_plank.physics_material_override.friction = 0.55
	_prop_box("block_1", Vector3(-1.8, 0.8, -3.4), Vector3.ONE * 1.5, 1.4, GOLD)
	_prop_box("block_2", Vector3(1.8, 0.8, -3.4), Vector3.ONE * 1.5, 1.4, CORAL)
	_prop_box("block_3", Vector3(-4.8, 0.8, -22.5), Vector3.ONE * 1.5, 1.4, CREAM)
	_prop_box("block_4", Vector3(-5.0, 0.8, -15.3), Vector3.ONE * 1.5, 1.4, GOLD)


func _build_seesaw() -> void:
	var pivot := _static_box("SeesawPivot", Vector3(0.0, 0.55, -23.0), Vector3(2.1, 1.1, 0.9), NAVY)
	var board := _prop_box("seesaw", Vector3(0.0, 1.2, -23.0), Vector3(4.4, 0.35, 9.0), 4.5, CORAL)
	board.angular_damp = 0.9
	if not authoritative:
		return
	var hinge := HingeJoint3D.new()
	hinge.name = "SeesawHinge"
	add_child(hinge)
	hinge.position = Vector3(0.0, 1.2, -23.0)
	# Hinge local Z is the pivot axis; rotate it onto the board's width.
	hinge.rotation.y = PI * 0.5
	hinge.node_a = hinge.get_path_to(pivot)
	hinge.node_b = hinge.get_path_to(board)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-13.0))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(13.0))


func _build_switch_and_fan() -> void:
	_static_box("WindSwitchBase", switch_position + Vector3(0.0, -0.5, 0.0), Vector3(1.3, 1.0, 1.3), NAVY)
	_switch_handle = Node3D.new()
	_switch_handle.name = "RedLever"
	_switch_handle.position = switch_position
	add_child(_switch_handle)
	_box_visual(_switch_handle, Vector3(0.18, 1.2, 0.18), Vector3(0.0, 0.6, 0.0), CREAM)
	_box_visual(_switch_handle, Vector3(0.55, 0.45, 0.55), Vector3(0.0, 1.2, 0.0), CORAL)
	_wind_label = _label("WIND  >", switch_position + Vector3(0.0, 2.6, 0.0), 42, NAVY)
	_static_box("FanStand", Vector3(-9.6, 1.3, -25.0), Vector3(1.0, 3.0, 1.0), NAVY)
	_box_visual(self, Vector3(1.0, 3.6, 3.6), Vector3(-9.6, 3.1, -25.0), CREAM)
	_fan_rotor = Node3D.new()
	_fan_rotor.name = "FanBlades"
	_fan_rotor.position = Vector3(-8.96, 3.1, -25.0)
	add_child(_fan_rotor)
	_box_visual(_fan_rotor, Vector3(0.12, 2.8, 0.4), Vector3.ZERO, CORAL)
	_box_visual(_fan_rotor, Vector3(0.12, 0.4, 2.8), Vector3.ZERO, CORAL)
	_wind_arrow = Node3D.new()
	_wind_arrow.name = "WindDirection"
	_wind_arrow.position = Vector3(-4.0, 0.05, -24.0)
	add_child(_wind_arrow)
	_box_visual(_wind_arrow, Vector3(2.2, 0.04, 0.22), Vector3.ZERO, NAVY)
	var first := _box_visual(_wind_arrow, Vector3(0.8, 0.04, 0.22), Vector3(0.85, 0.0, -0.23), NAVY)
	first.rotation.y = -PI * 0.25
	var second := _box_visual(_wind_arrow, Vector3(0.8, 0.04, 0.22), Vector3(0.85, 0.0, 0.23), NAVY)
	second.rotation.y = PI * 0.25


func _build_finish() -> void:
	_static_box("FinishLeft", Vector3(-3.4, 4.0, -36.5), Vector3(0.7, 4.0, 0.7), MINT)
	_static_box("FinishRight", Vector3(3.4, 4.0, -36.5), Vector3(0.7, 4.0, 0.7), MINT)
	_box_visual(self, Vector3(7.5, 0.75, 0.7), Vector3(0.0, 6.0, -36.5), CORAL)
	_label("EVERYONE UP!", Vector3(0.0, 6.0, -36.08), 58, NAVY)


func _build_signs() -> void:
	# Floor stencils leave the camera and the physical play space unobstructed.
	_label("HANDS FULL", Vector3(0.0, 0.025, 5.4), 72, NAVY, true)
	_label("STEADY THE BRIDGE", Vector3(0.0, 0.025, -6.7), 32, NAVY, true)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 0.012, -7.2), NAVY)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 0.012, -13.3), NAVY)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 2.012, -29.3), NAVY)


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.84
		result.metallic_specular = 0.18
		_materials[color] = result
	return _materials[color]


func _box_visual(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = _beveled_box(size)
	visual.material_override = _material(color)
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual


func _beveled_box(size: Vector3) -> ArrayMesh:
	# Tiny authored chamfers catch the light; physics remains a simple box.
	var half := size * 0.5
	var radius: float = minf(0.055, minf(size.x, minf(size.y, size.z)) * 0.16)
	var inner := half - Vector3.ONE * radius
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for axis in 3:
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for sign_value: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * sign_value
				point[u] = inner[u] * corner.x
				point[v] = inner[v] * corner.y
				points.append(point)
			_mesh_quad(vertices, normals, points, normal)
	for edge_axis in 3:
		var u: int = (edge_axis + 1) % 3
		var v: int = (edge_axis + 2) % 3
		for sign_u: float in [-1.0, 1.0]:
			for sign_v: float in [-1.0, 1.0]:
				var a := Vector3.ZERO
				a[edge_axis] = -inner[edge_axis]
				a[u] = half[u] * sign_u
				a[v] = inner[v] * sign_v
				var b := a
				b[edge_axis] = inner[edge_axis]
				var c := b
				c[u] = inner[u] * sign_u
				c[v] = half[v] * sign_v
				var d := c
				d[edge_axis] = -inner[edge_axis]
				var normal := Vector3.ZERO
				normal[u] = sign_u
				normal[v] = sign_v
				_mesh_quad(vertices, normals, [a, b, c, d], normal.normalized())
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var signs := Vector3(x, y, z)
				var a := inner * signs
				var b := a
				var c := a
				a.x = half.x * x
				b.y = half.y * y
				c.z = half.z * z
				_mesh_triangle(vertices, normals, a, b, c, signs.normalized())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mesh_quad(vertices: PackedVector3Array, normals: PackedVector3Array, points: Array[Vector3], normal: Vector3) -> void:
	_mesh_triangle(vertices, normals, points[0], points[1], points[2], normal)
	_mesh_triangle(vertices, normals, points[0], points[2], points[3], normal)


func _mesh_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot front faces use clockwise winding.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	vertices.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))


func track_puppets(puppets: Array) -> void:
	for key: String in _contact_sources.keys():
		if key.begins_with("crew:"):
			_contact_marks[key].queue_free()
			_contact_marks.erase(key)
			_contact_sources.erase(key)
	_contact_exclusions.clear()
	for index in puppets.size():
		var actor: Node3D = puppets[index]
		_add_contact("crew:" + str(index), actor, 1.05)
		for bone: PhysicalBone3D in actor.physics_bones:
			_contact_exclusions.append(bone.get_rid())


func _add_contact(key: String, source: Node3D, radius: float) -> void:
	if _contact_material == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(0.10, 0.17, 0.19, 0.28), Color(0.10, 0.17, 0.19, 0.14), Color(0.10, 0.17, 0.19, 0.0)])
		var texture := GradientTexture2D.new()
		texture.width = 32
		texture.height = 32
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		_contact_material = StandardMaterial3D.new()
		_contact_material.albedo_texture = texture
		_contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_contact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contact_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_contact_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 1.6)
	mark.mesh = plane
	mark.material_override = _contact_material.duplicate()
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.visible = false
	add_child(mark)
	_contact_sources[key] = weakref(source)
	_contact_marks[key] = mark


func _contact_position(source: Node3D) -> Vector3:
	if source.has_method("visual_position"):
		return source.visual_position()
	return source.body_position() if source.has_method("body_position") else source.global_position


func _sample_contacts() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for key: String in _contact_sources:
		var source: Node3D = _contact_sources[key].get_ref()
		var mark: MeshInstance3D = _contact_marks[key]
		if not is_instance_valid(source):
			mark.hide()
			continue
		var at: Vector3 = _contact_position(source)
		var exclude: Array[RID] = _contact_exclusions.duplicate()
		if source is PhysicsBody3D:
			exclude.append(source.get_rid())
		var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 9.0, 1, exclude)
		var hit: Dictionary = space.intersect_ray(query)
		mark.visible = not hit.is_empty() and hit.normal.y > 0.55
		if mark.visible:
			mark.position.y = hit.position.y + 0.018
			# GeometryInstance transparency is ignored by Compatibility rendering.
			var fade: float = clampf((at.y - hit.position.y - 1.0) / 8.0, 0.0, 0.7)
			(mark.material_override as StandardMaterial3D).albedo_color.a = 1.0 - fade


func _follow_contacts() -> void:
	for key: String in _contact_sources:
		var source: Node3D = _contact_sources[key].get_ref()
		if not is_instance_valid(source):
			continue
		var at: Vector3 = _contact_position(source)
		var mark: MeshInstance3D = _contact_marks[key]
		mark.position.x = at.x
		mark.position.z = at.z


func _static_box(id: String, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("party_grabbable")
	add_child(body)
	_box_visual(body, size, Vector3.ZERO, color)
	_add_box_collision(body, size)
	return body


func _prop_box(id: String, at: Vector3, size: Vector3, mass: float, color: Color) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = id
	body.position = at
	body.mass = mass
	body.collision_layer = 1
	body.collision_mask = 1
	body.continuous_cd = true
	body.linear_damp = 0.18
	body.angular_damp = 0.7
	body.freeze = not authoritative
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.9
	physics_material.bounce = 0.04
	body.physics_material_override = physics_material
	body.add_to_group("party_grabbable")
	add_child(body)
	_box_visual(body, size, Vector3.ZERO, color)
	_add_box_collision(body, size)
	props[id] = body
	_prop_ids.append(id)
	_initial_prop_poses[id] = body.global_transform
	return body


func _add_box_collision(body: CollisionObject3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)


func _label(value: String, at: Vector3, font_size: int, color: Color, on_floor: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 0
	label.position = at
	label.no_depth_test = false
	label.shaded = false
	label.double_sided = true
	if on_floor:
		label.rotation.x = -PI * 0.5
	add_child(label)
	return label
