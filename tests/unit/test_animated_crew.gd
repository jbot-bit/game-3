extends GutTest

func new_crew() -> Node3D:
	var script: Script=load("res://game/player/animated_crew.gd")
	var actor: Node3D=script.new()
	add_child_autofree(actor)
	actor.configure(Color("62b9db"),"angler","soft_tip")
	return actor

func test_outfit_changes_keep_hand_tool_and_crew_identity() -> void:
	var actor: Node3D=new_crew()
	var head: MeshInstance3D=actor.get_node_or_null("Head/Face")
	assert_not_null(head,"Crew has a readable square face on its head pivot")
	if head==null: return
	assert_true(head.mesh is BoxMesh,"The crew silhouette uses simple block geometry")
	var tool: Node3D=actor.get_node("RightArm/HeldTool")
	var tip: Node3D=tool.get_node("RodTip")
	var coat: MeshInstance3D=actor.get_node("Torso/Coat")
	var original_material: Material=coat.material_override
	actor.configure(Color("62b9db"),"angler","soft_tip")
	assert_same(actor.get_node("Torso/Coat").material_override,original_material)
	actor.configure(Color("e67c61"),"stormwatch","soft_tip")
	assert_same(actor.get_node("RightArm/HeldTool"),tool,"Outfit swaps must never replace the effect attachment")
	assert_same(tool.get_node("RodTip"),tip,"The unchanged rod stays attached during outfit swaps")
	assert_eq(actor.get_meta("outfit_id"),"stormwatch")
	assert_eq(actor.get_meta("crew_color"),Color("e67c61"))
	assert_ne(actor.get_node("Torso/Coat").material_override,original_material)
	assert_eq(actor.get_node("Torso/CrewScarf").material_override.albedo_color,Color("e67c61"))

func test_carry_walk_moves_legs_but_keeps_supporting_hands_steady() -> void:
	var actor: Node3D=new_crew()
	var leg: Node3D=actor.get_node_or_null("LeftLeg")
	assert_not_null(leg,"The block crew animates at the hip pivot")
	if leg==null: return
	for frame: int in range(60): actor.animate_motion(4.25,1.0/60.0,true)
	var leg_before: Quaternion=leg.quaternion
	var arm: Node3D=actor.get_node("RightArm")
	var arm_before: Quaternion=arm.quaternion
	actor.animate_motion(4.25,0.2,true)
	assert_gt(leg_before.angle_to(leg.quaternion),0.05,"Stride must continue while carrying")
	assert_lt(arm_before.angle_to(arm.quaternion),0.001,"Support arms stay steady while walking")
	assert_lt((actor.get_node("RightArm/Hand") as Node3D).global_position.z,arm.global_position.z-0.35,"Hands must support cargo ahead of the body, towards -Z")
	assert_false(actor.get_node("RightArm/HeldTool").visible)

func test_cast_follows_the_hand_then_points_rod_over_water() -> void:
	var actor: Node3D=new_crew()
	var tool: Node3D=actor.get_node("RightArm/HeldTool")
	var before: Vector3=tool.global_position
	actor.animate_motion(0.0,0.2,false,false,false,false,true)
	assert_eq(actor.animation_state,"Cast")
	assert_gt(before.distance_to(tool.global_position),0.1,"Casting must move the held rod with the arm")
	for frame: int in range(100): actor.animate_motion(0.0,1.0/60.0,false,false,false,false,true)
	assert_eq(actor.animation_state,"Fishing")
	assert_true(tool.visible)
	assert_lt(tool.global_position.z,actor.global_position.z-0.3,"Fishing hand must hold the rod in front of the body")
	var tip: Node3D=tool.get_node("RodTip")
	assert_lt(tip.global_position.z-tool.global_position.z,-1.0,"Rod points ahead over water")
	assert_lt(absf(tip.global_position.x-tool.global_position.x),0.05,"Rod must not cross sideways through the crew")

