extends GutTest
const World=preload("res://game/world/island.gd")

func route_distance(world: Node3D,from: Vector3,to: Vector3) -> float:
	var at: Vector3=from
	var distance: float=0.0
	for hop: int in range(40):
		if at.distance_to(to)<0.1: return distance
		var next: Vector3=world.route_step(at,to)
		if at.distance_to(next)<0.1: return INF
		distance+=at.distance_to(next)
		at=next
	return INF

func test_unrepaired_route_travel_is_short_without_shrinking_walkway_width() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var first: float=route_distance(world,world.markers.spawn,world.markers.jetty)
	print("COMPACT_FIRST_FISH metres=",first," seconds_at_5mps=",first/5.0)
	assert_lte(first/5.0,8.0,"Spawn to first fishing via grounded capsule-clear route")
	for id: String in world.markers:
		if id in ["refuge_mooring","escape_channel","escape_destination"]: continue
		var distance: float=route_distance(world,world.markers.boat,world.markers[id])
		print("COMPACT_ROUTE ",id," metres=",distance," seconds_at_5mps=",distance/5.0)
		assert_lte(distance/5.0,25.0,id+" reachable from home before any shortcuts")
	var crossing: MeshInstance3D=world.get_node("RepairedCrossing").get_child(0)
	assert_eq((crossing.mesh as BoxMesh).size.z,6.0,"Compact layout retains full carrying/rescue width")

func test_reeds_cast_stays_outside_shelter_and_distinct_from_seaward_tidepools() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var cast_at: Vector3=world.markers.reeds+Vector3(0,0,9)
	assert_eq(world.fishing_habitat(cast_at),"reeds","Lagoon-facing cast remains Reeds after map compression")
	assert_gte(cast_at.distance_to(world.markers.reeds),8.0,"Reeds cast remains outside shelter and cast exclusion")
	assert_true(world._route_ground(cast_at),"Designated Reeds cast stands on real ground")
	assert_eq(world.fishing_habitat(world.markers.tidepools),"tidepools","Seaward site keeps its own habitat")
	assert_eq(world.fishing_habitat(world.markers.beacon),"beacon","Northern site keeps its own habitat")

func test_station_return_lane_clears_whole_fish_at_carry_height() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2.5,1.25,0.7)
	for station: String in ["jetty","reeds"]:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.transform=Transform3D(Basis.IDENTITY,world.markers[station]+Vector3(0,1,0.82))
		query.motion=Vector3(0,0,4)
		query.collision_mask=1
		assert_eq(world.get_world_3d().direct_space_state.cast_motion(query)[0],1.0,station+" south return clears trophy-sized cargo without bypassing collision")

func test_grounded_jetty_home_route_also_clears_carried_fish() -> void:
	var world: Node3D=World.new()
	add_child_autofree(world)
	await wait_physics_frames(3)
	var at: Vector3=world.markers.jetty
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2.5,1.25,0.7)
	var clear: bool=true
	for step: int in range(200):
		if at.distance_to(world.markers.boat)<0.15: break
		var next: Vector3=world.route_step(at,world.markers.boat)
		var direction: Vector3=(next-at).normalized()
		at=at.move_toward(next,0.2)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.transform=Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),at+Vector3.UP+direction*0.82)
		query.collision_mask=1
		var hits: Array[Dictionary]=world.get_world_3d().direct_space_state.intersect_shape(query)
		if not hits.is_empty():
			print("CARGO_ROUTE_BLOCKED at=",at," collider=",hits[0].collider.get_path())
			clear=false
			break
	assert_true(clear,"Normal Jetty to home route supports carried fish as well as the player's capsule")
	assert_lt(at.distance_to(world.markers.boat),0.15)
