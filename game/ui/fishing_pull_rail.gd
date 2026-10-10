extends Control
## Presentation only. Smooth host positions; never calculate catch progress here.
const TRANSITION_SECONDS: float = 0.08
var tracking: bool = false
var rightward: bool = false
var bar_width: float = 0.34
var _shown_bar: float = 0.5
var _shown_fish: float = 0.5
var _from_bar: float = 0.5
var _from_fish: float = 0.5
var _target_bar: float = 0.5
var _target_fish: float = 0.5
var _elapsed: float = TRANSITION_SECONDS
var _has_snapshot: bool = false
var _track_style: StyleBoxFlat
var _window_style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 68
	_track_style = _style(Color("0b1d2c"), Color("36566b"), 9)
	_window_style = _style(Color("f3eee2"), Color("fff9ec"), 5)

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func set_tracking(center: float, width: float, fish: float, inside: bool) -> void:
	bar_width = clampf(width, 0.05, 1.0)
	var bar: float = clampf(center, bar_width * 0.5, 1.0 - bar_width * 0.5)
	fish = clampf(fish, 0.0, 1.0)
	tracking = inside
	if not _has_snapshot:
		_shown_bar = bar
		_shown_fish = fish
		_has_snapshot = true
	if not is_equal_approx(bar, _target_bar) or not is_equal_approx(fish, _target_fish):
		_from_bar = _shown_bar
		_from_fish = _shown_fish
		_target_bar = bar
		_target_fish = fish
		_elapsed = 0.0
	queue_redraw()

func set_input_direction(value: bool) -> void:
	if rightward == value: return
	rightward = value
	queue_redraw()

func _process(delta: float) -> void:
	if _elapsed >= TRANSITION_SECONDS: return
	_elapsed = minf(TRANSITION_SECONDS, _elapsed + maxf(0.0, delta))
	var weight: float = _elapsed / TRANSITION_SECONDS
	_shown_bar = lerpf(_from_bar, _target_bar, weight)
	_shown_fish = lerpf(_from_fish, _target_fish, weight)
	queue_redraw()

func _draw() -> void:
	if _track_style == null: return
	var track := Rect2(8, 16, maxf(1.0, size.x - 16), 36)
	draw_style_box(_track_style, track)
	var inner := Rect2(track.position + Vector2(4,4), track.size - Vector2(8,8))
	var width: float = inner.size.x * bar_width
	var window := Rect2(inner.position.x + inner.size.x * _shown_bar - width * 0.5, inner.position.y, width, inner.size.y)
	_window_style.bg_color = Color("a9ead6") if tracking else Color("f3eee2")
	draw_style_box(_window_style, window)
	var center: Vector2 = window.get_center()
	var direction: float = 1.0 if rightward else -1.0
	draw_polyline(PackedVector2Array([center + Vector2(-direction*3,-4), center + Vector2(direction*2,0), center + Vector2(-direction*3,4)]), Color("395b64"), 2.0, true)
	var fish_x: float = inner.position.x + inner.size.x * _shown_fish
	var cyan := Color("5ce1ff")
	draw_line(Vector2(fish_x,9),Vector2(fish_x,59),Color("0b1d2c"),7.0,true)
	draw_line(Vector2(fish_x,9),Vector2(fish_x,59),cyan,3.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(fish_x-5,3),Vector2(fish_x+5,3),Vector2(fish_x,9)]),cyan)
