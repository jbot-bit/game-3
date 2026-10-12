extends SceneTree
const Sim = preload("res://sim.gd")
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g = Sim.new()
	g.reset("coop")
	check(g.players[1].pos.y > 6 and g.players[1].pos.z > 32, "Team starts on a raised deck behind its own hoop")
	var start: Vector3 = g.players[1].pos
	for i in 179: g.step(1.0/60)
	check(g.players[1].pos == start and g.players[1].vel == Vector3.ZERO, "Countdown holds all seats on the deck")
	for i in 3: g.step(1.0/60)
	check(not g.players[1].grounded and g.players[1].vel.y > 15, "GO launches the team into the court")
	check(g.players[1].jump_count == 1, "Kickoff leaves one extra jump")
	check(g.players[1].vel.z < 0 and g.players[4].vel.z > 0, "Both sides launch towards midfield")
	var before: float = g.players[1].vel.y
	g.action(1, "jump")
	check(g.players[1].jump_count == 2 and g.players[1].vel.y >= before, "Extra jump keeps kickoff momentum")
	var airtime = 0.0
	while not g.players[1].grounded and airtime < 5:
		g.step(1.0/60)
		airtime += 1.0/60
	check(airtime > 2.0 and airtime < 4, "Kickoff has a sustained airborne entry")
	check(absf(g.players[1].pos.z) < 14, "Unsteered kickoff reaches the midfield contest")
	check(g.players[1].jump_count == 0, "Landing restores both jumps")
	g.reset("versus")
	for i in 182: g.step(1.0/60)
	check(g.players[1].pos.y < 1 and g.players[1].jump_count == 0, "Free-for-all retains its three-way ground start")
	if g.has_method("surface_height"):
		check(g.surface_height(Vector3(0,9,Sim.KICKOFF_Z), 10) > 6, "Raised deck accepts landing from above")
		check(g.surface_height(Vector3(0,4,Sim.KICKOFF_Z), 4) < 4, "Players and balls can pass below the deck")
	else: check(false, "Raised deck supplies one-way collision")
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players.keys():
		if id != 1: g.players.erase(id)
	g.players[1].pos = g.hoop(1) + Vector3(0,-3,3)
	g.players[1].grounded = false
	g.players[1].vel = Vector3(0,6,-7)
	g.ball.owner = 1
	g.action(1,"dunk")
	var duration: float = g.players[1].get("dunk_duration",0)
	var hang = 0.0
	var release = -1.0
	var elapsed = 0.0
	var previous: Vector3 = g.players[1].pos
	var maximum_step = 0.0
	for i in 125:
		var held: bool = g.ball.owner == 1
		g.step(1.0/60)
		elapsed += 1.0/60
		if held and g.ball.owner != 1 and release < 0: release = elapsed
		if g.players[1].dunk > 0:
			maximum_step = maxf(maximum_step,previous.distance_to(g.players[1].pos))
			if g.players[1].pos.distance_to(g.players[1].dunk_target) < .15 and held: hang += 1.0/60
		previous = g.players[1].pos
	check(duration >= .9 and duration <= 1.35 and release >= .6 and release <= 1.0, "Dunk gathers and releases within a responsive bounded window")
	check(hang >= .15 and hang <= .4, "Brief readable rim hang does not trap the player")
	check(maximum_step < .6 and g.baskets == 1, "Responsive windup remains continuous and scores once")
	print("REFERENCE_FEEL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"kickoff_airtime":airtime,"dunk_duration":duration,"dunk_release":release,"dunk_hold":hang,"max_step":maximum_step}))
	quit(1 if failures else 0)
