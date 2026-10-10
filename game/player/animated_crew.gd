class_name AnimatedCrew
extends Node3D
## Six-part block crew. Only presentation moves; Angler owns collision and rules.
const Model=preload("res://game/player/block_crew_model.gd")
const Art=preload("res://game/world/block_art.gd")
const ACTION_LENGTH: float=0.8
var animation_state: String="Idle"
var _palette_key: String=""
var _action: String=""
var _action_left: float=0.0
var _was_fishing: bool=false
var _seated: bool=false
var _clock: float=0.0
var _stride: float=0.0
var _body_lift: float=0.0

func _init() -> void:
	name="BlockCrew"
	Model.build(self)
	configure(Color("62b9db"))

func configure(color: Color, outfit_id: String="harbour", rod_id: String="starter") -> void:
	set_meta("crew_color",color)
	set_outfit_appearance(outfit_id)
	set_rod_appearance(rod_id)

func set_outfit_appearance(outfit_id: String) -> void:
	if outfit_id not in ["harbour","angler","deckhand","stormwatch"]: outfit_id="harbour"
	var color: Color=get_meta("crew_color",Color("62b9db")) as Color
	var key: String=color.to_html()+":"+outfit_id
	if key==_palette_key: return
	_palette_key=key
	set_meta("outfit_id",outfit_id)
	Model.dress(self,outfit_id,color)

func set_rod_appearance(rod_id: String) -> void:
	Art.set_rod_appearance(self,rod_id)

func play_action(action: String) -> void:
	if action not in ["throw","cast"]: return
	_action="Throw" if action=="throw" else "Cast"
	_action_left=ACTION_LENGTH

func set_seated(value: bool) -> void:
	_seated=value
	if value: _clear_action()

func animate_motion(speed: float, delta: float, carrying: bool=false, downed: bool=false, being_carried: bool=false, carrying_teammate: bool=false, fishing: bool=false) -> void:
	var dt: float=maxf(delta,0.0)
	_clock+=dt
	var disabled: bool=downed or being_carried or _seated
	if fishing and not _was_fishing and not disabled: play_action("cast")
	_was_fishing=fishing
	if disabled or (not fishing and _action=="Cast"): _clear_action()
	var moving: bool=speed>0.12
	var state: String="Run" if speed>3.4 else ("Walk" if moving else "Idle")
	if carrying or carrying_teammate: state="CarryWalk" if moving else "CarryIdle"
	if fishing: state="Fishing"
	if not _action.is_empty(): state=_action
	if _seated: state="Seated"
	if downed: state="Downed"
	if being_carried: state="Passenger"
	animation_state=state
	_stride+=dt*(8.0 if state=="Run" else 6.0)*clampf(speed/2.8,0.5,1.6)
	var swing: float=sin(_stride)
	var idle: float=sin(_clock*2.4)
	var left_arm: Vector3=Vector3(0.025*idle,0,-0.06)
	var right_arm: Vector3=Vector3(-0.025*idle,0,0.06)
	var left_leg: Vector3=Vector3.ZERO
	var right_leg: Vector3=Vector3.ZERO
	var head: Vector3=Vector3(0,idle*0.025,0)
	var torso: Vector3=Vector3.ZERO
	var body_pitch: float=0.0
	var body_roll: float=0.0
	var lift: float=0.008*(idle+1.0)
	var rod_pitch: float=-0.68
	match state:
		"Walk","Run","CarryWalk":
			var amount: float=0.67 if state=="Run" else 0.46
			left_leg.x=swing*amount
			right_leg.x=-swing*amount
			left_arm.x=-swing*amount*0.8
			right_arm.x=swing*amount*0.8
			torso.y=swing*0.055
			head.y=-swing*0.035
			lift=absf(cos(_stride))*0.035
			if state=="Run": torso.x=-0.09
		"Seated":
			left_leg.x=PI*0.5
			right_leg.x=PI*0.5
			left_arm.x=0.30
			right_arm.x=0.30
			lift=-(Model.PIVOTS.LeftLeg as Vector3).y
		"Downed":
			body_pitch=-PI*0.5
			left_arm.z=-0.27
			right_arm.z=0.27
			head.x=-0.10
			lift=0.29
		"Passenger":
			body_roll=PI*0.5
			left_arm.x=-0.35
			right_arm.x=-0.35
			left_leg.x=0.22
			right_leg.x=-0.18
			lift=0.0
	if state in ["CarryIdle","CarryWalk"]:
		left_arm=Vector3(1.05,0,-0.08)
		right_arm=Vector3(1.05,0,0.08)
	if state=="Fishing":
		left_arm=Vector3(0.95,0.16,-0.12)
		right_arm=Vector3(0.85+idle*0.035,0,0)
		head.x=0.055
		torso.x=-0.025
	if state in ["Cast","Throw"]:
		var progress: float=1.0-_action_left/ACTION_LENGTH
		var arm_pitch: float=lerpf(-0.9,1.45,smoothstep(0.24,0.65,progress))
		rod_pitch=lerpf(0.55,-0.68,smoothstep(0.15,0.55,progress))
		right_arm=Vector3(arm_pitch,0,0)
		left_arm=Vector3(0.40,0,-0.12)
		torso.y=sin(progress*PI)*-0.12
		head.x=-sin(progress*PI)*0.08
		_action_left=maxf(0.0,_action_left-dt)
		if _action_left<=0.0: _clear_action()
	var blend: float=1.0 if is_zero_approx(dt) else 1.0-exp(-16.0*dt)
	_pose("LeftArm",left_arm,blend)
	_pose("RightArm",right_arm,blend)
	_pose("LeftLeg",left_leg,blend)
	_pose("RightLeg",right_leg,blend)
	_pose("Head",head,blend)
	_pose("Torso",torso,blend)
	rotation.x=lerp_angle(rotation.x,body_pitch,blend)
	rotation.z=lerp_angle(rotation.z,body_roll,blend)
	_body_lift=lerpf(_body_lift,lift,blend)
	# Callers own this node's translation, including terrain height and boat seats.
	var part_lift: Vector3=basis.inverse()*Vector3(0,_body_lift,0)
	for key: String in Model.PIVOTS:
		(get_node(key) as Node3D).position=(Model.PIVOTS[key] as Vector3)+part_lift
	var arm: Node3D=get_node("RightArm")
	var tool: Node3D=arm.get_node("HeldTool")
	# Keep the settled rod aimed over water while the square arm breathes.
	var grip: Basis=arm.basis.inverse()*Basis(Vector3.RIGHT,rod_pitch) if state in ["Fishing","Cast"] else Basis.IDENTITY
	tool.quaternion=tool.quaternion.slerp(grip.get_rotation_quaternion(),blend)
	tool.visible=not carrying and not carrying_teammate and not downed and not being_carried and not _seated and state!="Throw"

func _pose(part_name: String, target: Vector3, blend: float) -> void:
	var part: Node3D=get_node(part_name)
	part.quaternion=part.quaternion.slerp(Quaternion.from_euler(target),blend)

func _clear_action() -> void:
	_action=""
	_action_left=0.0
