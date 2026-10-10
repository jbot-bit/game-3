extends GutTest

func new_crew() -> Node3D:
	var path: String="res://game/player/animated_crew.gd"
	assert_true(ResourceLoader.exists(path),"A real rigged presentation adapter must exist before player integration")
	if not ResourceLoader.exists(path): return null
	var script: Script=load(path)
	var actor: Node3D=script.new()
	add_child_autofree(actor)
	actor.configure(Color("62b9db"),"angler","soft_tip")
	return actor

func test_rig_has_six_body_meshes_no_weapons_and_stable_tool_anchor() -> void:
	var actor: Node3D=new_crew()
	if actor==null: return
	assert_eq(actor.name,StringName("BlockCrew"))
	var rig: Node=actor.get_node("RiggedModel")
	assert_eq(rig.find_children("*","MeshInstance3D",true,false).size(),6)
	for forbidden: String in ["Knife","Knife_Offhand","Throwable","1H_Crossbow","2H_Crossbow","Rogue_Cape"]:
		assert_null(rig.find_child(forbidden,true,false),"No weapon or cape remains on the fishing crew")
	var tool: Node=actor.get_node("RightArm/HeldTool")
	assert_not_null(tool.get_node("RodTip"))
	var material: Material=rig.find_child("Rogue_Body",true,false).material_override
	actor.configure(Color("62b9db"),"angler","soft_tip")
	assert_same(actor.get_node("RightArm/HeldTool"),tool)
	assert_same(rig.find_child("Rogue_Body",true,false).material_override,material,"Repeated loadouts reuse their palette material")
	assert_eq(actor.get_meta("outfit_id"),"angler")
	assert_eq(actor.get_meta("crew_color"),Color("62b9db"))

func test_authored_motion_advances_legs_while_carry_arms_hold_and_rod_hides() -> void:
	var actor: Node3D=new_crew()
	if actor==null: return
	var rig: Skeleton3D=actor.get_node("RiggedModel/Rig/Skeleton3D")
	var leg: int=rig.find_bone("upperleg.l")
	var arm: int=rig.find_bone("upperarm.r")
	# Settle the deliberate 300ms transition from idle before checking the hold.
	for frame: int in range(30): actor.animate_motion(4.25,1.0/60.0,true,false,false,false,false)
	var leg_before: Quaternion=rig.get_bone_pose_rotation(leg)
	var arm_before: Quaternion=rig.get_bone_pose_rotation(arm)
	actor.animate_motion(4.25,0.2,true,false,false,false,false)
	assert_gt(leg_before.angle_to(rig.get_bone_pose_rotation(leg)),0.05,"Authored stride must change bone pose over time")
	assert_lt(arm_before.angle_to(rig.get_bone_pose_rotation(arm)),0.001,"Carry arms remain posed while walking legs advance")
	assert_false(actor.get_node("RightArm/HeldTool").visible)
	actor.animate_motion(0.0,0.3,false,false,false,false,true)
	assert_eq(actor.animation_state,"Cast","A new cast starts its authored action before the hold")
	for frame: int in range(100): actor.animate_motion(0.0,1.0/60.0,false,false,false,false,true)
	assert_true(actor.get_node("RightArm/HeldTool").visible)
	assert_eq(actor.animation_state,"Fishing")
	var tool: Node3D=actor.get_node("RightArm/HeldTool")
	var tip: Node3D=tool.get_node("RodTip")
	assert_lt(tip.global_position.z-tool.global_position.z,-1.0,"Fishing grip must point ahead over water")
	# Allow the small authored idle sway while rejecting a cross-body rod angle.
	assert_lt(absf(tip.global_position.x-tool.global_position.x),0.05,"The rod must not aim sideways across the crew")
	actor.animate_motion(0.0,0.3,false,true,false,false,false)
	assert_eq(actor.animation_state,"Downed")
	assert_false(actor.get_node("RightArm/HeldTool").visible)

func test_throw_returns_to_locomotion_and_seated_passenger_has_no_rod() -> void:
	var actor: Node3D=new_crew()
	if actor==null: return
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
