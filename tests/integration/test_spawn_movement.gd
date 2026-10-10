extends GutTest
const World=preload("res://game/world/island.gd")
const Player=preload("res://game/player/player.gd")

func test_all_three_spawn_slots_have_upward_ground_and_allow_the_first_walk() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	var crew: Array[CharacterBody3D]=[]
	var starts: Array[Vector3]=[]
	for slot in range(3):
		var actor: CharacterBody3D=Player.new()
		actor.setup("crew_%d"%(slot+1),Color.WHITE)
		world.add_child(actor)
		actor.position=world.markers.spawn+Vector3((slot-1)*2.5,0,0)
		actor.last_dry=actor.position
		crew.append(actor)
		starts.append(actor.position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for start in starts:
		var query:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*5,start-Vector3.UP*5,1)
		var ground: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		assert_false(ground.is_empty(),"The rendered terrain must collide from above at every spawn")
		if not ground.is_empty(): assert_gt(ground.normal.y,0.9)
	var stayed_above_water: Array[bool]=[true,true,true]
	for tick in range(60):
		await get_tree().physics_frame
		for slot in range(3):
			crew[slot].advance(1.0/60.0,Vector2.UP,0.0,true)
			stayed_above_water[slot]=stayed_above_water[slot] and crew[slot].global_position.y>0.4
	for slot in range(3):
		assert_true(stayed_above_water[slot],"Walking away from spawn must stay grounded")
		assert_gt(starts[slot].z-crew[slot].global_position.z,4.0,"Real movement must not repeatedly fall and water-recover to spawn")
		assert_true(crew[slot].is_on_floor(),"All three starting lanes finish on physical terrain")
