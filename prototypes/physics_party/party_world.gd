class_name PartyWorld
extends Node3D
## A suspended salvage-yard course. The host owns the seven movable props.

const CREAM := Color("eee8dc")
const MINT := Color("43d6cf")
const CORAL := Color("ff9c44")
const NAVY := Color("142536")
const SKY := Color("718ca4")
const GOLD := Color("f2c355")
const STEEL := Color("243d52")
const DECK := Color("536878")
const PETROL := Color("287e83")
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
var _background_cranes: Array[Node3D] = []


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
	_build_grapple_anchors()
	for id: String in ["block_1", "block_2", "block_3", "block_4"]:
		_add_contact("prop:" + id, props[id], 1.15)
	_prop_ids.sort()
	set_wind(wind_direction)
	preload("res://prototypes/physics_party/party_mesh_batch.gd").merge_tree(self)


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
	environment.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("253d5c")
	sky_material.sky_horizon_color = Color("91a6b5")
	sky_material.ground_bottom_color = Color("172b40")
	sky_material.ground_horizon_color = Color("91a6b5")
	sky_material.sky_curve = 0.22
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bfd9ec")
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("718aa2")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0025
	environment.fog_sky_affect = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SalvageYardSky"
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "EveningKey"
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_color = Color("ffe3bd")
	# Compatibility renders shadowed lights in sRGB: keep the key restrained
	# so safety orange and suit colours do not clip to yellow/white.
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	_build_yard_silhouette()


func _build_platforms() -> void:
	# A ready bridge teaches walking on real moving props before precise grabs.
	_static_box("Start", Vector3(0.0, -0.5, -0.5), Vector3(16.0, 1.0, 14.0), CREAM)
	_static_box("Middle", Vector3(0.0, -0.5, -19.0), Vector3(16.0, 1.0, 12.0), MINT)
	_static_box("Finish", Vector3(0.0, 1.5, -34.0), Vector3(16.0, 1.0, 10.0), CREAM)
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
	_wind_label = _label("WIND  >", switch_position + Vector3(0.0, 2.6, 0.0), 42, CREAM)
	_static_box("FanStand", Vector3(-9.6, 1.3, -25.0), Vector3(1.0, 3.0, 1.0), NAVY)
	_fan_housing(Vector3(-9.6, 3.1, -25.0))
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
	_static_box("FinishLeft", Vector3(-3.4, 4.0, -36.5), Vector3(0.7, 4.0, 0.7), STEEL)
	_static_box("FinishRight", Vector3(3.4, 4.0, -36.5), Vector3(0.7, 4.0, 0.7), STEEL)
	_extraction_gate(Vector3(0.0, 6.0, -36.5))


func _build_signs() -> void:
	# Floor stencils leave the camera and the physical play space unobstructed.
	_label("HANDS FULL", Vector3(0.0, 0.055, 5.4), 72, CREAM, true)
	_label("01 / STEADY THE BRIDGE", Vector3(0.0, 0.055, -6.7), 32, CREAM, true)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 0.035, -7.2), GOLD)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 0.035, -13.3), GOLD)
	_box_visual(self, Vector3(15.3, 0.025, 0.10), Vector3(0.0, 2.035, -29.3), GOLD)


func _build_grapple_anchors() -> void:
	_grapple_gantry("BridgeGrapple", Vector3(0, 9, -10.5), 18.0, -0.5)
	_grapple_gantry("FinishGrapple", Vector3(0, 10, -27.0), 18.0, -0.5)


