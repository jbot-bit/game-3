extends GutTest

const PlayerBody=preload("res://game/player/player.gd")
const FishBody=preload("res://game/fishing/physical_fish.gd")
const CELL_PATH: String="res://game/physics/supply_cell.gd"

func make_floor(height: float=0.0) -> void:
	var body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(20,1,20)
	collider.shape=shape
	body.add_child(collider)
	body.position.y=height-0.5
	body.collision_layer=1
	add_child_autofree(body)

func make_fish() -> RigidBody3D:
	var fish: RigidBody3D=FishBody.new()
	fish.setup("flop:1","penny_perch",true)
	fish.position=Vector3(0,0.5,0)
	add_child_autofree(fish)
	fish.set_host_simulated(true)
	return fish

func test_carried_angler_does_not_predict_gravity_and_carrier_has_weight() -> void:
	make_floor(1.0)
	var actor: CharacterBody3D=PlayerBody.new()
	actor.setup("crew_1",Color("62b9db"))
	actor.position=Vector3(0,1.02,0)
	add_child_autofree(actor)
	actor.last_dry=actor.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(actor.has_method("rescue_transform"),"Carrying requires a stable shoulder anchor")
	if not actor.has_method("rescue_transform"): return
	actor.being_carried=true
	var before: Vector3=actor.global_position
	actor.advance(0.1,Vector2.RIGHT,1.0,true)
	assert_eq(actor.global_position,before)
	assert_eq(actor.velocity,Vector3.ZERO)
	actor.being_carried=false
	actor.carrying_teammate=true
	for tick: int in range(20): actor.advance(0.01,Vector2.RIGHT,0.0,true)
	assert_eq(actor.velocity.x,3.5)
	actor.carrying_teammate=false
	actor.carrying=true
	for tick: int in range(20): actor.advance(0.01,Vector2.RIGHT,0.0,true)
	assert_eq(actor.velocity.x,4.25)
	actor.carrying=false
	for tick: int in range(20): actor.advance(0.01,Vector2.RIGHT,0.0,true)
	assert_eq(actor.velocity.x,5.0)
	var pose: Transform3D=actor.rescue_transform()
	assert_true(pose.origin.is_finite())
	assert_gt(pose.origin.y,actor.global_position.y+1.0)
	assert_lt(pose.origin.distance_to(actor.global_position),2.0)

func test_charged_toss_keeps_legacy_default_and_clamps_strength() -> void:
	var fish: RigidBody3D=make_fish()
	fish.toss(Vector3.RIGHT)
	assert_eq(fish.linear_velocity,Vector3(5,2,0))
	var supports_charge: bool=false
	for method: Dictionary in fish.get_method_list():
		if method.name=="toss": supports_charge=method.args.size()==2
	assert_true(supports_charge,"A charged toss must accept bounded strength")
	if not supports_charge: return
	fish.toss(Vector3.RIGHT,1.0)
	assert_gt(fish.linear_velocity.x,5.0)
	assert_lte(fish.linear_velocity.length(),8.0)
	var charged: Vector3=fish.linear_velocity
	fish.toss(Vector3.RIGHT,100.0)
	assert_eq(fish.linear_velocity,charged)
	fish.toss(Vector3.RIGHT,-100.0)
	assert_eq(fish.linear_velocity,Vector3(5,2,0))
	fish.toss(Vector3.RIGHT,NAN)
	assert_true(fish.linear_velocity.is_finite())
	fish.set_game_paused(true)
	fish.toss(Vector3.RIGHT,1.0)
	assert_eq(fish.linear_velocity,Vector3(5,2,0))

func test_loose_grounded_fish_flops_but_held_fish_is_still() -> void:
	make_floor()
	var fish: RigidBody3D=make_fish()
	for frame: int in range(80): await get_tree().physics_frame
	var greatest_hop: float=0.0
	var greatest_speed: float=0.0
	for frame: int in range(270):
		await get_tree().physics_frame
		greatest_hop=maxf(greatest_hop,fish.linear_velocity.y)
		greatest_speed=maxf(greatest_speed,fish.linear_velocity.length())
	assert_gt(greatest_hop,0.5,"An unattended trophy should give a small visible flop")
	assert_lte(greatest_speed,8.05)
	assert_true(fish.set_carry_pose(Transform3D(Basis.IDENTITY,Vector3(0,2,0)),Vector3(0,1,0)))
	var held_at: Vector3=fish.global_position
	for frame: int in range(200): await get_tree().physics_frame
	assert_eq(fish.global_position,held_at)
	assert_eq(fish.linear_velocity,Vector3.ZERO)

func test_supply_cell_reuses_physics_without_fish_flops() -> void:
	assert_true(ResourceLoader.exists(CELL_PATH),"Physical supplies need a battery body")
	if not ResourceLoader.exists(CELL_PATH): return
	make_floor()
	var cell: RigidBody3D=load(CELL_PATH).new()
	cell.setup_cell("cell_1")
	cell.position=Vector3(0,1,0)
	add_child_autofree(cell)
	cell.set_host_simulated(true)
	assert_true(cell is PhysicalFish)
	assert_eq(cell.cell_id,"cell_1")
	assert_true(cell.get_node("BatteryVisual").get_child_count()>=4)
	for frame: int in range(90): await get_tree().physics_frame
	var hops: float=0.0
	for frame: int in range(240):
		await get_tree().physics_frame
		hops=maxf(hops,cell.linear_velocity.y)
	assert_lt(hops,0.2)
	cell.toss(Vector3.RIGHT,1.0)
	assert_gt(cell.linear_velocity.x,5.0)
	cell.set_host_simulated(false)
	cell.apply_network_pose({"sequence":2,"transform":Transform3D(Basis.IDENTITY,Vector3(4,2,0))})
	cell.apply_network_pose({"sequence":1,"transform":Transform3D(Basis.IDENTITY,Vector3(9,2,0))})
	assert_eq(cell.global_position.x,4.0)
	assert_true(cell.freeze)


