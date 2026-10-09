extends Node3D
## Local physics probe. Production LAN play uses the main scene and its Session.

const Art = preload("res://game/world/block_art.gd")
const FishBody = preload("res://game/fishing/physical_fish.gd")
const CargoModel = preload("res://game/fishing/cargo_rules.gd")
var _cargo = CargoModel.new()
var _players: Array[CharacterBody3D] = []
var _fish: RigidBody3D
var _selected: int = 0
var _paused: bool = false
var _label: Label
var _note: String = "Grab the trophy and pass it across the dock."
var _dry_positions: Array[Vector3] = []
var _deposit_time: float = 0.0
var _fixture_sequence: int = 0

func _ready() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("82b7c8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Art.CREAM
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	Art.box(self, Vector3(0, -0.35, 0), Vector3(12, 0.7, 9), Art.GRASS, true)
	Art.box(self, Vector3(0, -0.12, -6), Vector3(4.5, 0.24, 4), Art.WOOD, true)
	Art.box(self, Vector3(0, -0.3, -9.5), Vector3(5, 0.6, 2), Art.WOOD, true)
	Art.box(self, Vector3(0, -0.65, 0), Vector3(90, 0.1, 90), Art.WATER)
	Art.box(self, Vector3(2.9, 0.8, -1.5), Vector3(0.4, 1.6, 3), Art.WOOD, true)
	Art.box(self, Vector3(0, 0.02, -9.5), Vector3(2.5, 0.07, 1.5), Art.AMBER)
	var colors: Array[Color] = [Color("62b9db"), Color("e67c61"), Color("a28ad6")]
	for index: int in range(3):
		var body := CharacterBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 1
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		collider.shape = capsule
		collider.position.y = 0.9
		body.add_child(collider)
		body.add_child(Art.crew(colors[index]))
		body.position = Vector3(float(index - 1) * 2, 0.1, 1)
		add_child(body)
		_players.append(body)
		_dry_positions.append(body.position)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(11, 13, 13)
	camera.look_at(Vector3(0, 0, -3))
	camera.fov = 60
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 18)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Art.CREAM)
	_label.add_theme_color_override("font_shadow_color", Art.INK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_label)
	_reset_fixture()

func _reset_fixture() -> void:
	if is_instance_valid(_fish):
		_fish.queue_free()
	_cargo = CargoModel.new()
	_fixture_sequence += 1
	var id: String = "yard:%d" % _fixture_sequence
	_cargo.register_catch({"catch_id": id, "run_id": "yard", "profile_id": "crew_1", "species_id": "penny_perch", "trait_id": "oversized", "catch_value": 12}, "whole")
	_fish = FishBody.new()
	_fish.setup(id, "penny_perch", true)
	_fish.position = Vector3(0, 1, -1)
	add_child(_fish)
	_fish.set_host_simulated(true)
	_fish.set_game_paused(_paused)
	_cargo.set_paused(_paused)
	_deposit_time = 0.0
	_note = "Fresh test fish. This yard does not modify household progress."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				_selected = int(event.keycode - KEY_1)
			KEY_E:
				_interact()
			KEY_P:
				_paused = not _paused
				_cargo.set_paused(_paused)
				_fish.set_game_paused(_paused)
			KEY_R:
				_reset_fixture()
			KEY_B:
				if not _paused:
					_cargo.release("crew_%d" % (_selected + 1), "drop")
					_fish.enter_water()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var result: Dictionary = _cargo.release("crew_%d" % (_selected + 1), "toss")
		if result.ok:
			_fish.toss(-_players[_selected].global_basis.z)
			_note = "Tossed. Hold E near a flying fish to receive it."

func _interact() -> void:
	var profile_id: String = "crew_%d" % (_selected + 1)
	if not _cargo.held_by(profile_id).is_empty():
		if _cargo.release(profile_id, "drop").ok:
			_fish.drop()
		return
	var distance: float = _players[_selected].global_position.distance_to(_fish.global_position)
	var result: Dictionary = _cargo.grab(_fish.catch_id, profile_id, {"distance_m": distance, "line_of_sight": true, "active": true})
	_note = "Picked up." if result.ok else str(result.code)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_fish):
		return
	_label.text = "ONE MORE CAST • LOCAL PHYSICS YARD\n1–3 choose crew  ·  WASD move  ·  E grab/drop  ·  Click toss\nP pause  ·  B test water recovery  ·  R fresh fixture\nCrew %d  |  %s\n%s" % [_selected + 1, "PAUSED" if _paused else "RUNNING", _note]
	if _paused:
		return
	for index: int in range(_players.size()):
		var body: CharacterBody3D = _players[index]
		var movement := Vector3.ZERO
		if index == _selected:
			movement = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
		var profile_id: String = "crew_%d" % (index + 1)
		var holding: bool = not _cargo.held_by(profile_id).is_empty()
		body.velocity.x = movement.x * (3.4 if holding else 4.0)
		body.velocity.z = movement.z * (3.4 if holding else 4.0)
		body.velocity.y = -1 if body.is_on_floor() else body.velocity.y - 9.8 * delta
		if movement.length_squared() > 0.01:
			body.rotation.y = atan2(-movement.x, -movement.z)
		body.move_and_slide()
		if body.is_on_floor():
			_dry_positions[index] = body.position
		if body.position.y < -0.7:
			body.position = _dry_positions[index]
			body.velocity = Vector3.ZERO
		if holding:
			var pose := Transform3D(Basis(Vector3.UP, body.rotation.y), body.global_position - body.global_basis.z * 1.15 + Vector3.UP * 1.15)
			if not _fish.set_carry_pose(pose, _dry_positions[index] + Vector3.UP * 0.8):
				_cargo.release(profile_id, "drop")
				_fish.drop()
				_note = "Carry blocked; fish safely dropped."
	if _fish.global_position.y < -0.45 and not _fish.recovering:
		_fish.enter_water()
	if Input.is_physical_key_pressed(KEY_E) and _fish.linear_velocity.length() > 0.5:
		var body: CharacterBody3D = _players[_selected]
		var offset: Vector3 = _fish.global_position - (body.global_position + Vector3.UP)
		var received: Dictionary = _cargo.receive(_fish.catch_id, [{"profile_id": "crew_%d" % (_selected + 1), "distance_m": offset.length(), "facing": (-body.global_basis.z).dot(offset.normalized()) > 0.0, "receiving": true, "active": true}])
		if received.ok:
			_note = "Received the same fish."
	var in_crate: bool = absf(_fish.position.x) < 1.25 and absf(_fish.position.z + 9.5) < 0.75 and _fish.position.y < 1.5
	_deposit_time = _deposit_time + delta if in_crate and _fish.linear_velocity.length() < 0.5 else 0.0
	if _deposit_time >= 0.3:
		_note = "Delivery area reached. Local physics result only; no reward saved."
