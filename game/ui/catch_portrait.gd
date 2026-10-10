extends SubViewportContainer
## Uses the landed species' real world model in a separate, non-interactive viewport.
const Art = preload("res://game/world/block_art.gd")
var _viewport: SubViewport
var _fish: Node3D
var _camera: Camera3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(146, 124)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(292, 248)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e6faff")
	environment.environment.ambient_light_energy = 0.85
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.3
	world.add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0, 0.35, 4)
	world.add_child(_camera)
	_camera.look_at(Vector3.ZERO)
	_camera.current = true

func show_species(species_id: String, trait_id: String) -> void:
	if _fish != null:
		_fish.free()
	_fish = Art.fish(species_id, false, trait_id)
	_fish.rotation_degrees = Vector3(-8, -12, 8)
	_camera.size = maxf(1.45, Art.fish_dimensions(species_id).x + 0.6)
	if species_id == "crown_ray": _fish.rotation_degrees.x = -36
	_viewport.add_child(_fish)
	# A single frame is sufficient; the reveal itself never creates a second fish simulation.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
