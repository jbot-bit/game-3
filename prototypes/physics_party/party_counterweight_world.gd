extends "res://prototypes/physics_party/party_world.gd"
## Counterweight: load the long arm, climb together, turn across the breeze.
## All interaction, recovery and replication come from the original world.


func _init() -> void:
	switch_position = Vector3(-3.6, 5.2, -17.0)


func intro_text() -> String:
	return "Weight the low end. Blocks can stay when friends move on."


func spawn_point(slot: int, checkpoint: int = 0) -> Vector3:
	var offset: float = float(clampi(slot, 0, 2) - 1) * 2.8
	if checkpoint >= 2:
		return Vector3(17.0, 7.2, -17.0 + offset)
	if checkpoint == 1:
		return Vector3(offset, 7.2, -17.0)
	return Vector3(offset, 3.0, 3.5)


func checkpoint_contains(at: Vector3) -> bool:
	return absf(at.x) < 4.8 and at.z < -14.0 and at.z > -20.8 and at.y >= 4.0 and at.y < 12.0


func goal_contains(at: Vector3) -> bool:
	return at.x > 13.6 and at.x < 20.8 and at.z < -12.5 and at.z > -21.5 and at.y >= 4.0 and at.y < 12.0


func wind_at(at: Vector3) -> Vector3:
	if at.x > 5.0 and at.x < 14.0 and at.z > -22.0 and at.z < -12.0 and at.y > 2.0 and at.y < 12.0:
		return Vector3(0.0, 0.0, float(wind_direction) * WIND_ACCELERATION)
	return Vector3.ZERO


func set_wind(direction: int) -> void:
	super.set_wind(direction)
	if is_instance_valid(_wind_arrow):
		_wind_arrow.rotation.y = -PI * 0.5 if wind_direction > 0 else PI * 0.5


func _build_platforms() -> void:
	_static_box("Start", Vector3(0, -0.5, 1.5), Vector3(14, 1, 9), CREAM)
	_static_box("Middle", Vector3(0, 3.7, -17.5), Vector3(10, 1, 7), MINT)
	_static_box("Finish", Vector3(17, 3.7, -17), Vector3(8, 1, 10), CREAM)
	# The broad low loading end needs neither stacking nor a precision socket.
	_static_box("LoadingStep", Vector3(0, 0.2, -2.2), Vector3(5.2, 0.4, 1.4), GOLD)


func _build_props() -> void:
	for side: float in [-15.2, -18.8]:
		_static_box("PlankRestNear" + str(side), Vector3(4.0, 4.325, side), Vector3(0.8, 0.25, 2.5), NAVY)
		_static_box("PlankRestFar" + str(side), Vector3(14.0, 4.325, side), Vector3(0.8, 0.25, 2.5), NAVY)
	# The second crossing turns right: two independent movable walkways.
	var near_plank := _prop_box("plank_left", Vector3(9, 4.65, -15.2), Vector3(11.5, 0.35, 2.0), 1.0, MINT)
	var far_plank := _prop_box("plank_right", Vector3(9, 4.65, -18.8), Vector3(11.5, 0.35, 2.0), 1.0, CORAL)
	near_plank.physics_material_override.friction = 0.55
	far_plank.physics_material_override.friction = 0.55
	_prop_box("block_1", Vector3(-4.5, 0.8, 0.5), Vector3.ONE * 1.5, 2.0, GOLD)
	_prop_box("block_2", Vector3(1.7, 0.8, 0.5), Vector3.ONE * 1.5, 2.0, CORAL)
	_prop_box("block_3", Vector3(-5.3, 0.8, 2.6), Vector3.ONE * 1.5, 2.0, CREAM)
	_prop_box("block_4", Vector3(5.3, 0.8, 2.6), Vector3.ONE * 1.5, 2.0, GOLD)


