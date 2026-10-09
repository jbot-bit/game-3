extends SceneTree
## Original catalogue assets rendered by Godot; never touches household saves.
const Art = preload("res://game/world/block_art.gd")
const FishData = preload("res://game/fishing/species.gd")

func _initialize() -> void:
	call_deferred("_run")

func _label(parent: Node3D, title: String, point: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = title
	label.position = point
	label.font_size = 32
	label.pixel_size = 0.008
	label.outline_size = 7
	label.modulate = Art.CREAM
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _run() -> void:
	root.size = Vector2i(1600,1000)
	var scene: Node3D = Node3D.new()
	root.add_child(scene)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202d3a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bad1d5")
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 0.55
	scene.add_child(light)
	var index: int = 0
	for species: String in FishData.catalog():
		var x: float = float(index%4)*3.0-4.5
		var y: float = 5.4-float(index/4)*2.0
		var fish: Node3D = Art.fish(species)
		scene.add_child(fish)
		fish.position = Vector3(x,y,0)
		fish.rotation.x = -0.32
		fish.rotation.y = 0.3
		_label(scene,FishData.catalog()[species].name,Vector3(x,y-0.65,0))
		index += 1
	index = 0
	for trait_id: String in ["none","oversized","moonlit","stormmarked"]:
		var x: float = float(index)*3.0-4.5
		var fish: Node3D = Art.fish("penny_perch",trait_id=="oversized",trait_id)
		scene.add_child(fish)
		fish.position = Vector3(x,-1.0,0)
		fish.rotation.x = -0.25
		_label(scene,trait_id.capitalize(),Vector3(x,-1.8,0))
		index += 1
	var camera: Camera3D = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0,3.0,14.6)
	camera.look_at(Vector3(0,2.0,0))
	camera.fov = 56
	camera.current = true
	for frame: int in range(12): await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://logs/fish-catalog.png")
	var result: Error = root.get_texture().get_image().save_png(path)
	print("FISH_CATALOG_RENDER_" + ("OK" if result==OK else "FAILED") + ": " + path)
	quit(0 if result==OK else 1)
