extends SceneTree
## Presentation contract check; no networking or save writes.
const Art = preload("res://game/world/block_art.gd")
const World = preload("res://game/world/island.gd")
const Crew = preload("res://game/player/player.gd")
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	if not FileAccess.file_exists("res://game/world/gameplay_effects.gd"):
		push_error("Missing gameplay effects implementation")
		quit(1)
		return
	var Effects: Script = load("res://game/world/gameplay_effects.gd")
	if Effects == null or not Effects.can_instantiate():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var scene: Node3D = Node3D.new()
	root.add_child(scene)
	var world: Node3D = World.new()
	scene.add_child(world)
	var avatars: Dictionary = {}
	var colors: Array[Color] = [Color("62b9db"), Color("e67c61"), Color("a28ad6")]
	for index: int in range(3):
		var avatar: Node3D = Crew.new()
		scene.add_child(avatar)
		avatar.call("setup", "crew_%s" % (index + 1), colors[index])
		avatar.position = Vector3(-59.0 - float(index) * 1.8, 2.05, 4.0 + float(index))
		avatar.rotation.y = -PI / 2.0
		avatar.set_physics_process(false)
		avatars["crew_%s" % (index + 1)] = avatar
	var effects: Node3D = Effects.new()
	scene.add_child(effects)
	var data: Dictionary = {"run":{"run_id":"probe", "elapsed_s":320.0, "phase":"night", "paused":false, "crossing_left":-1, "players":{"crew_1":{"aboard":true},"crew_2":{"aboard":true},"crew_3":{"aboard":true}}}, "fishing":{"crew_1":{"elapsed":3.0,"tension":0.7,"pull":0.4}}, "progression":{"profiles":{"crew_1":{"role_id":"scout"}}}, "abilities":{"ready_at":{"crew_1":348.0},"keeper_until":324.0}, "keeper_position":Vector3(-60,2.05,5), "poses":{"hunter":Transform3D(Basis.IDENTITY,Vector3(-65,2.05,-12))}, "cargo":{}, "cosmetic_catches":[{"catch_id":"odd_probe","profile_id":"crew_2","species_id":"bellgill","odd":true}], "director":"sighting"}
	effects.call("update_view",data,avatars,world,0.1)
	check(effects.has_node("Cast_crew_1/Bobber"), "An active cast needs a visible bobber")
	check(effects.has_node("Cast_crew_1/Line0"), "An active cast needs a rod-to-water line")
	check(effects.get_node("KeeperZone").visible, "Keeper safety zone must be visible while active")
	check(effects.get_node("ScoutCue").visible, "Scout activation must mark the hunter")
	check(effects.get_node("Sighting").visible, "Sighting director event needs a visible silhouette")
	check(effects.has_node("Odd_odd_probe/BlockFish/OddHat"), "Odd packed catches need a visible silly fish")
	var focus: Vector3 = effects.call("cast_focus","crew_1")
	check(focus.x > -56.0 and focus.y < 0.8, "Jetty bobber must be on lagoon water")
	# A second cast may arrive in the next snapshot without an empty frame.
	data.fishing.crew_1.catch_id="next-cast"
	data.fishing.crew_1.habitat_id="tidepools"
	effects.call("update_view",data,avatars,world,0.1)
	check(effects.call("cast_focus","crew_1")==world.fishing_focus("tidepools"),"New catch ID replaces the old cast's habitat focus")
	await process_frame
	var fish: Node3D = Art.fish("bellgill",true)
	var art: RefCounted = Art.new()
	art.call("add_odd_appearance",fish,"bellgill")
	art.call("add_odd_appearance",fish,"bellgill")
	check(fish.get_node("OddHat").get_child_count() == 3,"Odd appearance must be idempotent")
	fish.free()
	var camera: Camera3D = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(-66,6,11)
	camera.look_at(Vector3(-55,2.0,4.5))
	camera.fov = 65
	camera.current = true
	if "--render" in OS.get_cmdline_user_args():
		for mode: String in ["day","night"]:
			world.call("set_time",100.0 if mode == "day" else 320.0)
			await capture("effects-" + mode)
	var skiff: Node3D = world.get_node("MothSkiff") as Node3D
	var start: Transform3D = skiff.transform
	var actor_start: Vector3 = (avatars.crew_1 as Node3D).global_position
	var trophy_body: RigidBody3D = RigidBody3D.new()
	trophy_body.name = "Fish_whole_probe"
	trophy_body.freeze = true
	scene.add_child(trophy_body)
	trophy_body.add_child(Art.fish("bellgill", true))
	trophy_body.position = Vector3(-58,3,4)
	data.cargo = {"whole_probe":{"state":"whole_held","carrier_id":"crew_1","catch_record":{"species_id":"bellgill"}}}
	data.cosmetic_catches.append({"catch_id":"whole_probe","profile_id":"crew_1","species_id":"bellgill","odd":true})
	data.run.phase = "refuge"
	data.run.crossing_left = 10.0
	effects.call("update_view",data,avatars,world,0.1)
	check(skiff.position.distance_to(start.origin) > 10.0, "Refuge crossing must visibly move the boat")
	check(effects.call("refuge_target") == skiff,"Camera target must follow the skiff")
	check((avatars.crew_1 as Node3D).global_position == actor_start,"Presentation must never move authoritative avatars")
	check(not avatars.crew_1.visual.visible,"Aboard avatar should not be duplicated on the dock")
	check(skiff.has_node("RefugeCrew"),"Crossing needs visible crew aboard")
	check(not trophy_body.visible, "Carried authoritative fish should not be duplicated on the dock")
	check(skiff.has_node("RefugeCrew/crew_1/BlockFish/OddHat"),"Crossing should show the carried odd fish aboard")
	if "--render" in OS.get_cmdline_user_args():
		camera.position = skiff.position + Vector3(7,5,10)
		camera.look_at(skiff.position + Vector3(0,1.5,0))
		await capture("effects-refuge")
	# Successful arrival banks and deletes physical catch bodies before dawn.
	trophy_body.queue_free()
	await process_frame
	data.run.phase = "day"
	data.run.elapsed_s = 0.0
	data.run.run_id = "next_day"
	data.run.crossing_left = -1.0
	data.fishing = {}
	data.abilities = {}
	data.cosmetic_catches = []
	data.director = ""
	effects.call("update_view",data,avatars,world,0.1)
	await process_frame
	check(skiff.transform.is_equal_approx(start),"Next dawn must restore the skiff")
	check(avatars.crew_1.visual.visible,"Next dawn must restore aboard avatar visuals")
	check(not effects.has_node("Cast_crew_1"),"Ended casts must remove lines and bobbers")
	check(not effects.get_node("KeeperZone").visible,"Expired Keeper zone must disappear")
	check(not effects.get_node("ScoutCue").visible,"Expired Scout cue must disappear")
	check(not effects.get_node("Sighting").visible,"Cleared sighting must disappear")
	if not failed:
		print("GAMEPLAY_EFFECTS_PROBE_OK")
	quit(1 if failed else 0)

func capture(label: String) -> void:
	for frame: int in range(12):
		await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://logs/" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK,"Capture failed: " + path)
	print("EFFECTS_RENDER: " + path)