func test_throw_returns_to_locomotion_and_seating_hides_tool() -> void:
	var actor: Node3D=new_crew()
	actor.play_action("throw")
	actor.animate_motion(2.4,0.1)
	assert_eq(actor.animation_state,"Throw")
	assert_false(actor.get_node("RightArm/HeldTool").visible)
	for frame: int in range(110): actor.animate_motion(2.4,1.0/60.0)
	assert_eq(actor.animation_state,"Walk")
	actor.set_seated(true)
	actor.animate_motion(0.0,0.4)
	assert_eq(actor.animation_state,"Seated")
	assert_false(actor.get_node("RightArm/HeldTool").visible)
	var leg: Node3D=actor.get_node_or_null("LeftLeg")
	assert_not_null(leg)
	if leg!=null: assert_lt((leg.get_node("Boot") as Node3D).global_position.z,leg.global_position.z-0.4,"Seated boots point forward from the hips, towards -Z")

func test_downed_and_passenger_interrupt_actions_without_resuming_them() -> void:
	var actor: Node3D=new_crew()
	actor.play_action("throw")
	actor.animate_motion(0.0,0.1,false,true)
	assert_eq(actor.animation_state,"Downed")
	assert_false(actor.get_node("RightArm/HeldTool").visible)
	actor.animate_motion(0.0,0.1)
	assert_eq(actor.animation_state,"Idle","Recovery must not resume an interrupted throw")
	actor.animate_motion(0.0,0.5,false,true,true)
	assert_eq(actor.animation_state,"Passenger")
	assert_false(actor.get_node("RightArm/HeldTool").visible)
	assert_gt(actor.rotation.z,1.3,"Carried crew lies across the carrier's shoulder")

func test_motion_preserves_caller_placement_and_bobs_only_body_parts() -> void:
	var actor: Node3D=new_crew()
	actor.position=Vector3(5,2.05,8)
	var head: Node3D=actor.get_node("Head")
	var head_before: Vector3=head.position
	actor.animate_motion(0.0,0.2)
	assert_eq(actor.position,Vector3(5,2.05,8),"Idle must preserve world and boat seat placement")
	assert_gt(head.position.y,head_before.y,"Breathing belongs to the body parts")
	actor.animate_motion(4.0,0.2)
	assert_eq(actor.position,Vector3(5,2.05,8),"Locomotion must preserve world placement")
	actor.set_seated(true)
	actor.animate_motion(0.0,0.4)
	assert_eq(actor.position,Vector3(5,2.05,8),"Seating must preserve the assigned boat offset")
	actor.set_seated(false)
	actor.animate_motion(0.0,0.4,false,true)
	assert_eq(actor.position,Vector3(5,2.05,8),"Downed pose must not replace the gameplay position")

func test_seated_pose_uses_root_as_hip_datum_on_first_frame() -> void:
	var actor: Node3D=new_crew()
	actor.position=Vector3(0,0.154,0)
	actor.set_seated(true)
	actor.animate_motion(0.0,0.0)
	assert_eq(actor.position,Vector3(0,0.154,0),"Caller owns the seat datum")
	assert_almost_eq((actor.get_node("LeftLeg") as Node3D).global_position.y,0.154,0.001,"Seated hip is at the caller's seat datum on its first frame")
	assert_lt((actor.get_node("LeftLeg/Boot") as Node3D).global_position.z,-0.4,"Boat passenger begins seated with boots forward")

func test_cast_release_aims_rod_forward_while_the_hand_reaches_out() -> void:
	var actor: Node3D=new_crew()
	for frame: int in range(40): actor.animate_motion(0.0,1.0/60.0,false,false,false,false,true)
	assert_eq(actor.animation_state,"Cast")
	var tool: Node3D=actor.get_node("RightArm/HeldTool")
	var tip: Node3D=tool.get_node("RodTip")
	assert_lt(tool.global_position.z,actor.global_position.z-0.3,"Cast release hand reaches towards water")
	assert_lt(tip.global_position.z-tool.global_position.z,-0.8,"Rod tip follows the released cast towards the water")
