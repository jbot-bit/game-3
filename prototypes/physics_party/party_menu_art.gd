extends Control
## Authored, resolution-independent toy theatre for the party launcher.
## Animation stops with the menu; it never participates in game simulation.
var mode_id: String = "coop"
var clock: float = 0.0
const INK := Color("24332f")
const ORANGE := Color("ee7544")
const MINT := Color("8ecab3")
const PAPER := Color("fff8e5")
const PURPLE := Color("aaa0d8")

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func _draw() -> void:
	var scale_factor: float = minf(size.x / 420.0, size.y / 228.0)
	draw_set_transform(Vector2((size.x - 420.0 * scale_factor) * 0.5, 0), 0, Vector2.ONE * scale_factor)
	# The platform is a paper-cut theatre, with actual silhouettes of the game's
	# faceless, floppy characters rather than a stock illustration or logo.
	_ellipse(Vector2(211, 195), Vector2(179, 25), Color(INK, 0.09))
	_ellipse(Vector2(210, 147), Vector2(177, 62), INK)
	draw_rect(Rect2(33, 124, 354, 24), INK)
	_ellipse(Vector2(210, 126), Vector2(177, 61), INK)
	_ellipse(Vector2(210, 122), Vector2(170, 55), ORANGE)
	_ellipse(Vector2(210, 118), Vector2(144, 43), PAPER)
	for index: int in range(9):
		var angle: float = PI * float(index + 1) / 10.0
		var at := Vector2(210 + cos(angle) * 174, 146 + sin(angle) * 52)
		draw_line(at, at + Vector2(-4, 11), Color("e8ae55"), 4, true)
	var bob: float = sin(clock * 1.5) * 2.5
	if mode_id == "coop":
		_puppet(Vector2(115, 104 + bob), ORANGE, -0.16, 0)
		_puppet(Vector2(289, 102 - bob), MINT, 0.12, 1)
		_puppet(Vector2(216, 119 + bob), PURPLE, 0.06, 2)
		_limb(Vector2(125, 67 + bob), Vector2(294, 77 - bob), INK, 17)
		_limb(Vector2(125, 64 + bob), Vector2(294, 74 - bob), Color("e8ae55"), 10)
	else:
		_puppet(Vector2(119, 108 + bob), ORANGE, -0.22, 1)
		_puppet(Vector2(270, 87 - absf(sin(clock * 1.5)) * 9), MINT, 0.26, 2)
		_puppet(Vector2(326, 148 + bob), PURPLE, 0.68, 0)
		if mode_id in ["knockout", "wipeout"]:
			var angle: float = clock * 0.55
			var end := Vector2(cos(angle) * 135, sin(angle) * 36)
			_limb(Vector2(211, 111) - end, Vector2(211, 111) + end, INK, 15)
			_limb(Vector2(211, 108) - end, Vector2(211, 108) + end, ORANGE, 9)
			_limb(Vector2(211, 125), Vector2(211, 97), INK, 13)
			draw_circle(Vector2(211, 97), 8, MINT)
		if mode_id in ["gladiator", "knockout"]:
			_limb(Vector2(91, 57 + bob), Vector2(157, 85 + bob), INK, 12)
			_limb(Vector2(88, 56 + bob), Vector2(155, 84 + bob), Color("e8ae55"), 7)
	# Hand-drawn movement marks; no particles or textures to load.
	for index: int in range(3):
		var at := Vector2(360 + index * 7, 61 + index * 8)
		draw_line(at, at + Vector2(10, -15 + index * 5), INK, 3, true)
	draw_arc(Vector2(65, 115), 25, PI * 0.83, PI * 1.29, 12, INK, 2, true)
	draw_line(Vector2(43, 123), Vector2(38, 111), INK, 2, true)
	draw_set_transform(Vector2.ZERO)

func _puppet(feet: Vector2, paint: Color, lean: float, pose: int) -> void:
	var hip := feet + Vector2(lean * 15, -26)
	var neck := feet + Vector2(lean * 44, -58)
	_limb(hip + Vector2(-6, 0), feet + Vector2(-14, 0), INK, 18)
	_limb(hip + Vector2(6, 0), feet + Vector2(14, -3), INK, 18)
	_limb(hip + Vector2(-6, 0), feet + Vector2(-14, 0), paint.darkened(0.1), 12)
	_limb(hip + Vector2(6, 0), feet + Vector2(14, -3), paint.darkened(0.1), 12)
	var left := neck + Vector2(-31, -7 if pose == 2 else 24)
	var right := neck + Vector2(30, -17 if pose != 0 else 23)
	_limb(neck + Vector2(-7, 8), left, INK, 17)
	_limb(neck + Vector2(7, 8), right, INK, 17)
	_limb(neck + Vector2(-7, 8), left, paint, 11)
	_limb(neck + Vector2(7, 8), right, paint, 11)
	_limb(hip, neck + Vector2(0, 6), INK, 30)
	_limb(hip, neck + Vector2(0, 6), paint, 24)
	var head := neck + Vector2(lean * 4, -15)
	_limb(head, head + Vector2(0, -4), INK, 31)
	_limb(head, head + Vector2(0, -4), paint.lightened(0.07), 25)
	draw_arc(head + Vector2(-1, -2), 8, PI * 1.08, PI * 1.5, 8, Color(PAPER, 0.45), 2, true)

func _limb(start: Vector2, end: Vector2, color: Color, width: float) -> void:
	draw_line(start, end, color, width, true)
	draw_circle(start, width * 0.5, color)
	draw_circle(end, width * 0.5, color)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(64):
		var angle: float = TAU * float(index) / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, color)
