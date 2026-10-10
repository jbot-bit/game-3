class_name AnimatedCrew
extends Node3D
## Presentation adapter for KayKit's CC0 rig. Physics and game rules stay on Angler.
## Motion uses authored skeletal clips; cargo variants keep their authored stride.
const SOURCE: PackedScene=preload("res://assets/kaykit/Rogue.glb")
const PALETTE: Shader=preload("res://assets/kaykit/crew_palette.gdshader")
const Art=preload("res://game/world/block_art.gd")
const REMOVED: Array[String]=["Knife_Offhand","1H_Crossbow","2H_Crossbow","Knife","Throwable","Rogue_Cape"]
const ARM_BONES: Array[String]=["upperarm.l","lowerarm.l","hand.l","upperarm.r","lowerarm.r","hand.r"]
static var _clips: AnimationLibrary
static var _palettes: Dictionary={}
var skeleton: Skeleton3D
var player: AnimationPlayer
var animation_state: String=""
var _model: Node3D
var _right_anchor: Node3D
var _left_anchor: Node3D
var _hand_right: int=-1
var _hand_left: int=-1
var _palette_key: String=""
var _grip_basis: Basis=Basis.IDENTITY
var _grip_calibrated: bool=false
var _action: String=""
var _action_left: float=0.0
var _was_fishing: bool=false
var _seated: bool=false

func _init() -> void:
	name="BlockCrew"
	_model=SOURCE.instantiate() as Node3D
	_model.name="RiggedModel"
	_model.rotation.y=PI # KayKit faces +Z; the game and rod face -Z.
	add_child(_model)
	for node: Node in _model.find_children("*","MeshInstance3D",true,false):
		if str(node.name) in REMOVED:
			node.get_parent().remove_child(node)
			node.free()
	skeleton=_model.get_node("Rig/Skeleton3D") as Skeleton3D
	player=_model.get_node("AnimationPlayer") as AnimationPlayer
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if _clips==null: _build_clips(player)
	for library: StringName in player.get_animation_library_list(): player.remove_animation_library(library)
	player.add_animation_library("",_clips)
	_right_anchor=Node3D.new()
	_right_anchor.name="RightArm"
	add_child(_right_anchor)
	_left_anchor=Node3D.new()
	_left_anchor.name="LeftArm"
	add_child(_left_anchor)
	var tool: Node3D=Node3D.new()
	tool.name="HeldTool"
	_right_anchor.add_child(tool)
	_hand_right=skeleton.find_bone("hand.r")
	_hand_left=skeleton.find_bone("hand.l")
	configure(Color("62b9db"))
	player.play("Idle")
	player.advance(0)
	_update_anchors()

func configure(color: Color, outfit_id: String="harbour", rod_id: String="starter") -> void:
	set_meta("crew_color",color)
	set_outfit_appearance(outfit_id)
	set_rod_appearance(rod_id)

func set_outfit_appearance(outfit_id: String) -> void:
	var color: Color=get_meta("crew_color",Color("62b9db")) as Color
	var key: String=color.to_html()+":"+outfit_id
	if key==_palette_key: return
	_palette_key=key
	set_meta("outfit_id",outfit_id)
	if not _palettes.has(key):
		var material: ShaderMaterial=ShaderMaterial.new()
		material.shader=PALETTE
		var body: MeshInstance3D=skeleton.get_node("Rogue_Body") as MeshInstance3D
		var original: StandardMaterial3D=body.mesh.surface_get_material(0) as StandardMaterial3D
		material.set_shader_parameter("source_texture",original.albedo_texture)
		material.set_shader_parameter("crew_color",color)
		var coat: Color={"angler":Color("c9a365"),"deckhand":Color("b5694e"),"stormwatch":Color("526589")}.get(outfit_id,color) as Color
		material.set_shader_parameter("outfit_color",coat)
		_palettes[key]=material
	for node: Node in skeleton.get_children():
		if node is MeshInstance3D: node.material_override=_palettes[key] as ShaderMaterial

func set_rod_appearance(rod_id: String) -> void:
	Art.set_rod_appearance(self,rod_id)

func play_action(action: String) -> void:
	var clip: String={"throw":"Throw","cast":"Cast"}.get(action,"") as String
	if clip.is_empty(): return
	_action=clip
	_action_left=player.get_animation(clip).length

func set_seated(value: bool) -> void:
	_seated=value
	if value:
		_action=""
		_action_left=0.0

