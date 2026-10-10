extends GutTest

class CountedWorld extends "res://game/world/island.gd":
	var route_calls: int=0
	var collision_updates: int=0
	func route_step(from: Vector3,to: Vector3) -> Vector3:
		route_calls+=1
		return super.route_step(from,to)
	func _set_collision(node: Node,enabled: bool) -> void:
		collision_updates+=1
		super._set_collision(node,enabled)

var scene: Node3D
var world: CountedWorld
var session: Session
var c: RunController

func before_each() -> void:
	scene=Node3D.new()
	add_child_autofree(scene)
	world=CountedWorld.new()
	scene.add_child(world)
	session=Session.new()
	scene.add_child(session)
	c=RunController.new()
	scene.add_child(c)
	c.configure(session,world)
	assert_true(c.prepare_host("user://tests/hunter-perf-"+str(Time.get_ticks_usec())+".json").ok)
	assert_eq(session.host(24637),OK)
	c.start_day()
	c.set_physics_process(false)
	c.avatars.crew_1.global_position=world.markers.boat
	c.avatars.crew_1.last_dry=world.markers.boat
	c.hunter.global_position=world.markers.beacon
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.route_calls=0
	world.collision_updates=0

func after_each() -> void:
	session.close()

func test_daylight_and_recovery_do_not_solve_routes_for_a_stationary_hunter() -> void:
	for frame in range(12): c._tick_hunter(1.0/60.0)
	assert_eq(world.route_calls,0,"Daylight hunter does not move; do not solve its route")
	c.run.elapsed_s=300.0
	c.hunter_rules.state="recover"
	for frame in range(12): c._tick_hunter(1.0/60.0)
	assert_eq(world.route_calls,0,"Recovery also stays still without path work")
	assert_eq(Vector2(c.hunter.velocity.x,c.hunter.velocity.z),Vector2.ZERO)

func test_patrol_moves_every_tick_but_replans_at_a_bounded_cadence() -> void:
	c.run.elapsed_s=300.0
	for frame in range(30): c._tick_hunter(1.0/60.0)
	assert_between(world.route_calls,1,3,"A half-second patrol needs at most three path solves, not thirty")
	assert_almost_eq(Vector2(c.hunter.velocity.x,c.hunter.velocity.z).length(),2.6,0.001)
	assert_gt(c.hunter.global_position.distance_to(world.markers.beacon),1.0)
	assert_true(world._route_ground(c.hunter.global_position),"Cached waypoint movement must remain on the island")

func test_detection_and_attack_do_not_wait_for_a_cached_route_timer() -> void:
	c.run.elapsed_s=300.0
	c.avatars.crew_1.global_position=world.markers.reeds+Vector3(0,0,9)
	c.avatars.crew_1.last_dry=c.avatars.crew_1.global_position
	c.hunter.global_position=c.avatars.crew_1.global_position+Vector3(0,0,1.0)
	c._tick_hunter(1.0/60.0)
	assert_eq(c.hunter_rules.state,"warn","Nearby crew must still be detected immediately")
	assert_false(c.run.players.crew_1.downed,"Warning gives the crew its escape window")
	c.hunter_rules.state="chase"
	c.hunter_rules.state_time=0.0
	c._tick_hunter(1.0/60.0)
	assert_true(c.run.players.crew_1.downed,"Contact attacks remain a per-tick authority check")

func test_unchanged_repair_snapshots_do_not_requeue_collisions() -> void:
	world.set_repaired(false)
	world.set_campaign({})
	await get_tree().physics_frame
	world.collision_updates=0
	for tick in range(20):
		world.set_repaired(false)
		world.set_campaign({})
	assert_eq(world.collision_updates,0,"Unchanged 5 Hz snapshots must not recursively requeue bridge physics")
	assert_false(has_floor(world.layout_point(Vector3(0,2.05,10))),"The initial broken span remains physically absent")
	assert_false(has_floor(world.layout_point(Vector3(41,2.05,-22))),"The initial ridge remains physically absent")
	world._route_links_valid=true
	world.set_repaired(true)
	world.set_campaign({"ridge_steps":true})
	assert_false(world._route_links_valid,"Repair must still invalidate cached navigation links")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(has_floor(world.layout_point(Vector3(0,2.05,10))),"Repair makes the crossing a real collider")
	assert_true(has_floor(world.layout_point(Vector3(41,2.05,-22))),"Repair makes the ridge a real collider")
	world.set_repaired(false)
	world.set_campaign({})
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(has_floor(world.layout_point(Vector3(0,2.05,10))))
	assert_false(has_floor(world.layout_point(Vector3(41,2.05,-22))))

func has_floor(at: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2.0,at-Vector3.UP*1.0,1)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
