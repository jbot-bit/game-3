extends SceneTree
const Sim=preload("res://sim.gd")

func _initialize() -> void:
	var runs=[]
	for specification in [
		{"name":"coop_all_autonomous","mode":"coop","idle":[]},
		{"name":"coop_one_idle_human","mode":"coop","idle":[1]},
		{"name":"coop_three_idle_humans","mode":"coop","idle":[1,2,3]},
		{"name":"versus_all_autonomous","mode":"versus","idle":[]},
		{"name":"teams_one_each","mode":"teams","setup":{"active_humans":[1,2],"teams":{1:0,2:1},"bots":{0:0,1:0}},"idle":[]},
		{"name":"teams_two_against_one","mode":"teams","setup":{"active_humans":[1,2,3],"teams":{1:0,2:0,3:1},"bots":{0:0,1:0}},"idle":[]}
	]:
		var sim=Sim.new()
		sim.reset(specification.mode,specification.get("setup",{}))
		var seat_data={}
		for id in sim.players:
			seat_data[id]={"possession_seconds":0.0,"ground_possession_seconds":0.0,"jump_commands":0,"second_jump_commands":0,"pass_commands":0,"throw_commands":0,"tackle_commands":0,"dunk_commands":0,"fixed_launches":0,"speed_boosts":0,"longest_stationary_possession":0.0,"stationary_possession":0.0,"airborne_carrier_defense_seconds":0.0,"defensive_jump_commands":0}
		var stuck_ball=0.0
		var longest_stuck=0.0
		var previous_ball=sim.ball.pos
		var finite=true
		for tick in 60*360:
			var before={}
			for id in sim.players:
				var p: Dictionary=sim.players[id]
				var d: Dictionary=seat_data[id]
				before[id]={"boost":p.boost_time,"position":p.pos}
				if id in specification.idle: continue
				var command=sim.bot_command(id)
				var attacking_air=false
				if sim.ball.owner>0 and sim.team(sim.ball.owner)!=sim.team(id):
					var carrier: Dictionary=sim.players[sim.ball.owner]
					attacking_air=not carrier.grounded and carrier.pos.y>Sim.floor_height(carrier.pos.x,carrier.pos.z)+1.5 and sim.flat_distance(p.pos,carrier.pos)<5
					if attacking_air: d.airborne_carrier_defense_seconds+=1.0/60
				if command.action=="jump":
					d.jump_commands+=1
					if p.jump_count==1: d.second_jump_commands+=1
					if attacking_air: d.defensive_jump_commands+=1
				for action in ["pass","throw","tackle","dunk"]:
					if command.action==action: d[action+"_commands"]+=1
				sim.move_input(id,command.move,command.aim)
				if command.action!="": sim.action(id,command.action,command.charge)
			sim.step(1.0/60)
			for id in sim.players:
				var p: Dictionary=sim.players[id]
				var d: Dictionary=seat_data[id]
				finite=finite and p.pos.is_finite() and p.vel.is_finite()
				if sim.ball.owner==id and sim.reset_time<=0:
					d.possession_seconds+=1.0/60
					if p.grounded: d.ground_possession_seconds+=1.0/60
					if p.pos.distance_to(before[id].position)<.02 and p.dunk<=0: d.stationary_possession+=1.0/60
					else: d.stationary_possession=0
					d.longest_stationary_possession=maxf(d.longest_stationary_possession,d.stationary_possession)
				else: d.stationary_possession=0
				if p.boost_time>before[id].boost+.3:
					if p.vel.y>Sim.LAUNCH_SPEED-.5:
						for pad in Sim.PADS:
							if sim.flat_distance(p.pos,pad)<1.5: d.fixed_launches+=1
					else: d.speed_boosts+=1
			finite=finite and sim.ball.pos.is_finite() and sim.ball.vel.is_finite()
			if sim.ball.owner==0 and sim.reset_time<=0 and sim.ball.pos.distance_to(previous_ball)<.005: stuck_ball+=1.0/60
			else: stuck_ball=0
			longest_stuck=maxf(longest_stuck,stuck_ball)
			previous_ball=sim.ball.pos
			if sim.winner>=0: break
		runs.append({"name":specification.name,"winner":sim.winner,"scores":sim.scores,"clock":sim.clock,"remaining":sim.time_left,"finite":finite,"longest_static_loose_ball_seconds":longest_stuck,"counters":{"grabs":sim.grabs,"throws":sim.throws,"dunks":sim.dunks,"tackles":sim.tackles,"baskets":sim.baskets},"players":seat_data})
	print("REVIEW_V3_ACTIVE "+JSON.stringify(runs))
	quit()
