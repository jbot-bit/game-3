class_name Angler
extends CharacterBody3D

const CrewVisual = preload("res://game/player/animated_crew.gd")
const Gear = preload("res://game/progression/equipment.gd")
var profile_id: String = ""
var visual: Node3D
var name_tag: Label3D
var lamp: SpotLight3D
var last_dry: Vector3
var downed: bool = false
var carrying: bool = false
var being_carried: bool = false
var carrying_teammate: bool = false
var cargo_speed: float = 4.25
var _outfit_id: String = ""
var fishing: bool = false
var motion_time: float = 0.0
var desired_position: Vector3
var _render_root: Node3D
var _ground_shadow: MeshInstance3D
static var _shadow_mesh: QuadMesh
static var _shadow_material: ShaderMaterial
var _previous_pose: Transform3D
var _current_pose: Transform3D
var _poses_ready: bool = false
var _network_received: bool = false
var _network_remote: bool = false
var _network_position: Vector3
var _network_yaw: float = 0.0
var _network_from: Transform3D
var _network_to: Transform3D
var _network_elapsed: float = 0.05
var _correction_offset: Vector3 = Vector3.ZERO
var _correction_from: Vector3 = Vector3.ZERO
var _correction_elapsed: float = 0.1

const NETWORK_TRANSITION: float = 0.05
const CORRECTION_TRANSITION: float = 0.1

const ACCELERATION: float = 36.0
const DECELERATION: float = 48.0
const TURN_RESPONSE: float = 18.0

func _ready() -> void:
	# Capture after the authoritative/predicted controller has advanced this tick.
	process_physics_priority = 10
	reset_visual_interpolation()

func _physics_process(_delta: float) -> void:
	if not _poses_ready or _current_pose.origin.distance_to(global_position) > 3.0:
		reset_visual_interpolation()
	else:
		_previous_pose = _current_pose
		_current_pose = global_transform

func _process(delta: float) -> void:
	_network_elapsed=minf(NETWORK_TRANSITION,_network_elapsed+maxf(0.0,delta))
	_correction_elapsed=minf(CORRECTION_TRANSITION,_correction_elapsed+maxf(0.0,delta))
	_correction_offset=_correction_from*(1.0-_correction_elapsed/CORRECTION_TRANSITION)
	if is_instance_valid(_render_root): _render_root.global_transform = render_transform()
	if is_instance_valid(_ground_shadow): _ground_shadow.visible = is_on_floor() and not being_carried and visual.visible

func reset_visual_interpolation() -> void:
	_previous_pose = global_transform
	_current_pose = global_transform
	_poses_ready = true
	_network_from=global_transform
	_network_to=global_transform
	_network_elapsed=NETWORK_TRANSITION
	_correction_offset=Vector3.ZERO
	_correction_from=Vector3.ZERO
	_correction_elapsed=CORRECTION_TRANSITION
	if is_instance_valid(_render_root): _render_root.global_transform = global_transform

func use_local_presentation() -> void:
	# A disconnected client can host from the same scene and reuse its former
	# remote host avatar. Its presentation must follow local physics again.
	_network_received=false
	_network_remote=false
	reset_visual_interpolation()

func render_transform(fraction: float = -1.0) -> Transform3D:
	# Presentation only: collision, held-object transforms and network poses retain
	# the current authoritative transform. A teleport never sweeps the visual map.
	if not _poses_ready or _current_pose.origin.distance_to(global_position) > 3.0:
		return global_transform
	if _network_remote:
		return _network_from.interpolate_with(_network_to,_network_elapsed/NETWORK_TRANSITION)
	var alpha: float = Engine.get_physics_interpolation_fraction() if fraction < 0.0 else fraction
	var shown: Transform3D=_previous_pose.interpolate_with(_current_pose, clampf(alpha, 0.0, 1.0))
	shown.origin+=_correction_offset
	return shown

func apply_network_pose(pose: Dictionary, predicted: bool, reset: bool=false) -> void:
	var before: Transform3D=render_transform(1.0)
	var old_position: Vector3=global_position
	var snap: bool=reset or not _network_received or old_position.distance_to(pose.position)>3.0
	var duplicate: bool=_network_received and _network_position.is_equal_approx(pose.position) and is_equal_approx(_network_yaw,float(pose.yaw))
	# Preserve the existing collision-body correction. Smoothing changes only
	# the displayed pose; it never predicts a remote collider through scenery.
	global_position=global_position.lerp(pose.position,0.85)
	rotation.y=lerp_angle(rotation.y,pose.yaw,0.8)
	velocity=pose.velocity
	_network_received=true
	_network_remote=not predicted
	_network_position=pose.position
	_network_yaw=pose.yaw
	if snap:
		reset_visual_interpolation()
		return
	if _network_remote:
		_network_to=global_transform
		# Reliable state snapshots can repeat the latest 20 Hz pose. Preserve the
		# original endpoint instead of extending presentation lag every 200 ms.
		if not duplicate:
			_network_from=before
			_network_elapsed=0.0
	else:
		# Prediction keeps advancing the body. Absorb a small reconciliation in
		# presentation, then repay it within 100 ms; cap accumulated visual error.
		var correction: Vector3=global_position-old_position
		_previous_pose.origin+=correction
		_current_pose.origin+=correction
		_correction_from=(_correction_offset-correction).limit_length(0.75)
		_correction_offset=_correction_from
		_correction_elapsed=0.0