func _grapple_gantry(id: String, at: Vector3, width: float, foot_y: float, turned: bool = false) -> void:
	# Wide, forgiving targets overhead; supports stay outside the walking route.
	var beam_size := Vector3(1.0, 0.9, width) if turned else Vector3(width, 0.9, 1.0)
	var beam := _static_box(id, at, beam_size, PETROL)
	beam.add_to_group("party_grapple_anchor")
	var clamp_size := Vector3(1.1, 1.05, 2.2) if turned else Vector3(2.2, 1.05, 1.1)
	_box_visual(beam, clamp_size, Vector3.ZERO, GOLD)
	var beam_accent := Vector3(0.04, 0.10, width - 0.6) if turned else Vector3(width - 0.6, 0.10, 0.04)
	_box_visual(beam, beam_accent, Vector3(-0.52, 0.20, 0.0) if turned else Vector3(0.0, 0.20, 0.52), MINT)
	var post_height: float = at.y - foot_y
	for side: float in [-1.0, 1.0]:
		var offset := Vector3(0, 0, side * (width * 0.5 - 0.35)) if turned else Vector3(side * (width * 0.5 - 0.35), 0, 0)
		_static_box(id + "Post" + str(side), Vector3(at.x + offset.x, foot_y + post_height * 0.5, at.z + offset.z), Vector3(0.5, post_height, 0.5), NAVY)
		_box_visual(self, Vector3(0.86, 0.6, 0.86), Vector3(at.x + offset.x, foot_y + 0.3, at.z + offset.z), GOLD)
		_box_visual(self, Vector3(0.62, 0.35, 0.62), Vector3(at.x + offset.x, at.y - 0.85, at.z + offset.z), STEEL)
		for rung in 4:
			var brace_offset: Vector3 = offset * 0.96
			var brace := _box_visual(self, Vector3(0.17, 1.7, 0.17), Vector3(at.x + brace_offset.x, at.y - 1.6 - rung * 1.45, at.z + brace_offset.z), PETROL)
			if turned:
				brace.rotation.x = side * 0.22
			else:
				brace.rotation.z = side * 0.22
	var sign_at: Vector3 = at + (Vector3(-0.57, 0, 0) if turned else Vector3(0, 0, 0.57))
	var sign := _label("HOOK / Q", sign_at, 28, NAVY)
	if turned:
		sign.rotation.y = -PI * 0.5


func _dress_deck(body: Node3D, size: Vector3, accent: Color) -> void:
	# Surface markings are meshes, never extra collision or network bodies.
	var half := size * 0.5
	var top: float = half.y + 0.015
	_box_visual(body, Vector3(size.x + 0.10, 0.25, size.z + 0.10), Vector3(0, -half.y + 0.05, 0), NAVY)
	# Lift the finish surface clear of the original box face to avoid z-fighting.
	_box_visual(body, Vector3(size.x - 0.16, 0.02, size.z - 0.16), Vector3(0, top - 0.012, 0), DECK)
	# Broad inset plates and narrow seams give the deck scale without noisy texture.
	for x in range(1, int(size.x / 3.0)):
		_box_visual(body, Vector3(0.035, 0.015, size.z - 0.72), Vector3(-half.x + x * 3.0, top, 0), STEEL)
	for z in range(1, int(size.z / 3.0)):
		_box_visual(body, Vector3(size.x - 0.72, 0.015, 0.035), Vector3(0, top, -half.z + z * 3.0), STEEL)
	for side: float in [-1.0, 1.0]:
		_box_visual(body, Vector3(0.16, 0.018, size.z - 0.5), Vector3(side * (half.x - 0.3), top + 0.012, 0), accent)
		_box_visual(body, Vector3(size.x - 0.5, 0.018, 0.16), Vector3(0, top + 0.012, side * (half.z - 0.3)), accent)
		_box_visual(body, Vector3(size.x - 0.4, 0.22, 0.13), Vector3(0, 0.02, side * (half.z + 0.025)), STEEL)
		for stripe in range(int(size.x / 0.85)):
			var stripe_x: float = -half.x + 0.55 + stripe * 0.85
			_box_visual(body, Vector3(0.38, 0.18, 0.035), Vector3(stripe_x, 0.02, side * (half.z + 0.10)), GOLD)
		for corner: float in [-1.0, 1.0]:
			var corner_at := Vector3(side * (half.x - 0.6), top + 0.024, corner * (half.z - 0.6))
			_cylinder_visual(body, 0.085, 0.035, corner_at, CREAM)
			# Foundations continue into the yard haze rather than floating as toy slabs.
			var leg_height: float = maxf(8.0, body.position.y + 19.0)
			_box_visual(body, Vector3(0.85, leg_height, 0.85), Vector3(side * (half.x - 1.0), -half.y - leg_height * 0.5, corner * (half.z - 1.0)), STEEL)
			_box_visual(body, Vector3(1.25, 0.8, 1.25), Vector3(side * (half.x - 1.0), -half.y - 1.4, corner * (half.z - 1.0)), PETROL)
		_box_visual(body, Vector3(size.x - 1.0, 0.45, 0.45), Vector3(0, -1.9, side * (half.z - 1.0)), NAVY)


