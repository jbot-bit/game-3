extends SceneTree
const Court = preload("res://world.gd")
const IDS = ["evie","tyler","dad"]
const OUTFITS = ["blank","jersey","stripes","hoodie","space","gold"]
const ACCESSORIES = ["none","cap","sweatband","shades","headphones","horns","crown"]
var court
var evidence = "C:/game-3/build/crown-court-evidence/family-visual"
var capture_enabled = false
var checks = 0
var failures = 0

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture_enabled = true
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok, label):
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func capture(label):
	if not capture_enabled: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func run():
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1440,900)
	court = Court.new()
	root.add_child(court)
	court.actor_root = Node3D.new()
	court.add_child(court.actor_root)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bcdbe1")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .18
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,155,0)
	light.light_energy = .16
	light.shadow_enabled = true
	root.add_child(light)
	var fill = OmniLight3D.new()
	fill.position = Vector3(-3,3,-4)
	fill.light_energy = 0.0
	fill.omni_range = 15
	root.add_child(fill)
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color("718b9b")
	floor_mesh.material_override = floor_material
	root.add_child(floor_mesh)
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(0,2.0,-7)
	camera.look_at(Vector3(0,1.0,0))
	for i in 3:
		var actor = court._make_actor(i+1)
		actor.root.position.x = (1-i)*1.65
		actor.label.text = IDS[i].capitalize()
		court._equip_actor(actor,i+1,{"character":IDS[i],"outfit":"blank","accessory":"none"})
	for angle in [0,18,90,180]:
		for actor in court.actors.values(): actor.rig.rotation_degrees.y = angle
		await capture("starter-%d" % angle)
	for actor in court.actors.values(): actor.rig.rotation.y = 0
	for outfit in OUTFITS:
		for accessory in ACCESSORIES:
			for i in 3:
				var actor = court.actors[i+1]
				court._equip_actor(actor,i+1,{"character":IDS[i],"outfit":outfit,"accessory":accessory})
				check(actor.character == IDS[i],"identity retained")
				check(not actor.face.visible,"generic face hidden")
				check(actor.identity.find_children("Mouth*","MeshInstance3D",true,false).size()==1,"explicit visible mouth for "+IDS[i])
				check(actor.identity.transform.is_finite(),"finite identity")
			await capture(outfit+"-"+accessory)
			await process_frame
	for actor in court.actors.values():
		court._equip_actor(actor,1,{"character":"blank"})
		check(actor.face.visible and actor.identity == null,"blank restored")
	var f = FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"combinations":126,"native_captures":capture_enabled},"  "))
	f.close()
	print("FAMILY_VISUAL ",checks," checks, ",failures," failures")
	court.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
