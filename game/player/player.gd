class_name Angler
extends CharacterBody3D

const Art = preload("res://game/world/block_art.gd")
var profile_id: String = ""
var visual: Node3D
var name_tag: Label3D
var lamp: SpotLight3D
var last_dry: Vector3
var downed: bool = false
var carrying: bool = false
var fishing: bool = false
var motion_time: float = 0.0
var desired_position: Vector3

func setup(id: String, color: Color) -> void:
	profile_id=id
	collision_layer=2
	collision_mask=1
	var shape=CollisionShape3D.new()
	var capsule=CapsuleShape3D.new()
	capsule.radius=0.38
	capsule.height=1.9
	shape.shape=capsule
	shape.position.y=0.95
	add_child(shape)
	visual=Art.crew(color)
	add_child(visual)
	name_tag=Label3D.new()
	name_tag.position=Vector3(0,2.65,0)
	name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font_size=28
	name_tag.outline_size=5
	name_tag.pixel_size=0.008
	add_child(name_tag)
	lamp=SpotLight3D.new()
	lamp.position=Vector3(0.45,1.5,-0.45)
	lamp.rotation.x=-0.25
	lamp.light_color=Color("ffd071")
	lamp.light_energy=2.5
	lamp.spot_range=8.0
	lamp.spot_angle=35.0
	lamp.shadow_enabled=false
	add_child(lamp)

func advance(delta: float, direction: Vector2, yaw: float, enabled: bool) -> void:
	var d: Vector2=direction.limit_length(1.0) if enabled and not downed and not fishing else Vector2.ZERO
	velocity.x=d.x*5.0*(0.85 if carrying else 1.0)
	velocity.z=d.y*5.0*(0.85 if carrying else 1.0)
	if not is_on_floor(): velocity.y-=22.0*delta
	else: velocity.y=0.0
	if d.length()>0.05: rotation.y=lerp_angle(rotation.y,atan2(-d.x,-d.y),minf(1,delta*12))
	elif enabled and is_finite(yaw): rotation.y=lerp_angle(rotation.y,yaw,minf(1,delta*12))
	move_and_slide()
	if is_on_floor() and global_position.y>0.4: last_dry=global_position
	if global_position.y<0.15:
		global_position=last_dry
		velocity=Vector3.ZERO
	animate(delta,d.length())

func animate(delta: float, speed: float) -> void:
	motion_time+=delta*8.0
	visual.rotation.z=lerpf(visual.rotation.z,-1.25 if downed else sin(motion_time)*speed*0.04, minf(1,delta*10))
	for side in ["LeftLeg","RightLeg"]:
		var leg: Node3D=visual.get_node(side)
		leg.rotation.x=sin(motion_time+(PI if side=="RightLeg" else 0.0))*speed*0.45
	for side in ["LeftArm","RightArm"]:
		var arm: Node3D=visual.get_node(side)
		arm.rotation.x=1.1 if carrying else (-0.65 if fishing else sin(motion_time+(PI if side=="LeftArm" else 0.0))*speed*0.25)
	visual.get_node("RightArm/HeldTool").visible=not carrying

func carry_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,rotation.y), global_position + Vector3(0,1.0,0) - global_basis.z*1.35)

func set_loadout(data: Dictionary, remaining: float, lamp_enabled: bool) -> void:
	BlockArt.set_rod_appearance(visual,str(data.get("rod_id","starter")))
	name_tag.text=str(data.get("name",profile_id))
	lamp.visible=lamp_enabled and remaining>0
	lamp.spot_range=12.0 if data.get("lamp_id","flood")=="surveyor" else 8.0
	lamp.spot_angle=15.0 if data.get("lamp_id","flood")=="surveyor" else 35.0