func setup(id: String, color: Color) -> void:
	profile_id=id
	if _shadow_mesh==null:
		_shadow_mesh=QuadMesh.new()
		_shadow_mesh.size=Vector2(1.35,1.05)
		var shader:=Shader.new()
		shader.code="shader_type spatial; render_mode blend_mix,unshaded,cull_disabled,depth_draw_never; void fragment(){ float edge=length(UV-vec2(0.5)); ALBEDO=vec3(0.06,0.09,0.11); ALPHA=0.24*(1.0-smoothstep(0.12,0.5,edge)); }"
		_shadow_material=ShaderMaterial.new()
		_shadow_material.shader=shader
	_ground_shadow=MeshInstance3D.new()
	_ground_shadow.name="FootShadow"
	_ground_shadow.mesh=_shadow_mesh
	_ground_shadow.material_override=_shadow_material
	_ground_shadow.rotation.x=-PI/2.0
	_ground_shadow.position.y=0.025
	_ground_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_shadow.hide()
	add_child(_ground_shadow)
	collision_layer=2
	collision_mask=1
	var shape=CollisionShape3D.new()
	var capsule=CapsuleShape3D.new()
	capsule.radius=0.38
	capsule.height=1.9
	shape.shape=capsule
	shape.position.y=0.95
	add_child(shape)
	_render_root=Node3D.new()
	_render_root.name="RenderedCrew"
	_render_root.top_level=true
	add_child(_render_root)
	visual=CrewVisual.new()
	visual.configure(color)
	_render_root.add_child(visual)
	name_tag=Label3D.new()
	name_tag.position=Vector3(0,2.65,0)
	name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font_size=28
	name_tag.outline_size=5
	name_tag.pixel_size=0.008
	_render_root.add_child(name_tag)
	lamp=SpotLight3D.new()
	lamp.position=Vector3(0.45,1.5,-0.45)
	lamp.rotation.x=-0.25
	lamp.light_color=Color("ffd071")
	lamp.light_energy=2.5
	lamp.spot_range=8.0
	lamp.spot_angle=35.0
	lamp.shadow_enabled=false
	_render_root.add_child(lamp)

func advance(delta: float, direction: Vector2, _yaw: float, enabled: bool) -> void:
	if being_carried:
		velocity=Vector3.ZERO
		animate(delta,0.0)
		return
	var movable: bool = enabled and not downed and not fishing
	var d: Vector2 = direction.limit_length(1.0) if movable else Vector2.ZERO
	var pace: float = 3.5 if carrying_teammate else (cargo_speed if carrying else 5.0)
	# Ground acceleration/retained facing adapted from GDQuest's MIT controller:
	# gdquest.com/library/character_movement_3d_platformer/ (code only).
	var horizontal := Vector2(velocity.x, velocity.z)
	var response: float = DECELERATION if d.is_zero_approx() or horizontal.dot(d) < 0.0 else ACCELERATION
	horizontal = horizontal.move_toward(d * pace, response * delta).limit_length(pace) if movable else Vector2.ZERO
	velocity.x=horizontal.x
	velocity.z=horizontal.y
	if not is_on_floor(): velocity.y-=22.0*delta
	else: velocity.y=0.0
	if d.length()>0.05:
		rotation.y=lerp_angle(rotation.y,atan2(-d.x,-d.y),1.0-exp(-TURN_RESPONSE*delta))
	var before: Vector3 = global_position
	move_and_slide()
	var travel: Vector3 = global_position-before
	var actual_speed: float = Vector2(travel.x,travel.z).length()/maxf(delta,0.0001)
	if is_on_floor() and global_position.y>0.4: last_dry=global_position
	if global_position.y<0.15:
		global_position=last_dry
		velocity=Vector3.ZERO
		actual_speed=0.0
		reset_visual_interpolation()
	animate(delta,clampf(actual_speed/5.0,0.0,1.0))
func animate(delta: float, speed: float) -> void:
	visual.animate_motion(speed*5.0,delta,carrying,downed,being_carried,carrying_teammate,fishing)
func carry_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,rotation.y), global_position + Vector3(0,1.0,0) - global_basis.z*0.82)

func rescue_transform() -> Transform3D:
	# The passenger's visual turns sideways around its feet; this offset centres
	# its torso across the carrier's shoulders while keeping the body upright.
	return Transform3D(Basis(Vector3.UP,rotation.y),global_position+Vector3.UP*1.65+global_basis.x*0.85+global_basis.z*0.7)

func set_loadout(data: Dictionary, remaining: float, lamp_enabled: bool) -> void:
	visual.set_rod_appearance(str(data.get("rod_id","starter")))
	var outfit_id: String=str(data.get("outfit_id","harbour"))
	if _outfit_id!=outfit_id:
		_outfit_id=outfit_id
		visual.set_outfit_appearance(outfit_id)
		cargo_speed=float(Gear.outfit(outfit_id).get("carry_speed",4.25))
	name_tag.text=str(data.get("name",profile_id))
	lamp.visible=lamp_enabled and remaining>0 and not being_carried
	lamp.spot_range=12.0 if data.get("lamp_id","flood")=="surveyor" else 8.0
	lamp.spot_angle=15.0 if data.get("lamp_id","flood")=="surveyor" else 35.0
