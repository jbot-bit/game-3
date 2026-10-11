extends RefCounted
## Ring-out rules. Only tick mutates authority; present changes display geometry.
const Pugil = preload("res://prototypes/physics_party/party_pugil.gd")
const COUNTDOWN: float = 3.0
const INTERMISSION: float = 3.0
const ROUND_SECONDS: float = 90.0
const TARGET_WINS: int = 3
var world: Node3D
var combat = Pugil.new()
var phase: String = "practice"
var timer: float = 0.0
var round_number: int = 0
var scores: Dictionary = {}
var entrants: Array[String] = []
var alive: Array[String] = []
var _known: Array[String] = []
var _forfeits: Array[String] = []
var _winner: String = ""
var _round_winner: String = ""
var _settle: float = -1.0
var _round_roster_broken: bool = false
var _completed_sent: bool = false

func configure(arena: Node3D) -> void:
	world = arena
	reset()

func reset() -> void:
	phase = "practice"
	timer = 0.0
	round_number = 0
	scores.clear()
	entrants.clear()
	alive.clear()
	_known.clear()
	_forfeits.clear()
	_winner = ""
	_round_winner = ""
	_settle = -1.0
	_round_roster_broken = false
	_completed_sent = false
	combat.reset()
	_sync_hazards()

func tick(actors: Dictionary, controls: Dictionary, delta: float) -> Dictionary:
	var event: Dictionary = {"reset_ids": [], "completed": false}
	if not is_instance_valid(world) or not is_finite(delta) or delta <= 0.0: return event
	delta = minf(delta, 0.1)
	var connected: Array[String] = []
	for id: String in actors:
		if connected.size() < 3 and is_instance_valid(actors[id]): connected.append(id)
	connected.sort()
	for id: String in connected:
		if not scores.has(id): scores[id] = 0
	for id: String in _known:
		if id not in connected:
			scores.erase(id)
			if id in entrants and phase in ["countdown", "fight"]: _round_roster_broken = true
	_known = connected.duplicate()
	if phase == "complete":
		combat.tick(actors, {}, [], delta)
		return event
	if _round_roster_broken:
		# An opponent leaving never manufactures a round win or a bag.
		phase = "intermission" if connected.size() >= 2 else "practice"
		timer = INTERMISSION if connected.size() >= 2 else 0.0
		_round_winner = ""
		alive.clear()
		entrants.clear()
		_settle = -1.0
		_round_roster_broken = false
		combat.reset()
		_forfeits.clear()
	if phase == "practice":
		if connected.size() >= 2:
			_begin_round(connected, event)
		else:
			for id: String in connected:
				if _fallen(actors[id]) or id in _forfeits: event.reset_ids.append(id)
			_forfeits.clear()
	elif phase == "countdown":
		timer = maxf(0.0, timer - delta)
		if timer <= 0.0:
			phase = "fight"
			timer = ROUND_SECONDS
	elif phase == "intermission":
		timer = maxf(0.0, timer - delta)
		if timer <= 0.0:
			if connected.size() >= 2: _begin_round(connected, event)
			else: phase = "practice"
	elif phase == "fight":
		timer = maxf(0.0, timer - delta)
		for id: String in alive.duplicate():
			if id in _forfeits or _fallen(actors[id]): alive.erase(id)
		_forfeits.clear()
		if alive.size() <= 1:
			if _settle < 0.0: _settle = 0.18
			_settle = maxf(0.0, _settle - delta)
			if _settle <= 0.0: _finish_round(alive[0] if alive.size() == 1 else "", event)
		elif timer <= 0.0: _finish_round("", event)
	var eligible: Array = alive if phase == "fight" else connected if phase == "practice" else []
	combat.tick(actors, controls, eligible, delta)
	_sync_hazards()
	return event

func _sync_hazards() -> void:
	if is_instance_valid(world) and world.has_method("set_round_phase"):
		world.set_round_phase(phase, round_number)

func _begin_round(connected: Array[String], event: Dictionary) -> void:
	entrants = connected.duplicate()
	alive = connected.duplicate()
	round_number = mini(9999, round_number + 1)
	phase = "countdown"
	timer = COUNTDOWN
	_settle = -1.0
	_round_winner = ""
	_forfeits.clear()
	combat.reset()
	event.reset_ids = connected.duplicate()

func _finish_round(id: String, event: Dictionary) -> void:
	_round_winner = id
	if not id.is_empty(): scores[id] = mini(TARGET_WINS, int(scores.get(id, 0)) + 1)
	if not id.is_empty() and scores[id] >= TARGET_WINS:
		_winner = id
		phase = "complete"
		timer = 0.0
		if not _completed_sent:
			event.completed = true
			_completed_sent = true
	else:
		phase = "intermission"
		timer = INTERMISSION

