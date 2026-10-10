extends GutTest
const World=preload("res://game/world/island.gd")

func test_north_route_is_flat_and_keeps_unrepaired_patrol_connected() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for x in [-66.0,-45.0,-20.0,0.0,20.0,44.0,66.0]:
		var query:=PhysicsRayQueryParameters3D.create(World.layout_point(Vector3(x,8,-55.5)),World.layout_point(Vector3(x,-2,-55.5)),1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		assert_false(hit.is_empty())
		if not hit.is_empty(): assert_almost_eq(hit.position.y,2.0,0.025,"Coarse terrain triangles must not slope hills into the flat patrol corridor")
	# Actual endpoints where the previous full-body traversal stalled.
	for leg in [{"at":Vector3(65.87162,2.000896,-50.04466),"to":"terraces"},{"at":Vector3(-46.75813,1.970643,-44.17729),"to":"beacon"}]:
		leg.at=World.layout_point(leg.at)
		var next: Vector3=world.route_step(leg.at,world.markers[leg.to])
		assert_gt(Vector2(next.x-leg.at.x,next.z-leg.at.z).length(),0.2,"Unrepaired island must offer a genuine next patrol waypoint")

func test_lido_route_keeps_the_full_width_platform_supported_without_water_shortcuts() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(world._route_ground(world.markers.terraces+Vector3(0,0,6)),"The wider platform must not declare the water beyond its edge walkable")
	var from: Vector3=World.layout_point(Vector3(-44,2.05,-53))
	var next: Vector3=world.route_step(from,world.markers.terraces)
	assert_gt(next.distance_to(from),0.2,"The compact full-width platform must still have a connected approach")

func test_lido_west_approach_has_continuous_support_over_the_beach_lip() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for z in [-48.5,-47.5,-46.5,-45.5]:
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(World.layout_point(Vector3(-51,5,z)),World.layout_point(Vector3(-51,0,z)),1))
		assert_false(hit.is_empty())
		if not hit.is_empty(): assert_between(hit.position.y,1.97,2.075,"Wooden access must physically cover the drop before the Lido platform")
