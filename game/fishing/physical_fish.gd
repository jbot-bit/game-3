class_name PhysicalFish
extends RigidBody3D

var catch_id: String = ""
var recovering: bool = false
var last_dry_position := Vector3.ZERO
var water_height: float = -0.2
var held: bool = false
var _host_simulated: bool = false
var _game_paused: bool = false
var _recover_elapsed: float = 0.0
var _saved_velocity := Vector3.ZERO
var _saved_angular := Vector3.ZERO
var _sequence: int = 0
var _received_sequence: int = -1
var _visual: Node3D
var _shape: BoxShape3D
var _target_pose := Transform3D.IDENTITY
var _bob_origin := Vector3.ZERO
var _visual_offset := Transform3D.IDENTITY

func setup(id: String, species: String, oversized: bool = true, trait_id: String = "none") -> void:
	catch_id = id
	name = "Fish_" + id.validate_node_name()
	collision_layer = 4
	collision_mask = 1
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	mass = 1.5
	linear_damp = 0.3
	angular_damp = 2.0
	_shape = BoxShape3D.new()
	_shape.size = Vector3(1.9, 0.65, 0.6) if oversized else Vector3(1.2, 0.45, 0.4)
	if species == "bellgill":
		_shape.size = Vector3(1.7, 1.25, 0.7) if oversized else Vector3(1.1, 0.8, 0.45)
	elif species == "lantern_eel":
		_shape.size = Vector3(2.5, 0.45, 0.45) if oversized else Vector3(1.6, 0.3, 0.3)
	elif species not in ["penny_perch", "perch"]:
		var geometry: GDScript = load("res://game/world/block_art.gd")
		_shape.size = geometry.fish_collision_dimensions(species,oversized)
	var collider := CollisionShape3D.new()
	collider.shape = _shape
	add_child(collider)
	var art_script: GDScript = load("res://game/world/block_art.gd")
	_visual = art_script.fish(species, oversized, trait_id)
	_visual_offset = _visual.transform
	add_child(_visual)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	last_dry_position = global_position
	_target_pose = global_transform

func set_host_simulated(value: bool) -> void:
	_host_simulated = value
	collision_layer = 4 if value else 0
	collision_mask = 1 if value else 0
	freeze = not value or held or recovering or _game_paused
	if is_instance_valid(_visual):
		_visual.top_level = not value
		if value:
			_visual.transform = _visual_offset
		else:
			_visual.global_transform = global_transform * _visual_offset

func set_carry_pose(pose: Transform3D, anchor: Vector3) -> bool:
	if not _host_simulated or _game_paused or recovering or not pose.origin.is_finite() or not anchor.is_finite():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = pose
	query.collision_mask = 1
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	query.transform = global_transform
	query.motion = pose.origin - global_position
	var travel: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	if travel.size() >= 1 and travel[0] < 0.999:
		return false
	held = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = pose
	last_dry_position = anchor
	return true

func drop() -> void:
	if not _host_simulated:
		return
	held = false
	freeze = recovering or _game_paused
	_saved_velocity=Vector3.ZERO
	_saved_angular=Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false

func toss(direction: Vector3) -> void:
	if not _host_simulated or _game_paused or recovering or not direction.is_finite():
		return
	drop()
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	linear_velocity = horizontal * 5.0 + Vector3.UP * 2.0
	angular_velocity = Vector3(0, 0, 2.0)

func set_game_paused(value: bool) -> void:
	if value == _game_paused:
		return
	_game_paused = value
	if value:
		_saved_velocity = linear_velocity
		_saved_angular = angular_velocity
		freeze = true
	else:
		freeze = not _host_simulated or held or recovering
		if not freeze:
			linear_velocity = _saved_velocity
			angular_velocity = _saved_angular
			sleeping = false

func enter_water() -> void:
	if not _host_simulated or recovering or _game_paused:
		return
	recovering = true
	held = false
	_recover_elapsed = 0.0
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_bob_origin = global_position
	_bob_origin.y = water_height + 0.3
	global_position = _bob_origin

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _host_simulated or _game_paused or held or recovering:
		return
	state.linear_velocity = state.linear_velocity.limit_length(8.0)
	state.angular_velocity = state.angular_velocity.limit_length(6.0)
	for index: int in range(state.get_contact_count()):
		var normal: Vector3 = state.transform.basis * state.get_contact_local_normal(index)
		if normal.dot(Vector3.UP) > 0.5 and state.transform.origin.y > water_height:
			last_dry_position = state.transform.origin + Vector3.UP * 0.05

func _physics_process(delta: float) -> void:
	if not _host_simulated or _game_paused:
		return
	if recovering:
		_recover_elapsed += delta
		global_position = _bob_origin + Vector3.UP * sin(_recover_elapsed * 5.0) * 0.08
		if _recover_elapsed >= 2.0:
			recovering = false
			global_transform = Transform3D(Basis.IDENTITY, last_dry_position)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			freeze = false
			sleeping = false
			reset_physics_interpolation()
	elif not held and (global_position.y < water_height - 0.5 or absf(global_position.x) > 130 or absf(global_position.z) > 110):
		enter_water()

func _process(delta: float) -> void:
	if not _host_simulated and is_instance_valid(_visual):
		_visual.global_transform = _visual.global_transform.interpolate_with(_target_pose * _visual_offset, 1.0 - exp(-18.0 * delta))

func pose_snapshot() -> Dictionary:
	_sequence += 1
	return {"catch_id": catch_id, "sequence": _sequence, "transform": global_transform, "linear_velocity": linear_velocity, "angular_velocity": angular_velocity, "held": held, "recovering": recovering}

func apply_network_pose(data: Dictionary) -> void:
	if _host_simulated or int(data.get("sequence", -1)) <= _received_sequence:
		return
	if not data.get("transform") is Transform3D:
		return
	var pose: Transform3D = data.transform
	if not pose.origin.is_finite():
		return
	_received_sequence = int(data.sequence)
	_target_pose = pose
	global_transform = pose
	held = bool(data.get("held", false))
	recovering = bool(data.get("recovering", false))
	freeze = true
