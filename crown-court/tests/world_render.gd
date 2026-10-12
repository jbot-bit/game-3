extends SceneTree

const World = preload("res://world.gd")
var world: Node3D
var state: Dictionary

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	state = {"players": {}, "ball": {"pos": Vector3(.3, 1.2, 6), "vel": Vector3.ZERO, "owner": 1}, "mode": "coop", "event_id": 0, "names": {1: "YOU", 2: "JELLY", 3: "BISCUIT", 4: "PEPPER", 5: "BUBBLE", 6: "MANGO"}}
	var positions := [Vector3(0, 0, 7), Vector3(-2.5, 0, 3), Vector3(2.6, 0, 1), Vector3(-1, 0, -5), Vector3(3, 0, -6), Vector3(-3, 0, -7)]
	for i in 6:
		state["players"][i + 1] = {"pos": positions[i], "vel": Vector3.ZERO, "facing": Vector3.FORWARD if i < 3 else Vector3.BACK, "grounded": true}
	for i in 25:
		world.present(state, 0, 1.0 / 60.0, 0, .43)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_overview.png")
	state["aim_preview"] = PackedVector3Array()
	for i in 24:
		var time := float(i + 1) * .06
		state["aim_preview"].append(Vector3(.3, 1.9, 6) + Vector3(0, 12, -14) * time + Vector3.DOWN * 9.0 * time * time)
	state["aim_bad"] = false
	for i in 25:
		world.present(state, 1, 1.0 / 60.0, 0, .43)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_gameplay.png")
	assert(world.preview_dots[0].material_override == world.aim_good_material)
	state["aim_bad"] = true
	world.present(state, 1, 1.0 / 60.0, 0, .43)
	assert(world.preview_dots[0].material_override == world.aim_bad_material)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_overcharge.png")
	state["aim_preview"] = PackedVector3Array()
	state["players"][1]["giant"] = 5.0
	state["power_pads"] = [{"pos": Vector3(3, 0, 4), "time": 12.0, "owner": 1}]
	state["power_balls"] = [{"id": 1, "pos": Vector3(1, 1.3, 3), "owner": 1}]
	state["event_id"] = 1
	state["event_kind"] = "power"
	state["event_player"] = 1
	for i in 25:
		state["power_balls"][0]["pos"].z -= .09
		world.present(state, 1, 1.0 / 60.0, 0, .43)
		await process_frame
	assert(world.actors[1]["rig"].scale.y > 1.6)
	assert(world.temporary_pads.size() == 1 and world.power_orbs.size() == 1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_powers.png")
	state["players"][1]["giant"] = 0.0
	state["power_pads"] = []
	state["power_balls"] = []
	var hoop: Vector3 = world.sim_constants["NORTH"]
	state["players"][1]["pos"] = hoop + Vector3(0, -1.8, 1.5)
	state["players"][1]["grounded"] = false
	state["players"][1]["dunk"] = .4
	state["ball"]["pos"] = hoop + Vector3(0, .5, .1)
	state["event_id"] = 2
	state["event_kind"] = "dunk"
	for i in 25:
		state["players"][1]["dunk"] = lerpf(1.25, .26, float(i) / 24.0)
		world.present(state, 1, 1.0 / 60.0, -.3, .43)
		await process_frame
	assert(world.actors[1]["dunk_ring"].visible)
	var effects_before: int = world.effects.size()
	state["players"][1]["dunk"] = .24
	world.present(state, 1, 1.0 / 60.0, -.3, .43)
	assert(not world.actors[1]["dunk_ring"].visible and world.effects.size() > effects_before)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_dunk.png")
	state["cosmetics"] = {1: {"outfit": "blank", "accessory": "none"}, 2: {"outfit": "jersey", "accessory": "cap"}, 3: {"outfit": "stripes", "accessory": "shades"}, 4: {"outfit": "hoodie", "accessory": "headphones"}, 5: {"outfit": "space", "accessory": "horns"}, 6: {"outfit": "gold", "accessory": "crown"}}
	state["names"] = {1: "BLANK", 2: "JERSEY", 3: "STRIPES", 4: "HOODIE", 5: "SPACE", 6: "GOLD"}
	state["ball"] = {}
	for i in 6:
		state["players"][i + 1] = {"pos": Vector3(-4.6 + i * 1.85, 0, 0), "vel": Vector3.ZERO, "facing": Vector3.BACK, "grounded": true}
	for i in 45:
		world.present(state, 0, 1.0 / 60.0, 0, .43)
		world.camera.position = Vector3(0, 4.3, 10.5)
		world.camera.look_at(Vector3(0, .9, 0))
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/world_cosmetics.png")
	# Equipment changes must preserve the player root and camera anchors.
	var saved_actor: Node3D = world.actors[1]["root"]
	state["cosmetics"][1] = {"outfit": "blank", "accessory": "sweatband"}
	world.present(state, 1, 1.0 / 60.0, 0, .43)
	assert(saved_actor == world.actors[1]["root"])
	assert(world.actors[1]["costume"].get_child_count() > 0)
	assert(world.temporary_pads.is_empty() and world.power_orbs.is_empty())
	state["mode"] = "teams"
	state["players"][3]["team"] = 1
	state["players"][4]["team"] = 0
	world.present(state, 1, 1.0 / 60.0, 0, .43)
	assert(world.actors[3]["team"] == 1 and world.actors[4]["team"] == 0)
	for point in [Vector2(-11, 3), Vector2(-6.8, 0), Vector2(9, -10), Vector2(0, 21)]:
		assert(absf(world._floor_height(point.x, point.y) - world.floor_model.floor_height(point.x, point.y)) < .001)
	world.build("versus")
	state["mode"] = "versus"
	world.present(state, 1, 1.0 / 60.0, 0, .43)
	world.present({}, 0, 1.0 / 60.0, 0, .43)
	print("WORLD_METRICS: scene nodes=", world.get_child_count(), " draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("WORLD_RENDER_PASS: overview, follow camera, green/red cached trajectory, dunk windup/slam, all cosmetics, equip identity, teams, terrain parity, giant, power pad/orb, cleanup, mode switch, empty state")
	quit()
