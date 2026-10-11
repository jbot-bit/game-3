extends "res://prototypes/physics_party/party_world.gd"
## Foam-stick ring-out arena. The pool is decoration, never a rescue floor.

const ELIMINATION_Y := -2.0
const ARENA_RADIUS := 14.0
const PLATFORM_TOP := 4.0
const PAD_BLUE := Color("287bb5")
const PAD_PINK := Color("d55e80")
const PAD_YELLOW := Color("dfaf48")
var elimination_y: float = ELIMINATION_Y


func _ready() -> void:
	if _built: return
	_built = true
	_build_lighting()
	_pad("MainRing", Vector3(0, 3.3, 0), 7.8, 1.4, PAD_BLUE)
	for side: float in [-1.0, 1.0]:
		var bridge := _static_box("BalanceBridge" + str(side), Vector3(side * 8.7, 3.7, 0), Vector3(3.2, 0.6, 1.8), PAD_YELLOW)
		_box_visual(bridge, Vector3(2.9, 0.04, 0.12), Vector3(0, 0.32, 0), CREAM)
		_pad("DuelPodium" + str(side), Vector3(side * 11.2, 3.3, 0), 2.3, 1.4, PAD_PINK)
	for slot in 3:
		var at: Vector3 = spawn_point(slot) - Vector3.UP * 2.96
		_cylinder_visual(self, 0.8, 0.025, at, [PAD_YELLOW, MINT, PAD_PINK][slot])
	_label("GLADIATOR", Vector3(0, 4.045, -1.0), 82, CREAM, true)
	_label("STAY ON  /  PUSH THEM OFF", Vector3(0, 4.05, 1.0), 28, CREAM, true)
	preload("res://prototypes/physics_party/party_mesh_batch.gd").merge_tree(self)


func spawn_point(slot: int, _checkpoint: int = 0) -> Vector3:
	var angle: float = TAU * float(clampi(slot, 0, 2)) / 3.0 + PI * 0.5
	return Vector3(cos(angle) * 4.1, PLATFORM_TOP + 3.0, sin(angle) * 4.1)


func arena_contains(at: Vector3) -> bool:
	return at.is_finite() and Vector2(at.x, at.z).length() <= ARENA_RADIUS and at.y >= ELIMINATION_Y and at.y < 35.0


func checkpoint_contains(_at: Vector3) -> bool: return false
func goal_contains(_at: Vector3) -> bool: return false
func wind_at(_at: Vector3) -> Vector3: return Vector3.ZERO
func capture_movers() -> Dictionary: return {}
func apply_presented_movers(_data: Dictionary) -> void: pass


func _pad(id: String, at: Vector3, radius: float, height: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	_cylinder_visual(body, radius, height, Vector3.ZERO, color)
	_cylinder_visual(body, radius - 0.2, 0.045, Vector3(0, height * 0.5 + 0.012, 0), color.lightened(0.16))
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a9c3d2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1f3ff")
	environment.ambient_light_energy = 0.32
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var sky := WorldEnvironment.new()
	sky.environment = environment
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff5db")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)
	_box_visual(self, Vector3(400, 0.15, 400), Vector3(0, -3.7, -55), Color("2c6376"))
	# Seating, pool stripes and flags are visual only; a fallen contestant cannot land here.
	for side: float in [-1.0, 1.0]:
		for row in 4:
			_box_visual(self, Vector3(3.0, 1.1, 48), Vector3(side * (22 + row * 3), row * 1.2, 0), PAD_BLUE if row % 2 == 0 else PAD_PINK)
		for index in 6:
			_box_visual(self, Vector3(1.8, 0.03, 7.0), Vector3(side * 18, -3.59, index * 8.0 - 20), CREAM)
			_box_visual(self, Vector3(0.12, 10, 0.12), Vector3(side * 19.5, 4.0, index * 8.0 - 20), CREAM)
			_box_visual(self, Vector3(1.8, 1.1, 0.08), Vector3(side * 19.5 + 0.8, 8.4, index * 8.0 - 20), PAD_YELLOW if index % 2 == 0 else PAD_PINK)
