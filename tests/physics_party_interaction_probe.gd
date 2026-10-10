extends SceneTree
## Contact fixtures and ordinary control inputs; no direct joint/velocity edits.
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
var actor: Node3D
var controls: Dictionary = {}
var failures: Array[String] = []
var checks: int = 0
var evidence: Dictionary = {}
var camera: Camera3D

func _initialize() -> void: call_deferred("run_probe")

func run_probe() -> void:
	_box(false, "Floor", Vector3(0,-0.5,0), Vector3(45,1,45), Color("c5c4b1"))
	_box(false, "Ledge", Vector3(12,1.5,0), Vector3(8,3,6), Color("73c7b0"))
	if DisplayServer.get_name() != "headless":
		root.size=Vector2i(960,540)
		root.gui_disable_input=true
		var world_environment:=WorldEnvironment.new()
		var sky:=Environment.new()
		sky.background_mode=Environment.BG_COLOR
		sky.background_color=Color("99bec8")
		sky.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		sky.ambient_light_color=Color.WHITE
		sky.ambient_light_energy=0.65
		world_environment.environment=sky
		root.add_child(world_environment)
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-45,-25,0)
		root.add_child(light)
		camera=Camera3D.new()
		camera.current=true
		root.add_child(camera)
	actor=Puppet.instantiate()
	actor.authoritative=true
	root.add_child(actor)
	actor.setup_color(Color("ef805f"))
	actor.reset_at(Vector3(0,4,0))
	await ticks(150)
	var standing: float=actor.body_position().y
	check(actor.is_on_floor, "fixture starts with actual floor contact")
	await test_grab_priority()
	actor.reset_at(Vector3(0,4,0))
	controls={}
	await ticks(3)
	var buffered: bool=false
	var pressed_y: float=0.0
	for tick in 150:
		if not actor.is_on_floor and actor.physical_bone_body.linear_velocity.y < -0.5 and actor.body_position().y < standing+0.6:
			buffered=true
			pressed_y=actor.body_position().y
			break
		await ticks(1)
	check(buffered,"landing fixture reaches airborne input window")
	controls={"jump":true}
	await ticks(1)
	controls={}
	var landing_peak: float=actor.body_position().y
	var peak_up_speed: float=-100.0
	var first_contact_tick: int=-1
	for tick in 45:
		await ticks(1)
		landing_peak=maxf(landing_peak,actor.body_position().y)
		peak_up_speed=maxf(peak_up_speed,actor.physical_bone_body.linear_velocity.y)
		if first_contact_tick<0 and actor.is_on_floor: first_contact_tick=tick
	check(landing_peak>pressed_y+0.25,"a jump tapped just before landing launches after floor contact")
	check(first_contact_tick>=0 and first_contact_tick<=5,"landing input is within the intended 120 ms buffer")
	evidence.landing_jump={"pressed_y":pressed_y,"peak_y":landing_peak,"peak_up_speed":peak_up_speed,"first_contact_tick":first_contact_tick}
	await capture("landing")
	await ticks(90)
	actor.reset_at(Vector3(12,5.0,0))
	await ticks(120)
	check(actor.is_on_floor,"ledge fixture settles on elevated support")
	controls={"move":Vector2(0,-1),"yaw":0.0}
	var left_ledge: bool=false
	for tick in 180:
		await ticks(1)
		if not actor.is_on_floor:
			left_ledge=true
			break
	check(left_ledge,"ordinary walking leaves the raised ledge")
	await ticks(3)
	var ledge_y: float=actor.body_position().y
	controls={"move":Vector2(0,-1),"jump":true}
	await ticks(1)
	controls={}
	var ledge_peak: float=actor.body_position().y
	for tick in 18:
		await ticks(1)
		ledge_peak=maxf(ledge_peak,actor.body_position().y)
	check(ledge_peak>ledge_y+0.25,"jump still responds three ticks after walking off the ledge")
	evidence.ledge_jump={"pressed_y":ledge_y,"peak_y":ledge_peak}
	await capture("ledge")
	controls={}
	await ticks(120)
	print("INTERACTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"limits":"One physical puppet, real broadphase overlaps and landing/ledge contacts, scripted controls. Not family play or a LAN latency rating."}))
	quit(0 if failures.is_empty() else 1)

func test_grab_priority() -> void:
	var trials: Array=[]
	var overlap_trials: int=0
	var movable_wins: int=0
	for trial in 4:
		actor.reset_at(Vector3(0,3,0))
		controls={}
		await ticks(80)
		var hand: Vector3=actor.left_area.global_position
		var support: PhysicsBody3D
		var prop: PhysicsBody3D
		if trial%2==0:
			support=_box(false,"Support",hand+Vector3(0,-0.18,0),Vector3(0.5,0.16,0.5),Color("233e52"))
			prop=_box(true,"Movable",hand+Vector3(0,0.05,0),Vector3(0.20,0.20,0.20),Color("f0ba4b"))
		else:
			prop=_box(true,"Movable",hand+Vector3(0,0.05,0),Vector3(0.20,0.20,0.20),Color("f0ba4b"))
			support=_box(false,"Support",hand+Vector3(0,-0.18,0),Vector3(0.5,0.16,0.5),Color("233e52"))
		await ticks(3)
		var overlaps: Array=actor.left_area.get_overlapping_bodies()
		var both: bool=overlaps.has(prop) and overlaps.has(support)
		if both: overlap_trials+=1
		controls={"left":true}
		await ticks(1)
		var target: Node=actor.get("_left_target")
		if both and target==prop: movable_wins+=1
		var names: Array=[]
		for body: Node in overlaps: names.append(str(body.name))
		trials.append({"both_overlap":both,"overlap_order":names,"selected":str(target.name) if is_instance_valid(target) else "none"})
		await capture("grab")
		controls={}
		await ticks(2)
		prop.queue_free()
		support.queue_free()
		await ticks(2)
	check(overlap_trials>=2,"at least two real hand overlaps contain both prop and support")
	check(overlap_trials>0 and movable_wins==overlap_trials,"movable props win over a nearby static support in either creation order")
	evidence.grabs=trials

func _box(movable: bool,label: String,at: Vector3,size: Vector3,color: Color) -> PhysicsBody3D:
	var body: PhysicsBody3D=RigidBody3D.new() if movable else StaticBody3D.new()
	body.name=label
	if body is RigidBody3D: body.mass=0.35
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	visual.material_override=material
	body.add_child(visual)
	root.add_child(body)
	body.global_position=at
	return body

func ticks(count: int) -> void:
	for tick in count:
		actor.set_controls(controls)
		await physics_frame

func capture(label: String) -> void:
	if camera==null: return
	camera.position=actor.visual_position()+Vector3(4,2.5,-6)
	camera.look_at(actor.visual_position()+Vector3(0,0.3,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/hands-full-interaction-"+label+".png")

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
	print("INTERACTION_CHECK "+("PASS " if value else "FAIL ")+label)
