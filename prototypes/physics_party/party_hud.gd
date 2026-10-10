extends CanvasLayer

signal host_requested(name: String)
signal join_requested(address: String, name: String)
signal leave_requested()
signal quit_requested()
signal resume_requested()
signal power_chosen(id: String)
signal restart_requested()

const Rules = preload("res://prototypes/physics_party/party_rules.gd")
const NAVY: Color = Color("162d38")
const CREAM: Color = Color("f7f0dc")
const MINT: Color = Color("a9e4c7")
const CORAL: Color = Color("f08b72")
const MUTED: Color = Color("b5c5c6")

class PowerMark extends Control:
	var power_id: String = ""
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var ink: Color = Color("162d38")
		match power_id:
			"spring":
				var points: PackedVector2Array = []
				for index: int in range(7):
					points.append(center + Vector2(-19 if index % 2 == 0 else 19, -26 + index * 8))
				draw_polyline(points, ink, 5.0, true)
			"heavy":
				draw_circle(center + Vector2(0, -20), 12, ink, false, 5.0, true)
				draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -15), center + Vector2(15, -15), center + Vector2(27, 28), center + Vector2(-27, 28)]), ink)
			"swift":
				for index: int in range(3):
					var left: Vector2 = center + Vector2(-26 + index * 14, -20)
					draw_polyline(PackedVector2Array([left, left + Vector2(16, 20), left + Vector2(0, 40)]), ink, 5.0, true)
			"feather":
				draw_line(center + Vector2(-18, 26), center + Vector2(18, -26), ink, 4.0, true)
				for index: int in range(4):
					var base: Vector2 = center + Vector2(-10 + index * 7, 16 - index * 10)
					draw_line(base, base + Vector2(-14, -12), ink, 4.0, true)
					draw_line(base, base + Vector2(17, 5), ink, 4.0, true)
			"grip":
				draw_style_box(_block(ink), Rect2(center + Vector2(-21, -4), Vector2(42, 30)))
				for index: int in range(4):
					draw_line(center + Vector2(-15 + index * 10, 5), center + Vector2(-15 + index * 10, -22 - (6 if index in [1, 2] else 0)), ink, 7.0, true)
	func _block(color: Color) -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(7)
		return style

