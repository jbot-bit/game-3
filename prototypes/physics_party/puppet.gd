extends Node3D
## Active physical puppet adapted from PiCode9560 (MIT; vendor/picode/LICENSE).
## Input and camera belong to the session. Only the host simulates bodies/joints.
const MODEL: PackedScene=preload("res://prototypes/physics_party/vendor/picode/Character.glb")
const BASE_MOVE_FORCE: float=50.0
const BASE_JUMP_SPEED: float=7.0
const MAX_LINEAR_SPEED: float=22.0
const MAX_ANGULAR_SPEED: float=45.0
const POSE_SECONDS: float=0.05
@export var angular_spring_stiffness: float=3000.0
@export var angular_spring_damping: float=80.0
@export var max_angular_force: float=9999.0
var authoritative: bool=true
var physics_bones: Array[PhysicalBone3D]=[]
var active_arm_left: bool=false
var active_arm_right: bool=false
var grabbing_arm_left: bool=false
var grabbing_arm_right: bool=false
var ragdoll_mode: bool=false
var power_id: String=""
var is_on_floor: bool=false
var _controls: Dictionary={}
var _control_age: float=0.0
var _jump_held: bool=false
var _jump_queued: bool=false
var _jump_cooldown: float=0.0
var _base_mass: Array[float]=[]
var _base_gravity: Array[float]=[]
var _body_offsets: Array[Transform3D]=[]
var _pose_from: Array=[]
var _pose_to: Array=[]
var _shown_pose: Array=[]
var _pose_elapsed: float=POSE_SECONDS
var _direct_presentation: bool=false
var _host_previous: Array=[]
var _host_current: Array=[]
var _render_skel: Skeleton3D
var _visual_position: Vector3
var _has_visual_position: bool=false
var _crew_color: Color=Color("77bdd1")
var _left_target: PhysicsBody3D
var _right_target: PhysicsBody3D
@onready var physical_skel: Skeleton3D=$Physical/Armature/Skeleton3D
@onready var animated_skel: Skeleton3D=$Animated/Armature/Skeleton3D
@onready var animation_tree: AnimationTree=$Animated/AnimationTree
@onready var physical_bone_body: PhysicalBone3D=$"Physical/Armature/Skeleton3D/Physical Bone Body"
@onready var left_hand: PhysicalBone3D=$"Physical/Armature/Skeleton3D/Physical Bone LArm2"
@onready var right_hand: PhysicalBone3D=$"Physical/Armature/Skeleton3D/Physical Bone RArm2"
@onready var left_area: Area3D=$"Physical/Armature/Skeleton3D/Physical Bone LArm2/LGrabArea"
@onready var right_area: Area3D=$"Physical/Armature/Skeleton3D/Physical Bone RArm2/RGrabArea"
@onready var left_joint: PinJoint3D=$Physical/GrabJointLeft
@onready var right_joint: PinJoint3D=$Physical/GrabJointRight
@onready var left_floor: ShapeCast3D=$"Physical/Armature/Skeleton3D/Physical Bone LLeg2/OnFloorLeft"
@onready var right_floor: ShapeCast3D=$"Physical/Armature/Skeleton3D/Physical Bone RLeg2/OnFloorRight"

