extends SceneTree
var failures: Array[String]=[]
var checks: int=0
var host: Node3D
var remote: Node3D
var report: Dictionary={}
var held_controls: Dictionary={}
var camera: Camera3D

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists("res://prototypes/physics_party/puppet.gd"):
		_check(false,"party puppet implementation exists")
		_finish()
		return
	var scene: PackedScene=load("res://prototypes/physics_party/puppet.tscn")
	if scene==null:
		_check(false,"party puppet scene loads")
		_finish()
		return
	var floor_body:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(60,1,60)
	shape.shape=box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	floor_body.position.y=-0.5
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(960,540)
		root.gui_disable_input=true
		var floor_mesh:=MeshInstance3D.new()
		var floor_box:=BoxMesh.new()
		floor_box.size=box.size
		floor_mesh.mesh=floor_box
		floor_body.add_child(floor_mesh)
		var environment:=WorldEnvironment.new()
		var sky:=Environment.new()
		sky.background_mode=Environment.BG_COLOR
		sky.background_color=Color("77949e")
		sky.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		sky.ambient_light_color=Color.WHITE
		sky.ambient_light_energy=0.8
		environment.environment=sky
		root.add_child(environment)
		var sun:=DirectionalLight3D.new()
		sun.rotation_degrees=Vector3(-45,-30,0)
		root.add_child(sun)
		camera=Camera3D.new()
		camera.current=true
		root.add_child(camera)
	host=scene.instantiate()
	host.authoritative=true
	host.position=Vector3(0,4,0)
	root.add_child(host)
	host.setup_color(Color("ef7657"))
	await _ticks(180)
	_check(host.capture_pose().size()==10,"ten authoritative physical body transforms")
	_check(_finite(host.capture_pose()),"settled puppet has finite body transforms")
	_check(host.has_method("visual_position"),"camera can read the actual rendered torso position")
	_check(host.process_priority<0,"puppet display updates before the parent camera")
	_check_blank_person(host,Color("ef7657"),"host")
	await _capture("settled")
	await _capture("face-front")
	if "--face-only" in OS.get_cmdline_user_args():
		_finish()
		return
	var start: Vector3=host.body_position()
	_hold({"move":Vector2(0,-1),"yaw":0.0})
	await _ticks(90)
	var moved: float=Vector2(host.body_position().x-start.x,host.body_position().z-start.z).length()
	_check(moved>1.5,"world-space movement travels at least1.5m")
	await _capture("walking")
	_hold({})
	await _ticks(60)
	var jump_start: float=host.body_position().y
	_hold({"jump":true})
	await _ticks(12)
	_check(host.body_position().y>jump_start+0.35,"jump edge raises the physical body")
	await _ticks(180)
	_check(absf(host.body_position().y-jump_start)<0.5,"held jump does not repeat after landing")
	_hold({"left":true})
	await _ticks(12)
	var bar:=StaticBody3D.new()
	var bar_shape:=CollisionShape3D.new()
	var bar_box:=BoxShape3D.new()
	bar_box.size=Vector3(0.65,0.3,0.3)
	bar_shape.shape=bar_box
	bar.add_child(bar_shape)
	root.add_child(bar)
	bar.global_position=host.get_node("Physical/Armature/Skeleton3D/Physical Bone LArm2/LGrabArea").global_position
	var bar_mesh:=MeshInstance3D.new()
	var bar_box_mesh:=BoxMesh.new()
	bar_box_mesh.size=bar_box.size
	bar_mesh.mesh=bar_box_mesh
	bar.add_child(bar_mesh)
	await _ticks(12)
	_check(not host.get_node("Physical/GrabJointLeft").node_b.is_empty(),"left grab makes a physical joint")
	await _capture("grab")
	_hold({})
	await _ticks(6)
	_check(host.get_node("Physical/GrabJointLeft").node_b.is_empty(),"released grab clears the physical joint")
	bar.queue_free()
	_hold({"limp":true})
	await _ticks(60)
	var limp_y: float=host.body_position().y
	_hold({})
	await _ticks(120)
	_check(host.body_position().y>limp_y+0.4,"explicit limp release recovers upright")
	remote=scene.instantiate()
	remote.authoritative=false
	root.add_child(remote)
	remote.setup_color(Color("73bfda"))
	var pose: Array=host.capture_pose()
	remote.apply_pose(pose)
	await _ticks(8)
	_check(remote.body_position().distance_to(host.body_position())<0.4,"remote torso reconstructs host body pose")
	var skel: Skeleton3D=remote.get_node("Physical/Armature/Skeleton3D")
	var bodies: Array=skel.get_children().filter(func(node: Node): return node is PhysicalBone3D)
	var largest_error: float=0.0
	for index in bodies.size():
		var body: PhysicalBone3D=bodies[index]
		var expected: Transform3D=pose[index]*body.body_offset.affine_inverse()
		var shown: Transform3D=skel.global_transform*skel.get_bone_global_pose(body.get_bone_id())
		largest_error=maxf(largest_error,expected.origin.distance_to(shown.origin))
		_check(body.collision_layer==0 and body.collision_mask==0,"remote bone cannot collide")
	_check(largest_error<0.05,"remote skin uses inverse physical-body offsets")
	_check_blank_person(remote,Color("73bfda"),"remote")
	host.setup_color(Color("af8ce5"))
	_check_blank_person(host,Color("af8ce5"),"recolored host")
	_check(remote._render_skel.get_node("Character").material_override.albedo_color==Color("73bfda"),"changing host color does not recolor another player")
	if host.has_method("visual_position") and remote.has_method("visual_position"):
		_check(remote.visual_position().distance_to(pose[0].origin)<0.05,"remote camera position matches rendered torso")
		var halfway: Array=pose.duplicate()
		for index in halfway.size(): halfway[index].origin+=Vector3(0.37,0,0)
		var authoritative_position: Vector3=host.body_position()
		host._render_pose(halfway)
		_check(host.visual_position().distance_to(halfway[0].origin)<0.001,"host camera position uses the precise interpolated pose")
		_check(host.body_position().distance_to(authoritative_position)<0.001,"render smoothing cannot change authoritative body position")
	var shifted: Array=pose.duplicate()
	for index in shifted.size(): shifted[index].origin+=Vector3(2,0,0)
	remote.apply_pose(shifted)
	await create_timer(0.10).timeout
	_check(remote.body_position().distance_to(shifted[0].origin)<0.08,"remote interpolation reaches its newest pose")
	await _capture("host-and-remote")
	_check(remote.has_method("present_pose"),"shared network timeline can present a remote pose directly")
	if remote.has_method("present_pose"):
		var presented: Array=shifted.duplicate()
		for index in presented.size(): presented[index].origin+=Vector3(0.41,0,0)
		remote.present_pose(presented)
		await _ticks(6)
		_check(remote.visual_position().distance_to(presented[0].origin)<0.001,"direct presentation is not overwritten by the old arrival lerp")
		_check(remote.body_position().distance_to(presented[0].origin)<0.001,"direct presentation also updates remote body position")
		var invalid: Array=presented.duplicate()
		invalid[2].origin.x=NAN
		remote.present_pose(invalid)
		_check(_finite(remote.capture_pose()),"direct presentation rejects non-finite bone transforms")
		var before_host: Vector3=host.body_position()
		host.present_pose(presented)
		_check(host.body_position().distance_to(before_host)<0.001,"direct presentation cannot modify authoritative simulation")
	var base_mass: float=host.physics_bones[0].mass
	host.set_power("heavy")
	_check(is_equal_approx(host.physics_bones[0].mass,base_mass*1.7),"heavy applies mass bonus")
	host.set_power("feather")
	_check(is_equal_approx(host.physics_bones[0].mass,base_mass),"changing power clears old mass bonus")
	_check(is_equal_approx(host.physics_bones[0].gravity_scale,0.7),"feather applies gravity bonus")
	host.set_power("")
	_check(is_equal_approx(host.physics_bones[0].gravity_scale,1.0),"clearing power restores gravity")
	await process_frame
	host.reset_at(Vector3(5,3,5))
	_check(host.body_position().distance_to(Vector3(5,3,5))<0.05,"reset translates torso to requested location")
	_check(_finite(host.capture_pose()),"reset leaves finite whole-body pose")
	_hold({})
	await _ticks(8)
	var reset_position: Vector3=host.body_position()
	_check(Vector2(reset_position.x-5,reset_position.z-5).length()<0.3,"render-frame reset persists after physics synchronization")
	await _ticks(90)
	# A real second authoritative puppet is deliberately placed at the hand;
	# this checks friend physics/ownership, not autonomous navigation skill.
	var friend: Node3D=scene.instantiate()
	friend.authoritative=true
	friend.position=Vector3(15,4,0)
	root.add_child(friend)
	friend.setup_color(Color("af8ce5"))
	await _ticks(90)
	_hold({"left":true,"right":true})
	await _ticks(12)
	var right_bar:=StaticBody3D.new()
	var right_bar_shape:=CollisionShape3D.new()
	var right_bar_box:=BoxShape3D.new()
	right_bar_box.size=Vector3(0.5,0.3,0.3)
	right_bar_shape.shape=right_bar_box
	right_bar.add_child(right_bar_shape)
	root.add_child(right_bar)
	right_bar.global_position=host.right_area.global_position
	await _ticks(8)
	var unrelated: NodePath=host.right_joint.node_b
	_check(not unrelated.is_empty(),"right hand establishes unrelated prop constraint")
	friend.reset_at(host.left_area.global_position+Vector3(0,0,0.15))
	await _ticks(8)
	var grabbed_friend: Node=host.get_node_or_null(host.left_joint.node_b) if not host.left_joint.node_b.is_empty() else null
	_check(grabbed_friend is PhysicalBone3D and friend.is_ancestor_of(grabbed_friend),"left hand grabs a real second puppet bone")
	_check(_finite(host.capture_pose()) and _finite(friend.capture_pose()),"friend contact keeps both articulated bodies finite")
	_check(host.has_method("release_grabs_to"),"recovery can detach only the affected puppet")
	if host.has_method("release_grabs_to"):
		host.release_grabs_to(friend)
		_check(host.left_joint.node_b.is_empty(),"targeted recovery detaches the grabbed friend")
		_check(host.right_joint.node_b==unrelated,"targeted recovery preserves unrelated prop constraint")
	friend.queue_free()
	await _ticks(4)
	_check(host.left_joint.node_b.is_empty(),"disconnecting a grabbed friend releases its joint")
	host.release_grabs_to(right_bar)
	_check(host.right_joint.node_b.is_empty(),"targeted release also accepts the held body itself")
	_hold({})
	right_bar.queue_free()
	report={"movement_m":moved,"remote_skin_position_error_m":largest_error,"checks":checks,"failures":failures}
	_finish()

