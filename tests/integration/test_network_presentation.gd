extends GutTest

var stage: Node3D
var session: Session
var controller: RunController
var remote: Angler
var local: Angler

func before_each() -> void:
	stage=Node3D.new()
	add_child_autofree(stage)
	session=Session.new()
	stage.add_child(session)
	session.local_profile_id="crew_1"
	controller=RunController.new()
	stage.add_child(controller)
	controller.session=session
	controller.set_physics_process(false)
	controller.set_process(false)
	controller.snapshot_data={"run":{"run_id":"presentation-a","elapsed_s":300.0}}
	for id: String in ["crew_1","crew_2"]:
		var actor:=Angler.new()
		actor.setup(id,Color.SKY_BLUE)
		stage.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.global_position=Vector3(0,2,0)
		actor.reset_visual_interpolation()
		controller.avatars[id]=actor
	local=controller.avatars.crew_1
	remote=controller.avatars.crew_2

func after_each() -> void:
	session.close()

func receive(id: String, x: float) -> void:
	controller._poses_received({"run_id":"presentation-a","players":{id:{"position":Vector3(x,2,0),"yaw":0.0,"velocity":Vector3(5,0,0)}}})

func test_remote_moves_between_twenty_hz_packets_at_120_hz_without_changing_body_correction() -> void:
	receive("crew_2",0.0)
	var trace: Array[float]=[]
	var stopped_frames: int=0
	var prior: float=0.0
	for packet: int in range(1,13):
		var before: float=remote.global_position.x
		receive("crew_2",float(packet)*0.25)
		assert_almost_eq(remote.global_position.x,before+(float(packet)*0.25-before)*0.85,0.00001,"Presentation cannot change received body reconciliation")
		for frame: int in range(6):
			if frame%2==0: remote._physics_process(1.0/60.0)
			remote._process(1.0/120.0)
			var shown: float=remote.render_transform(0.5).origin.x
			if packet>2 and shown-prior<0.0001: stopped_frames+=1
			assert_gte(shown,prior-0.00001,"A forward remote walk must not reverse between updates")
			trace.append(shown)
			prior=shown
	assert_eq(stopped_frames,0,"20 Hz arrivals must not freeze the visual for two physics ticks between packets")
	assert_almost_eq(prior,remote.global_position.x,0.0001,"A stopped stream must finish its short transition, never drift indefinitely")
	print("NETWORK_PRESENTATION_120HZ_TRACE "+JSON.stringify(trace))

func test_local_small_correction_does_not_jump_the_rendered_camera_target() -> void:
	receive("crew_1",0.0)
	local.global_position=Vector3(1,2,0)
	local.reset_visual_interpolation()
	var before: Vector3=local.render_transform(1.0).origin
	var camera:=CrewCamera.new()
	stage.add_child(camera)
	camera.target=local
	camera.follow(1.0)
	var camera_before: Vector3=camera.global_position
	receive("crew_1",0.8)
	local._physics_process(1.0/60.0)
	assert_almost_eq(local.global_position.x,0.83,0.00001,"Keep the existing authoritative body correction")
	assert_lt(local.render_transform(1.0).origin.distance_to(before),0.01,"The camera follows render_transform; a normal reconciliation must not jerk it backwards")
	camera.follow(1.0/120.0)
	assert_lt(camera.global_position.distance_to(camera_before),0.002,"The real follow camera should not chase the correction on its arrival frame")
	for frame: int in range(24): local._process(1.0/120.0)
	assert_almost_eq(local.render_transform(1.0).origin.x,0.83,0.0001,"Small correction smoothing must expire rather than retain visual error")
	receive("crew_1",0.63)
	receive("crew_1",15.0)
	assert_eq(local.render_transform(1.0).origin,local.global_position,"A local teleport clears all old correction offsets")