func _ready() -> void:
	# The following camera must use the same pose the player sees this frame.
	process_priority=-10
	for child: Node in physical_skel.get_children():
		if child is PhysicalBone3D:
			physics_bones.append(child)
			_base_mass.append(child.mass)
			_base_gravity.append(child.gravity_scale)
			_body_offsets.append(child.body_offset)
	for player: Node in find_children("*","AnimationPlayer",true,false):
		player.stop()
		for clip: StringName in player.get_animation_list():
			if clip!="RESET": player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	animation_tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active=authoritative
	if authoritative:
		physical_skel.physical_bones_start_simulation()
		# A separate display skeleton allows smooth host rendering without
		# writing interpolated transforms back into authoritative rigid bodies.
		var shown: Node3D=MODEL.instantiate()
		shown.name="RenderedPuppet"
		shown.transform=$Physical.transform
		add_child(shown)
		var player: AnimationPlayer=shown.get_node("AnimationPlayer")
		player.stop()
		player.process_mode=Node.PROCESS_MODE_DISABLED
		_render_skel=shown.get_node("Armature/Skeleton3D")
		var source_mesh: MeshInstance3D=physical_skel.get_node("Character")
		_render_skel.get_node("Character").mesh=source_mesh.mesh
		source_mesh.hide()
		_host_current=capture_pose()
		_host_previous=_host_current.duplicate()
	else:
		physical_skel.physical_bones_stop_simulation()
		_render_skel=physical_skel
		for bone: PhysicalBone3D in physics_bones:
			bone.collision_layer=0
			bone.collision_mask=0
		left_area.monitoring=false
		right_area.monitoring=false
		left_floor.enabled=false
		right_floor.enabled=false
	_build_face()
	setup_color(_crew_color)
	set_power(power_id)

func setup_color(color: Color) -> void:
	_crew_color=color
	if not is_node_ready(): return
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.8
	var mesh: MeshInstance3D=_render_skel.get_node("Character")
	mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_face() -> void:
	var attachment:=BoneAttachment3D.new()
	attachment.name="Face"
	attachment.bone_name="Head"
	_render_skel.add_child(attachment)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("233e52")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var eye_shape:=SphereMesh.new()
	eye_shape.radius=0.072
	eye_shape.height=0.18
	eye_shape.radial_segments=12
	eye_shape.rings=6
	for side: float in [-1.0,1.0]:
		var eye:=MeshInstance3D.new()
		eye.name="LeftEye" if side<0.0 else "RightEye"
		eye.mesh=eye_shape
		eye.material_override=material
		eye.position=Vector3(side*0.17,0.56,0.61)
		eye.scale=Vector3(1,1,0.45)
		eye.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attachment.add_child(eye)

func set_controls(data: Dictionary) -> void:
	if not authoritative: return
	var move: Variant=data.get("move",Vector2.ZERO)
	if not move is Vector2 or not move.is_finite(): move=Vector2.ZERO
	var yaw: float=float(data.get("yaw",0.0))
	var pitch: float=float(data.get("pitch",0.0))
	var jump: bool=bool(data.get("jump",false))
	if jump and not _jump_held: _jump_queued=true
	_jump_held=jump
	_controls={"move":move.limit_length(1.0),"yaw":yaw if is_finite(yaw) else 0.0,"pitch":clampf(pitch,-PI/2,PI/2) if is_finite(pitch) else 0.0,"left":bool(data.get("left",false)),"right":bool(data.get("right",false)),"limp":bool(data.get("limp",false))}
	_control_age=0.0

func _physics_process(delta: float) -> void:
	if not authoritative: return
	_host_previous=_host_current
	_host_current=capture_pose()
	_control_age+=delta
	if _control_age>0.4:
		_controls={}
		_jump_held=false
	_jump_cooldown=maxf(0.0,_jump_cooldown-delta)
	active_arm_left=bool(_controls.get("left",false))
	active_arm_right=bool(_controls.get("right",false))
	ragdoll_mode=bool(_controls.get("limp",false))
	if ragdoll_mode: release_all()
	else:
		_grab_tick(true,active_arm_left)
		_grab_tick(false,active_arm_right)
	var move: Vector2=_controls.get("move",Vector2.ZERO)
	animation_tree.set("parameters/walking/blend_amount",1.0 if move.length_squared()>0.01 and not ragdoll_mode else 0.0)
	animation_tree.set("parameters/grab_dir/blend_position",clampf(float(_controls.get("pitch",0.0))*2.7,-1,1) if active_arm_left or active_arm_right else 0.0)
	animated_skel.rotation.y=float(_controls.get("yaw",0.0))
	animation_tree.advance(delta)
	is_on_floor=_floor_contact(left_floor) or _floor_contact(right_floor)
	if not ragdoll_mode:
		var move_multiplier: float=1.25 if power_id=="swift" else 1.0
		physical_bone_body.linear_velocity+=Vector3(move.x,0,move.y)*BASE_MOVE_FORCE*move_multiplier*delta
		var damping: float=pow(0.9,delta*60.0)
		physical_bone_body.linear_velocity*=Vector3(damping,1,damping)
		if _jump_queued and is_on_floor and _jump_cooldown<=0.0:
			var speed: float=BASE_JUMP_SPEED*(1.3 if power_id=="spring" else 1.0)
			for bone: PhysicalBone3D in physics_bones: bone.linear_velocity.y+=speed
			_jump_cooldown=0.55
		_springs(delta)
	_jump_queued=false
	for bone: PhysicalBone3D in physics_bones:
		bone.linear_velocity=bone.linear_velocity.limit_length(MAX_LINEAR_SPEED)
		bone.angular_velocity=bone.angular_velocity.limit_length(MAX_ANGULAR_SPEED)

