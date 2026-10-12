extends SceneTree
const World = preload("res://world.gd")
var evidence := "C:/game-3/build/crown-court-evidence/motion-poses"
var checks: Array = []
var capture := false
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
		if arg=="--capture": capture=true
	run.call_deferred()
func check(ok: bool, label: String):
	checks.append({"passed":ok,"check":label})
	print("PASS " if ok else "FAIL ",label)
func run():
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,800)
	var world=World.new()
	root.add_child(world)
	world.build("coop")
	var actor=world._make_actor(1)
	world.actors[1]=actor
	world._equip_actor(actor,1,{"character":"dad","accessory":"cap"})
	var data={"pos":Vector3(0,0,0),"vel":Vector3(0,0,-7),"move":Vector3.ZERO,"facing":Vector3.FORWARD,"grounded":true,"slide_time":.5,"slide_kind":"dive"}
	for n in 30: world._present_actor(actor,1,data,false,false,Vector3(5,1,0),"Dad",1.0/60)
	var slide_pitch: float=actor.rig.rotation.x
	check(slide_pitch<-.45,"Dive recovery stays low while residual momentum slides")
	check(actor.left_foot.position.y<.16 and actor.right_foot.position.y<.16,"Recovery plants both feet instead of running in place")
	world.camera.position=Vector3(4,3,-5)
	world.camera.look_at(Vector3(0,1,0))
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join("dive-slide.png"))
	data.slide_time=0
	data.vel=Vector3.ZERO
	for n in 60: world._present_actor(actor,1,data,false,false,Vector3(5,1,0),"Dad",1.0/60)
	check(absf(actor.rig.rotation.x)<.02,"Recovery returns upright without persistent pose offset")
	data.vel=Vector3(0,0,-7)
	for n in 30: world._present_actor(actor,1,data,false,false,Vector3(5,1,0),"Dad",1.0/60)
	check(actor.left_foot.position.y<.17 and actor.right_foot.position.y<.17,"Released run coasts with planted feet")
	for side in [-1,1]:
		var target=Vector3(8,3,side*53)
		var wanted=Vector3(8,5,side*62)
		var result: Vector3=world._clear_stadium_boom(target,wanted)
		check(absf(result.z)<56.31 and result.distance_to(target)>2,"Goal orbit boom stays inside foreground crowd wall %s"%side)
		data.pos=Vector3(8,world._floor_height(8,side*53),side*53)
		data.vel=Vector3.ZERO
		world._present_actor(actor,1,data,false,false,Vector3(15,1,0),"Dad",1.0)
		if capture:
			world.camera.position=wanted
			world.camera.look_at(target)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence.path_join("goal-obstructed-%s.png"%side))
		world.camera.position=result
		world.camera.look_at(target)
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence.path_join("goal-clearance-%s.png"%side))
	check(world._clear_stadium_boom(Vector3(0,3,0),Vector3(0,5,9))==Vector3(0,5,9),"Normal court camera boom unchanged")
	check(world._clear_stadium_boom(Vector3(0,3,56.29),Vector3(0,4,64)).distance_to(Vector3(0,3,56.29))>1.19,"Wall contact retains nonzero camera view axis")
	for target in [Vector3(0,3,56.29),Vector3(32.15,3,56.15)]:
		world.camera.position=world._clear_stadium_boom(target,target+Vector3(2,1,8))
		world.camera.look_at(target)
		check(world.camera.basis.is_finite() and absf(world.camera.basis.determinant()-1)<.001,"Wall and corner view basis remains finite and orthonormal")
	var passed=true
	for entry in checks: passed=passed and entry.passed
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks},"  "))
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
