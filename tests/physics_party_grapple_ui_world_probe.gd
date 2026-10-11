extends SceneTree
## Real HUD state transitions and collision rays; no household save or network.
const HUD = preload("res://prototypes/physics_party/party_hud.gd")
const WORLD_PATHS: Array[String] = [
	"res://prototypes/physics_party/party_world.gd",
	"res://prototypes/physics_party/party_counterweight_world.gd",
]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.gui_disable_input = true
	var hud: CanvasLayer = HUD.new()
	root.add_child(hud)
	_check(hud.has_method("update_grapple"), "HUD accepts live grapple feedback")
	if hud.has_method("update_grapple"):
		await _check_hud(hud)
	hud.queue_free()
	await process_frame
	for path: String in WORLD_PATHS:
		var world: Node3D = load(path).new()
		world.setup(false)
		root.add_child(world)
		await physics_frame
		await physics_frame
		var anchors: Array[Node] = get_nodes_in_group("party_grapple_anchor")
		_check(anchors.size() >= 2, path.get_file() + " has overhead grapple targets for both crossings")
		for checkpoint: int in [0, 1]:
			var start: Vector3 = world.spawn_point(1, checkpoint)
			var target_visible: bool = false
			for anchor: Node3D in anchors:
				if anchor.global_position.y <= start.y + 2.0 or anchor.global_position.distance_to(start) > 28.0:
					continue
				var ray := PhysicsRayQueryParameters3D.create(start, anchor.global_position, 1)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.get("collider") == anchor and anchor is StaticBody3D:
					target_visible = true
			_check(target_visible, path.get_file() + " has reachable static overhead target from checkpoint " + str(checkpoint))
		_check(world.props.size() == 7, path.get_file() + " keeps seven networked movable props")
		if DisplayServer.get_name() != "headless":
			var camera := Camera3D.new()
			root.add_child(camera)
			camera.position = Vector3(28, 26, 21)
			camera.look_at(Vector3(5, 4, -12))
			camera.current = true
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("res://logs/grapple-" + path.get_file().get_basename() + ".png") == OK, path.get_file() + " native world screenshot saved")
			camera.queue_free()
		world.queue_free()
		await process_frame
	print("GRAPPLE_UI_WORLD " + JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check_hud(hud: CanvasLayer) -> void:
	var data: Dictionary = {"phase": "play", "players": {"crew_1": {"name": "Player", "power": "spring"}}, "note": "Get everyone across."}
	hud.update_grapple("pull", false, true)
	var reticle: Control = hud.get("_grapple_reticle")
	var status: Label = hud.get("_grapple_status")
	_check(not reticle.is_visible_in_tree(), "Menu hides grapple aim")
	hud.show_game()
	hud.update_view(data, "crew_1", true)
	hud.update_grapple("pull", false, false)
	_check(reticle.is_visible_in_tree(), "Gameplay shows grapple aim")
	_check("Pull" in status.text, "HUD identifies pull mode")
	var unavailable_color: Color = reticle.modulate
	hud.update_grapple("swing", false, true)
	_check("Swing" in status.text, "HUD identifies swing mode")
	_check(reticle.modulate != unavailable_color, "Valid target highlights the reticle")
	hud.update_grapple("swing", true, true)
	_check("Release Q" in status.text, "Attached HUD explains detach control")
	await process_frame
	_check(status.get_global_rect().end.x <= 960.0 and status.get_global_rect().end.y <= 540.0, "Grapple help fits minimum window")
	_check(reticle.get_global_rect().get_center().distance_to(Vector2(480, 270)) < 1.0, "Grapple aim is at viewport center")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://logs/grapple-hud-960x540.png") == OK, "Native HUD screenshot saved")
	data.players.crew_1.power = ""
	data.offers = {"crew_1": ["spring", "heavy", "grip"]}
	hud.update_view(data, "crew_1", true)
	_check(not reticle.is_visible_in_tree(), "Power draft hides grapple aim immediately")
	data.players.crew_1.power = "spring"
	data.phase = "complete"
	hud.update_view(data, "crew_1", true)
	_check(not reticle.is_visible_in_tree(), "Completion hides grapple aim immediately")
	hud.show_menu()
	hud.update_grapple("pull", false, true)
	_check(not reticle.is_visible_in_tree(), "Menu keeps aim hidden despite target updates")

func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures.append(message)
