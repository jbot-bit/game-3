extends Control

var amount = 0.0
var power = "Hype"
var key = "Q"
var status_text = "0%"
var ready_reveal = 0.0
var has_status = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 142)

func set_status(value: float, power_name: String, controller: bool, status: String = "", button_key: String = "") -> void:
	var previous = [amount, power, key, status_text]
	if has_status and amount < 1.0 and value >= 1.0: ready_reveal = .7
	if value < 1.0: ready_reveal = 0.0
	has_status = true
	amount = clampf(value, 0.0, 1.0)
	power = {"giant": "Giant", "pad": "Jump pad", "blast": "Homing ball"}.get(power_name, "Hype")
	key = button_key if not button_key.is_empty() else "Y" if controller else "Q"
	status_text = status if not status.is_empty() else "Ready" if amount >= 1 else "%d%%" % roundi(amount * 100)
	if previous != [amount, power, key, status_text]: queue_redraw()

func _process(dt: float) -> void:
	if ready_reveal <= 0.0: return
	ready_reveal = maxf(0.0, ready_reveal - dt)
	queue_redraw()

# Snapshot comparisons avoid replaying rewards on joining or repeated network frames.
static func score_feedback(previous: Dictionary, scores: Dictionary, mode: String, names: Dictionary, winner: int = -1) -> Dictionary:
	if previous.is_empty(): return {}
	var changed: Array = []
	for side in scores:
		if previous.has(side) and int(scores[side]) > int(previous[side]): changed.append(side)
	if changed.is_empty(): return {}
	if changed.size() != 1: return {"text":"Score updated", "cue":"score", "side":-1, "delta":0}
	var side = changed[0]
	var delta = int(scores[side]) - int(previous[side])
	var title = str(names.get(side, "Bot %d" % int(side))).substr(0, 12)
	if mode == "teams": title = "Blue" if int(side) == 0 else "Orange"
	elif mode != "versus": title = "Your team" if int(side) == 0 else "Bots"
	var other_best = -1
	var previous_best = -1
	for rival in scores:
		if rival == side: continue
		other_best = maxi(other_best, int(scores[rival]))
		previous_best = maxi(previous_best, int(previous.get(rival, scores[rival])))
	var detail = "Basket!"
	var cue = "score"
	if winner == int(side):
		detail = "Winning basket!"
	elif int(scores[side]) == other_best:
		detail = "All tied!"
		cue = "score_tie"
	elif int(scores[side]) > other_best and int(previous[side]) <= previous_best:
		detail = "Takes the lead!"
		cue = "score_lead"
	return {"text":"%s +%d\n%s" % [title, delta, detail], "cue":cue, "side":int(side), "delta":delta}

static func clock_feedback(previous: int, remaining: int, winner: int = -1) -> Dictionary:
	if previous < 0 or remaining >= previous or winner >= 0: return {}
	if remaining <= 0: return {"text":"Overtime!", "cue":"overtime"}
	if remaining <= 10 and previous > 10: return {"text":"10 seconds!", "cue":"late_clock"}
	if remaining <= 30 and previous > 30: return {"text":"30 seconds!", "cue":"late_clock"}
	return {}

func _draw() -> void:
	var center = Vector2(60, 52)
	if ready_reveal > 0.0:
		var progress = 1.0 - ready_reveal / .7
		draw_arc(center, 45 + progress * 10.0, 0, TAU, 64, Color(1.0, .67, .33, ready_reveal * .85), 3, true)
	draw_circle(center, 45, Color(0.025, 0.055, 0.105, 0.88))
	draw_arc(center, 42, -PI * 0.5, PI * 1.5, 64, Color("38536b"), 4, true)
	if amount > 0: draw_arc(center, 42, -PI * 0.5, -PI * 0.5 + TAU * amount, 64, Color("54e5cd") if amount < 1.0 else Color("ffac54"), 4, true)
	if amount >= 1: draw_circle(center, 35, Color(1.0, .67, .33, .13))
	var font = ThemeDB.fallback_font
	var size = 29
	var width = font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(60 - width * 0.5, 62), key, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffac54") if amount >= 1 else Color("c8d6e0"))
	for entry in [[power,111], [status_text,134]]:
		var label = str(entry[0])
		var baseline = float(entry[1])
		width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string_outline(font, Vector2(60 - width * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color("102237"))
		draw_string(font, Vector2(60 - width * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffac54") if status_text == "Ready" else Color("f7f4ec"))
