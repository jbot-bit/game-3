extends SceneTree

func _initialize() -> void:
	var Sim = load("res://sim.gd")
	var passed = true
	for mode in ["coop", "versus"]:
		var game = Sim.new()
		game.reset(mode)
		# Five minutes of live play excludes countdowns and basket celebrations.
		# Closely matched teams may reach regulation and sudden death.
		for frame in 60 * 600:
			for id in game.players:
				var command = game.bot_command(id)
				game.move_input(id, command.move, command.aim)
				if command.action != "": game.action(id, command.action, command.charge)
			game.step(1.0 / 60)
			if game.winner >= 0: break
		var ok = game.grabs > 5 and game.throws + game.dunks > 2 and game.baskets > 2 and game.winner >= 0
		for id in game.players: ok = ok and game.players[id].pos.is_finite() and game.players[id].vel.is_finite()
		ok = ok and game.ball.pos.is_finite()
		print("MATCH_RESULT " + JSON.stringify({"mode":mode,"ok":ok,"seconds":game.clock,"live_time_left":game.time_left,"scores":game.scores,"grabs":game.grabs,"throws":game.throws,"dunks":game.dunks,"tackles":game.tackles,"baskets":game.baskets,"winner":game.winner}))
		passed = passed and ok
	quit(0 if passed else 1)