func _dress_crate(body: Node3D, size: Vector3, number: String) -> void:
	var half := size * 0.5
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box_visual(body, Vector3(0.17, size.y + 0.035, 0.17), Vector3(x * (half.x - 0.055), 0, z * (half.z - 0.055)), NAVY)
	for y: float in [-1.0, 1.0]:
		_box_visual(body, Vector3(size.x + 0.025, 0.16, size.z + 0.025), Vector3(0, y * (half.y - 0.07), 0), STEEL)
	for side: float in [-1.0, 1.0]:
		_box_visual(body, Vector3(size.x * 0.67, 0.58, 0.035), Vector3(0, 0, side * (half.z + 0.02)), STEEL)
		_box_visual(body, Vector3(0.45, 0.12, 0.06), Vector3(0, 0.38, side * (half.z + 0.03)), CREAM)
	var label := Label3D.new()
	label.text = "CARGO / 0" + number
	label.font_size = 32
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = CREAM
	label.position = Vector3(0, 0, half.z + 0.045)
	body.add_child(label)
	# The top handle is inset visually; the original box stays easy to pick up.
	_box_visual(body, Vector3(0.55, 0.035, 0.15), Vector3(0, half.y + 0.015, 0), NAVY)


func _dress_walkway(body: Node3D, size: Vector3, accent: Color) -> void:
	var length_on_z: bool = size.z > size.x
	var length: float = size.z if length_on_z else size.x
	var width: float = size.x if length_on_z else size.z
	var top: float = size.y * 0.5 + 0.017
	for side: float in [-1.0, 1.0]:
		var rail_size := Vector3(0.18, size.y + 0.025, length) if length_on_z else Vector3(length, size.y + 0.025, 0.18)
		var rail_at := Vector3(side * (width * 0.5 - 0.075), 0, 0) if length_on_z else Vector3(0, 0, side * (width * 0.5 - 0.075))
		_box_visual(body, rail_size, rail_at, NAVY)
	for rib in range(int(length / 0.9)):
		var offset: float = -length * 0.5 + 0.45 + rib * 0.9
		var rib_size := Vector3(width - 0.48, 0.025, 0.07) if length_on_z else Vector3(0.07, 0.025, width - 0.48)
		var rib_at := Vector3(0, top, offset) if length_on_z else Vector3(offset, top, 0)
		_box_visual(body, rib_size, rib_at, STEEL)
	var stripe_size := Vector3(0.10, 0.02, length - 0.55) if length_on_z else Vector3(length - 0.55, 0.02, 0.10)
	_box_visual(body, stripe_size, Vector3(0, top + 0.016, 0), CREAM if accent != CREAM else GOLD)


func _fan_housing(at: Vector3, turned: bool = false) -> void:
	var frame := Node3D.new()
	frame.position = at
	if turned:
		frame.rotation.y = PI * 0.5
	add_child(frame)
	var outer := _cylinder_visual(frame, 1.85, 0.72, Vector3.ZERO, PETROL)
	outer.rotation.z = PI * 0.5
	var inner := _cylinder_visual(frame, 1.52, 0.035, Vector3(0.38, 0, 0), NAVY)
	inner.rotation.z = PI * 0.5
	for side: float in [-1.0, 1.0]:
		_box_visual(frame, Vector3(0.08, 0.16, 3.7), Vector3(0.44, side * 1.10, 0), STEEL)
		_box_visual(frame, Vector3(0.08, 3.7, 0.16), Vector3(0.44, 0, side * 1.10), STEEL)
	var hub := _cylinder_visual(frame, 0.25, 0.30, Vector3(0.69, 0, 0), GOLD)
	hub.rotation.z = PI * 0.5


func _extraction_gate(at: Vector3, turned: bool = false) -> void:
	var frame := Node3D.new()
	frame.position = at
	if turned:
		frame.rotation.y = -PI * 0.5
	add_child(frame)
	_box_visual(frame, Vector3(7.5, 0.75, 0.7), Vector3.ZERO, NAVY)
	_box_visual(frame, Vector3(6.5, 0.11, 0.045), Vector3(0, 0.27, 0.37), MINT)
	for side: float in [-1.0, 1.0]:
		_box_visual(frame, Vector3(0.12, 3.0, 0.045), Vector3(side * 3.4, -2.0, 0.37), MINT)
	var sign := Label3D.new()
	sign.text = "EXTRACTION / ALL CREW"
	sign.font_size = 44
	sign.pixel_size = 0.007
	sign.modulate = CREAM
	sign.outline_size = 0
	sign.position = Vector3(0, -0.03, 0.38)
	frame.add_child(sign)