func _fallen(actor: Node3D) -> bool:
	var point: Vector3 = actor.body_position()
	return not point.is_finite() or point.y < float(world.get("elimination_y")) or point.length() > 500.0

func controls_allowed(id: String) -> bool:
	return phase == "practice" or (phase == "fight" and id in alive)

func forfeit(id: String) -> void:
	if (phase == "practice" or (phase == "fight" and id in alive)) and id not in _forfeits: _forfeits.append(id)

func winner_id() -> String: return _winner

func status_text() -> String:
	match phase:
		"practice": return "SOLO PRACTICE / Invite a second player to start a match"
		"countdown": return "ROUND %d / %d" % [round_number, ceili(timer)]
		"fight": return "ROUND %d / %d standing / %ds / First to 3 wins" % [round_number, alive.size(), ceili(timer)]
		"intermission": return "ROUND DRAW / Next round in %d" % ceili(timer) if _round_winner.is_empty() else "%s wins the round / Next in %d" % [_round_winner, ceili(timer)]
		"complete": return "%s WINS THE MATCH" % _winner
	return ""

func hint_text() -> String:
	if is_instance_valid(world) and world.has_method("hazard_status_text"):
		var warning: String = world.hazard_status_text()
		var controls_hint: String = "Jump the low bar. Dodge the high arm. Swing to push rivals off."
		return controls_hint if warning.is_empty() else warning + "\n" + controls_hint
	if is_instance_valid(world) and world.has_method("set_round_phase"):
		return "Jump the low sweeper. Avoid the high arm. LMB swing / RMB brace."
	return "LMB: swing padded stick   RMB: brace   Stay on the platform!"

func capture() -> Dictionary:
	var shown: Dictionary = {}
	for id: String in _known: shown[id] = combat.visual_state(id)
	return {"version": 1, "phase": phase, "timer": timer, "round": round_number, "scores": scores.duplicate(),
		"entrants": entrants.duplicate(), "alive": alive.duplicate(), "winner": _winner, "round_winner": _round_winner, "fighters": shown}

func present(data: Dictionary, actors: Dictionary) -> void:
	if not valid_snapshot(data): return
	for id: String in actors:
		var shown: Dictionary = data.fighters.get(id, {"swing": 0.0, "brace": false, "yaw": 0.0})
		actors[id].set_combat_visual(true, shown.swing, shown.brace, shown.yaw)

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 10 or not data.get("version") is int or data.version != 1: return false
	if not data.get("phase") in ["practice", "countdown", "fight", "intermission", "complete"]: return false
	if not _number(data.get("timer"), 0.0, ROUND_SECONDS): return false
	if not data.get("round") is int or data.round < 0 or data.round > 9999: return false
	for key: String in ["scores", "fighters"]:
		if not data.get(key) is Dictionary or data[key].size() > 3: return false
		for id: Variant in data[key]:
			if not _valid_id(id): return false
	for key: String in ["entrants", "alive"]:
		if not data.get(key) is Array or data[key].size() > 3: return false
		var seen: Array = []
		for id: Variant in data[key]:
			if not _valid_id(id) or id in seen: return false
			seen.append(id)
	for id: String in data.alive:
		if id not in data.entrants: return false
	for key: String in ["winner", "round_winner"]:
		if not data.get(key) is String or (not data[key].is_empty() and not _valid_id(data[key])): return false
	for value: Variant in data.scores.values():
		if not value is int or value < 0 or value > TARGET_WINS: return false
	for value: Variant in data.fighters.values():
		if not value is Dictionary or value.size() != 3 or not value.get("brace") is bool: return false
		if not _number(value.get("swing"), 0.0, 1.0) or not _number(value.get("yaw"), -PI, PI): return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 32 and value.is_valid_identifier()

static func interpolate(before: Dictionary, after: Dictionary, blend: float) -> Dictionary:
	if not valid_snapshot(before) or not valid_snapshot(after): return {}
	var shown: Dictionary = after.duplicate(true)
	if not is_finite(blend): return shown
	blend = clampf(blend, 0.0, 1.0)
	if before.phase == after.phase: shown.timer = lerpf(float(before.timer), float(after.timer), blend)
	for id: String in shown.fighters:
		if not before.fighters.has(id): continue
		var a: Dictionary = before.fighters[id]
		var b: Dictionary = after.fighters[id]
		shown.fighters[id].yaw = wrapf(lerp_angle(float(a.yaw), float(b.yaw), blend), -PI, PI)
		if a.swing > 0.0 and b.swing >= a.swing: shown.fighters[id].swing = lerpf(float(a.swing), float(b.swing), blend)
	return shown
