extends SceneTree
const Sim = preload("res://sim.gd")

func _initialize() -> void:
	var reports = []
	var passed = true
	var team_releases = {0:0,1:0}
	var team_receptions = {0:0,1:0}
	for spec in [
		{"mode":"coop","setup":{}},
		{"mode":"teams","setup":{"active_humans":[1,2,3],"teams":{1:1,2:0,3:1},"bots":{0:2,1:1}}},
		{"mode":"versus","setup":{}}
	]:
		var g = Sim.new()
		g.reset(spec.mode,spec.setup)
		var releases = {}
		var receptions = {}
		var last_pass_time = {}
		var shortest_receive_to_pass = INF
		var last_receive_time = {}
		var previous_owner = 0
		var finite = true
		for frame in 60*600:
			for id in g.players:
				var order = g.bot_command(id)
				g.move_input(id,order.move,order.aim)
				var throws_before = g.throws
				var owner_before = int(g.ball.owner)
				var target_before = int(g.ball.pass_target)
				if order.action!="": g.action(id,order.action,order.charge)
				if order.action=="pass" and g.throws>throws_before:
					var side = g.team(id)
					releases[side] = releases.get(side,0)+1
					last_pass_time[id] = g.clock
					if last_receive_time.has(id): shortest_receive_to_pass = minf(shortest_receive_to_pass,g.clock-last_receive_time[id])
				if owner_before==0 and g.ball.owner==id and target_before==id:
					receptions[g.team(id)] = receptions.get(g.team(id),0)+1
					last_receive_time[id] = g.clock
			var pending_receiver = int(g.ball.pass_target)
			previous_owner = int(g.ball.owner)
			g.step(1.0/60)
			if previous_owner==0 and pending_receiver>0 and g.ball.owner==pending_receiver:
				receptions[g.team(pending_receiver)] = receptions.get(g.team(pending_receiver),0)+1
				last_receive_time[pending_receiver] = g.clock
			finite = finite and g.ball.pos.is_finite() and g.ball.vel.is_finite()
			for id in g.players: finite = finite and g.players[id].pos.is_finite() and g.players[id].vel.is_finite()
			if g.winner>=0: break
		var ok = g.winner>=0 and g.baskets>0 and finite and (g.time_left<=0 or (spec.mode=="versus" and g.scores[g.winner]>=7) or (spec.mode!="versus" and abs(g.scores[0]-g.scores[1])>=4))
		if spec.mode=="versus": ok = ok and releases.is_empty()
		else:
			# A four-point shutout can end before one side earns an outlet. Require
			# actual passing in each team mode, and both sides across the roster set.
			ok = ok and releases.get(0,0)+releases.get(1,0)>0 and receptions.get(0,0)+receptions.get(1,0)>0 and shortest_receive_to_pass>=.95
			for side in [0,1]:
				team_releases[side] += releases.get(side,0)
				team_receptions[side] += receptions.get(side,0)
		passed = passed and ok
		reports.append({"mode":spec.mode,"setup":spec.setup,"passed":ok,"scores":g.scores,"winner":g.winner,"seconds":g.clock,"actual_pass_releases":releases,"actual_pass_receptions":receptions,"shortest_receive_to_pass_seconds":shortest_receive_to_pass if shortest_receive_to_pass<INF else null,"finite":finite})
	passed = passed and team_releases[0]>0 and team_releases[1]>0 and team_receptions[0]>0 and team_receptions[1]>0
	print("TEAMPLAY_MATCH_RESULT "+JSON.stringify({"passed":passed,"runs":reports,"team_releases_across_rosters":team_releases,"team_receptions_across_rosters":team_receptions,"scope":"Deterministic full autonomous matches, actual action and physics paths; no human fun or win-rate balance claim"}))
	quit(0 if passed else 1)
