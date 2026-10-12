extends SceneTree
const Sim=preload("res://sim.gd")

func _initialize() -> void:
	var results=[]
	var passed=true
	for pair_side in [0,1]:
		var sim=Sim.new()
		sim.reset("teams",{"active_humans":[1,2,3],"teams":{1:pair_side,2:pair_side,3:1-pair_side},"bots":{0:0,1:0}})
		var pair_possession_frames=0
		var pair_launches=0
		for tick in 60*90:
			var boost_before={}
			for id in sim.players:
				boost_before[id]=sim.players[id].boost_time
				var command=sim.bot_command(id)
				sim.move_input(id,command.move,command.aim)
				if command.action!="": sim.action(id,command.action,command.charge)
			sim.step(1.0/60)
			if sim.ball.owner in [1,2]: pair_possession_frames+=1
			for id in [1,2]:
				var p: Dictionary=sim.players[id]
				if p.boost_time>boost_before[id]+.3 and p.vel.y>Sim.LAUNCH_SPEED-.5: pair_launches+=1
			if sim.winner>=0: break
		# This checks participation, not an arbitrary win rate: two autonomous
		# teammates must not bypass every loose-ball kickoff for the entire match.
		var ok=pair_possession_frames>=6
		passed=passed and ok
		results.append({"pair_side":pair_side,"pass":ok,"pair_possession_seconds":pair_possession_frames/60.0,"pair_launches":pair_launches,"winner":sim.winner,"scores":sim.scores,"seconds":sim.clock,"tackles":sim.tackles})
	print("REVIEW_V3_KICKOFF "+JSON.stringify(results))
	quit(0 if passed else 1)
