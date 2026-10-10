extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var document: GLTFDocument=GLTFDocument.new()
	var state: GLTFState=GLTFState.new()
	var result: Error=document.append_from_file(ProjectSettings.globalize_path("res://.tools/art-sources/kaykit-adventurers/Rogue.glb"),state)
	if result!=OK:
		push_error("GLTF LOAD "+str(result))
		quit(1)
		return
	var rig: Node=document.generate_scene(state)
	root.add_child(rig)
	for node: Node in rig.find_children("*","",true,false):
		if node is MeshInstance3D:
			print("MESH ",rig.get_path_to(node)," ",node.get_aabb()," ",node.position)
		elif node is Skeleton3D:
			print("SKELETON ",rig.get_path_to(node)," bones=",node.get_bone_count())
			for bone: int in range(node.get_bone_count()):
				if node.get_bone_name(bone) in ["head","hips","hand.r","hand.l","upperarm.r","upperarm.l","chest"]:
					print("BONE ",node.get_bone_name(bone)," ",node.get_bone_global_rest(bone))
		elif node is AnimationPlayer:
			print("ANIMPLAYER ",rig.get_path_to(node)," ",node.get_animation_list())
			var animation: Animation=node.get_animation("Walking_A")
			for track: int in range(animation.get_track_count()):
				print("TRACK ",animation.track_get_path(track)," TYPE ",animation.track_get_type(track))
	var skeleton: Skeleton3D=rig.get_node("Rig/Skeleton3D")
	var player: AnimationPlayer=rig.get_node("AnimationPlayer")
	for clip: String in ["Idle","2H_Ranged_Aiming","2H_Melee_Idle","Use_Item","PickUp","Throw","Sit_Chair_Idle"]:
		player.play(clip)
		player.advance(0.3)
		print("GRIP ",clip," right=",skeleton.get_bone_global_pose(skeleton.find_bone("hand.r")).origin," left=",skeleton.get_bone_global_pose(skeleton.find_bone("hand.l")).origin," length=",player.get_animation(clip).length)
	rig.queue_free()
	await process_frame
	quit(0)
