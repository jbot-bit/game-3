extends GutTest

const Camera = preload("res://game/player/camera_rig.gd")
var scene: Node3D
var actor: Node3D
var camera: Camera3D

func before_each() -> void:
	scene = Node3D.new()
	add_child_autofree(scene)
	actor = Node3D.new()
	scene.add_child(actor)
	camera = Camera.new()
	scene.add_child(camera)
	camera.target = actor
	camera.position = Vector3(0, 4.962, 6.753)
	await get_tree().physics_frame
	await get_tree().physics_frame

func obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	scene.add_child(body)
	body.position = at
	return body

func clear_view_of(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 17)
	return camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func test_side_of_pillar_cannot_hide_the_avatars_shoulder() -> void:
	obstacle(Vector3(0.58, 3.2, 3.5), Vector3(0.7, 5, 0.8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var focus := actor.global_position + Vector3(0, 1.7, 0)
	assert_true(clear_view_of(focus), "The old center ray misses this pillar edge")
	camera.follow(1.0)
	assert_true(camera.global_position.z < 3.1 or camera.global_position.y > 6.25, "Camera must move in front of or above the nearby pillar edge")
	assert_true(clear_view_of(focus + Vector3(0.45, 0, 0)), "Keep the full avatar visible, including its shoulder")
	assert_true(clear_view_of(focus - Vector3(0.45, 0, 0)))

func test_new_wall_is_resolved_on_actual_camera_before_rendering() -> void:
	obstacle(Vector3(0, 3, 4), Vector3(6, 7, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0 / 60.0)
	assert_lt(camera.global_position.z, 3.75, "Interpolation cannot leave the camera behind a newly encountered wall")
	assert_true(clear_view_of(actor.global_position + Vector3(0, 1.7, 0)))

func test_avatar_close_to_wall_still_gets_an_unblocked_view() -> void:
	# A standing avatar can fit here while a wider camera sweep begins overlapping
	# the wall. Physics shape sweeps ignore an obstacle they already overlap.
	obstacle(Vector3(0, 3, 0.6), Vector3(6, 7, 0.2))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0)
	assert_lt(camera.global_position.z, 0.5, "Do not ignore a wall beside the starting camera corridor")
	assert_true(clear_view_of(actor.global_position + Vector3(0, 1.7, 0)))

func test_camera_restores_distance_smoothly_after_obstacle_is_removed() -> void:
	var wall := obstacle(Vector3(0, 3, 4), Vector3(6, 7, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0)
	var nearby: Vector3 = camera.global_position
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0 / 60.0)
	assert_gt(camera.global_position.z, nearby.z, "Clearance returns camera toward normal framing")
	assert_lt(camera.global_position.z, 6.0, "Removing a wall must not snap to full camera distance")
	for frame in range(120): camera.follow(1.0 / 60.0)
	assert_almost_eq(camera.global_position.distance_to(actor.global_position + Vector3(0, 1.7, 0)), 7.5, 0.02)

func test_open_space_preserves_orbit_and_movement_controls() -> void:
	camera.apply_settings({"mouse_sensitivity": 2.0, "invert_y": true})
	camera.orbit(Vector2(10, 10))
	camera.follow(1.0)
	assert_almost_eq(camera.yaw, -0.08, 0.0001)
	assert_almost_eq(camera.pitch, -0.39, 0.0001)
	assert_almost_eq(camera.movement(Vector2.UP).length(), 1.0, 0.0001)
	assert_almost_eq(camera.global_position.distance_to(actor.global_position + Vector3(0, 1.7, 0)), 7.5, 0.02)

func test_jetty_cast_beside_rock_keeps_camera_outside_the_crews_head() -> void:
	# Actual jetty cast fixture: the centre ray misses the nearby rock, while
	# the shoulder sweep used to stop 0.43 m from the face and obscure the screen.
	var world: Node3D=load("res://game/world/island.gd").new()
	scene.add_child(world)
	actor.position=Vector3(-28.72,2.0,3.1)
	camera.yaw=-1.0614
	camera.position=Vector3(-34.616,6.964,6.393)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var focus:=actor.global_position+Vector3(0,1.7,0)
	for frame: int in range(90): camera.follow(1.0/60.0)
	assert_gt(camera.global_position.distance_to(focus),1.5,"A blocked shoulder sweep must find a clear viewpoint outside the character")
	assert_true(clear_view_of(focus),"The replacement viewpoint cannot cross the rock")
	assert_true(clear_view_of(actor.global_position+Vector3(0,0.9,0)),"Keep the body visible below the face")
	assert_true(clear_view_of(focus+camera.global_basis.x*0.38),"Keep the right shoulder visible")
	assert_true(clear_view_of(focus-camera.global_basis.x*0.38),"Keep the left shoulder visible")
	assert_almost_eq(camera.yaw,-1.0614,0.00001,"Automatic clearance must preserve the player's orbit and movement heading")

func test_foliage_blocks_camera_without_blocking_gameplay_collision_queries() -> void:
	var canopy:=obstacle(Vector3(0,4,4),Vector3(3,4,1))
	canopy.collision_layer=16
	canopy.collision_mask=0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var travel_ray:=PhysicsRayQueryParameters3D.create(Vector3(0,3,0),Vector3(0,3,6),1)
	assert_true(scene.get_world_3d().direct_space_state.intersect_ray(travel_ray).is_empty(),"Foliage must not become a gameplay wall")
	camera.follow(1.0)
	assert_true(camera.global_position.z < 3.5 or camera.global_position.y > 6.55,"The camera must stay in front of or above opaque foliage")
	assert_true(clear_view_of(actor.global_position+Vector3(0,1.7,0)),"Foliage cannot cover the character")

func test_jetty_cast_preserves_readable_body_scale_and_fishing_target() -> void:
	var world: Node3D=load("res://game/world/island.gd").new()
	scene.add_child(world)
	actor.position=Vector3(-28.72,2.05,3.1)
	camera.fov=65
	camera.yaw=-1.0615183
	camera.position=Vector3(-34.616,6.964,6.393)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var focus: Vector3=actor.global_position+Vector3(0,1.7,0)
	for frame: int in range(90): camera.follow(1.0/60.0)
	assert_gt(camera.global_position.distance_to(focus),4.0,"A clear camera must leave room to read the crew and surrounding fishing water")
	var frame_height: float=camera.get_viewport().get_visible_rect().size.y
	var head: Vector2=camera.unproject_position(actor.position+Vector3(0,2.65,0))
	var feet: Vector2=camera.unproject_position(actor.position)
	assert_lt(head.distance_to(feet)/frame_height,0.5,"The crew must occupy less than half the screen height at the jetty")
	var relative: Vector3=camera.global_position-focus
	assert_lt(absf(angle_difference(camera.yaw,atan2(relative.x,relative.z))),0.1,"A clear elevated view must preserve the screen-relative movement heading")


func test_fishing_frames_the_actual_bobber_and_crew_in_all_five_pockets() -> void:
	assert_true(camera.has_method("set_fishing_focus"),"The camera must compose around the actual fishing target")
	if not camera.has_method("set_fishing_focus"): return
	var world: Node3D=load("res://game/world/island.gd").new()
	scene.add_child(world)
	camera.fov=65
	await get_tree().physics_frame
	await get_tree().physics_frame
	var viewport: Vector2=camera.get_viewport().get_visible_rect().size
	for habitat: String in ["jetty","reeds","terraces","tidepools","beacon"]:
		actor.position=world.markers["reeds_cast" if habitat=="reeds" else habitat]
		if habitat=="jetty": actor.position+=Vector3(-1,0,1)
		var bobber: Vector3=world.fishing_focus(habitat)
		var toward: Vector3=bobber-actor.position
		camera.yaw=atan2(-toward.x,-toward.z)
		var original_yaw: float=camera.yaw
		camera.call("set_fishing_focus",bobber)
		camera.position=actor.position+Basis(Vector3.UP,camera.yaw)*Vector3(0,5,7)
		for frame: int in range(120): camera.follow(1.0/60.0)
		var bobber_screen: Vector2=camera.unproject_position(bobber)/viewport
		var head_screen: Vector2=camera.unproject_position(actor.position+Vector3(0,2.65,0))/viewport
		var feet_screen: Vector2=camera.unproject_position(actor.position)/viewport
		assert_false(camera.is_position_behind(bobber),habitat+": bobber must stay in front of the lens")
		assert_true(Rect2(0.12,0.16,0.76,0.63).has_point(bobber_screen),habitat+": bobber must remain in the usable view, got "+str(bobber_screen))
		assert_lt(absf(head_screen.y-feet_screen.y),0.5,habitat+": crew must not dominate the screen")
		# Conservative silhouette bounds for the actual block crew head and cap,
		# with extra room for the bobber itself, rather than an arbitrary gap.
		var head_bounds:=Rect2(camera.unproject_position(actor.position+Vector3(-0.55,1.3,-0.55))/viewport,Vector2.ZERO)
		for x: float in [-0.55,0.55]:
			for y: float in [1.3,2.3]:
				for z: float in [-0.55,0.55]:
					head_bounds=head_bounds.expand(camera.unproject_position(actor.position+Vector3(x,y,z))/viewport)
		assert_false(head_bounds.grow(0.025).has_point(bobber_screen),habitat+": head must not conceal the bobber")
		assert_true(clear_view_of(bobber),habitat+": scenery must not conceal the bobber")
		assert_true(clear_view_of(actor.position+Vector3(0,1.7,0)),habitat+": crew must stay visible")
		assert_almost_eq(camera.yaw,original_yaw,0.0001,habitat+": framing must not alter movement heading")

func test_fishing_composition_eases_in_and_out_without_moving_orbit_controls() -> void:
	assert_true(camera.has_method("set_fishing_focus"),"Fishing focus must be optional and reversible")
	if not camera.has_method("set_fishing_focus"): return
	camera.follow(1.0)
	var before: Transform3D=camera.global_transform
	camera.call("set_fishing_focus",Vector3(0,0,-10))
	camera.follow(1.0/60.0)
	assert_lt(camera.global_position.distance_to(before.origin),0.6,"Beginning a cast must not jump the lens")
	assert_gt(camera.global_basis.z.dot(before.basis.z),0.99,"Fishing look-ahead must ease in")
	for frame: int in range(120): camera.follow(1.0/60.0)
	camera.call("clear_fishing_focus")
	var fishing: Transform3D=camera.global_transform
	camera.follow(1.0/60.0)
	assert_lt(camera.global_position.distance_to(fishing.origin),0.6,"Ending a cast must not jump the lens")
	assert_gt(camera.global_basis.z.dot(fishing.basis.z),0.99,"Fishing look-ahead must ease out")
	for frame: int in range(120): camera.follow(1.0/60.0)
	assert_almost_eq(camera.yaw,0.0,0.0001)
	assert_almost_eq(camera.pitch,-0.45,0.0001)
	assert_almost_eq(camera.global_position.distance_to(actor.position+Vector3(0,1.7,0)),7.5,0.02)

func test_walking_past_a_rock_eases_reframing_without_orbit_jumps() -> void:
	var world: Node3D=load("res://game/world/island.gd").new()
	scene.add_child(world)
	actor.position=Vector3(-29.2,2.05,3.1)
	camera.yaw=-1.0615183
	await get_tree().physics_frame
	await get_tree().physics_frame
	for frame: int in range(120): camera.follow(1.0/60.0)
	var largest_step: float=0.0
	for frame: int in range(120):
		var previous: Vector3=camera.position
		actor.position.x+=0.01
		camera.follow(1.0/60.0)
		largest_step=maxf(largest_step,camera.position.distance_to(previous))
	assert_lt(largest_step,1.0,"A slow walk past a rock must not snap the camera to a different elevation")

func test_reduced_effects_keeps_user_composition_while_preserving_collision() -> void:
	camera.apply_settings({"reduced_effects":true})
	camera.follow(1.0)
	var before: Transform3D=camera.global_transform
	camera.set_fishing_focus(Vector3(6,0,-10))
	for frame: int in range(120): camera.follow(1.0/60.0)
	assert_lt(camera.global_position.distance_to(before.origin),0.001)
	assert_gt(camera.global_basis.z.dot(before.basis.z),0.99999,"Reduced effects must not add a fishing camera transition")

func test_forward_movement_follows_rendered_view_after_wall_avoidance() -> void:
	obstacle(Vector3(0,3,0.6),Vector3(6,7,0.2))
	await get_tree().physics_frame
	await get_tree().physics_frame
	camera.follow(1.0)
	var rendered_forward: Vector2=-Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	assert_gt(camera.movement(Vector2.UP).dot(rendered_forward),0.999,"Forward movement must follow the view after automatic side clearance")
	assert_almost_eq(camera.yaw,0.0,0.0001,"Collision avoidance must retain the requested orbit heading")

func test_movement_before_first_follow_uses_requested_orbit_heading() -> void:
	camera.yaw=PI/2.0
	assert_almost_eq(camera.movement(Vector2.UP).x,-1.0,0.0001)
	assert_almost_eq(camera.movement(Vector2.UP).y,0.0,0.0001)




func test_manual_orbit_can_override_fishing_composition() -> void:
	camera.set_fishing_focus(Vector3(0,0,-10))
	for frame: int in range(120): camera.follow(1.0/60.0)
	camera.orbit(Vector2(40,-100))
	for frame: int in range(120): camera.follow(1.0/60.0)
	var backward: Vector3=(camera.position-(actor.position+Vector3(0,1.7,0))).normalized()
	assert_almost_eq(atan2(backward.x,backward.z),camera.yaw,0.01,"Manual orbit must control the view while fishing")
	assert_almost_eq(-asin(backward.y),camera.pitch,0.01,"Manual pitch must not be pinned by fishing composition")
	camera.clear_fishing_focus()
	camera.set_fishing_focus(Vector3(0,0,-10))
	for frame: int in range(120): camera.follow(1.0/60.0)
	assert_gt(camera.position.y,actor.position.y+6.0,"A new cast can resume automatic composition")
