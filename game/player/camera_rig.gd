class_name CrewCamera
extends Camera3D

var yaw: float = 0.0
var pitch: float = -0.45
var target: Node3D
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var distance: float = 7.5
var _clearance_shape := SphereShape3D.new()

const VIEW_CLEARANCE: float = 0.55

func apply_settings(values: Dictionary) -> void:
	mouse_sensitivity = clampf(float(values.get("mouse_sensitivity", 1.0)), 0.2, 3.0)
	invert_y = bool(values.get("invert_y", false))

func orbit(relative: Vector2) -> void:
	yaw-=relative.x*0.004*mouse_sensitivity
	pitch=clampf(pitch-relative.y*0.003*mouse_sensitivity*(-1.0 if invert_y else 1.0),-0.85,-0.12)

func zoom(steps: float) -> void:
	if is_finite(steps): distance=clampf(distance-steps*0.6,4.5,10.0)

func follow(delta: float) -> void:
	if not is_instance_valid(target): return
	var target_position: Vector3=target.render_transform().origin if target.has_method("render_transform") else target.global_position
	var focus: Vector3=target_position+Vector3(0,1.7,0)
	var offset: Vector3=Basis(Vector3.UP,yaw)*Vector3(0,-sin(pitch)*distance,cos(pitch)*distance)
	var wanted: Vector3=_clear_view_position(focus,focus+offset)
	var eased: Vector3=global_position.lerp(wanted,1.0-exp(-14.0*maxf(0.0,delta)))
	# Ease back out, but resolve the actual rendered position immediately when
	# a wall enters the view. Interpolating through that wall still hides the crew.
	global_position=_clear_view_position(focus,eased)
	look_at(focus)

func _clear_view_position(focus: Vector3, destination: Vector3) -> Vector3:
	var motion: Vector3=destination-focus
	if motion.length_squared()<0.0001: return destination
	# A center ray can skim a pillar while half the avatar is hidden. Sweep a
	# shoulder-width corridor, also keeping the lens away from nearby corners.
	_clearance_shape.radius=VIEW_CLEARANCE
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=_clearance_shape
	query.transform=Transform3D(Basis.IDENTITY,focus)
	query.motion=motion
	query.collision_mask=1
	query.margin=0.04
	var space:=get_world_3d().direct_space_state
	var fraction: float=space.cast_motion(query)[0]
	# Shape sweeps skip obstacles overlapping their starting volume. The avatar
	# can stand closer to a wall than this camera corridor, so retain a center ray
	# for that tight-space case instead of letting the camera pass through it.
	var ray:=PhysicsRayQueryParameters3D.create(focus,destination,1)
	var hit: Dictionary=space.intersect_ray(ray)
	if not hit.is_empty():
		fraction=minf(fraction,maxf(0.0,focus.distance_to(hit.position)-0.12)/motion.length())
	return focus+motion*fraction

func movement(raw: Vector2) -> Vector2:
	var d: Vector3=Basis(Vector3.UP,yaw)*Vector3(raw.x,0,raw.y)
	return Vector2(d.x,d.z)
