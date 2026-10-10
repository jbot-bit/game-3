extends GutTest
const World=preload("res://game/world/island.gd")

func test_fishing_and_moth_are_over_water_not_new_terrain() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var points: Dictionary={"Moth":world.get_node("MothSkiff").global_position}
	for habitat in world.fishing_markers(): points[habitat]=world.fishing_focus(habitat)
	for label in points:
		var at: Vector3=points[label]
		var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,10,at.z),Vector3(at.x,0.2,at.z),1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		assert_true(hit.is_empty(),str(label)+" must be open water above sea level")
