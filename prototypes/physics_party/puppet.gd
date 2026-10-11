extends Node3D
## Active physical puppet adapted from PiCode9560 (MIT; vendor/picode/LICENSE).
## Input and camera belong to the session. Only the host simulates bodies/joints.
const MODEL: PackedScene=preload("res://prototypes/physics_party/vendor/picode/Character.glb")
const RUN_SPEED: float=5.5
const GROUND_ACCELERATION: float=45.0
const GROUND_BRAKING: float=65.0
const AIR_ACCELERATION: float=10.0
const BASE_JUMP_SPEED: float=7.0
const MAX_LINEAR_SPEED: float=22.0
const MAX_ANGULAR_SPEED: float=45.0
const POSE_SECONDS: float=0.05
const JUMP_BUFFER_SECONDS: float=0.12
const LEDGE_GRACE_SECONDS: float=0.10
const Grapple = preload("res://prototypes/physics_party/party_grapple.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
const Accessories = preload("res://prototypes/physics_party/party_accessories.gd")
const Pugil = preload("res://prototypes/physics_party/party_pugil.gd")
var _combat_enabled: bool=false
var _combat_swing: float=0.0
var _combat_braced: bool=false
var _combat_yaw: float=0.0
var _combat_impact_grace: float=0.0
var _padded_stick: Node3D
var grapple: Node3D
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
var _jump_buffer: float=0.0
var _floor_grace: float=0.0
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
var _appearance: Dictionary={}
var _accessory: BoneAttachment3D
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
	grapple=Grapple.new()
	grapple.name="Grapple"
	add_child(grapple)
	setup_color(_crew_color)
	_apply_accessory()
	set_power(power_id)

func setup_color(color: Color) -> void:
	_crew_color=color
	if not is_node_ready(): return
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.8
	var mesh: MeshInstance3D=_render_skel.get_node("Character")
	mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.show()

func set_appearance(style: Dictionary) -> void:
	var color_id: Variant=style.get("color", "orange")
	var color: Color=Cosmetics.color_for(color_id if color_id is String else "orange")
	var accessory_id: String=Accessories.valid_id(style.get("accessory", "none"))
	var previous: String=str(_appearance.get("accessory", "none"))
	_appearance={"color":color_id if color_id is String else "orange", "accessory":accessory_id}
	if not _crew_color.is_equal_approx(color): setup_color(color)
	if is_node_ready() and previous!=accessory_id: _apply_accessory()

func _apply_accessory() -> void:
	if is_instance_valid(_accessory):
		# Detach immediately so a snapshot cannot display two looks for a frame.
		_accessory.get_parent().remove_child(_accessory)
		_accessory.queue_free()
	_accessory=Accessories.build(_render_skel, str(_appearance.get("accessory", "none")))

func set_controls(data: Dictionary) -> void:
	if not authoritative: return
	var move: Variant=data.get("move",Vector2.ZERO)
	if not move is Vector2 or not move.is_finite(): move=Vector2.ZERO
	var yaw: float=float(data.get("yaw",0.0))
	var pitch: float=float(data.get("pitch",0.0))
	var jump: bool=bool(data.get("jump",false))
	if jump and not _jump_held: _jump_buffer=JUMP_BUFFER_SECONDS
	_jump_held=jump
	_controls={"move":move.limit_length(1.0),"yaw":yaw if is_finite(yaw) else 0.0,"pitch":clampf(pitch,-PI/2,PI/2) if is_finite(pitch) else 0.0,"left":bool(data.get("left",false)),"right":bool(data.get("right",false)),"limp":bool(data.get("limp",false))}
	_controls.grapple=bool(data.get("grapple",false))
	_controls.grapple_mode=str(data.get("grapple_mode","pull"))
	_controls.aim=data.get("aim",Vector3.ZERO)
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
	_combat_impact_grace=maxf(0.0,_combat_impact_grace-delta)
	active_arm_left=_combat_enabled or bool(_controls.get("left",false))
	active_arm_right=_combat_enabled or bool(_controls.get("right",false))
	ragdoll_mode=bool(_controls.get("limp",false))
	if ragdoll_mode: release_all()
	else:
		_grab_tick(true,bool(_controls.get("left",false)) and not _combat_enabled)
		_grab_tick(false,bool(_controls.get("right",false)) and not _combat_enabled)
	var move: Vector2=_controls.get("move",Vector2.ZERO)
	animation_tree.set("parameters/walking/blend_amount",1.0 if move.length_squared()>0.01 and not ragdoll_mode else 0.0)
	animation_tree.set("parameters/grab_dir/blend_position",0.0 if _combat_enabled else clampf(float(_controls.get("pitch",0.0))*2.7,-1,1) if active_arm_left or active_arm_right else 0.0)
	animated_skel.rotation.y=float(_controls.get("yaw",0.0))
	animation_tree.advance(delta)
	is_on_floor=_floor_contact(left_floor) or _floor_contact(right_floor)
	_floor_grace=LEDGE_GRACE_SECONDS if is_on_floor else maxf(0.0,_floor_grace-delta)
	if not ragdoll_mode:
		_move_tick(move,delta)
		if _jump_buffer>0.0 and _floor_grace>0.0 and _jump_cooldown<=0.0:
			var speed: float=BASE_JUMP_SPEED*(1.3 if power_id=="spring" else 1.0)
			# A buffered landing jump should not spend its impulse cancelling a
			# fall. Keep upward platform momentum, clear only downward velocity.
			for bone: PhysicalBone3D in physics_bones:
				bone.linear_velocity.y=maxf(0.0,bone.linear_velocity.y)+speed
			_jump_cooldown=0.55
			_jump_buffer=0.0
			_floor_grace=0.0
		_springs(delta)
	else:
		_jump_buffer=0.0
		_floor_grace=0.0
	_jump_buffer=maxf(0.0,_jump_buffer-delta)
	grapple.tick(delta,_controls)
	for bone: PhysicalBone3D in physics_bones:
		bone.linear_velocity=bone.linear_velocity.limit_length(MAX_LINEAR_SPEED)
		bone.angular_velocity=bone.angular_velocity.limit_length(MAX_ANGULAR_SPEED)

func _move_tick(move: Vector2, delta: float) -> void:
	# Drive the ragdoll's shared momentum. Driving only its torso makes input
	# wait for nine other bodies to catch up through the joints.
	var velocity:=Vector3.ZERO
	var total_mass: float=0.0
	for bone: PhysicalBone3D in physics_bones:
		velocity+=bone.linear_velocity*bone.mass
		total_mass+=bone.mass
	if total_mass<=0.0: return
	velocity/=total_mass
	velocity.y=0.0
	var speed: float=RUN_SPEED*(1.25 if power_id=="swift" else 1.0)
	var desired:=Vector3(move.x,0,move.y)*speed
	var change:=Vector3.ZERO
	if (is_on_floor or _floor_grace>0.0) and not grapple.active and _combat_impact_grace<=0.0:
		var braking: bool=move.is_zero_approx() or velocity.dot(desired)<0.0
		change=(desired-velocity).limit_length((GROUND_BRAKING if braking else GROUND_ACCELERATION)*delta)
	elif not move.is_zero_approx():
		# Air steering adds only along the requested direction. Releasing keys
		# cannot erase a jump or swing, and fast grapple launches stay fast.
		var direction: Vector3=desired.normalized()
		var remaining: float=maxf(0.0,desired.length()-velocity.dot(direction))
		change=direction*minf(remaining,AIR_ACCELERATION*delta)
	for bone: PhysicalBone3D in physics_bones:
		bone.linear_velocity+=change

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
		var body: Object=cast.get_collider(index)
		# Crossed legs are not ground; a teammate can still support this puppet.
		if body is PhysicalBone3D and body.get_parent()==physical_skel: continue
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
	var chosen: PhysicsBody3D
	var chosen_priority: int=-1
	var chosen_distance: float=INF
	for candidate: Node3D in area.get_overlapping_bodies():
		if not candidate is PhysicsBody3D: continue
		if candidate is PhysicalBone3D and candidate.get_parent()==physical_skel: continue
		# A floor/support touching the same hand must not steal a prop or rescue.
		# Existing holds stay attached until released; this only selects a new hold.
		var priority: int=1 if candidate is RigidBody3D or candidate is PhysicalBone3D else 0
		var distance: float=area.global_position.distance_squared_to(candidate.global_position)
		if priority>chosen_priority or (priority==chosen_priority and distance<chosen_distance):
			chosen=candidate
			chosen_priority=priority
			chosen_distance=distance
	if chosen==null: return
	joint.global_position=area.global_position
	joint.node_a=hand.get_path()
	joint.node_b=chosen.get_path()
	if left:
		_left_target=chosen
		grabbing_arm_left=true
	else:
		_right_target=chosen
		grabbing_arm_right=true

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
	if is_instance_valid(grapple): grapple.cancel()

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
	_update_stick()

func set_combat_visual(enabled: bool, swing: float=0.0, braced: bool=false, facing_yaw: float=0.0) -> void:
	_combat_enabled=enabled
	_combat_swing=clampf(swing,0.0,1.0) if is_finite(swing) else 0.0
	_combat_braced=braced
	_combat_yaw=facing_yaw if is_finite(facing_yaw) else 0.0
	if enabled and not is_instance_valid(_padded_stick) and is_node_ready(): _padded_stick=Pugil.build_staff(self)
	if is_instance_valid(_padded_stick):
		_padded_stick.visible=enabled
		_update_stick()

func _update_stick() -> void:
	if not _combat_enabled or not is_instance_valid(_padded_stick): return
	var sweep: float=0.0
	if _combat_swing>0.0:
		# A visible wind-up, forward sweep and return share the host swing clock.
		sweep=sin(_combat_swing*TAU-0.4)*1.05
	var facing:=Basis(Vector3.UP,_combat_yaw)
	_padded_stick.global_position=visual_position()+facing*Vector3(0,0.28,-0.9 if _combat_braced else -0.75)
	_padded_stick.global_basis=facing*Basis(Vector3.UP,sweep)
	_padded_stick.rotate_object_local(Vector3.FORWARD,0.08 if _combat_braced else 0.18)

func apply_combat_impact(velocity: Vector3, grace: float=0.34) -> void:
	if not authoritative or not velocity.is_finite() or not is_finite(grace): return
	var bounded: Vector3=velocity.limit_length(12.0)
	_combat_impact_grace=maxf(_combat_impact_grace,clampf(grace,0.0,0.4))
	for bone: PhysicalBone3D in physics_bones:
		bone.linear_velocity=(bone.linear_velocity+bounded).limit_length(MAX_LINEAR_SPEED)

func reset_at(point: Vector3) -> void:
	if not authoritative or not point.is_finite() or not is_node_ready(): return
	release_all()
	_controls={}
	_jump_held=false
	_jump_buffer=0.0
	_floor_grace=0.0
	_combat_impact_grace=0.0
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