func _springs(delta: float) -> void:
	for bone: PhysicalBone3D in physics_bones:
		if not active_arm_left and str(bone.name).contains("LArm"): continue
		if not active_arm_right and str(bone.name).contains("RArm"): continue
		var desired: Transform3D=animated_skel.global_transform*animated_skel.get_bone_global_pose(bone.get_bone_id())
		var current: Transform3D=bone.global_transform*bone.body_offset.affine_inverse()
		var difference: Basis=desired.basis*current.basis.inverse()
		var force: Vector3=angular_spring_stiffness*difference.get_euler()-angular_spring_damping*bone.angular_velocity
		var boost: float=1.2 if power_id=="grip" and (str(bone.name).contains("Arm")) else 1.0
		bone.angular_velocity+=(force*boost).limit_length(max_angular_force*boost)*delta

func _floor_contact(cast: ShapeCast3D) -> bool:
	for index in cast.get_collision_count():
		if cast.get_collision_normal(index).y>0.5: return true
	return false

func _grab_tick(left: bool, wanted: bool) -> void:
	var joint: PinJoint3D=left_joint if left else right_joint
	var target: PhysicsBody3D=_left_target if left else _right_target
	if not wanted or (not joint.node_b.is_empty() and not is_instance_valid(target)):
		_release_hand(left)
		return
	if not joint.node_b.is_empty(): return
	var area: Area3D=left_area if left else right_area
	var hand: PhysicalBone3D=left_hand if left else right_hand
	for candidate: Node3D in area.get_overlapping_bodies():
		if not candidate is PhysicsBody3D: continue
		if candidate is PhysicalBone3D and candidate.get_parent()==physical_skel: continue
		joint.global_position=area.global_position
		joint.node_a=hand.get_path()
		joint.node_b=candidate.get_path()
		if left:
			_left_target=candidate
			grabbing_arm_left=true
		else:
			_right_target=candidate
			grabbing_arm_right=true
		return

func _release_hand(left: bool) -> void:
	var joint: PinJoint3D=left_joint if left else right_joint
	joint.node_a=NodePath()
	joint.node_b=NodePath()
	if left:
		_left_target=null
		grabbing_arm_left=false
	else:
		_right_target=null
		grabbing_arm_right=false

func release_all() -> void:
	if not is_node_ready(): return
	_release_hand(true)
	_release_hand(false)

func release_grabs_to(other: Node) -> void:
	if not is_node_ready() or not is_instance_valid(other): return
	if is_instance_valid(_left_target) and (other==_left_target or other.is_ancestor_of(_left_target)):
		_release_hand(true)
	if is_instance_valid(_right_target) and (other==_right_target or other.is_ancestor_of(_right_target)):
		_release_hand(false)

func body_position() -> Vector3:
	if not authoritative and not _shown_pose.is_empty(): return _shown_pose[0].origin
	return physical_bone_body.global_position if is_node_ready() else global_position

func visual_position() -> Vector3:
	return _visual_position if _has_visual_position else body_position()

