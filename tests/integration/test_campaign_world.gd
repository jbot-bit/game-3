extends GutTest
const World=preload("res://game/world/island.gd")

func test_second_shortcut_has_support_only_when_repaired() -> void:
	var world=World.new()
	add_child_autofree(world)
	var a=World.layout_point(Vector3(16,2.05,10))
	var b=World.layout_point(Vector3(66,2.05,-54))
	assert_false(world._route_segment(a,b))
	world.set_campaign({"ridge_steps":true})
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(world._route_segment(a,b))
	var middle=a.lerp(b,0.5)
	var hit=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(middle+Vector3.UP*2,middle-Vector3.UP*2,1))
	assert_false(hit.is_empty(),"Repaired shortcut needs an actual floor, not just navigation")
	world.set_campaign({})
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(world._route_segment(a,b))

func test_hunter_capsule_crosses_both_shortcuts_junction() -> void:
	var world=World.new()
	add_child_autofree(world)
	world.set_campaign({"ridge_steps":true})
	world.set_repaired(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shape=CapsuleShape3D.new()
	shape.radius=0.48
	shape.height=3.8
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,World.layout_point(Vector3(16,3.96,10)))
	query.motion=World.layout_point(Vector3(20,0,0))
	query.collision_mask=1
	var motion=world.get_world_3d().direct_space_state.cast_motion(query)
	assert_eq(motion[0],1.0,"No shortcut railing may block the central walking route")

func test_all_content_markers_are_grounded_and_escape_channel_is_water() -> void:
	var world=World.new()
	add_child_autofree(world)
	await get_tree().physics_frame
	for marker in IslandContent.cache_markers().values()+IslandContent.repair_markers().values():
		assert_true(world.markers.has(marker),str(marker))
		assert_true(world._route_ground(world.markers[marker]),str(marker)+" needs safe footing")
	for habitat in world.fishing_markers():
		assert_true(world._route_ground(world.markers[habitat]),habitat)
	assert_false(world._route_ground(World.layout_point(Vector3(0,2,57))),"Moth needs a real open sea channel")
