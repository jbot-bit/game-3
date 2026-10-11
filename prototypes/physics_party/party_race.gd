extends RefCounted
## Host-only race progress. Clients receive results; input cannot claim checkpoints.
const LIMIT: float = 300.0
var world: Node3D
var phase: String = "countdown"
var countdown: float = 3.0
var elapsed: float = 0.0
var runners: Dictionary = {}
var winner: String = ""
var _instances: Dictionary = {}

func configure(value: Node3D) -> void:
	world = value
	reset()

func reset() -> void:
	phase = "countdown"
	countdown = 3.0
	elapsed = 0.0
	runners.clear()
	_instances.clear()
	winner = ""

func tick(actors: Dictionary, delta: float) -> Dictionary:
	var event: Dictionary = {"reset_ids": [], "completed": false, "reward": false}
	if not world.authoritative or not is_finite(delta) or delta <= 0.0: return event
	for id in runners.keys():
		if not actors.has(id):
			runners.erase(id)
			_instances.erase(id)
	for id in actors:
		if not is_instance_valid(actors[id]): continue
		if _instances.get(id, 0) != actors[id].get_instance_id():
			runners[id] = {"checkpoint": 0, "falls": 0, "finished": false, "time": 0.0}
			_instances[id] = actors[id].get_instance_id()
	# Leaving forfeits a live race result. A new connection reusing that slot
	# must never inherit a departed player's win.
	if phase != "complete":
		winner = ""
		var best: float = INF
		for id in runners:
			if runners[id].finished and float(runners[id].time) < best:
				best = float(runners[id].time)
				winner = str(id)
	if actors.is_empty() or phase == "complete": return event
	var step: float = minf(delta, 0.05)
	if phase == "countdown":
		countdown = maxf(0.0, countdown - step)
		if countdown == 0.0: phase = "running"
		return event
	elapsed += step
	for id in runners:
		var actor: Node3D = actors[id]
		var at: Vector3 = actor.body_position()
		if runners[id].finished:
			if not at.is_finite() or at.y < -8.0 or at.length() > 500.0:
				if not event.has("reset_goal_ids"): event.reset_goal_ids = []
				event.reset_goal_ids.append(id)
			continue
		if not at.is_finite() or at.y < -8.0 or at.length() > 500.0:
			recover(id)
			event.reset_ids.append(id)
			continue
		if actor.is_on_floor:
			var reached: int = world.checkpoint_index(at)
			if reached == int(runners[id].checkpoint) + 1: runners[id].checkpoint = reached
			if int(runners[id].checkpoint) == 3 and world.goal_contains(at):
				runners[id].finished = true
				runners[id].time = elapsed
				if winner.is_empty(): winner = str(id)
	var done: bool = not runners.is_empty()
	for value: Dictionary in runners.values(): done = done and value.finished
	if done or elapsed >= LIMIT:
		phase = "complete"
		event.completed = true
		event.reward = not winner.is_empty()
	return event

func controls_allowed(id: String) -> bool:
	return phase == "running" and runners.has(id) and not runners[id].finished

func recover(id: String) -> void:
	if runners.has(id) and phase == "running" and not runners[id].finished: runners[id].falls += 1

func checkpoint_for(id: String) -> int: return int(runners.get(id, {}).get("checkpoint", 0))

func capture() -> Dictionary:
	return {"version": 1, "phase": phase, "elapsed": elapsed, "remaining": countdown if phase == "countdown" else maxf(0.0, LIMIT - elapsed), "winner": winner, "runners": runners.duplicate(true), "results": runners.duplicate(true)}

func status_text() -> String:
	if phase == "countdown": return "WIPEOUT / START IN %d" % ceili(countdown)
	if phase == "complete": return "WIPEOUT / FINISH TIMES"
	return "WIPEOUT / %02d:%02d / KEEP YOUR BALANCE" % [int(elapsed) / 60, int(elapsed) % 60]

func hint_text() -> String:
	return "Cross the tipping beams and jump the sweepers. Reach all three checkpoints in order. F returns you to your checkpoint; the clock keeps running."