func _build_seesaw() -> void:
	# An off-centre hinge gives a block on the long arm useful leverage.
	# Friends can replace that weight, then leave the blocks behind to cross.
	var pivot := _static_box("SeesawPivot", Vector3(0, 0.85, -9.0), Vector3(2.1, 1.7, 0.9), NAVY)
	var board := _prop_box("seesaw", Vector3(0, 2.0, -6.5), Vector3(5.2, 0.35, 11.0), 4.5, CORAL)
	board.angular_damp = 0.9
	if not authoritative:
		return
	var hinge := HingeJoint3D.new()
	hinge.name = "SeesawHinge"
	add_child(hinge)
	hinge.position = Vector3(0, 2.0, -9.0)
	hinge.rotation.y = PI * 0.5
	hinge.node_a = hinge.get_path_to(pivot)
	hinge.node_b = hinge.get_path_to(board)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-15.0))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(15.0))


func _build_switch_and_fan() -> void:
	_static_box("WindSwitchBase", switch_position + Vector3(0, -0.5, 0), Vector3(1.3, 1, 1.3), NAVY)
	_switch_handle = Node3D.new()
	_switch_handle.name = "RedLever"
	_switch_handle.position = switch_position
	add_child(_switch_handle)
	_box_visual(_switch_handle, Vector3(0.18, 1.2, 0.18), Vector3(0, 0.6, 0), CREAM)
	_box_visual(_switch_handle, Vector3(0.55, 0.45, 0.55), Vector3(0, 1.2, 0), CORAL)
	_wind_label = _label("WIND  >", switch_position + Vector3(0, 2.6, 0), 42, CREAM)
	_static_box("FanStand", Vector3(9, 5.5, -22.4), Vector3(1, 3, 1), NAVY)
	_fan_housing(Vector3(9, 7.3, -22.4), true)
	# Parent rotates around X; local X is turned onto this fan's Z axis.
	var fan_frame := Node3D.new()
	fan_frame.position = Vector3(9, 7.3, -21.76)
	fan_frame.rotation.y = PI * 0.5
	add_child(fan_frame)
	_fan_rotor = Node3D.new()
	_fan_rotor.name = "FanBlades"
	fan_frame.add_child(_fan_rotor)
	_box_visual(_fan_rotor, Vector3(0.12, 2.8, 0.4), Vector3.ZERO, CORAL)
	_box_visual(_fan_rotor, Vector3(0.12, 0.4, 2.8), Vector3.ZERO, CORAL)
	_wind_arrow = Node3D.new()
	_wind_arrow.name = "WindDirection"
	_wind_arrow.position = Vector3(2.0, 4.23, -17.0)
	add_child(_wind_arrow)
	_box_visual(_wind_arrow, Vector3(2.2, 0.04, 0.22), Vector3.ZERO, NAVY)
	var first := _box_visual(_wind_arrow, Vector3(0.8, 0.04, 0.22), Vector3(0.85, 0, -0.23), NAVY)
	first.rotation.y = -PI * 0.25
	var second := _box_visual(_wind_arrow, Vector3(0.8, 0.04, 0.22), Vector3(0.85, 0, 0.23), NAVY)
	second.rotation.y = PI * 0.25


func _build_finish() -> void:
	_static_box("FinishLeft", Vector3(18.5, 6.2, -20.4), Vector3(0.7, 4, 0.7), STEEL)
	_static_box("FinishRight", Vector3(18.5, 6.2, -13.6), Vector3(0.7, 4, 0.7), STEEL)
	_extraction_gate(Vector3(18.5, 8.2, -17), true)


func _build_signs() -> void:
	_label("COUNTERWEIGHT", Vector3(0, 0.055, 5.3), 62, CREAM, true)
	_label("02 / LOAD THE LOW END", Vector3(0, 0.055, -0.5), 31, CREAM, true)
	_label("TURN INTO THE BREEZE", Vector3(0.2, 4.255, -20.2), 26, CREAM, true)
	_box_visual(self, Vector3(13.3, 0.025, 0.10), Vector3(0, 0.035, -2.7), GOLD)
	_box_visual(self, Vector3(9.3, 0.025, 0.10), Vector3(0, 4.235, -14.2), GOLD)


func _build_grapple_anchors() -> void:
	_grapple_gantry("LiftGrapple", Vector3(0, 12, -9.5), 16.0, -0.5)
	_grapple_gantry("BreezeGrapple", Vector3(9, 14, -17), 13.0, 3.7, true)