func _finite(pose: Array) -> bool:
	for body: Transform3D in pose:
		if not body.origin.is_finite() or not body.basis.is_finite(): return false
	return true

func _check_blank_person(person: Node3D, color: Color, label: String) -> void:
	var mesh: MeshInstance3D=person._render_skel.get_node("Character")
	_check(mesh.is_visible_in_tree(),label+" displays the continuous humanoid skin")
	_check(mesh.material_override is StandardMaterial3D,label+" uses a plain body material")
	if mesh.material_override is StandardMaterial3D:
		var material: StandardMaterial3D=mesh.material_override
		_check(material.albedo_color==color,label+" has the requested single body color")
		_check(material.roughness>=0.8 and material.metallic==0.0 and not material.emission_enabled,label+" has a matte nonmetallic body")
	_check(person._render_skel.find_children("Face","",true,false).is_empty(),label+" has no face or eyes")
	_check(person._render_skel.find_children("Gear*","",true,false).is_empty(),label+" has no clothing or gear attachments")
	_check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,label+" casts a body shadow")

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame
		if is_instance_valid(host): host.set_controls(held_controls)

func _hold(data: Dictionary) -> void:
	held_controls=data
	host.set_controls(data)

func _capture(label: String) -> void:
	if camera==null: return
	camera.position=host.body_position()+Vector3(5,3,7)
	camera.look_at(host.body_position()+Vector3(0.7,0,0))
	if label=="face-front":
		camera.position=host.body_position()+Vector3(2.2,1.8,-6)
		camera.look_at(host.body_position()+Vector3(0,0.5,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/research/party-puppet-"+label+".png")

func _check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
	print("PUPPET_CHECK "+("PASS " if value else "FAIL ")+label)

func _finish() -> void:
	print("PUPPET_PROBE_RESULT "+JSON.stringify(report if not report.is_empty() else {"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
