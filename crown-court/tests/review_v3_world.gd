extends SceneTree
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
var world: Node3D
var unchanged := true
var results := []

func _initialize() -> void:
	run.call_deferred()

func present(sim: RefCounted) -> void:
	var state: Dictionary = sim.snapshot()
	state.players = {1: state.players[1]}
	var before := var_to_bytes(state)
	world.present(state, 1, 1.0 / 60, 0, .43)
	unchanged = unchanged and before == var_to_bytes(state)

func prepare(giant: bool) -> RefCounted:
	var sim = Sim.new()
	sim.reset("coop")
	sim.reset_time = 0.0
	for id in sim.players: sim.players[id].pos = Vector3(15 if id % 2 else -15, 1, 0)
	sim.players[1].giant = 7.0 if giant else 0.0
	sim.ball.owner = 1
	return sim

func run() -> void:
	world = World.new()
	root.add_child(world)
	world.build("coop")
	var passed := true
	for growth in ["normal", "giant", "onset", "expiry"]:
		var sim = prepare(growth in ["giant", "expiry"])
		var p: Dictionary = sim.players[1]
		p.pos = Vector3(0, 0, -13)
		p.aim = Vector3.FORWARD
		p.facing = p.aim
		for frame in 90:
			sim.ball.pos = sim.hand_position(1)
			present(sim)
		p.vel = Vector3.FORWARD * 18
		for frame in 30:
			p.pos.z -= .3
			sim.ball.pos = sim.hand_position(1)
			present(sim)
		if growth == "onset": p.giant = 7.0
		if growth == "expiry": p.giant = 0.0
		sim.ball.pos = sim.hand_position(1)
		present(sim)
		var before: Vector3 = world.ball_root.position
		var initial_offset: float = before.distance_to(sim.ball.pos)
		sim.action(1, "throw", .5)
		present(sim)
		var jump: float = world.ball_root.position.distance_to(before)
		var score_offset := 0.0
		var kickoff_offset := 0.0
		var residual_at_200ms := 0.0
		for frame in 240:
			sim.step(1.0 / 60)
			present(sim)
			if frame == 11: residual_at_200ms = world.ball_root.position.distance_to(sim.ball.pos)
			if sim.celebration_time > 0: score_offset = maxf(score_offset, world.ball_root.position.distance_to(sim.ball.pos))
			if sim.baskets > 0 and sim.celebration_time <= 0:
				kickoff_offset = world.ball_root.position.distance_to(sim.ball.pos)
				break
		var ok: bool = jump < .001 and residual_at_200ms < .01 and sim.baskets == 1 and kickoff_offset < .001
		passed = passed and ok
		results.append({"case":"throw_" + growth,"pass":ok,"release_without_time_jump_m":jump,"initial_presentation_offset_m":initial_offset,"residual_at_200ms_m":residual_at_200ms,"score_offset_m":score_offset,"kickoff_offset_m":kickoff_offset,"baskets":sim.baskets})
	for giant in [false, true]:
		for approach in [Vector3(0, 0, 4.3), Vector3(4, 0, 0), Vector3(0, 0, -4)]:
			var sim = prepare(giant)
			var p: Dictionary = sim.players[1]
			p.pos = Sim.NORTH + approach
			p.pos.y = Sim.floor_height(p.pos.x, p.pos.z) + 1.2
			p.grounded = false
			p.aim = -approach.normalized()
			p.facing = p.aim
			p.vel = p.aim * 9.5 + Vector3.UP * 6
			sim.ball.pos = sim.hand_position(1)
			for frame in 90: present(sim)
			sim.action(1, "dunk")
			var hand_gap := 0.0
			var release_offset := 0.0
			var score_offset := 0.0
			var kickoff_offset := 0.0
			for frame in 300:
				var owned: bool = sim.ball.owner == 1
				sim.step(1.0 / 60)
				present(sim)
				if sim.ball.owner == 1:
					for key in ["left_hand", "right_hand"]:
						hand_gap = maxf(hand_gap, world.actors[1][key].global_position.distance_to(world.ball_root.global_position))
				elif owned: release_offset = world.ball_root.position.distance_to(sim.ball.pos)
				if sim.celebration_time > 0: score_offset = maxf(score_offset, world.ball_root.position.distance_to(sim.ball.pos))
				if sim.baskets > 0 and sim.celebration_time <= 0:
					kickoff_offset = world.ball_root.position.distance_to(sim.ball.pos)
					break
			var ok: bool = sim.baskets == 1 and hand_gap < .82 and kickoff_offset < .001
			passed = passed and ok
			results.append({"case":"dunk","giant":giant,"approach":approach,"pass":ok,"hand_center_gap_m":hand_gap,"release_offset_m":release_offset,"score_offset_m":score_offset,"kickoff_offset_m":kickoff_offset,"baskets":sim.baskets})
	print("REVIEW_V3_WORLD " + JSON.stringify({"pass":passed and unchanged,"presentation_input_unchanged":unchanged,"cases":results}))
	world.free()
	quit(0 if passed and unchanged else 1)
