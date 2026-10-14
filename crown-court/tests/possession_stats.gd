extends SceneTree

const Sim = preload("res://sim.gd")
var checks = []

func check(ok: bool, label: String, details = {}) -> void:
	checks.append({"passed":ok,"check":label,"details":details})
	if not ok: printerr("FAIL ", label, " ", details)

func fresh():
	var g = Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.ball.lock = 0
	for id in g.players:
		g.players[id].pos = Vector3(26,0,id*4-14)
		g.players[id].guard = 0
	g.players[1].pos = Vector3(0,0,0)
	g.players[2].pos = Vector3(0,0,-8)
	g.players[4].pos = Vector3(12,0,-8)
	g.players[1].aim = Vector3.FORWARD
	return g

func complete_pass(g) -> void:
	g.secure_ball(1)
	g.action(1,"pass")
	for frame in 120:
		g.step(1.0/60)
		if g.ball.owner > 0: break
	check(g.ball.owner == 2,"Physical pass reaches teammate",{"owner":g.ball.owner})

func recover(g, id: int, automatic: bool) -> void:
	# Position an eligible collector at the released ball; production catch paths
	# decide possession and rewards. No direct stats or release-metadata writes.
	g.players[id].pos = g.ball.pos-Vector3.UP*1.1
	g.ball.lock = 0
	if automatic: g.ball_step(1.0/180)
	else: g.action(id,"grab")
	check(g.ball.owner == id,"Collector recovers through ordinary catch path",{"owner":g.ball.owner,"automatic":automatic})

func _initialize() -> void:
	for automatic in [false,true]:
		var g = fresh()
		complete_pass(g)
		g.hit(4,2)
		recover(g,1,automatic)
		check(g.players[4].stats.tackles == 1 and g.players[4].stats.steals == 1,"Dislodging defender earns exactly one tackle and steal")
		check(g.players[1].stats.steals == 0,"Recovering own team's dislodged ball is not an interception",g.players[1].stats)
		check(g.players[1].stats.passes == 1 and g.players[1].hype == Sim.HYPE_CATCH*2+Sim.HYPE_PASS,"Recovery preserves earned pass and catch Hype",g.players[1].stats)
		var hype = g.players[1].hype
		var steals = g.players[1].stats.steals
		g.action(1,"grab")
		check(g.players[1].hype == hype and g.players[1].stats.steals == steals,"Repeated catch cannot duplicate rewards")
		g = fresh()
		g.secure_ball(4)
		g.action(4,"throw",.6)
		recover(g,1,automatic)
		check(g.players[1].stats.steals == 1,"Live opponent throw still credits one interception",g.players[1].stats)
		# The intercepted release must not remain eligible for a second steal
		# after a tackle and recovery by the original shooting side.
		g.hit(4,1)
		recover(g,5,automatic)
		check(g.players[5].stats.steals == 0,"Earlier intercepted shot cannot credit a later loose-ball recovery",g.players[5].stats)
	var failed = checks.filter(func(row): return not row.passed).size()
	print("POSSESSION_STATS_RESULT ",JSON.stringify({"checks":checks,"failures":failed}))
	quit(0 if failed == 0 else 1)
