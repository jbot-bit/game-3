extends Control

var amount = 0.0
var power = "Hype"
var key = "Q"
var status_text = "0%"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 142)

func set_status(value: float, power_name: String, controller: bool, status: String = "", button_key: String = "") -> void:
	var previous = [amount, power, key, status_text]
	amount = clampf(value, 0.0, 1.0)
	power = {"giant": "Giant", "pad": "Jump pad", "blast": "Homing ball"}.get(power_name, "Hype")
	key = button_key if not button_key.is_empty() else "Y" if controller else "Q"
	status_text = status if not status.is_empty() else "Ready" if amount >= 1 else "%d%%" % roundi(amount * 100)
	if previous != [amount, power, key, status_text]: queue_redraw()

func _draw() -> void:
	var center = Vector2(60, 52)
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
