class_name CrewCamera
extends Camera3D

var yaw: float = 0.0
var pitch: float = -0.45
var target: Node3D
var mouse_sensitivity: float = 1.0
var invert_y: bool = false

func apply_settings(values: Dictionary) -> void:
	mouse_sensitivity = clampf(float(values.get("mouse_sensitivity", 1.0)), 0.2, 3.0)
	invert_y = bool(values.get("invert_y", false))

func orbit(relative: Vector2) -> void:
	yaw-=relative.x*0.004*mouse_sensitivity
	pitch=clampf(pitch-relative.y*0.003*mouse_sensitivity*(-1.0 if invert_y else 1.0),-0.85,-0.12)

func follow(delta: float) -> void:
	if not is_instance_valid(target): return
	var focus: Vector3=target.global_position+Vector3(0,1.7,0)
	var offset: Vector3=Basis(Vector3.UP,yaw)*Vector3(0,-sin(pitch)*7.5,cos(pitch)*7.5)
	var wanted: Vector3=focus+offset
	var query=PhysicsRayQueryParameters3D.create(focus,wanted,1)
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): wanted=hit.position+(focus-hit.position).normalized()*0.3
	global_position=global_position.lerp(wanted,minf(1.0,delta*14.0))
	look_at(focus)

func movement(raw: Vector2) -> Vector2:
	var d: Vector3=Basis(Vector3.UP,yaw)*Vector3(raw.x,0,raw.y)
	return Vector2(d.x,d.z)