func _build_yard_silhouette() -> void:
	# Crane groups can move aside when a longer course is attached after construction.
	_box_visual(self, Vector3(220, 1, 220), Vector3(0, -23, -20), Color("273e51"))
	for index in 7:
		var building_height: float = 7.0 + float((index * 7) % 11)
		var x: float = -60.0 + index * 20.0
		_box_visual(self, Vector3(13, building_height, 14), Vector3(x, -18.0 + building_height * 0.5, -76), STEEL)
		_box_visual(self, Vector3(13.5, 0.5, 14.5), Vector3(x, -17.8 + building_height, -76), NAVY)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 32.0, -8.0, -42.0)
		var crane := Node3D.new()
		crane.name = "BackgroundCraneLeft" if side < 0 else "BackgroundCraneRight"
		crane.position = at
		add_child(crane)
		_background_cranes.append(crane)
		_box_visual(crane, Vector3(2, 30, 2), Vector3.ZERO, STEEL)
		_box_visual(crane, Vector3(19, 1.0, 1.4), Vector3(-side * 6.0, 14, 0), PETROL)
		_box_visual(crane, Vector3(0.10, 11, 0.10), Vector3(-side * 12.0, 8.5, 0), NAVY)
		_box_visual(crane, Vector3(0.75, 1.2, 0.75), Vector3(-side * 12.0, 3, 0), GOLD)
		var brace := _box_visual(crane, Vector3(13, 0.22, 0.22), Vector3(-side * 5.0, 10.8, 0), STEEL)
		brace.rotation.z = side * 0.48
		for level in 4:
			_box_visual(self, Vector3(7.5, 3.2, 3.5), Vector3(side * 27.0, -19.0 + level * 3.3, -13.0 - level * 2.0), PETROL if level % 2 == 0 else STEEL)


func clear_background_obstructions() -> void:
	# Include the original course and any appended course before moving decoration.
	# Disabled return ramps also reserve their space for later in the run.
	var play_bounds := AABB()
	var has_bounds: bool = false
	for collider: Node in find_children("*", "CollisionShape3D", true, false):
		if not collider.shape is BoxShape3D: continue
		var box: BoxShape3D = collider.shape
		var bounds: AABB = collider.global_transform * AABB(-box.size * 0.5, box.size)
		play_bounds = play_bounds.merge(bounds) if has_bounds else bounds
		has_bounds = true
	if not has_bounds: return
	play_bounds = play_bounds.grow(5.0)
	for crane: Node3D in _background_cranes:
		var crane_bounds := AABB()
		var has_mesh: bool = false
		for visual: Node in crane.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = visual.global_transform * visual.get_aabb()
			crane_bounds = crane_bounds.merge(bounds) if has_mesh else bounds
			has_mesh = true
		if not has_mesh or not play_bounds.intersects(crane_bounds): continue
		# Move the entire crane beyond one edge; physics and course transforms stay put.
		if crane.name == "BackgroundCraneLeft":
			crane.global_position.x += play_bounds.position.x - crane_bounds.end.x - 12.0
		else:
			crane.global_position.x += play_bounds.end.x - crane_bounds.position.x + 12.0


func _cylinder_visual(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.position = at
	parent.add_child(visual)
	return visual


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.72
		result.metallic_specular = 0.30
		result.metallic = 0.18 if color == STEEL or color == NAVY else 0.05
		_materials[color] = result
	return _materials[color]


func _box_visual(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = _beveled_box(size)
	visual.material_override = _material(color)
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size.y > 0.06 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var is_deck: bool = id in ["Start", "Middle", "Finish"]
	_box_visual(body, size, Vector3.ZERO, DECK if is_deck else color)
	if is_deck:
		_dress_deck(body, size, GOLD if id == "Start" else MINT)
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
	if id.begins_with("block_"):
		_dress_crate(body, size, id.trim_prefix("block_"))
	else:
		_dress_walkway(body, size, color)
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