func animate_motion(speed: float, delta: float, carrying: bool=false, downed: bool=false, being_carried: bool=false, carrying_teammate: bool=false, fishing: bool=false) -> void:
	if fishing and not _was_fishing and not downed and not being_carried: play_action("cast")
	_was_fishing=fishing
	if not fishing and _action=="Cast": _action=""
	var moving: bool=speed>0.12
	var clip: String="Run" if speed>3.4 else ("Walk" if moving else "Idle")
	var pace: float=clampf(speed/4.8,0.65,1.35) if clip=="Run" else (clampf(speed/2.4,0.5,1.6) if moving else 1.0)
	if carrying or carrying_teammate:
		clip="CarryWalk" if moving else "CarryIdle"
		pace=clampf(speed/3.2,0.55,1.4) if moving else 1.0
	if fishing:
		clip="Fishing"
		pace=1.0
	if not _action.is_empty():
		clip=_action
		pace=1.0
		_action_left=maxf(0.0,_action_left-delta)
		if _action_left<=0.0: _action=""
	if _seated:
		clip="Seated"
		pace=1.0
	if downed:
		clip="Downed"
		pace=1.0
	if being_carried:
		clip="Passenger"
		pace=1.0
	rotation.z=lerpf(rotation.z,PI*0.5 if being_carried else 0.0,minf(delta*12.0,1.0))
	if animation_state!=clip:
		animation_state=clip
		player.play(clip,0.3)
	player.speed_scale=pace
	player.advance(maxf(0.0,delta))
	_update_anchors()
	var tool: Node3D=_right_anchor.get_node("HeldTool") as Node3D
	# The sampled support pose comes from a crossbow clip. Correct only the prop's
	# grip angle after casting so the fishing rod points over the water, not sideways.
	var grip: Basis=_right_anchor.basis.inverse()*Basis(Vector3.RIGHT,-0.65) if clip=="Fishing" else Basis.IDENTITY
	tool.quaternion=tool.quaternion.slerp(grip.get_rotation_quaternion(),minf(delta*12.0,1.0))
	tool.visible=not carrying and not carrying_teammate and not downed and not being_carried and not _seated and clip!="Throw"

func _update_anchors() -> void:
	# Calibrate the rod's neutral grip once, then follow the actual hand in full.
	# Casting and throwing consequently retain attachment during authored motion.
	var rig_to_crew: Transform3D=_model.transform*(skeleton.get_parent() as Node3D).transform*skeleton.transform
	var hand: Transform3D=rig_to_crew*skeleton.get_bone_global_pose(_hand_right)
	if not _grip_calibrated:
		_grip_basis=hand.basis.inverse()
		_grip_calibrated=true
	_right_anchor.transform=hand*Transform3D(_grip_basis,Vector3.ZERO)
	_left_anchor.position=rig_to_crew*skeleton.get_bone_global_pose(_hand_left).origin

static func _build_clips(source: AnimationPlayer) -> void:
	_clips=AnimationLibrary.new()
	var names: Dictionary={"Idle":"Idle","Walk":"Walking_A","Run":"Running_A","Downed":"Lie_Pose","Passenger":"Idle","Fishing":"2H_Ranged_Aiming","Cast":"Throw","Throw":"Throw","Seated":"Sit_Chair_Idle"}
	for key: String in names:
		var clip: Animation=source.get_animation(str(names[key])).duplicate() as Animation
		clip.loop_mode=Animation.LOOP_NONE if key in ["Cast","Throw"] else Animation.LOOP_LINEAR
		_clips.add_animation(key,clip)
	var hold: Animation=source.get_animation("2H_Ranged_Aiming")
	for key: String in ["CarryIdle","CarryWalk"]:
		var clip: Animation=source.get_animation("Idle" if key=="CarryIdle" else "Walking_A").duplicate() as Animation
		for track: int in range(clip.get_track_count()-1,-1,-1):
			if _arm_path(clip.track_get_path(track)): clip.remove_track(track)
		for track: int in range(hold.get_track_count()):
			if not _arm_path(hold.track_get_path(track)): continue
			if hold.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
			if str(hold.track_get_path(track).get_subname(0)).ends_with(".r"): continue
			var index: int=clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(index,hold.track_get_path(track))
			var rotation: Quaternion=hold.rotation_track_interpolate(track,0.25)
			clip.track_insert_key(index,0.0,rotation)
			# Mirror the supporting left arm, avoiding the original crossbow trigger pose.
			var mirror: int=clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(mirror,NodePath(str(hold.track_get_path(track)).replace(".l",".r")))
			clip.track_insert_key(mirror,0.0,Quaternion(rotation.x,-rotation.y,-rotation.z,rotation.w))
		clip.loop_mode=Animation.LOOP_LINEAR
		_clips.add_animation(key,clip)
	# Both hands support the rod in front after the cast settles.
	_clips.remove_animation("Fishing")
	_clips.add_animation("Fishing",_clips.get_animation("CarryIdle").duplicate() as Animation)

static func _arm_path(path: NodePath) -> bool:
	return path.get_subname_count()>0 and str(path.get_subname(0)) in ARM_BONES