var _root: Control
var _menu: Control
var _game: Control
var _draft: Control
var _ending: Control
var _connection: VBoxContainer
var _resume: Button
var _leave: Button
var _name: LineEdit
var _address: LineEdit
var _status: Label
var _join_address: Label
var _objective: Label
var _crew: Label
var _power: Label
var _note: Label
var _wind: Label
var _progress: Label
var _ending_detail: Label
var _restart: Button
var _host_wait: Label
var _cards: HBoxContainer
var _offer_ids: Array[String] = []
var _collection: VBoxContainer
var _collected_buttons: HBoxContainer
var _owned_ids: Array[String] = []
var _in_session: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_full(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	_build_menu()
	_build_game()
	_build_draft()
	_build_ending()
	show_menu()

func show_menu(status: String = "") -> void:
	if _root == null: return
	_menu.show()
	_game.hide()
	_draft.hide()
	_ending.hide()
	_status.text = status
	_connection.visible = not _in_session
	_resume.visible = _in_session
	_leave.visible = _in_session
	if not _in_session: _name.grab_focus()

func show_game() -> void:
	if _root == null: return
	_in_session = true
	_menu.hide()
	_game.show()

func reset_session(status: String = "") -> void:
	_in_session = false
	_offer_ids.clear()
	_owned_ids.clear()
	if _collection != null: _collection.hide()
	if _join_address != null: _join_address.hide()
	show_menu(status)

func blocks_input() -> bool:
	return _menu == null or _menu.visible or _draft.visible or _ending.visible

func is_menu_open() -> bool:
	return _menu != null and _menu.visible

func update_view(data: Dictionary, local_id: String, is_host: bool) -> void:
	if _root == null: return
	var players: Dictionary = data.get("players", {})
	var address: String = str(data.get("join_address", "")).strip_edges()
	_join_address.text = "Join: " + address
	_join_address.visible = is_host and _in_session and not address.is_empty()
	var me: Dictionary = players.get(local_id, {})
	var finished: int = 0
	var crew_names: PackedStringArray = []
	for id: Variant in players:
		var player: Dictionary = players[id]
		var safe: bool = bool(player.get("finished", false))
		if safe: finished += 1
		crew_names.append(str(player.get("name", "Player")) + (" ✓" if safe else ""))
	_crew.text = " · ".join(crew_names)
	_objective.text = "Get everyone across  %d/%d" % [finished, players.size()]
	if int(data.get("checkpoint", 0)) > 0:
		_objective.text = "Checkpoint set.  %d/%d across" % [finished, players.size()]
	_wind.text = "WIND →" if int(data.get("wind", 1)) > 0 else "← WIND"
	_wind.add_theme_color_override("font_color", CORAL if int(data.get("wind", 0)) > 0 else MINT)
	var owned: Array[String] = []
	for id: String in data.get("unlocked_power_ids", []):
		if not Rules.power_info(id).is_empty() and id not in owned:
			owned.append(id)
	if owned != _owned_ids:
		_owned_ids = owned
		_rebuild_collected()
	_collection.visible = not owned.is_empty()
	_progress.text = "%d/5 powers collected · %d clears" % [owned.size(), int(data.get("completions", 0))]
	_note.text = str(data.get("note", ""))
	var power_id: String = str(me.get("power", ""))
	var info: Dictionary = Rules.power_info(power_id)
	_power.text = str(info.get("name", "PICK YOUR POWER"))
	var complete: bool = str(data.get("phase", "play")) == "complete"
	var choices: Array[String] = []
	for id: String in data.get("offers", {}).get(local_id, []):
		if not Rules.power_info(id).is_empty() and id not in choices:
			choices.append(id)
	if choices != _offer_ids:
		_offer_ids = choices
		_rebuild_cards()
	_draft.visible = not _menu.visible and not complete and power_id.is_empty() and (not choices.is_empty() or not owned.is_empty())
	_ending.visible = not _menu.visible and complete
	_restart.visible = is_host
	_host_wait.visible = not is_host
	var save_failed: bool = bool(data.get("save_failed", false))
	_restart.text = "Retry save" if save_failed else "Another run"
	_host_wait.text = "Waiting for the host to retry saving…" if save_failed else "Waiting for the host…"
	_ending_detail.text = "Progress not saved.\nRetry to keep this clear." if save_failed else "%d/5 powers collected\n%d clears · Crew level %d" % [owned.size(), int(data.get("completions", 0)), int(data.get("level", 1))]
	_ending_detail.add_theme_color_override("font_color", CORAL if save_failed else CREAM)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _draft.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = int(event.physical_keycode) - KEY_1
	if index >= 0 and index < _offer_ids.size():
		power_chosen.emit(_offer_ids[index])
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	_menu = _scrim(NAVY)
	var box: VBoxContainer = _center_box(_menu, 440)
	box.add_theme_constant_override("separation", 14)
	_label(box, "1–3 PLAYERS · LAN CO-OP", 13, MINT)
	_label(box, "HANDS FULL", 54, CREAM)
	_label(box, "Grab. Climb. Get everyone across.", 20, CREAM)
	_connection = VBoxContainer.new()
	_connection.add_theme_constant_override("separation", 9)
	box.add_child(_connection)
	_label(_connection, "YOUR NAME", 12, MUTED)
	_name = LineEdit.new()
	_name.placeholder_text = "Name"
	_name.max_length = 24
	_name.custom_minimum_size.y = 44
	_connection.add_child(_name)
	var host: Button = _button(_connection, "Host game", MINT)
	host.pressed.connect(func() -> void:
		if _name.text.strip_edges().is_empty():
			_status.text = "Enter your name."
		else:
			_status.text = "Starting…"
			host_requested.emit(_name.text.strip_edges()))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_connection.add_child(row)
	_address = LineEdit.new()
	_address.placeholder_text = "Host's IP address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.custom_minimum_size.y = 44
	row.add_child(_address)
	var join: Button = _button(row, "Join", CREAM)
	join.custom_minimum_size.x = 95
	join.pressed.connect(_join)
	_address.text_submitted.connect(func(_text: String) -> void: _join())
	_join_address = _label(box, "", 16, MINT)
	_join_address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_address.hide()
	_resume = _button(box, "Back to game", MINT)
	_resume.pressed.connect(func() -> void:
		show_game()
		resume_requested.emit())
	_leave = _button(box, "Leave game", CREAM)
	_leave.pressed.connect(func() -> void: leave_requested.emit())
	_status = _label(box, "", 16, CORAL)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 24
	_label(box, "Same Wi-Fi or home network · Up to 3 players", 13, MUTED)
	var quit: Button = _button(box, "Quit game", CREAM)
	quit.pressed.connect(func() -> void: quit_requested.emit())

func _join() -> void:
	if _name.text.strip_edges().is_empty():
		_status.text = "Enter your name."
	elif _address.text.strip_edges().is_empty():
		_status.text = "Enter the host's IP address."
	else:
		_status.text = "Joining…"
		join_requested.emit(_address.text.strip_edges(), _name.text.strip_edges())

func _build_game() -> void:
	_game = Control.new()
	_full(_game)
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_game)
	var top: MarginContainer = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_margin(top, 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var left_plate: PanelContainer = _backplate(row)
	left_plate.custom_minimum_size.x = 370
	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_plate.add_child(left)
	_objective = _label(left, "Get everyone across", 22, CREAM)
	_crew = _label(left, "", 15, CREAM)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var right_plate: PanelContainer = _backplate(row)
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_plate.add_child(right)
	_wind = _label(right, "WIND →", 16, MINT)
	_progress = _label(right, "0/5 powers collected · 0 clears", 14, CREAM)
	_wind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bottom_plate: PanelContainer = _backplate(_game)
	bottom_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_plate.offset_left = 16
	bottom_plate.offset_right = 670
	bottom_plate.offset_top = -146
	bottom_plate.offset_bottom = -16
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	bottom_plate.add_child(bottom)
	_note = _label(bottom, "", 17, CREAM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power = _label(bottom, "", 14, MINT)
	_label(bottom, "WASD Move · Mouse Look · Hold LMB / RMB to grab\nSpace Jump · R Flop · E Switch · F Recover · M Mute · Esc Menu", 15, CREAM)

func _build_draft() -> void:
	_draft = _scrim(Color(0.05, 0.12, 0.16, 0.88))
	var box: VBoxContainer = _center_box(_draft, 740)
	box.add_theme_constant_override("separation", 18)
	var title: Label = _label(box, "PICK A POWER", 36, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(box, "Pick 1, 2 or 3. Finish to keep it.", 17, MINT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	box.add_child(_cards)
	_collection = VBoxContainer.new()
	_collection.add_theme_constant_override("separation", 8)
	box.add_child(_collection)
	var heading: Label = _label(_collection, "Collected powers · Pick any", 15, MINT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collected_buttons = HBoxContainer.new()
	_collected_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_collected_buttons.add_theme_constant_override("separation", 8)
	_collection.add_child(_collected_buttons)
	_collection.hide()

func _rebuild_collected() -> void:
	for child: Node in _collected_buttons.get_children():
		_collected_buttons.remove_child(child)
		child.queue_free()
	for id: String in _owned_ids:
		var info: Dictionary = Rules.power_info(id)
		var button: Button = _button(_collected_buttons, str(info.name), MINT)
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = str(info.description)
		button.pressed.connect(func() -> void: power_chosen.emit(id))

func _rebuild_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for index: int in range(_offer_ids.size()):
		var id: String = _offer_ids[index]
		var info: Dictionary = Rules.power_info(id)
		var card: Button = _button(_cards, "", CREAM if index != 1 else MINT)
		card.custom_minimum_size = Vector2(230, 245)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inset: MarginContainer = MarginContainer.new()
		_full(inset)
		_margin(inset, 16)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inset)
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 12)
		inset.add_child(box)
		_label(box, "%02d" % (index + 1), 14, NAVY)
		var mark: PowerMark = PowerMark.new()
		mark.power_id = id
		mark.custom_minimum_size.y = 70
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mark)
		_label(box, str(info.name), 18, NAVY)
		var description: Label = _label(box, str(info.description), 16, NAVY)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(func() -> void: power_chosen.emit(id))

func _build_ending() -> void:
	_ending = _scrim(Color(0.05, 0.12, 0.16, 0.94))
	var box: VBoxContainer = _center_box(_ending, 480)
	box.add_theme_constant_override("separation", 18)
	_label(box, "EVERYONE MADE IT", 35, MINT)
	_ending_detail = _label(box, "", 20, CREAM)
	_restart = _button(box, "Another run", MINT)
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_host_wait = _label(box, "Waiting for the host…", 17, MUTED)
	var leave: Button = _button(box, "Leave game", CREAM)
	leave.pressed.connect(func() -> void: leave_requested.emit())

func _scrim(color: Color) -> Control:
	var layer: ColorRect = ColorRect.new()
	layer.color = color
	_full(layer)
	_root.add_child(layer)
	return layer

func _backplate(parent: Node) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _style(Color(NAVY, 0.96)))
	parent.add_child(plate)
	return plate

func _center_box(parent: Control, width: float) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	_full(center)
	parent.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = width
	center.add_child(box)
	return box

func _full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _margin(control: MarginContainer, amount: int) -> void:
	for edge: String in ["left", "right", "top", "bottom"]:
		control.add_theme_constant_override("margin_" + edge, amount)

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 45
	button.add_theme_color_override("font_color", NAVY)
	button.add_theme_color_override("font_hover_color", NAVY)
	button.add_theme_color_override("font_pressed_color", NAVY)
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12)))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CORAL))
	parent.add_child(button)
	return button

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(3)
	return style

func _theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("normal", "LineEdit", _style(CREAM))
	theme.set_stylebox("focus", "LineEdit", _style(CREAM, MINT))
	theme.set_color("font_color", "LineEdit", NAVY)
	theme.set_color("font_placeholder_color", "LineEdit", Color("61777f"))
	theme.set_color("caret_color", "LineEdit", NAVY)
	return theme