func test_hunter_smooths_between_packets_but_keeps_its_authoritative_body() -> void:
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(0,2,0))})
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(0.24,2,0))})
	assert_almost_eq(controller.hunter.global_position.x,0.24,0.00001)
	assert_almost_eq(controller.hunter_visual.global_position.x,0.0,0.00001,"A pose arrival must not immediately jump the visible hunter")
	var prior: float=0.0
	for frame: int in range(6):
		if controller.has_method("_process"): controller._process(1.0/120.0)
		var shown: float=controller.hunter_visual.global_position.x
		assert_gt(shown,prior,"The hunter should keep moving on every rendered frame between packets")
		prior=shown
	assert_almost_eq(prior,0.24,0.00001,"No extrapolation after the bounded transition")

func test_first_pose_large_teleport_and_new_run_do_not_sweep_across_the_island() -> void:
	receive("crew_2",2.0)
	assert_eq(remote.render_transform(0.5).origin,remote.global_position,"First pose snaps even within ordinary smoothing distance")
	receive("crew_2",2.25)
	remote._process(1.0/120.0)
	receive("crew_2",25.0)
	assert_eq(remote.render_transform(0.5).origin,remote.global_position,"A large teleport must not leave a trailing avatar")
	controller.snapshot_data.run.run_id="presentation-b"
	controller._poses_received({"run_id":"presentation-b","players":{"crew_2":{"position":remote.global_position+Vector3.RIGHT,"yaw":0.0,"velocity":Vector3.ZERO}},"hunter":Transform3D(Basis.IDENTITY,Vector3(18,2,0))})
	assert_eq(remote.render_transform(0.5).origin,remote.global_position,"New outing resets even a short relocation")
	assert_eq(controller.hunter_visual.global_transform,controller.hunter.global_transform)
	var before: Vector3=remote.global_position
	receive("crew_2",100.0)
	assert_eq(remote.global_position,before,"Prior-run packets must still be rejected")

func test_duplicate_snapshot_pose_does_not_restart_the_packet_transition() -> void:
	receive("crew_2",0.0)
	receive("crew_2",1.0)
	remote._process(0.025)
	receive("crew_2",1.0)
	remote._process(0.025)
	assert_almost_eq(remote.render_transform(1.0).origin.x,remote.global_position.x,0.00001,"A duplicate 5 Hz snapshot must not postpone the original 50 ms endpoint")
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(0,2,0))})
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(0.24,2,0))})
	controller._process(0.025)
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(0.24,2,0))})
	controller._process(0.025)
	assert_almost_eq(controller.hunter_visual.global_position.x,0.24,0.00001,"Duplicate hunter snapshots must not keep resetting its transition")

func test_disconnected_client_can_host_with_reused_player_and_hunter_visuals() -> void:
	var world:=IslandWorld.new()
	stage.add_child(world)
	controller.configure(session,world)
	session.local_profile_id="crew_2"
	receive("crew_1",1.0)
	controller._poses_received({"run_id":"presentation-a","hunter":Transform3D(Basis.IDENTITY,Vector3(6,2,0))})
	var retained_player: Angler=local
	session._server_disconnected()
	assert_eq(controller.avatars.crew_1,retained_player,"The disconnect path really retains the old remote host avatar")
	assert_true(controller.prepare_host("user://tests/authority-transition-"+str(Time.get_ticks_usec())+".json").ok)
	assert_eq(session.host(24648),OK)
	controller.start_day()
	assert_eq(controller.avatars.crew_1,retained_player,"Hosting reuses this avatar rather than masking the bug with a replacement")
	local._physics_process(1.0/60.0)
	local.global_position+=Vector3.RIGHT
	local._physics_process(1.0/60.0)
	assert_eq(local.render_transform(1.0).origin,local.global_position,"The new host visual must follow host physics instead of a stale network target")
	controller.hunter.global_position+=Vector3.RIGHT
	controller._process(1.0/60.0)
	assert_eq(controller.hunter_visual.global_transform,controller.hunter.global_transform,"The new host hunter must inherit its moving body again")
