extends GutTest
const Game=preload("res://game/main.gd")
var app: Node3D
var c: Node
var actor: Angler

func before_each() -> void:
	app=Game.new()
	app.game_port=24903
	app.save_path="user://tests/action-face-"+str(Time.get_ticks_usec())+".json"
	app.settings_path="user://tests/action-face-settings-"+str(Time.get_ticks_usec())+".json"
	add_child_autofree(app)
	app._host("Aim")
	c=app.controller
	c.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	actor=c.avatars.crew_1
	await get_tree().physics_frame

func after_each() -> void:
	app.session.close()

func test_accepted_cast_faces_its_water_focus_but_rejected_cast_keeps_facing() -> void:
	actor.global_position=app.world.markers.jetty
	actor.last_dry=actor.global_position
	actor.rotation.y=1.1
	var habitat: String=app.world.fishing_habitat(actor.global_position)
	var toward: Vector3=app.world.fishing_focus(habitat)-actor.global_position
	assert_true(c._cast("crew_1").ok)
	assert_almost_eq(actor.rotation.y,atan2(-toward.x,-toward.z),0.0001)
	actor.rotation.y=1.3
	assert_false(c._cast("crew_1").ok)
	assert_almost_eq(actor.rotation.y,1.3,0.0001)

func _held_body(kind: String) -> PhysicalFish:
	actor.global_position=Vector3(300,10,300)
	actor.last_dry=actor.global_position
	actor.rotation.y=0
	var body: PhysicalFish
	if kind=="fish":
		var record: Dictionary=CatchTable.roll("jetty","day",0,0.8,0.05,0.5)
		record.merge({"catch_id":"aim-fish","run_id":c.run.run_id,"profile_id":"crew_1"})
		c._add_landed(record)
		assert_true(c.cargo.grab("aim-fish","crew_1",{"active":true,"distance_m":0.0,"line_of_sight":true}).ok)
		body=c.fish_bodies["aim-fish"]
	else:
		assert_true(c.supplies.grab("cell_1","crew_1",{"active":true,"distance_m":0.0,"line_of_sight":true}).ok)
		body=c.supply_bodies.cell_1
	body.global_transform=actor.carry_transform()
	assert_true(body.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6))
	# This goes through the same controller move input stored after Session validation.
	assert_true(c.apply_intent(1,"move",{"direction":Vector2.ZERO,"yaw":PI/2.0},"aim").ok)
	return body

func test_fish_throw_faces_latest_view_yaw_and_starts_at_safe_rotated_hands() -> void:
	var body: PhysicalFish=_held_body("fish")
	assert_true(c._release("crew_1",true,0.5).ok)
	assert_almost_eq(actor.rotation.y,PI/2.0,0.0001)
	assert_lt(body.linear_velocity.x,-5.0)
	assert_almost_eq(body.linear_velocity.z,0.0,0.001)
	assert_lt(body.global_position.distance_to(actor.carry_transform().origin),0.001)

func test_cell_throw_faces_latest_view_yaw_and_starts_at_safe_rotated_hands() -> void:
	var body: PhysicalFish=_held_body("cell")
	assert_true(c._release_cell("crew_1",true,0.5).ok)
	assert_almost_eq(actor.rotation.y,PI/2.0,0.0001)
	assert_lt(body.linear_velocity.x,-5.0)
	assert_almost_eq(body.linear_velocity.z,0.0,0.001)
	assert_lt(body.global_position.distance_to(actor.carry_transform().origin),0.001)

func _block_aim() -> void:
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(0.2,0.8,0.2)
	collision.shape=shape
	wall.add_child(collision)
	app.add_child(wall)
	wall.global_position=actor.global_position+Vector3(-0.82,1,0)
	await get_tree().physics_frame
	await get_tree().physics_frame

func test_blocked_fish_turn_keeps_cargo_and_actor_in_their_original_pose() -> void:
	var body: PhysicalFish=_held_body("fish")
	var before: Transform3D=body.global_transform
	await _block_aim()
	var prior_velocity: Vector3=body.linear_velocity
	assert_false(c._release("crew_1",true,0.5).ok)
	assert_eq(c.cargo.held_by("crew_1"),"aim-fish")
	assert_eq(body.global_transform,before)
	assert_eq(body.linear_velocity,prior_velocity,"Rejected throw must not add an impulse")
	assert_almost_eq(actor.rotation.y,0.0,0.0001)

func test_blocked_cell_turn_keeps_cargo_and_actor_in_their_original_pose() -> void:
	var body: PhysicalFish=_held_body("cell")
	var before: Transform3D=body.global_transform
	await _block_aim()
	var prior_velocity: Vector3=body.linear_velocity
	assert_false(c._release_cell("crew_1",true,0.5).ok)
	assert_eq(c.supplies.held_by("crew_1"),"cell_1")
	assert_eq(body.global_transform,before)
	assert_eq(body.linear_velocity,prior_velocity,"Rejected throw must not add an impulse")
	assert_almost_eq(actor.rotation.y,0.0,0.0001)
