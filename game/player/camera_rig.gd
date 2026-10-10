class_name CrewCamera
extends Camera3D

var yaw: float = 0.0
var pitch: float = -0.45
var target: Node3D
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var distance: float = 7.5
var _clearance_shape := SphereShape3D.new()
var _fishing_focus: Vector3
var _has_fishing_focus: bool=false
var _fishing_blend: float=0.0
var _look_offset: Vector3=Vector3.ZERO
var _reduced_effects: bool=false
var _has_followed: bool=false
var _manual_fishing_orbit: bool=false

const VIEW_CLEARANCE: float = 0.55
const MIN_FRAME_DISTANCE: float = 4.2
# World geometry plus camera-only foliage. Excludes crew, cargo and the hunter.
const VIEW_MASK: int = 1 | 16

func apply_settings(values: Dictionary) -> void:
	mouse_sensitivity = clampf(float(values.get("mouse_sensitivity", 1.0)), 0.2, 3.0)
	invert_y = bool(values.get("invert_y", false))
	_reduced_effects = bool(values.get("reduced_effects", false))

func set_fishing_focus(point: Vector3) -> void:
	if not point.is_finite(): return
	if not _has_fishing_focus: _manual_fishing_orbit=false
	_fishing_focus=point
	_has_fishing_focus=true

func clear_fishing_focus() -> void:
	_has_fishing_focus=false

func orbit(relative: Vector2) -> void:
	if _has_fishing_focus: _manual_fishing_orbit=true
	yaw-=relative.x*0.004*mouse_sensitivity
	pitch=clampf(pitch-relative.y*0.003*mouse_sensitivity*(-1.0 if invert_y else 1.0),-0.85,-0.12)

func zoom(steps: float) -> void:
	if is_finite(steps): distance=clampf(distance-steps*0.6,4.5,10.0)

func follow(delta: float) -> void:
	if not is_instance_valid(target): return
	var target_position: Vector3=target.render_transform().origin if target.has_method("render_transform") else target.global_position
	var focus: Vector3=target_position+Vector3(0,1.7,0)
	var blend: float=1.0-exp(-5.0*maxf(0.0,delta))
	var fishing: bool=_has_fishing_focus and not _reduced_effects and not _manual_fishing_orbit
	_fishing_blend=lerpf(_fishing_blend,1.0 if fishing else 0.0,blend)
	var aim_offset: Vector3=Vector3.ZERO
	if fishing:
		aim_offset=(_fishing_focus-focus)*0.3
		aim_offset=aim_offset.limit_length(4.5)
	_look_offset=_look_offset.lerp(aim_offset,blend)
	var view_pitch: float=lerpf(pitch,minf(pitch,-0.8),_fishing_blend)
	var offset: Vector3=Basis(Vector3.UP,yaw)*Vector3(1.15*_fishing_blend,-sin(view_pitch)*distance,cos(view_pitch)*distance)
	var wanted: Vector3=_clear_view_position(focus,focus+offset)
	if focus.distance_to(wanted)<MIN_FRAME_DISTANCE:
		wanted=_alternate_view_position(focus,offset,wanted)
	var eased: Vector3=global_position.lerp(wanted,1.0-exp(-14.0*maxf(0.0,delta)))
	# Ease back out, but resolve the actual rendered position immediately when
	# a wall enters the view. Interpolating through that wall still hides the crew.
	global_position=_clear_view_position(focus,eased)
	# An angular transition can cross the original obstruction. Reframe directly
	# to the checked viewpoint instead of drawing from inside the avatar's head.
	if focus.distance_to(global_position)<2.0 and focus.distance_to(wanted)>=MIN_FRAME_DISTANCE:
		global_position=wanted
	look_at(focus+_look_offset)
	_has_followed=true

func _alternate_view_position(focus: Vector3, offset: Vector3, fallback: Vector3) -> Vector3:
	# Near a rock/wall, a wide sweep can stop almost at its origin even when the
	# player and centre sightline are clear. Prefer an elevated view, then orbit;
	# every candidate retains the same shoulder sweep and wall-ray checks.
	var best: Vector3=fallback
	# Raise the lens before rotating around the crew. This keeps the on-screen
	# forward direction aligned with movement, and clears low rocks and roofs.
	for raised_pitch: float in [-0.65,-0.85,-1.05,-1.25]:
		if raised_pitch>=pitch: continue
		var raised: Vector3=Basis(Vector3.UP,yaw)*Vector3(0,-sin(raised_pitch)*distance,cos(raised_pitch)*distance)
		var candidate: Vector3=_clear_view_position(focus,focus+raised)
		if focus.distance_squared_to(candidate)>focus.distance_squared_to(best): best=candidate
		if focus.distance_to(candidate)>=minf(distance*0.8,5.5): return candidate
	for angle: float in [0.35,-0.35,0.7,-0.7,1.05,-1.05,PI*0.5,-PI*0.5,PI]:
		var candidate: Vector3=_clear_view_position(focus,focus+Basis(Vector3.UP,angle)*offset)
		if focus.distance_squared_to(candidate)>focus.distance_squared_to(best): best=candidate
		if focus.distance_to(candidate)>=MIN_FRAME_DISTANCE: return candidate
	return best

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
	query.collision_mask=VIEW_MASK
	query.margin=0.04
	var space:=get_world_3d().direct_space_state
	var fraction: float=space.cast_motion(query)[0]
	# Shape sweeps skip obstacles overlapping their starting volume. The avatar
	# can stand closer to a wall than this camera corridor, so retain a center ray
	# for that tight-space case instead of letting the camera pass through it.
	var ray:=PhysicsRayQueryParameters3D.create(focus,destination,VIEW_MASK)
	var hit: Dictionary=space.intersect_ray(ray)
	if not hit.is_empty():
		fraction=minf(fraction,maxf(0.0,focus.distance_to(hit.position)-0.12)/motion.length())
	return focus+motion*fraction

func view_yaw() -> float:
	# Use the rendered screen direction after collision avoidance, preserving
	# the requested orbit yaw separately so the lens can return as space clears.
	if not _has_followed or not is_instance_valid(target): return yaw
	var backward:=Vector2(global_basis.z.x,global_basis.z.z)
	return atan2(backward.x,backward.y) if backward.length_squared()>0.0001 else yaw

func movement(raw: Vector2) -> Vector2:
	var d: Vector3=Basis(Vector3.UP,view_yaw())*Vector3(raw.x,0,raw.y)
	return Vector2(d.x,d.z)