func capture_pose() -> Array:
	if not authoritative and not _shown_pose.is_empty(): return _shown_pose.duplicate()
	var result: Array=[]
	for bone: PhysicalBone3D in physics_bones: result.append(bone.global_transform)
	return result

func apply_pose(pose: Array) -> void:
	if authoritative or _direct_presentation or not _valid_pose(pose): return
	if _pose_to.is_empty() or _pose_to[0].origin.distance_to(pose[0].origin)>8.0:
		_pose_to=pose.duplicate()
		_pose_from=pose.duplicate()
		_shown_pose=pose.duplicate()
		_pose_elapsed=POSE_SECONDS
		_render_pose(_shown_pose)
	else:
		_pose_from=_shown_pose.duplicate() if not _shown_pose.is_empty() else _pose_to.duplicate()
		_pose_to=pose.duplicate()
		_pose_elapsed=0.0

func present_pose(pose: Array) -> void:
	if authoritative or not _valid_pose(pose): return
	# The session samples every puppet and held prop from one shared timeline.
	# Do not interpolate that already sampled pose for a second time here.
	_direct_presentation=true
	_shown_pose=pose.duplicate()
	_render_pose(_shown_pose)

func _valid_pose(pose: Array) -> bool:
	if pose.size()!=10: return false
	for item: Variant in pose:
		if not item is Transform3D or not item.origin.is_finite() or not item.basis.is_finite(): return false
	return true

func _process(delta: float) -> void:
	if authoritative:
		if _host_current.size()!=10 or _host_previous.size()!=10: return
		var shown: Array=[]
		var fraction: float=clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0)
		for index in 10: shown.append(_host_previous[index].interpolate_with(_host_current[index],fraction))
		_render_pose(shown)
	elif not _direct_presentation and not _pose_to.is_empty():
		_pose_elapsed=minf(POSE_SECONDS,_pose_elapsed+maxf(0.0,delta))
		_shown_pose=[]
		for index in 10: _shown_pose.append(_pose_from[index].interpolate_with(_pose_to[index],_pose_elapsed/POSE_SECONDS))
		_render_pose(_shown_pose)

func _render_pose(pose: Array) -> void:
	if _render_skel==null or pose.size()!=10: return
	_visual_position=pose[0].origin
	_has_visual_position=true
	var local: Transform3D=_render_skel.global_transform.affine_inverse()
	for index in 10:
		_render_skel.set_bone_global_pose_override(physics_bones[index].get_bone_id(),local*pose[index]*_body_offsets[index].affine_inverse(),1.0,true)
	_render_skel.force_update_all_bone_transforms()

func reset_at(point: Vector3) -> void:
	if not authoritative or not point.is_finite() or not is_node_ready(): return
	release_all()
	_controls={}
	_jump_held=false
	_jump_queued=false
	var offset: Vector3=point-physical_bone_body.global_position
	for bone: PhysicalBone3D in physics_bones:
		var moved: Transform3D=bone.global_transform
		moved.origin+=offset
		# PhysicalBone sync can overwrite a Node3D transform changed between
		# physics ticks. Teleport the authoritative server body as well.
		PhysicsServer3D.body_set_state(bone.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,moved)
		bone.global_transform=moved
		bone.linear_velocity=Vector3.ZERO
		bone.angular_velocity=Vector3.ZERO
		PhysicsServer3D.body_set_state(bone.get_rid(),PhysicsServer3D.BODY_STATE_SLEEPING,false)
	_host_current=capture_pose()
	_host_previous=_host_current.duplicate()
	_render_pose(_host_current)

func set_power(id: String) -> void:
	power_id=id if id in ["spring","heavy","swift","feather","grip"] else ""
	for index in physics_bones.size():
		physics_bones[index].mass=_base_mass[index]*(1.7 if power_id=="heavy" else 1.0)
		physics_bones[index].gravity_scale=_base_gravity[index]*(0.7 if power_id=="feather" else 1.0)

func _exit_tree() -> void:
	if is_node_ready(): release_all()
