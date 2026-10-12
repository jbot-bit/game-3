extends SceneTree
const Sim = preload("res://sim.gd")

func _initialize() -> void:
	var sim := Sim.new()
	sim.reset("coop")
	var samples: Array = []
	var maximum_events := 0
	for frame in 60*60:
		for id in sim.players:
			var command: Dictionary = sim.bot_command(id)
			sim.move_input(id,command.move,command.aim)
			if not command.action.is_empty(): sim.action(id,command.action,command.charge)
		sim.step(1.0/60)
		if frame%3 == 0:
			var current := sim.snapshot()
			maximum_events = maxi(maximum_events,current.recent_events.size())
			var old := current.duplicate(true)
			old.erase("recent_events")
			old.erase("event_clock")
			var prior_bytes := var_to_bytes(old).compress(FileAccess.COMPRESSION_DEFLATE).size()
			var current_bytes := var_to_bytes(current).compress(FileAccess.COMPRESSION_DEFLATE).size()
			samples.append({"before":prior_bytes,"after":current_bytes,"delta":current_bytes-prior_bytes})
		if sim.winner >= 0: break
	var max_before := 0
	var max_after := 0
	var max_delta := 0
	var total_delta := 0
	for sample in samples:
		max_before = maxi(max_before,sample.before)
		max_after = maxi(max_after,sample.after)
		max_delta = maxi(max_delta,sample.delta)
		total_delta += sample.delta
	var report := {"samples":samples.size(),"maximum_events":maximum_events,"maximum_before_bytes":max_before,"maximum_after_bytes":max_after,"maximum_delta_bytes":max_delta,"mean_delta_bytes":float(total_delta)/samples.size(),"scope":"Actual six-bot simulation,20Hz snapshot sampling,identical dynamic snapshot with only two new event fields removed for old-size comparison. Sim-only payload,not complete network packet."}
	print("EVENT_PAYLOAD_RESULT ",JSON.stringify(report))
	quit(0 if maximum_events <= 16 and max_after < 65536 else 1)
