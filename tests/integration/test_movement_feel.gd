extends GutTest
const Player = preload("res://game/player/player.gd")
const Camera = preload("res://game/player/camera_rig.gd")
class RecordingPlayer:
	extends Angler
	var shown_speed: float=0.0
	func animate(_delta: float,speed: float) -> void:
		shown_speed=speed

var actor: Angler
var camera: CrewCamera
var stage: Node3D

func before_each() -> void:
	stage=Node3D.new()
	add_child_autofree(stage)
	var ground:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(100,2,100)
	shape.shape=box
	ground.add_child(shape)
	stage.add_child(ground)
	actor=RecordingPlayer.new()
	actor.setup("crew_1",Color.SKY_BLUE)
	stage.add_child(actor)
	actor.global_position=Vector3(0,1.01,0)
	actor.last_dry=actor.global_position
	camera=Camera.new()
	stage.add_child(camera)
	camera.target=actor
	await get_tree().physics_frame
	await get_tree().physics_frame

func test_orbiting_while_idle_does_not_turn_the_character() -> void:
	actor.rotation.y=1.1
	for i: int in range(30): actor.advance(1.0/60.0,Vector2.ZERO,-1.5,true)
	assert_almost_eq(actor.rotation.y,1.1,0.0001)

func test_starts_quickly_without_instant_full_speed_and_stops_within_eight_ticks() -> void:
	actor.advance(1.0/60.0,Vector2.RIGHT,0,true)
	assert_gt(actor.velocity.x,0.2)
	assert_lt(actor.velocity.x,2.0,"One physics tick should not jump to the full 5m/s")
	for i: int in range(15): actor.advance(1.0/60.0,Vector2.RIGHT,0,true)
	assert_almost_eq(actor.velocity.x,5.0,0.001)
	actor.advance(1.0/60.0,Vector2.ZERO,0,true)
	assert_gt(actor.velocity.x,0.0,"A short stopping phase supports the authored stop animation")
	for i: int in range(7): actor.advance(1.0/60.0,Vector2.ZERO,0,true)
	assert_almost_eq(actor.velocity.x,0.0,0.001)

func test_carry_speed_caps_and_disabled_states_remain_authoritative() -> void:
	actor.carrying=true
	for i: int in range(30): actor.advance(1.0/60.0,Vector2.ONE,0,true)
	assert_almost_eq(Vector2(actor.velocity.x,actor.velocity.z).length(),4.25,0.001)
	actor.carrying_teammate=true
	actor.advance(1.0/60.0,Vector2.ONE,0,true)
	assert_lte(Vector2(actor.velocity.x,actor.velocity.z).length(),3.5001)
	actor.fishing=true
	actor.advance(1.0/60.0,Vector2.ONE,0,true)
	assert_eq(Vector2(actor.velocity.x,actor.velocity.z),Vector2.ZERO)

func test_camera_settling_is_independent_of_render_rate() -> void:
	var stationary:=Node3D.new()
	stage.add_child(stationary)
	stationary.position=Vector3(0,2,0)
	camera.target=stationary
	var start:=Vector3(9,8,13)
	camera.position=start
	for i: int in range(3): camera.follow(1.0/30.0)
	var at_30: Vector3=camera.position
	camera.position=start
	for i: int in range(12): camera.follow(1.0/120.0)
	assert_lt(camera.position.distance_to(at_30),0.0001)

func test_zoom_is_bounded_and_does_not_change_movement_direction() -> void:
	assert_true(camera.has_method("zoom"))
	if not camera.has_method("zoom"): return
	var direction: Vector2=camera.movement(Vector2.UP)
	camera.zoom(100)
	assert_almost_eq(camera.distance,4.5,0.001)
	camera.zoom(-100)
	assert_almost_eq(camera.distance,10.0,0.001)
	assert_eq(camera.movement(Vector2.UP),direction)

func test_visual_interpolation_does_not_move_the_collision_body_and_resets_on_teleport() -> void:
	assert_true(actor.has_method("render_transform"))
	if not actor.has_method("render_transform"): return
	actor.reset_visual_interpolation()
	var from: Vector3=actor.global_position
	actor.global_position+=Vector3.RIGHT
	actor._physics_process(1.0/60.0)
	assert_almost_eq(actor.render_transform(0.5).origin.x,from.x+0.5,0.0001)
	assert_almost_eq(actor.global_position.x,from.x+1.0,0.0001)
	actor.global_position+=Vector3.RIGHT*10
	actor._physics_process(1.0/60.0)
	assert_eq(actor.render_transform(0.5).origin,actor.global_position)

func test_blocked_character_does_not_keep_playing_a_full_speed_walk() -> void:
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(0.4,4,8)
	shape.shape=box
	wall.add_child(shape)
	stage.add_child(wall)
	wall.position=Vector3(0.8,2,0)
	await get_tree().physics_frame
	for i: int in range(40):
		await get_tree().physics_frame
		actor.advance(1.0/60.0,Vector2.RIGHT,0,true)
	assert_lt(actor.shown_speed,0.05)
