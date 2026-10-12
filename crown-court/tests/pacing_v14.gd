extends SceneTree
var Sim = load("res://sim.gd")
func _initialize():
	# Optional immutable baseline script is used only by the comparison harness.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with('--baseline='): Sim=load(argument.trim_prefix('--baseline='))
	var reports=[]
	var passed=true
	# Attempts vary deterministic yaw/power error; RNG seeds alone do not vary bot aim.
	for attempt in range(24):
		for difficulty in ["easy","normal","hard"]:
			for moving in [false,true]:
				for side in [-1,1]:
					for distance in [8.0,12.0,15.0]:
						seed(1401+attempt)
						var g=Sim.new()
						g.reset("coop",{"bot_difficulty":difficulty})
						var id=1 if side==-1 else 4
						for other in g.players.keys():
							if other!=id: g.players.erase(other)
						g.reset_time=0; g.ball.lock=0; g.clock=10
						var p=g.players[id]
						p.pos=g.hoop(id)+Vector3(0,-Sim.HOOP_Y,-side*distance)
						p.pos.y=Sim.floor_height(p.pos.x,p.pos.z)
						p.vel=Vector3(0,0,side*Sim.SPEED*.94) if moving else Vector3.ZERO
						p.aim=Vector3(0,0,side); p.guard=0; p.possession_since=0
						g.ball.owner=id; g.ball.pos=g.hand_position(id)
						g.bot_command(id)
						g.bot_brains[id].react_at=0; g.bot_brains[id].next=0; g.bot_brains[id].attempt=attempt
						var release={}
						var start=g.hand_position(id)
						for frame in 360:
							if g.throws==0:
								var order=g.bot_command(id)
								g.move_input(id,order.move,order.aim)
								if order.action!="": g.action(id,order.action,order.charge)
								if g.throws>0: release={"delay":g.clock-10,"travel":start.distance_to(g.ball.pos),"origin":g.ball.pos,"velocity":g.ball.vel}
							g.step(1.0/60)
							if g.baskets: break
						passed=passed and not release.is_empty() and g.ball.pos.is_finite()
						if attempt==0 and difficulty=='hard' and moving and distance>=12: passed=passed and g.baskets==1
						reports.append({"attempt":attempt,"seed":1401+attempt,"difficulty":difficulty,"moving":moving,"side":side,"distance":distance,"score":g.baskets,"release":release})
	print('PACING_RESULT '+JSON.stringify(reports))
	print('PACING_CHECK ',passed)
	quit(0 if passed else 1)
