extends Node3D

const Sim = preload("res://sim.gd")
const Court = preload("res://world.gd")
const SoundBank = preload("res://audio.gd")
const Profile = preload("res://profile.gd")
const HypeIndicator = preload("res://hud.gd")
const NetworkAddress = preload("res://network_address.gd")
const PORT = 28888
const NETWORK_CHANNELS = 5
# Leave room for Godot RPC framing inside ENet's 1392-byte unreliable limit.
const UNRELIABLE_SNAPSHOT_BYTES = 1200
const MAX_SNAPSHOT_BYTES = 65536
const MAX_PENDING_SNAPSHOTS = 4
const INK = Color("11243c")
const PAPER = Color("f7f4ec")
const ORANGE = Color("ffac54")
const TEAL = Color("54e5cd")
const ACTIONS = ["jump", "grab", "catch", "throw", "tackle", "dunk", "pass", "interact", "catch_pass", "request_pass", "hype"]
const POWER_IDS = ["giant", "pad", "blast"]
const POWER_NAMES = ["Giant", "Jump pad", "Homing ball"]
const DIFFICULTY_IDS = ["easy", "normal", "hard"]
const REWARD_SAVE_ERROR = "Could not save reward. Retry before closing."
const CONTROLLER_BUTTONS = {"jump": JOY_BUTTON_A, "catch_pass": JOY_BUTTON_X, "request_pass": JOY_BUTTON_RIGHT_SHOULDER, "dunk": JOY_BUTTON_B, "hype": JOY_BUTTON_Y, "ball_camera": JOY_BUTTON_LEFT_SHOULDER, "recenter": JOY_BUTTON_RIGHT_STICK}
const CONTROLLER_UI = {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
var sim = Sim.new()
var aim_sim = Sim.new()
var presentation_sim = Sim.new()
var trajectory_sim = Sim.new()
var profile = Profile.new()
var cosmetics: Dictionary = {}
var match_id = ""
var rivalry = preload("res://series.gd").new()
var presentation_time_scale = 1.0
var wardrobe_panel: Control
var wardrobe_focus_id = "character"
var reveal_panel: Control
var result_bag_button: Button
var team_choices: Dictionary = {}
var balance_teams = true
var lobby_setup: Dictionary = {}
var team_rows: VBoxContainer
var lobby_note: Label
var state: Dictionary = {}
var preview: Dictionary = {}
var world: Node3D
var presentation_enabled = DisplayServer.get_name() != "headless"
var phase = "menu"
var local_seat = 1
var seats: Dictionary = {1: 1}
var names: Dictionary = {1: "PLAYER 1"}
var selected_mode = "coop"
var selected_power = "giant"
var selected_difficulty = "easy"
var powers: Dictionary = {}
var snapshot_count = 0
var snapshot_serial = 0
var snapshot_received_sequence = -1
var pending_snapshots: Dictionary = {}
var snapshot_transport: Dictionary = {"unreliable":0,"reliable":0,"coalesced":0,"stale":0,"max_unreliable_bytes":0,"max_reliable_bytes":0}
var remote_inputs: Dictionary = {}
var last_input: Dictionary = {}
var manual_input_enabled = true
var yaw = 0.0
var pitch = 0.43
var charge_time = 0.0
var charge_possession = -1.0
var charging = false
var ball_camera = false
var paused = false
var muted = false
var shot_assist = true
# Presentation: slow-motion and hit-stop are local time-scale pulses; the
# cinematic camera cuts live in world.gd and read these snapshot timers.
var cinematics_enabled = true
var slowmo_until = -1.0
var slowmo_scale = 1.0
var hitstop_until = -1.0
var _cinematic_score_at = -10.0
var _final_banner_shown = false
var _last_banner_event = -1
var nickname = ""
var last_ip = ""
var room_server_url = ""
var publish_online_room = false
var room_code = ""
var room_host_pending = false
var room_edit: LineEdit
var status_message = ""
var net_clock = 0.0
var ui_clock = 0.0
var connect_time = 0.0
var snapshot_received_at = 0.0
var local_direction = Vector3.ZERO
var last_aim = Vector3.FORWARD
var visual_jump_started = -1.0
var visual_jump_origin = 0.0
var visual_jump_speed = 0.0
var visual_jump_count = 0
var local_render_y = 0.0
var local_render_velocity_y = 0.0
var local_render_clock = -1.0
var visual_y_correction = 0.0
var player_render_history: Dictionary = {}
var ball_render_position = Vector3.ZERO
var ball_render_velocity = Vector3.ZERO
var ball_render_clock = -1.0
var ball_render_sequence = -1
var ball_render_round = ""
var ball_render_owner = -1
var ball_render_correction = Vector3.ZERO
var ball_render_age = 0.0
var ball_render_sample: Dictionary = {}
var ball_render_recovering = false
var last_event = -1
var event_age = 10.0
var shoot_previous = false
var input_armed = false
var controller_device = -1
var controller_trigger = false
var controller_rebinding = false
var controller_neutral = true
var controller_focus_root: Control
var controller_keyboard: Control
var controller_text_target: LineEdit
var controller_text_edit: LineEdit
var controller_nav_direction = Vector2.ZERO
var controller_nav_repeat = 0.0
var controller_focus_layout = 0
var controller_help_labels: Array[Label] = []
var _closing = false
var _winner_shown = false
var _earned_reward_round = ""
var _camera_spawn_pending = false
var _outcome_recorded = false
var _reward_seats: Array = []
var _reward_peers: Array = []
var pending_rewards: Dictionary = {}
var last_reward_attempt = -10.0
var reward_error = ""
var layer: CanvasLayer
var ui: Control
var panel: Control
var pause_panel: Control
var result_panel: Control
var score_label: Label
var clock_label: Label
var target_label: Label
var possession_label: Label
var prompt_label: Label
var prompt_back: Panel
var event_label: Label
var audio_label: Label
var charge_label: Label
var charge_bar: ProgressBar
var hype_ring: Control
var jump_label: Label
var rule_label: Label
var _hud_scores: Dictionary = {}
var _hud_announcement = ""
var _hud_announcement_until = 0.0
var _hud_countdown = -1
var _hud_remaining = -1
var _hud_score_at = -10.0
var _hud_owner = -1
var _hud_grounded = true
var _sound_event_id = -1
var _sound_event_clock = -1.0
var _sound_round = ""
var goal_flash: ColorRect
var charge_marker: ColorRect
var banner_label: Label
var intro_card: Control
var ball_marker: Label
var roster_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var mode_select: OptionButton
var power_select: OptionButton
var difficulty_select: OptionButton
var difficulty_label: Label
var power_description: Label
var _hype_amount = -1.0
var _hype_power = ""
var _hype_notice = ""
var _hype_notice_until = 0.0
var menu_note: Label
var wardrobe_button: Button
var sounds: Node
var hud_help: Control
var controls_hint: Label
var hud_help_until = 0.0

func _ready() -> void:
	# Explicit host routing avoids ENet relay races when two clients leave together.
	multiplayer.server_relay = false
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		nickname = str(cfg.get_value("player", "name", ""))
		last_ip = str(cfg.get_value("player", "ip", ""))
		muted = bool(cfg.get_value("audio", "muted", false))
		selected_power = clean_power(str(cfg.get_value("player", "power", "giant")))
		selected_difficulty = clean_difficulty(str(cfg.get_value("game", "bot_difficulty", "easy")))
		shot_assist = bool(cfg.get_value("game", "shot_assist", true))
	room_server_url = configured_room_server()
	setup_inputs()
	configure_controller()
	Input.joy_connection_changed.connect(controller_connection_changed)
	multiplayer.peer_connected.connect(peer_joined)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connection_failed.connect(func(): close_session("Could not connect. Check the room code or LAN address and try again."))
	multiplayer.server_disconnected.connect(func(): close_session("The host left the court. Start practice or join another game."))
	world = Court.new()
	add_child(world)
	world.build("coop")
	sounds = SoundBank.new()
	add_child(sounds)
	layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	show_menu()

func setup_inputs() -> void:
	var bindings = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "grab": [KEY_E], "tackle": [KEY_SHIFT], "dunk": [KEY_F], "pass_ball": [], "catch_pass": [], "request_pass": [], "hype": [KEY_Q], "ball_camera": [KEY_CTRL], "recenter": [KEY_R]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var key_event = InputEventKey.new()
			key_event.physical_keycode = key
			InputMap.action_add_event(action, key_event)
	if not InputMap.has_action("throw_ball"): InputMap.add_action("throw_ball")
	if not InputMap.has_action("controller_shoot"): InputMap.add_action("controller_shoot")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("throw_ball", mouse)
	var center_mouse = InputEventMouseButton.new()
	center_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("catch_pass", center_mouse)
	var middle_mouse = InputEventMouseButton.new()
	middle_mouse.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event("request_pass", middle_mouse)

func controller_devices() -> Array[int]:
	var devices: Array[int] = []
	for device in Input.get_connected_joypads(): devices.append(int(device))
	return devices

func controller_connection_changed(_device: int, _connected: bool) -> void:
	configure_controller()

func configure_controller() -> void:
	var devices = controller_devices()
	var next_device = controller_device if controller_device in devices else (int(devices[0]) if not devices.is_empty() else -1)
	if next_device == controller_device: return
	var previous_device = controller_device
	# Release through the old mapping before removing it. Keyboard/mouse bindings stay intact.
	controller_rebinding = true
	if previous_device >= 0:
		for button in CONTROLLER_BUTTONS.values() + CONTROLLER_UI.values():
			var released = InputEventJoypadButton.new()
			released.device = previous_device
			released.button_index = button
			Input.parse_input_event(released)
	Input.action_release("controller_shoot")
	controller_rebinding = false
	controller_trigger = false
	charging = false
	charge_time = 0.0
	shoot_previous = false
	input_armed = false
	controller_neutral = next_device < 0
	controller_device = next_device
	controller_nav_direction = Vector2.ZERO
	var buttons = CONTROLLER_BUTTONS.duplicate()
	buttons.merge(CONTROLLER_UI)
	var held_keys: Array[StringName] = []
	for action in buttons:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and ((event.physical_keycode != 0 and Input.is_physical_key_pressed(event.physical_keycode)) or (event.keycode != 0 and Input.is_key_pressed(event.keycode))): held_keys.append(action)
			elif event is InputEventMouseButton and Input.is_mouse_button_pressed(event.button_index): held_keys.append(action)
	for action in buttons:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action, event)
		if controller_device >= 0:
			var button_event = InputEventJoypadButton.new()
			button_event.device = controller_device
			button_event.button_index = buttons[action]
			InputMap.action_add_event(action, button_event)
	for event in InputMap.action_get_events("throw_ball"):
		if event is InputEventJoypadMotion: InputMap.action_erase_event("throw_ball", event)
	# Removing a binding resets that action in Godot, including a held keyboard key.
	# Restore those holds; neutral rearming prevents them becoming gameplay presses.
	for action in held_keys:
		if not Input.is_action_pressed(action): Input.action_press(action)
	if previous_device >= 0 and phase == "match" and manual_input_enabled and not _winner_shown: set_paused(true)
	if is_instance_valid(ui): update_controller_focus()

func controller_stick(x_axis: int, y_axis: int, deadzone: float) -> Vector2:
	if controller_device < 0 or not controller_neutral: return Vector2.ZERO
	var stick = Vector2(Input.get_joy_axis(controller_device, x_axis), Input.get_joy_axis(controller_device, y_axis))
	var magnitude = stick.length()
	return Vector2.ZERO if magnitude <= deadzone else stick.normalized() * clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)

func controller_labels(value: String) -> String:
	if controller_device < 0: return value
	var device_name = controller_name().to_lower()
	var labels = ["Bottom", "Right", "Left", "Top", "R trigger", "R shoulder", "L shoulder", "Menu"]
	if "dual" in device_name or "playstation" in device_name or "ps4" in device_name or "ps5" in device_name:
		labels = ["Cross", "Circle", "Square", "Triangle", "R2", "R1", "L1", "Options"]
	elif "nintendo" in device_name or "switch" in device_name or "joy-con" in device_name:
		labels = ["B", "A", "Y", "X", "ZR", "R", "L", "+"]
	elif "xbox" in device_name or "xinput" in device_name or "x-box" in device_name:
		return value
	# Mark original tokens first so Nintendo A/B and X/Y replacements cannot cascade.
	var tokens = [" / A", " / B", " / X", " / Y", "RT", "RB", "LB", "Start"]
	for index in tokens.size(): value = value.replace(tokens[index], "{pad%d}" % index)
	for index in tokens.size(): value = value.replace("{pad%d}" % index, (" / " if index < 4 else "") + labels[index])
	return value

func controller_name() -> String:
	return Input.get_joy_name(controller_device) if controller_device >= 0 else ""

func controller_at_rest() -> bool:
	if controller_device < 0: return true
	for button in CONTROLLER_BUTTONS.values() + CONTROLLER_UI.values() + [JOY_BUTTON_START]:
		if Input.is_joy_button_pressed(controller_device, button): return false
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if absf(Input.get_joy_axis(controller_device, axis)) > 0.2: return false
	return Input.get_joy_axis(controller_device, JOY_AXIS_TRIGGER_RIGHT) < 0.35

func controller_menu_root() -> Control:
	for candidate in [controller_keyboard, reveal_panel, wardrobe_panel]:
		if is_instance_valid(candidate) and candidate.is_inside_tree() and candidate.is_visible_in_tree(): return candidate
	if phase == "match":
		if _winner_shown and is_instance_valid(result_panel): return result_panel
		if paused and is_instance_valid(pause_panel): return pause_panel
		return null
	return panel if is_instance_valid(panel) else null

func focusable_controls(parent: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in parent.get_children():
		if child is Control and child.is_visible_in_tree():
			if child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled): found.append(child)
			found.append_array(focusable_controls(child))
	return found

func update_controller_focus() -> void:
	if controller_device < 0 or not is_instance_valid(ui): return
	var scope = controller_menu_root()
	var focused = get_viewport().gui_get_focus_owner()
	if not is_instance_valid(scope):
		if is_instance_valid(focused): focused.release_focus()
		controller_focus_root = null
		return
	var controls = focusable_controls(scope)
	if controls.is_empty(): return
	if scope != controller_focus_root or not is_instance_valid(focused) or not focused in controls:
		var preferred: Control = controls[0]
		for control in controls:
			if control is Button and control.text in ["Practice", "Start", "Resume", "Rematch", "Equip", "Open bag", "Done"]:
				preferred = control
				break
		preferred.grab_focus()
	controller_focus_root = scope
	var layout = hash(controls.map(func(control: Control): return [control.get_instance_id(), control.get_global_rect()]))
	if layout == controller_focus_layout: return
	controller_focus_layout = layout
	# Explicit neighbours prevent focus escaping to a menu behind a modal.
	for index in controls.size():
		var control = controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var direction = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]
			var best: Control = control
			var score = INF
			for other in controls:
				var offset = other.get_global_rect().get_center() - control.get_global_rect().get_center()
				var along = offset.dot(direction)
				if along <= 1.0: continue
				var rect = other.get_global_rect()
				var center = control.get_global_rect().get_center()
				var across = maxf(rect.position.x - center.x, maxf(center.x - rect.end.x, 0.0)) if direction.y != 0 else maxf(rect.position.y - center.y, maxf(center.y - rect.end.y, 0.0))
				var candidate_score = along + across * 3.0
				if candidate_score < score: score = candidate_score; best = other
			control.set_focus_neighbor(side, control.get_path_to(best))

func controller_back() -> void:
	if is_instance_valid(controller_keyboard): close_controller_keyboard(false)
	elif is_instance_valid(reveal_panel) and reveal_panel.is_inside_tree(): close_reveal()
	elif is_instance_valid(wardrobe_panel) and wardrobe_panel.is_inside_tree(): close_wardrobe()
	elif phase == "match" and paused and not _winner_shown: set_paused(false)
	elif phase in ["lobby", "connecting"] or (phase == "match" and _winner_shown): close_session()

func controller_navigate(direction: Vector2) -> void:
	for window in get_viewport().get_embedded_subwindows():
		if window is PopupMenu and window.visible:
			if direction.y == 0: return
			var count = window.item_count
			var next_index = window.get_focused_item()
			for attempt in count:
				next_index = (next_index + int(direction.y) + count) % count
				if not window.is_item_disabled(next_index) and not window.is_item_separator(next_index):
					window.set_focused_item(next_index)
					break
			return
	update_controller_focus()
	var focused = get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focused): return
	var side = SIDE_RIGHT if direction.x > 0 else SIDE_LEFT
	if direction.y != 0: side = SIDE_BOTTOM if direction.y > 0 else SIDE_TOP
	var next = focused.get_node_or_null(focused.get_focus_neighbor(side)) as Control
	if is_instance_valid(next): next.grab_focus()

func open_controller_keyboard(target: LineEdit) -> void:
	controller_text_target = target
	controller_keyboard = Control.new()
	controller_keyboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(controller_keyboard)
	var wash = ColorRect.new()
	wash.color = Color(0.015, 0.025, 0.045, 0.95)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controller_keyboard.add_child(wash)
	var card = make_card(controller_keyboard, Vector2(215, 150), Vector2(850, 490))
	var column = make_column(card, 12)
	make_label("Name" if target == name_edit else ("Room code" if target == room_edit else "Host address"), column, 26)
	controller_text_edit = LineEdit.new()
	controller_text_edit.text = target.text
	controller_text_edit.max_length = target.max_length
	controller_text_edit.custom_minimum_size.y = 48
	controller_text_edit.add_theme_font_size_override("font_size", 22)
	controller_text_edit.focus_mode = Control.FOCUS_NONE
	column.add_child(controller_text_edit)
	var grid = GridContainer.new()
	grid.columns = 10
	column.add_child(grid)
	for character in "1234567890abcdefghijklmnopqrstuvwxyz.-: ":
		var key = make_button("Space" if character == " " else character, func(): controller_text_edit.text += character, grid)
		key.custom_minimum_size.x = 75
		key.add_theme_font_size_override("font_size", 17)
	var row = HBoxContainer.new()
	column.add_child(row)
	make_button("Delete", func(): controller_text_edit.text = controller_text_edit.text.left(-1), row)
	make_button("Clear", func(): controller_text_edit.text = "", row)
	make_button("Cancel", func(): close_controller_keyboard(false), row)
	make_button("Done", func(): close_controller_keyboard(true), row, true)
	update_controller_focus.call_deferred()

func close_controller_keyboard(accept: bool) -> void:
	var target = controller_text_target
	if accept and is_instance_valid(target): target.text = controller_text_edit.text
	if is_instance_valid(controller_keyboard):
		ui.remove_child(controller_keyboard)
		controller_keyboard.queue_free()
	controller_keyboard = null
	controller_text_target = null
	controller_text_edit = null
	controller_focus_root = controller_menu_root()
	if is_instance_valid(target): target.grab_focus()

func box_style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func make_label(value: String, parent: Node, size: int = 18, color: Color = PAPER) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func outline(label: Label, width: int) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.035, 0.065, 0.95))
	label.add_theme_constant_override("outline_size", width)

func make_button(value: String, callback: Callable, parent: Node, accent: bool = false) -> Button:
	var button = Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if accent else PAPER)
	button.add_theme_color_override("font_hover_color", INK if accent else PAPER)
	button.add_theme_color_override("font_focus_color", INK if accent else PAPER)
	button.add_theme_stylebox_override("normal", box_style(ORANGE if accent else Color("28435c")))
	button.add_theme_stylebox_override("hover", box_style(Color("ffce88") if accent else Color("3a5971"), PAPER))
	button.add_theme_stylebox_override("pressed", box_style(TEAL if accent else Color("34536a")))
	button.add_theme_stylebox_override("focus", box_style(Color.TRANSPARENT, TEAL))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func make_card(parent: Node, at: Vector2, dimensions: Vector2, color: Color = Color(0.055, 0.11, 0.19, 0.94)) -> PanelContainer:
	var card = PanelContainer.new()
	card.position = at
	card.size = dimensions
	card.add_theme_stylebox_override("panel", box_style(color, Color(0.5, 0.7, 0.8, 0.2)))
	parent.add_child(card)
	return card

func make_column(parent: Node, separation: int = 10) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

func new_screen() -> Control:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	name_edit = null
	ip_edit = null
	room_edit = null
	roster_label = null
	difficulty_select = null
	difficulty_label = null
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	return panel

func backdrop(parent: Node) -> void:
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.12, 0.23)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)

func show_menu() -> void:
	phase = "menu"
	paused = false
	charging = false
	if not pending_rewards.is_empty() and not reward_error.is_empty(): status_message = reward_error
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.build(selected_mode)
	sim.set_difficulty(selected_difficulty)
	sim.reset(selected_mode)
	preview = sim.snapshot()
	var screen = new_screen()
	backdrop(screen)
	var title = make_label("Crown Court", screen, 48)
	title.position = Vector2(44, 30)
	var card = make_card(screen, Vector2(44, 106), Vector2(440, 570))
	var menu = make_column(card, 10)
	make_label("Name", menu, 16, Color("9bb4c7"))
	name_edit = LineEdit.new()
	name_edit.text = nickname
	name_edit.placeholder_text = "Player 1"
	name_edit.max_length = 16
	name_edit.custom_minimum_size.y = 42
	name_edit.add_theme_font_size_override("font_size", 18)
	menu.add_child(name_edit)
	var options_row = HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 6)
	menu.add_child(options_row)
	mode_select = OptionButton.new()
	mode_select.add_item("3 vs bots", 0)
	mode_select.add_item("Free-for-all", 1)
	mode_select.add_item("Custom teams", 2)
	mode_select.select({"coop": 0, "versus": 1, "teams": 2}.get(selected_mode, 0))
	mode_select.custom_minimum_size.y = 44
	mode_select.add_theme_font_size_override("font_size", 14)
	mode_select.get_popup().add_theme_font_size_override("font_size", 14)
	mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_row.add_child(mode_select)
	mode_select.item_selected.connect(func(index: int): selected_mode = ["coop", "versus", "teams"][index]; world.build(selected_mode); sim.reset(selected_mode); preview = sim.snapshot())
	power_select = OptionButton.new()
	for power_name in POWER_NAMES: power_select.add_item(power_name)
	power_select.select(POWER_IDS.find(clean_power(selected_power)))
	power_select.custom_minimum_size.y = 44
	power_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_select.add_theme_font_size_override("font_size", 14)
	power_select.get_popup().add_theme_font_size_override("font_size", 14)
	options_row.add_child(power_select)
	power_select.item_selected.connect(func(index: int): selected_power = POWER_IDS[index]; update_power_description(); save_settings())
	make_difficulty_select(options_row)
	make_button("Practice", func(): save_settings(); practice_game(selected_mode), menu, true)
	make_button("Same Wi-Fi / LAN", func(): save_settings(); show_lan_menu(), menu)
	menu_note = make_label(status_message if not status_message.is_empty() else "Playing from different houses? Use Play online.\nEmpty seats use bots.", menu, 16, Color("c0ced7"))
	menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_internet_help(screen)
	var power_card = make_card(screen, Vector2(552, 492), Vector2(600, 160))
	var power_column = make_column(power_card, 10)
	power_description = make_label("", power_column, 21, PAPER)
	power_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_power_description()
	make_label("Earn Hype by catching, passing, defending and scoring.", power_column, 16, Color("c0ced7"))
	menu_note.custom_minimum_size.x = 390
	wardrobe_button = make_button("Wardrobe  ·  %d bags" % int(profile.data.bags), func(): save_settings(); show_wardrobe(), menu)
	var bottom = HBoxContainer.new()
	menu.add_child(bottom)
	make_button("Quit", func(): get_tree().quit(), bottom)
	make_button("Sound " + ("off" if muted else "on"), func(): toggle_mute(); show_menu(), bottom)
	make_button("Shot assist " + ("on" if shot_assist else "off"), func(): shot_assist = not shot_assist; save_settings(); show_menu(), bottom)
	add_controls(screen)

func update_power_description() -> void:
	if not is_instance_valid(power_description): return
	power_description.text = {
		"giant": "Giant\nGrow larger and walk through sweepers.",
		"pad": "Jump pad\nPlace a launch pad that either team can use.",
		"blast": "Homing ball\nSend a homing ball at the nearest opponent."
	}.get(selected_power, "")

func add_controls(parent: Node) -> Control:
	var card = make_card(parent, Vector2(44, 728), Vector2(1192, 48), Color(0.04, 0.08, 0.14, 0.88))
	var hint = make_label("", card, 17, Color("c4d2de"))
	controller_help_labels.append(hint)
	update_controller_labels()
	return card

func update_controller_labels() -> void:
	controller_help_labels = controller_help_labels.filter(func(label): return is_instance_valid(label))
	for label in controller_help_labels:
		if controller_device < 0: label.text = "WASD Move   ·   Space Jump   ·   LMB Catch / pass   ·   RMB Tackle / shoot   ·   Ctrl Ball cam   ·   F1 Controls"
		elif phase == "match" and not paused and not _winner_shown: label.text = controller_labels("Left stick Move   ·   Jump / A   ·   Catch or pass / X   ·   RT Shoot   ·   Dunk / B   ·   Start Controls")
		else: label.text = controller_labels("D-pad / left stick Navigate   ·   Confirm / A   ·   Back / B")
	if is_instance_valid(controls_hint): controls_hint.text = controller_labels("Start Controls") if controller_device >= 0 else "F1 Controls"
	if is_instance_valid(pause_panel):
		var note = pause_panel.find_child("Note", true, false) as Label
		if is_instance_valid(note) and note.has_meta("controller_text"): note.text = controller_labels(note.get_meta("controller_text"))

func save_settings() -> void:
	if is_instance_valid(name_edit): nickname = clean_name(name_edit.text, 1)
	if is_instance_valid(ip_edit): last_ip = ip_edit.text.strip_edges()
	var cfg = ConfigFile.new()
	cfg.set_value("player", "name", nickname)
	cfg.set_value("player", "ip", last_ip)
	cfg.set_value("player", "power", clean_power(selected_power))
	cfg.set_value("game", "bot_difficulty", clean_difficulty(selected_difficulty))
	cfg.set_value("game", "shot_assist", shot_assist)
	cfg.set_value("audio", "muted", muted)
	cfg.save("user://settings.cfg")

func match_options() -> Dictionary:
	# Real matches open with the arena fly-over and honour the host's assist choice.
	return {"intro": cinematics_enabled and presentation_enabled and not scripted_session(), "shot_assist": shot_assist}

func scripted_session() -> bool:
	# Test harnesses drive the app with --script and scripted input on fixed
	# timings; they get the plain three second countdown and follow camera.
	return "--script" in OS.get_cmdline_args() and not "--full-presentation" in OS.get_cmdline_user_args()

func clean_name(value: String, slot: int) -> String:
	var clean = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().substr(0, 16)
	return clean if not clean.is_empty() else "PLAYER %d" % slot

func clean_power(value: String) -> String:
	return value if value in POWER_IDS else "giant"

func clean_difficulty(value: String) -> String:
	return value if value in DIFFICULTY_IDS else "easy"

func effective_difficulty() -> String:
	if phase == "match": return clean_difficulty(str(state.get("bot_difficulty", sim.bot_difficulty if multiplayer.is_server() else lobby_setup.get("bot_difficulty", "easy"))))
	return clean_difficulty(selected_difficulty if multiplayer.is_server() else str(lobby_setup.get("bot_difficulty", "easy")))

func make_difficulty_select(parent: Node) -> void:
	difficulty_select = OptionButton.new()
	for value in DIFFICULTY_IDS: difficulty_select.add_item(value.capitalize() + " bots")
	difficulty_select.select(DIFFICULTY_IDS.find(clean_difficulty(selected_difficulty)))
	difficulty_select.custom_minimum_size.y = 44
	difficulty_select.add_theme_font_size_override("font_size", 14 if phase == "menu" else 16)
	difficulty_select.get_popup().add_theme_font_size_override("font_size", 14 if phase == "menu" else 16)
	difficulty_select.add_theme_stylebox_override("focus", box_style(Color(0.04, 0.13, 0.19, 0.65), TEAL, 5))
	parent.add_child(difficulty_select)
	difficulty_select.item_selected.connect(func(index: int):
		if not multiplayer.is_server(): return
		selected_difficulty = DIFFICULTY_IDS[index]
		sim.set_difficulty(selected_difficulty)
		preview = sim.snapshot()
		save_settings()
		if phase == "lobby": broadcast_roster(); update_roster()
	)

func host_game(mode: String) -> void:
	room_code = ""
	room_host_pending = false
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 2, NETWORK_CHANNELS)
	if error != OK:
		status_message = "Could not host on UDP %d. Close another Crown Court host and retry." % PORT
		show_menu()
		return
	multiplayer.multiplayer_peer = peer
	selected_mode = mode if mode in ["coop", "versus", "teams"] else "coop"
	seats = {1: 1}
	names = {1: clean_name(nickname, 1)}
	cosmetics = {1: profile.outfit()}
	powers = {1: clean_power(selected_power)}
	local_seat = 1
	team_choices.clear()
	show_lobby()

func practice_game(mode: String) -> void:
	room_code = ""
	room_host_pending = false
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	selected_mode = mode if mode in ["coop", "versus", "teams"] else "coop"
	local_seat = 1
	seats = {1: 1}
	names = {1: clean_name(nickname, 1)}
	cosmetics = {1: profile.outfit()}
	powers = {1: clean_power(selected_power)}
	team_choices.clear()
	if selected_mode == "teams": balance_teams = true
	start_match()

func join_game(address: String) -> void:
	room_code = ""
	room_host_pending = false
	var endpoint = NetworkAddress.endpoint(address)
	if endpoint.has("error"):
		status_message = endpoint.error
		show_menu()
		return
	address = endpoint.host
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, endpoint.port, NETWORK_CHANNELS)
	if error != OK:
		status_message = "That address could not be used. Check the host IP or computer name."
		show_menu()
		return
	multiplayer.multiplayer_peer = peer
	seats.clear()
	names.clear()
	local_seat = 0
	phase = "connecting"
	connect_time = ui_clock
	var screen = new_screen()
	backdrop(screen)
	var card = make_card(screen, Vector2(380, 250), Vector2(520, 215))
	var column = make_column(card)
	make_label("Connecting", column, 28, ORANGE)
	var target = make_label("Connecting to " + address + " : " + str(endpoint.port), column, 18)
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	make_label("Waiting for host…", column, 17)
	make_button("Cancel", func(): close_session(), column)

func local_addresses() -> String:
	var addresses = NetworkAddress.available(IP.get_local_addresses())
	return ", ".join(addresses.lan) if not addresses.lan.is_empty() else "No local address found."

func configured_room_server() -> String:
	var config = ConfigFile.new()
	var path = OS.get_executable_path().get_base_dir().path_join("internet.cfg")
	if config.load(path) != OK and config.load("res://internet.cfg") != OK: return ""
	return str(config.get_value("server", "url", "")).strip_edges()

func host_room(mode: String, listed: bool = false) -> void:
	publish_online_room = listed
	selected_mode = mode if mode in ["coop", "versus", "teams"] else "coop"
	connect_room(true)

func join_room(code: String) -> void:
	publish_online_room = false
	connect_room(false, code)

func connect_room(create_room: bool, code: String = "") -> void:
	if _closing: return
	if room_server_url.is_empty() or not ResourceLoader.exists("res://room_peer.gd"):
		status_message = "Internet rooms are not available in this build. Practice and LAN are available."
		show_menu()
		return
	code = code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if not create_room and code.length() != 26:
		status_message = "Enter the room code shown in the host's lobby."
		show_menu()
		return
	var peer = load("res://room_peer.gd").new()
	if create_room and publish_online_room: peer.public_name = clean_name(nickname, 1)
	var reference = weakref(peer)
	peer.room_ready.connect(func(value: String):
		if _closing or multiplayer.multiplayer_peer != reference.get_ref(): return
		room_code = value
		if room_host_pending:
			room_host_pending = false
			show_lobby())
	peer.room_error.connect(func(message: String):
		if not _closing and multiplayer.multiplayer_peer == reference.get_ref(): close_session(message.substr(0, 100)))
	var error: int = peer.configure(room_server_url, create_room, code)
	if error != OK:
		status_message = str(peer.failure_text) if not str(peer.failure_text).is_empty() else "The room service could not be reached. Try again later."
		show_menu()
		return
	room_host_pending = create_room
	room_code = ""
	status_message = ""
	seats = {1: 1} if create_room else {}
	names = {1: clean_name(nickname, 1)} if create_room else {}
	cosmetics = {1: profile.outfit()} if create_room else {}
	powers = {1: clean_power(selected_power)} if create_room else {}
	team_choices.clear()
	local_seat = 1 if create_room else 0
	phase = "connecting"
	connect_time = ui_clock
	multiplayer.multiplayer_peer = peer
	var screen = new_screen()
	backdrop(screen)
	var card = make_card(screen, Vector2(380, 250), Vector2(520, 215))
	var column = make_column(card)
	make_label("Creating room" if create_room else "Joining room", column, 28, ORANGE)
	make_label("Connecting to room service…" if create_room else "Room " + code, column, 18)
	make_button("Cancel", func(): close_session(), column)

func show_lan_menu() -> void:
	var screen = new_screen()
	backdrop(screen)
	var card = make_card(screen, Vector2(300, 180), Vector2(680, 390))
	var column = make_column(card, 14)
	make_label("Same Wi-Fi / LAN", column, 28, TEAL)
	make_label("For different houses, go Back and choose Play online.", column, 18)
	make_button("Host LAN", func(): save_settings(); host_game(selected_mode), column)
	make_label("Join LAN", column, 16, Color("9bb4c7"))
	var join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	column.add_child(join_row)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Host IP or computer name"
	ip_edit.text = last_ip
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_font_size_override("font_size", 16)
	join_row.add_child(ip_edit)
	var join_button = make_button("Join LAN", func(): save_settings(); join_game(last_ip), join_row)
	join_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	join_button.custom_minimum_size.x = 90
	make_button("Back", show_menu, column)

func add_internet_help(screen: Control) -> void:
	var card = make_card(screen, Vector2(552, 130), Vector2(600, 330))
	var column = make_column(card, 14)
	make_label("Play online", column, 26, TEAL)
	var available = not room_server_url.is_empty()
	var help = make_label("Host a game, or find a game to join.\nNo addresses or codes needed." if available else "Internet service is not configured.", column, 19)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var host_button = make_button("Host online game", func(): save_settings(); host_room(selected_mode, true), column)
	host_button.disabled = not available
	var join_button = make_button("Find online game", func(): save_settings(); show_online_games(), column)
	join_button.disabled = not available
	make_label("Open games are visible to other players.", column, 16)

func show_online_games() -> void:
	var screen = new_screen()
	backdrop(screen)
	var card = make_card(screen, Vector2(250, 100), Vector2(780, 580))
	var column = make_column(card, 12)
	make_label("Join an online game", column, 30, TEAL)
	var notice = make_label("Finding games…", column, 18)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(710, 345)
	column.add_child(scroll)
	var games = VBoxContainer.new()
	games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(games)
	var request = HTTPRequest.new()
	request.timeout = 10.0
	request.body_size_limit = 131072
	screen.add_child(request)
	var refresh = func():
		if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
		var url = room_server_url.replace("wss://", "https://").replace("ws://", "http://").trim_suffix("/rooms") + "/lobbies"
		if request.request(url) != OK: notice.text = "Could not contact the server. Try Refresh."
	request.request_completed.connect(func(result: int, response: int, _headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS or response != 200:
			notice.text = "Server unavailable. Try Refresh."
			return
		var listing = JSON.parse_string(body.get_string_from_utf8())
		if not listing is Dictionary or not listing.get("games") is Array:
			notice.text = "Server returned an invalid game list."
			return
		for child in games.get_children():
			games.remove_child(child)
			child.queue_free()
		var count = 0
		for game in listing.games:
			if not game is Dictionary or str(game.get("version", "")) != str(ProjectSettings.get_setting("application/config/version")): continue
			var code = str(game.get("code", ""))
			if code.length() != 26: continue
			var label = "%s  ·  %d/3 players  ·  Join" % [str(game.get("name", "Family game")).left(28), int(game.get("players", 1))]
			make_button(label, func(): join_room(code), games)
			count += 1
		notice.text = "Choose a game below." if count > 0 else "No open games yet. Waiting for someone to host…"
	)
	var row = HBoxContainer.new()
	column.add_child(row)
	make_button("Refresh", refresh, row)
	make_button("Back", show_menu, row)
	var timer = Timer.new()
	timer.wait_time = 3.0
	screen.add_child(timer)
	timer.timeout.connect(refresh)
	timer.start()
	refresh.call()

func show_lobby() -> void:
	phase = "lobby"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.build(selected_mode)
	sim.set_difficulty(effective_difficulty())
	sim.reset(selected_mode)
	preview = sim.snapshot()
	var screen = new_screen()
	backdrop(screen)
	var card = make_card(screen, Vector2(74, 62), Vector2(680, 624))
	var column = make_column(card, 10)
	var heading = HBoxContainer.new()
	column.add_child(heading)
	var title = make_label("Lobby", heading, 32, ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if multiplayer.is_server(): make_difficulty_select(heading)
	else: difficulty_label = make_label(effective_difficulty().capitalize() + " bots", heading, 18, TEAL)
	make_label({"coop": "3 vs bots", "versus": "Free-for-all", "teams": "Custom teams"}.get(selected_mode, ""), column, 18)
	if not room_code.is_empty():
		make_label("Online game", column, 18, TEAL)
		make_label("Others choose Find online game, then your name." if multiplayer.is_server() and publish_online_room else "Connected through the internet server.", column, 17)
	elif multiplayer.is_server():
		make_label("LAN address", column, 16, TEAL)
		var addresses = make_label(local_addresses(), column, 19)
		addresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if selected_mode == "teams":
		team_rows = make_column(column, 8)
		if multiplayer.is_server():
			var balance = CheckBox.new()
			balance.text = "Balance teams with bots"
			balance.button_pressed = balance_teams
			balance.add_theme_font_size_override("font_size", 18)
			column.add_child(balance)
			balance.toggled.connect(func(value: bool): balance_teams = value; broadcast_roster(); update_roster())
	else: roster_label = make_label("", column, 22)
	update_roster()
	lobby_note = make_label("Empty seats use bots. Join any time." if selected_mode != "teams" else "Choose sides. Up to 3 players per team.", column, 17)
	lobby_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if multiplayer.is_server(): make_button("Start", start_match, column, true)
	else: make_label("Waiting for host…", column, 19, TEAL)
	make_button("Leave", func(): close_session(), column)
	add_controls(screen)

func update_roster() -> void:
	if is_instance_valid(difficulty_label): difficulty_label.text = effective_difficulty().capitalize() + " bots"
	if selected_mode == "teams" and phase == "lobby":
		update_team_rows()
		return
	if not is_instance_valid(roster_label): return
	var lines = PackedStringArray()
	for id in range(1, 4): lines.append("%02d    %s%s" % [id, names.get(id, "BOT / OPEN SEAT"), "  ·  YOU" if id == local_seat else ""])
	roster_label.text = "\n\n".join(lines)

func build_team_setup() -> Dictionary:
	var humans: Array = seats.values().duplicate()
	humans.sort()
	var mapping: Dictionary = {}
	var counts = {0: 0, 1: 0}
	for index in range(humans.size()):
		var slot = int(humans[index])
		var default_side = 1 if index == humans.size() - 1 and humans.size() > 1 else 0
		var side = clampi(int(team_choices.get(slot, default_side)), 0, 1)
		mapping[slot] = side
		counts[side] += 1
	var bots = {0: 0, 1: 0}
	if balance_teams:
		var target = maxi(counts[0], counts[1])
		for side in [0, 1]: bots[side] = target - counts[side]
	return {"teams": mapping, "active_humans": humans, "bots": bots, "bot_difficulty": clean_difficulty(selected_difficulty)}

func update_team_rows() -> void:
	if not is_instance_valid(team_rows): return
	for child in team_rows.get_children():
		team_rows.remove_child(child)
		child.queue_free()
	var setup = build_team_setup() if multiplayer.is_server() else lobby_setup
	var mapping: Dictionary = setup.get("teams", {})
	var humans: Array = seats.values().duplicate()
	humans.sort()
	for slot in humans:
		var row = HBoxContainer.new()
		team_rows.add_child(row)
		var name_label = make_label(str(names.get(slot, "Player %d" % slot)) + (" (you)" if slot == local_seat else ""), row, 20)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var side = OptionButton.new()
		side.add_item("Blue", 0)
		side.add_item("Orange", 1)
		side.select(int(mapping.get(slot, 0)))
		side.custom_minimum_size = Vector2(180, 40)
		side.add_theme_font_size_override("font_size", 18)
		side.disabled = not multiplayer.is_server()
		row.add_child(side)
		side.item_selected.connect(func(index: int): team_choices[int(slot)] = index; broadcast_roster(); update_team_rows())
	var bots: Dictionary = setup.get("bots", {})
	make_label("Bots: %d blue  ·  %d orange" % [bots.get(0, 0), bots.get(1, 0)], team_rows, 17, Color("a9bfce"))

func peer_joined(peer: int) -> void:
	if _closing or not multiplayer_active() or not multiplayer.is_server(): return
	var slot = 0
	for id in range(1, 4):
		if not id in seats.values():
			slot = id
			break
	if slot == 0:
		multiplayer.multiplayer_peer.disconnect_peer(peer)
		return
	if selected_mode == "teams" and phase == "match":
		if not add_match_human(slot):
			multiplayer.multiplayer_peer.disconnect_peer(peer)
			return
	seats[peer] = slot
	sim.reset_bot(slot)
	if selected_mode == "teams" and phase == "match":
		sim.match_setup = build_team_setup()
	names[slot] = "PLAYER %d" % slot
	powers[slot] = POWER_IDS[(slot - 1) % POWER_IDS.size()]
	last_input[slot] = ui_clock
	welcome.rpc_id(peer, slot, selected_mode, phase == "match", match_id)
	broadcast_roster()
	update_roster()

func add_match_human(slot: int) -> bool:
	var counts = {0: 0, 1: 0}
	for human in seats.values():
		if sim.players.has(human): counts[sim.team(human)] += 1
	var side = 0 if counts[0] <= counts[1] else 1
	if sim.players.has(slot): side = sim.team(slot)
	if not sim.add_human(slot, side):
		side = 1 - side
		if not sim.add_human(slot, side): return false
	team_choices[slot] = side
	if balance_teams: sim.ensure_balanced_teams()
	return true

func multiplayer_active() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

@rpc("authority", "call_remote", "reliable", 0)
func welcome(slot: int, mode: String, playing: bool, round_id: String = "") -> void:
	if _closing: return
	local_seat = slot
	selected_mode = mode
	register_name.rpc_id(1, nickname)
	register_equipment.rpc_id(1, profile.outfit())
	register_power.rpc_id(1, selected_power)
	if playing: begin_match(mode, round_id)
	else: show_lobby()

@rpc("any_peer", "call_remote", "reliable", 0)
func register_name(value: String) -> void:
	if not multiplayer.is_server(): return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer): return
	var slot = int(seats[peer])
	names[slot] = clean_name(value, slot)
	broadcast_roster()
	update_roster()

@rpc("authority", "call_remote", "reliable", 0)
func roster(mapping: Dictionary, labels: Dictionary, outfits: Dictionary = {}, setup: Dictionary = {}) -> void:
	seats = mapping
	names = labels
	cosmetics = outfits
	lobby_setup = setup
	if not multiplayer.is_server(): sim.set_difficulty(clean_difficulty(str(setup.get("bot_difficulty", "easy"))))
	update_roster()

@rpc("any_peer", "call_remote", "reliable", 0)
func register_equipment(value: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer): return
	cosmetics[int(seats[peer])] = Profile.valid_equipment(value)
	broadcast_roster()

@rpc("any_peer", "call_remote", "reliable", 0)
func register_power(value: String) -> void:
	if not multiplayer.is_server(): return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer): return
	var slot = int(seats[peer])
	powers[slot] = clean_power(value)
	if phase == "match" and sim.players.has(slot): sim.players[slot].power = powers[slot]

func sync_equipment() -> void:
	cosmetics[local_seat] = profile.outfit()
	if multiplayer.is_server(): broadcast_roster()
	elif phase in ["lobby", "match"] and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: register_equipment.rpc_id(1, profile.outfit())

func connected_peers() -> Array:
	var peers: Array = []
	if multiplayer_active() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		for peer in multiplayer.get_peers():
			if not seats.has(peer): continue
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				var enet_peer = multiplayer.multiplayer_peer.get_peer(peer)
				if enet_peer == null or enet_peer.get_state() != ENetPacketPeer.STATE_CONNECTED: continue
			peers.append(peer)
	return peers

func broadcast_roster() -> void:
	if _closing or not multiplayer_active() or not multiplayer.is_server(): return
	for peer in connected_peers(): roster.rpc_id(peer, seats, names, cosmetics, build_team_setup())

func peer_left(peer: int) -> void:
	if not multiplayer_active() or not multiplayer.is_server() or not seats.has(peer): return
	var slot = int(seats[peer])
	seats.erase(peer)
	sim.reset_bot(slot)
	names.erase(slot)
	cosmetics.erase(slot)
	powers.erase(slot)
	last_input.erase(slot)
	remote_inputs.erase(slot)
	pending_snapshots.erase(peer)
	if sim.players.has(slot): sim.move_input(slot, Vector3.ZERO, Vector3.FORWARD)
	# A leave request removes the seat before any further snapshot is sent.
	broadcast_roster.call_deferred()
	update_roster()

func start_match() -> void:
	if _closing or not multiplayer_active() or not multiplayer.is_server(): return
	if selected_mode == "teams":
		var setup = build_team_setup()
		var counts = {0: int(setup.bots[0]), 1: int(setup.bots[1])}
		for side in setup.teams.values(): counts[int(side)] += 1
		if counts[0] < 1 or counts[1] < 1 or counts[0] > 3 or counts[1] > 3:
			if is_instance_valid(lobby_note): lobby_note.text = "Each team needs 1–3 players. Choose sides or enable bots."
			return
		for slot in setup.teams: team_choices[slot] = int(setup.teams[slot])
		setup.merge(match_options())
		sim.call("reset", selected_mode, setup)
	else: sim.reset(selected_mode, match_options())
	sim.set_difficulty(selected_difficulty)
	powers[local_seat] = clean_power(selected_power)
	for slot in seats.values():
		if sim.players.has(slot): sim.players[slot].power = clean_power(str(powers.get(slot, POWER_IDS[(int(slot) - 1) % POWER_IDS.size()])))
	_outcome_recorded = false
	_reward_seats.clear()
	_reward_peers.clear()
	match_id = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), randi()]
	remote_inputs.clear()
	last_input.clear()
	for id in seats.values(): last_input[id] = ui_clock
	for peer in connected_peers(): begin_match.rpc_id(peer, selected_mode, match_id)
	begin_match(selected_mode, match_id)

func runback_series() -> void:
	if not multiplayer.is_server() or phase != "match" or int(state.get("winner", -1)) < 0 or selected_mode == "versus": return
	if not rivalry.active:
		rivalry.active = true
		rivalry.record(match_id, int(state.winner))
	elif rivalry.finished():
		rivalry.clear()
		rivalry.active = true
	start_match()

func single_rematch() -> void:
	rivalry.clear()
	start_match()

func choose_next_power(index: int) -> void:
	if index < 0 or index >= POWER_IDS.size() or int(state.get("winner", -1)) < 0: return
	selected_power = POWER_IDS[index]
	if multiplayer.is_server():
		powers[local_seat] = selected_power
		save_settings()
	else:
		var status = result_panel.find_child("NextPowerStatus", true, false) as Label
		if is_instance_valid(status): status.text = "Sending power choice to host…"
		register_next_power.rpc_id(1, selected_power, match_id)

@rpc("any_peer", "call_remote", "reliable", 0)
func register_next_power(value: String, round_id: String) -> void:
	if not multiplayer.is_server(): return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer): return
	var slot = int(seats[peer])
	var accepted = phase == "match" and sim.winner >= 0 and round_id == match_id
	if accepted: powers[slot] = clean_power(value)
	next_power_confirmed.rpc_id(peer, value, str(powers.get(slot, "giant")), accepted)

@rpc("authority", "call_remote", "reliable", 0)
func next_power_confirmed(requested: String, confirmed: String, accepted: bool) -> void:
	# A delayed answer to an older selection must not overwrite the newest choice.
	if selected_power != requested: return
	selected_power = clean_power(confirmed)
	save_settings()
	if not is_instance_valid(result_panel): return
	var choice = result_panel.find_child("NextPower", true, false) as OptionButton
	if is_instance_valid(choice): choice.select(POWER_IDS.find(selected_power))
	var status = result_panel.find_child("NextPowerStatus", true, false) as Label
	if is_instance_valid(status): status.text = "Power confirmed for next round." if accepted else "Host already started. Keeping " + POWER_NAMES[POWER_IDS.find(selected_power)] + "."

func series_text() -> String:
	var series: Dictionary = state.get("series", {})
	if not series.get("active", false): return "Run it back: first team to two match wins."
	var wins: Dictionary = series.get("wins", {})
	var sides = ["Your team", "Bots"] if selected_mode == "coop" else ["Blue", "Orange"]
	var tally = "%s %d : %d %s" % [sides[0], wins.get(0, 0), wins.get(1, 0), sides[1]]
	if series.get("finished", false): return "SERIES WON  ·  " + tally
	return "BEST OF 3  ·  " + tally

@rpc("authority", "call_remote", "reliable", 0)
func begin_match(mode: String, round_id: String = "") -> void:
	selected_mode = mode
	match_id = round_id
	phase = "match"
	paused = false
	_winner_shown = false
	_final_banner_shown = false
	_last_banner_event = -1
	_cinematic_score_at = -10.0
	slowmo_until = -1.0
	hitstop_until = -1.0
	_earned_reward_round = ""
	_camera_spawn_pending = true
	state = sim.snapshot() if multiplayer.is_server() else {}
	if not state.is_empty():
		state["match_id"] = match_id
		state["cosmetics"] = cosmetics.duplicate(true)
	world.build(mode)
	yaw = 0.0
	pitch = 0.43
	ball_camera = false
	visual_jump_started = -1.0
	local_render_clock = -1.0
	visual_y_correction = 0.0
	local_direction = Vector3.ZERO
	last_aim = Vector3.FORWARD
	snapshot_received_at = ui_clock
	charging = false
	charge_time = 0.0
	shoot_previous = false
	input_armed = false
	last_event = -1
	snapshot_count = 0
	snapshot_serial = 0
	snapshot_received_sequence = -1
	pending_snapshots.clear()
	snapshot_transport = {"unreliable":0,"reliable":0,"coalesced":0,"stale":0,"max_unreliable_bytes":0,"max_reliable_bytes":0}
	build_hud()
	if manual_input_enabled: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func close_session(message: String = "") -> void:
	if _closing: return
	rivalry.clear()
	_closing = true
	pending_snapshots.clear()
	charging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if multiplayer_active() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		if multiplayer.is_server():
			for peer in connected_peers(): session_ended.rpc_id(peer)
			await get_tree().create_timer(0.12).timeout
		elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			request_leave.rpc_id(1)
			await get_tree().create_timer(0.18).timeout
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	room_code = ""
	room_host_pending = false
	state.clear()
	seats = {1: 1}
	names = {1: clean_name(nickname, 1)}
	cosmetics = {1: profile.outfit()}
	local_seat = 1
	status_message = message
	_closing = false
	show_menu()

@rpc("authority", "call_remote", "reliable", 0)
func session_ended() -> void:
	close_session("The host closed the court. Start practice or host a new game.")

@rpc("any_peer", "call_remote", "reliable", 0)
func request_leave() -> void:
	if multiplayer.is_server(): peer_left(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func receive_move(direction: Vector3, aim: Vector3, round_id: String = "") -> void:
	if not multiplayer.is_server() or phase != "match" or round_id != match_id or not direction.is_finite() or not aim.is_finite(): return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer): return
	var slot = int(seats[peer])
	sim.move_input(slot, direction.limit_length(1), aim.limit_length(1))
	last_input[slot] = ui_clock
	remote_inputs[slot] = int(remote_inputs.get(slot, 0)) + 1

@rpc("any_peer", "call_remote", "reliable", 3)
func receive_action(command: String, charge: float, aim: Vector3, movement: Vector3 = Vector3.ZERO, round_id: String = "") -> void:
	if not multiplayer.is_server() or phase != "match" or round_id != match_id or not is_finite(charge) or not aim.is_finite() or not movement.is_finite() or not command in ACTIONS: return
	var peer = multiplayer.get_remote_sender_id()
	if seats.has(peer): host_action(int(seats[peer]), command, charge, aim, movement)

func submit_move(direction: Vector3, aim: Vector3) -> void:
	if phase != "match" or _closing or not multiplayer_active() or not direction.is_finite() or not aim.is_finite(): return
	local_direction = direction.limit_length(1)
	var horizontal = Vector3(aim.x, 0, aim.z)
	if horizontal.length() > 0.01: last_aim = horizontal.normalized()
	if multiplayer.is_server(): sim.move_input(local_seat, direction.limit_length(1), aim.limit_length(1))
	elif local_seat > 0 and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: receive_move.rpc_id(1, direction, aim, match_id)

func submit_action(command: String, charge: float = 0.5) -> void:
	if phase != "match" or _closing or not multiplayer_active() or not is_finite(charge) or not command in ACTIONS: return
	if command == "hype" and state.get("players", {}).has(local_seat) and float(state.players[local_seat].get("hype", 0)) < 100:
		_hype_notice = "Not ready"
		_hype_notice_until = ui_clock + 1.1
	# A catch press must not become a pass because an unseen packet granted possession.
	if command == "catch_pass": command = "pass" if owns_ball() else "catch"
	if command == "jump" and not multiplayer.is_server() and not state.is_empty() and state.players.has(local_seat):
		var p: Dictionary = state.players[local_seat]
		begin_jump_prediction(p)
	var action_aim = shot_direction() if command == "throw" else flat_control_aim()
	if multiplayer.is_server(): host_action(local_seat, command, charge, action_aim, local_direction)
	elif local_seat > 0 and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: receive_action.rpc_id(1, command, charge, action_aim, local_direction, match_id)

func begin_jump_prediction(player: Dictionary) -> void:
	if float(player.stun) > 0 or float(player.dunk) > 0 or float(state.get("reset_time", 0)) > 0: return
	var count = int(player.jump_count)
	var rising_speed = float(player.vel.y)
	if visual_jump_started >= 0 and ui_clock - visual_jump_started < .16:
		count = maxi(count, visual_jump_count)
		rising_speed = maxf(rising_speed, visual_jump_speed - Sim.PLAYER_GRAVITY * (ui_clock - visual_jump_started))
	if count >= 2: return
	visual_jump_origin = local_render_y if local_render_clock >= 0 else float(player.pos.y)
	visual_jump_speed = Sim.JUMP_SPEED if count == 0 else maxf(Sim.DOUBLE_JUMP_SPEED, rising_speed + 2.2)
	visual_jump_count = count + 1
	visual_jump_started = ui_clock
	visual_y_correction = 0.0

func local_visual_height(player: Dictionary, authoritative_y: float) -> float:
	var dt = clampf(ui_clock - local_render_clock, 0.0, .05) if local_render_clock >= 0 else 0.0
	var desired = authoritative_y
	var velocity_y = float(player.vel.y)
	if visual_jump_started >= 0:
		var elapsed = ui_clock - visual_jump_started
		if elapsed <= .16 and int(player.jump_count) < visual_jump_count and float(player.stun) <= 0 and float(player.dunk) <= 0:
			desired = visual_jump_origin + visual_jump_speed * elapsed - .5 * Sim.PLAYER_GRAVITY * elapsed * elapsed
			velocity_y = visual_jump_speed - Sim.PLAYER_GRAVITY * elapsed
		else:
			# Blend the small packet correction instead of snapping at acknowledgement.
			if local_render_clock >= 0: visual_y_correction = clampf(local_render_y + local_render_velocity_y * dt - desired, -1.2, 1.2)
			visual_jump_started = -1.0
	if absf(desired - local_render_y) > 6.0 or (float(state.get("reset_time", 0)) > 0 and float(state.get("celebration_time", 0)) <= 0): visual_y_correction = 0.0
	visual_y_correction *= exp(-24.0 * dt)
	local_render_y = desired + visual_y_correction
	local_render_velocity_y = velocity_y
	local_render_clock = ui_clock
	return local_render_y

func host_action(slot: int, command: String, charge: float, aim: Vector3 = Vector3.ZERO, movement: Vector3 = Vector3.INF) -> void:
	if not sim.players.has(slot) or not aim.is_finite(): return
	# The reliable action carries its press-time direction as well as aim.
	var direction: Vector3 = movement.limit_length(1) if movement.is_finite() else sim.players[slot].move
	sim.move_input(slot, direction, aim)
	if command == "throw": sim.set_shot_aim(slot, aim)
	if command == "catch_pass":
		sim.action(slot, "pass" if int(sim.ball.owner) == slot else "catch")
	elif command == "interact":
		if int(sim.ball.owner) == slot: return
		sim.action(slot, "grab")
		if int(sim.ball.owner) != slot: sim.action(slot, "tackle")
	else: sim.action(slot, command, clampf(charge, 0.0, 1.75))

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_state(packet: PackedByteArray) -> void:
	accept_snapshot(packet)

@rpc("authority", "call_remote", "reliable", 4)
func receive_large_state(packet: PackedByteArray) -> void:
	if _closing: return
	var unpacked = decode_snapshot(packet)
	if unpacked.is_empty(): return
	var sequence = int(unpacked._snapshot_seq)
	var round_id = str(unpacked.match_id)
	apply_snapshot(unpacked)
	# ACK delivery even when channel 4 overtakes begin_match on channel 0.
	# The sender validates this exact packet identity against its pending slot.
	if multiplayer_active() and not multiplayer.is_server():
		acknowledge_snapshot.rpc_id(1, round_id, sequence)

func accept_snapshot(packet: PackedByteArray) -> int:
	return apply_snapshot(decode_snapshot(packet))

func decode_snapshot(packet: PackedByteArray) -> Dictionary:
	if packet.size() > MAX_SNAPSHOT_BYTES: return {}
	var unpacked = bytes_to_var(packet.decompress_dynamic(131072, FileAccess.COMPRESSION_DEFLATE))
	if not unpacked is Dictionary or not unpacked.has("players") or not unpacked.has("ball") or not unpacked.has("match_id"): return {}
	if not unpacked.has("_snapshot_seq") or typeof(unpacked._snapshot_seq) != TYPE_INT or int(unpacked._snapshot_seq)<0: return {}
	return unpacked

func apply_snapshot(unpacked: Dictionary) -> int:
	if phase != "match" or _closing or unpacked.is_empty() or str(unpacked.match_id) != match_id: return -1
	var sequence = int(unpacked._snapshot_seq)
	if sequence <= snapshot_received_sequence:
		snapshot_transport.stale += 1
		return sequence
	snapshot_received_sequence = sequence
	unpacked.erase("_snapshot_seq")
	state = unpacked
	snapshot_received_at = ui_clock
	cosmetics = state.get("cosmetics", {})
	snapshot_count += 1
	return sequence

@rpc("any_peer", "call_remote", "reliable", 4)
func acknowledge_snapshot(round_id: String, sequence: int) -> void:
	if _closing or not multiplayer_active() or not multiplayer.is_server() or round_id != match_id: return
	var peer = multiplayer.get_remote_sender_id()
	if not seats.has(peer) or not pending_snapshots.has(peer): return
	var pending: Dictionary = pending_snapshots[peer]
	if str(pending.round_id) == round_id and sequence in pending.sequences:
		pending.sequences.erase(sequence)
		if pending.sequences.is_empty(): pending_snapshots.erase(peer)

func encode_snapshot() -> PackedByteArray:
	snapshot_serial += 1
	var wire = state.duplicate(false)
	wire["_snapshot_seq"] = snapshot_serial
	return var_to_bytes(wire).compress(FileAccess.COMPRESSION_DEFLATE)

func send_snapshot(peer: int, packet: PackedByteArray) -> void:
	if _closing or not seats.has(peer) or packet.size() > MAX_SNAPSHOT_BYTES: return
	if packet.size() <= UNRELIABLE_SNAPSHOT_BYTES:
		snapshot_transport.unreliable += 1
		snapshot_transport.max_unreliable_bytes = maxi(snapshot_transport.max_unreliable_bytes,packet.size())
		receive_state.rpc_id(peer, packet)
	else:
		# A bounded flight window sustains updates over an internet RTT. There is
		# no unsent backlog: when full, discard this sample and retry fresh state.
		var pending: Dictionary = pending_snapshots.get(peer, {"round_id":match_id,"sequences":[]})
		if snapshot_serial in pending.sequences: return
		if pending.sequences.size() >= MAX_PENDING_SNAPSHOTS:
			snapshot_transport.coalesced += 1
			return
		pending.sequences.append(snapshot_serial)
		pending_snapshots[peer] = pending
		snapshot_transport.reliable += 1
		snapshot_transport.max_reliable_bytes = maxi(snapshot_transport.max_reliable_bytes,packet.size())
		receive_large_state.rpc_id(peer, packet)

func _physics_process(dt: float) -> void:
	if phase != "match" or _closing or not multiplayer_active(): return
	if manual_input_enabled and not paused and not _winner_shown: read_controls(dt)
	if multiplayer.is_server():
		if paused and multiplayer.multiplayer_peer is OfflineMultiplayerPeer: return
		for id in sim.players:
			if not id in seats.values():
				var command: Dictionary = sim.bot_command(id)
				sim.move_input(id, command.get("move", Vector3.ZERO), command.get("aim", Vector3.FORWARD))
				if not str(command.get("action", "")).is_empty(): sim.action(id, command.action, float(command.get("charge", 0.5)))
			elif id != local_seat and ui_clock - float(last_input.get(id, ui_clock)) > 0.35:
				sim.move_input(id, Vector3.ZERO, Vector3.FORWARD)
		sim.step(dt)
		if sim.winner >= 0 and not _outcome_recorded:
			_outcome_recorded = true
			rivalry.record(match_id, sim.winner)
			_reward_seats = seats.values().duplicate()
			_reward_peers = seats.keys().duplicate()
		state = sim.snapshot()
		state["match_id"] = match_id
		state["series"] = rivalry.snapshot()
		state["cosmetics"] = cosmetics.duplicate(true)
		state["reward_seats"] = _reward_seats.duplicate()
		state["reward_peers"] = _reward_peers.duplicate()
		net_clock += dt
		if net_clock >= 0.05 and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			net_clock = 0.0
			var packet = encode_snapshot()
			for peer in connected_peers(): send_snapshot(peer, packet)

func controls_released() -> bool:
	for action in ["throw_ball", "controller_shoot", "jump", "grab", "tackle", "dunk", "pass_ball", "catch_pass", "request_pass", "hype"]:
		if Input.is_action_pressed(action): return false
	return controller_neutral

func read_controls(dt: float) -> void:
	if not state.is_empty() and float(state.get("reset_time", 0)) > 0:
		charging = false
		charge_time = 0.0
		input_armed = false
		submit_move(Vector3.ZERO, camera_forward())
		return
	if not input_armed:
		input_armed = controls_released()
		shoot_previous = false
		submit_move(Vector3.ZERO, camera_forward())
		return
	# A charge belongs to one possession. Keep shoot_previous until release so
	# a held button cannot resume that old shot if the ball is caught again.
	var possession = float(state.players[local_seat].get("possession_since",-1.0)) if owns_ball() else -1.0
	if charging and (not owns_ball() or possession != charge_possession):
		charging = false
		charge_time = 0.0
	var stick = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if controller_device >= 0:
		var left = controller_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, 0.2)
		if left.length_squared() > 0: stick = left
		var right = controller_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, 0.16)
		if right.length_squared() > 0:
			ball_camera = false
			yaw -= right.x * dt * 2.7
			pitch = clampf(pitch + right.y * dt * 1.4, 0.15, 0.9)
	var direction = Vector3(cos(yaw), 0, -sin(yaw)) * stick.x - camera_forward() * stick.y
	submit_move(direction, camera_forward())
	for action in ["jump", "grab", "tackle", "dunk", "catch_pass", "request_pass", "hype"]:
		if Input.is_action_just_pressed(action): submit_action("catch" if action == "grab" else action)
	if Input.is_action_just_pressed("pass_ball"): submit_action("pass")
	if Input.is_action_just_pressed("ball_camera"): ball_camera = not ball_camera
	if Input.is_action_just_pressed("recenter"): recenter()
	var pressed = Input.is_action_pressed("throw_ball") or Input.is_action_pressed("controller_shoot")
	if not shoot_previous and (pressed or Input.is_action_just_pressed("throw_ball") or Input.is_action_just_pressed("controller_shoot")):
		charge_time = 0.0
		if owns_ball():
			charging = true
			charge_possession = possession
		else:
			submit_action("tackle")
			charging = false
	if charging and pressed: charge_time = minf(charge_time + dt, 2.0)
	if charging and not pressed and (Input.is_action_just_released("throw_ball") or Input.is_action_just_released("controller_shoot") or shoot_previous):
		if owns_ball(): submit_action("throw", clampf(charge_time / 1.15, 0.0, 1.75))
		charging = false
	shoot_previous = pressed

func camera_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func flat_control_aim() -> Vector3:
	return camera_forward() if manual_input_enabled else Vector3(last_aim.x, 0, last_aim.z).normalized()

func shot_direction() -> Vector3:
	# Looking higher raises the launch loft. No basket or target enters this aim.
	if manual_input_enabled:
		var elevation = clampf(deg_to_rad(48.0) - (pitch - 0.43), deg_to_rad(-15.0), deg_to_rad(80.0))
		return camera_forward() * cos(elevation) + Vector3.UP * sin(elevation)
	# Legacy scripted input uses flat last_aim; explicit 3D input is literal.
	if last_aim.is_finite() and last_aim.length_squared() > 0.0001 and absf(last_aim.y) > 0.0001: return last_aim.normalized()
	var horizontal = Vector3(last_aim.x, 0, last_aim.z).normalized() if last_aim.is_finite() else Vector3.ZERO
	if horizontal.length_squared() < 0.0001: horizontal = Vector3.FORWARD
	return horizontal * cos(deg_to_rad(48.0)) + Vector3.UP * sin(deg_to_rad(48.0))

func owns_ball() -> bool:
	return not state.is_empty() and int(state.ball.owner) == local_seat

func can_dunk() -> bool:
	if not prepare_aim_sim(): return false
	return aim_sim.can_dunk(local_seat)

func prepare_aim_sim() -> bool:
	if state.is_empty() or not state.players.has(local_seat): return false
	# Aim changes immediately with input; snapshots can be a frame or packet behind.
	aim_sim.players = state.players.duplicate(false)
	aim_sim.players[local_seat] = state.players[local_seat].duplicate(false)
	aim_sim.players[local_seat].aim = flat_control_aim()
	aim_sim.set_shot_aim(local_seat, shot_direction())
	aim_sim.ball = state.ball
	aim_sim.mode = selected_mode
	aim_sim.winner = int(state.get("winner", -1))
	aim_sim.reset_time = float(state.get("reset_time", 0))
	aim_sim.shot_assist = bool(state.get("shot_assist", true))
	return true

func pass_target_preview() -> int:
	if selected_mode == "versus" or not owns_ball() or not prepare_aim_sim(): return 0
	return aim_sim.pass_target(local_seat)

func recenter() -> void:
	if state.is_empty() or not state.players.has(local_seat): return
	var target: Vector3 = attack_hoop() if owns_ball() else state.ball.pos
	var direction: Vector3 = target - state.players[local_seat].pos
	if Vector2(direction.x, direction.z).length() > 0.1: yaw = atan2(-direction.x, -direction.z)
	pitch = 0.43

func _input(event: InputEvent) -> void:
	if _closing: return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if controller_rebinding or event.device != controller_device:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			if event.axis_value >= 0.55 and not controller_trigger:
				controller_trigger = true
				Input.action_press("controller_shoot")
			elif event.axis_value <= 0.35 and controller_trigger:
				controller_trigger = false
				Input.action_release("controller_shoot")
		if not controller_neutral:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and phase == "match" and not _winner_shown:
			set_paused(not paused)
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(controller_menu_root()):
			update_controller_focus()
			if event is InputEventJoypadButton and event.pressed:
				if event.button_index == JOY_BUTTON_B:
					controller_back()
					get_viewport().set_input_as_handled()
					return
				var focused = get_viewport().gui_get_focus_owner()
				if event.button_index == JOY_BUTTON_A and focused is LineEdit and not is_instance_valid(controller_keyboard):
					open_controller_keyboard(focused)
					get_viewport().set_input_as_handled()
					return
			if event is InputEventJoypadMotion:
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ESCAPE, KEY_F1] and phase == "match" and not _winner_shown:
			set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M and not (get_viewport().gui_get_focus_owner() is LineEdit): toggle_mute()
	if event is InputEventMouseMotion and phase == "match" and not paused and manual_input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movement: Vector2 = event.screen_relative if event.screen_relative.length_squared() > 0 else event.relative
		if movement.length_squared() > 0.25: ball_camera = false
		yaw -= movement.x * 0.0032
		pitch = clampf(pitch + movement.y * 0.0028, 0.15, 0.9)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "match" and manual_input_enabled and not _winner_shown: set_paused(true)

func toggle_mute() -> void:
	muted = not muted
	save_settings()
	if is_instance_valid(audio_label): audio_label.text = "M  SOUND " + ("OFF" if muted else "ON")

func set_paused(value: bool) -> void:
	if phase != "match" or _closing: return
	paused = value
	charging = false
	charge_time = 0.0
	input_armed = false
	submit_move(Vector3.ZERO, camera_forward())
	if is_instance_valid(pause_panel): pause_panel.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or not manual_input_enabled else Input.MOUSE_MODE_CAPTURED

func build_hud() -> void:
	var screen = new_screen()
	_hype_amount = -1.0
	_hype_power = ""
	_hype_notice = ""
	_hype_notice_until = 0.0
	_hud_scores.clear()
	_hud_announcement = ""
	_hud_announcement_until = 0.0
	_hud_countdown = -1
	_hud_remaining = -1
	_hud_score_at = -10.0
	_hud_owner = -1
	_sound_event_id = -1
	_sound_event_clock = -1.0
	_sound_round = ""
	_hud_grounded = true
	goal_flash = ColorRect.new()
	goal_flash.color = Color(1, 0.7, 0.25, 0)
	goal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(goal_flash)
	var top = make_card(screen, Vector2(345, 20), Vector2(470, 58), Color(0.03, 0.07, 0.13, 0.91))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_style = top.get_theme_stylebox("panel") as StyleBoxFlat
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	var column = make_column(top, 4)
	var row = HBoxContainer.new()
	column.add_child(row)
	score_label = make_label("0  :  0", row, 21 if selected_mode == "versus" else 27)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var timer_card = make_card(screen, Vector2(823, 20), Vector2(112, 58), Color(0.03, 0.07, 0.13, 0.91))
	clock_label = make_label("5:00", timer_card, 27, PAPER)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule_label = make_label("", screen, 16, PAPER)
	rule_label.position = Vector2(345, 86)
	rule_label.size.x = 590
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(rule_label, 5)
	possession_label = make_label("Loose ball", screen, 19, TEAL)
	possession_label.position = Vector2(30, 680)
	outline(possession_label, 5)
	target_label = make_label("Orange hoop", screen, 16, PAPER)
	target_label.position = Vector2(30, 711)
	outline(target_label, 5)
	jump_label = make_label("", screen, 18, PAPER)
	jump_label.position = Vector2(30, 648)
	outline(jump_label, 5)
	audio_label = make_label("M  SOUND " + ("OFF" if muted else "ON"), screen, 16, Color("d2dde6"))
	audio_label.position = Vector2(1060, 136)
	audio_label.visible = false
	var crosshair = make_label("+", screen, 24, Color(1, 1, 1, 0.6))
	crosshair.position = Vector2(632, 384)
	outline(crosshair, 3)
	ball_marker = make_label("◆", screen, 22, PAPER)
	outline(ball_marker, 5)
	ball_marker.visible = false
	prompt_back = Panel.new()
	prompt_back.position = Vector2(244, 655)
	prompt_back.size = Vector2(792, 44)
	prompt_back.add_theme_stylebox_override("panel", box_style(Color(0.025, 0.055, 0.105, 0.8), Color.TRANSPARENT, 14))
	prompt_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(prompt_back)
	prompt_label = make_label("", screen, 21, PAPER)
	prompt_label.position = Vector2(260, 662)
	prompt_label.size = Vector2(760, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	outline(prompt_label, 4)
	charge_label = make_label("", screen, 17, ORANGE)
	charge_label.position = Vector2(440, 592)
	charge_label.size.x = 400
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(charge_label, 4)
	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(485, 624)
	charge_bar.size = Vector2(310, 13)
	charge_bar.show_percentage = false
	charge_bar.max_value = 1.75
	charge_bar.add_theme_stylebox_override("background", box_style(Color(0.03, 0.07, 0.13, 0.8), Color.TRANSPARENT, 5))
	charge_bar.add_theme_stylebox_override("fill", box_style(ORANGE, Color.TRANSPARENT, 5))
	charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(charge_bar)
	charge_marker = ColorRect.new()
	charge_marker.color = PAPER
	charge_marker.size = Vector2(4, 21)
	charge_marker.position = Vector2(485, 620)
	charge_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_marker.visible = false
	screen.add_child(charge_marker)
	banner_label = make_label("", screen, 66, ORANGE)
	banner_label.position = Vector2(90, 100)
	banner_label.size.x = 1100
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.pivot_offset = Vector2(550, 40)
	outline(banner_label, 12)
	banner_label.visible = false
	intro_card = build_intro_card(screen)
	hype_ring = HypeIndicator.new()
	hype_ring.position = Vector2(1105, 588)
	screen.add_child(hype_ring)
	event_label = make_label("", screen, 44, PAPER)
	event_label.position = Vector2(120, 110)
	event_label.size.x = 1040
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(event_label, 9)
	hud_help = add_controls(screen)
	hud_help_until = ui_clock + 8.0
	controls_hint = make_label("F1 Controls", screen, 16, Color("d2dde6"))
	controls_hint.position = Vector2(28, 750)
	outline(controls_hint, 5)
	pause_panel = build_overlay(screen, false)
	result_panel = build_overlay(screen, true)

func build_intro_card(parent: Node) -> Control:
	# Pre-match team card shown over the arena fly-over. Filled from the first
	# snapshot so late-joining peers read the same roster as the host.
	var card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	var band = ColorRect.new()
	band.color = Color(0.03, 0.07, 0.13, 0.72)
	band.position = Vector2(0, 250)
	band.size = Vector2(1280, 300)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	for stripe in [[Vector2(0, 250), Color("20a9df")], [Vector2(0, 544), Color("f79b35")]]:
		var line = ColorRect.new()
		line.color = stripe[1]
		line.position = stripe[0]
		line.size = Vector2(1280, 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(line)
	var left = make_label("", card, 30, Color("7fd4f5"))
	left.name = "Left"
	left.position = Vector2(60, 285)
	left.size = Vector2(480, 240)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(left, 6)
	var versus = make_label("VS", card, 88, PAPER)
	versus.name = "Versus"
	versus.position = Vector2(540, 330)
	versus.size = Vector2(200, 120)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(versus, 12)
	var right = make_label("", card, 30, Color("ffc98a"))
	right.name = "Right"
	right.position = Vector2(740, 285)
	right.size = Vector2(480, 240)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(right, 6)
	var title = make_label("", card, 24, PAPER)
	title.name = "Title"
	title.position = Vector2(0, 262)
	title.size = Vector2(1280, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outline(title, 5)
	card.visible = false
	return card

func fill_intro_card() -> void:
	if not is_instance_valid(intro_card) or state.is_empty(): return
	var labels = display_names()
	var sides = {0: PackedStringArray(), 1: PackedStringArray()}
	var all = PackedStringArray()
	for id in state.players:
		var tag = str(labels.get(id, "Bot %d" % int(id))).substr(0, 14)
		all.append(tag)
		var side = int(state.players[id].get("team", 0 if int(id) <= 3 else 1))
		if sides.has(side): sides[side].append(tag)
	var left = intro_card.find_child("Left", true, false) as Label
	var right = intro_card.find_child("Right", true, false) as Label
	var versus = intro_card.find_child("Versus", true, false) as Label
	var title = intro_card.find_child("Title", true, false) as Label
	if selected_mode == "versus":
		left.text = "\n".join(all)
		right.text = ""
		versus.text = ""
		left.position.x = 0
		left.size.x = 1280
		title.text = "FREE-FOR-ALL  ·  FIRST TO 7"
	else:
		left.position.x = 60
		left.size.x = 480
		left.text = ("BLUE" if selected_mode == "teams" else "YOUR TEAM") + "\n" + "\n".join(sides[0])
		right.text = ("ORANGE" if selected_mode == "teams" else "BOTS") + "\n" + "\n".join(sides[1])
		versus.text = "VS"
		title.text = "5 MINUTES  ·  WIN BY 4  ·  " + effective_difficulty().to_upper() + " BOTS"

func stats_summary() -> Dictionary:
	# Per-player line score for the final card plus a simple MVP pick.
	var rows: Array = []
	var labels = display_names()
	for id in state.players:
		var stats: Dictionary = state.players[id].get("stats", {})
		if stats.is_empty(): continue
		rows.append({"id": int(id), "name": str(labels.get(id, "Bot %d" % int(id))).substr(0, 12), "team": int(state.players[id].get("team", 0)),
			"points": int(stats.get("points", 0)), "assists": int(stats.get("assists", 0)), "steals": int(stats.get("steals", 0)), "hits": int(stats.get("tackles", 0)),
			"score": int(stats.get("points", 0)) * 3 + int(stats.get("assists", 0)) * 2 + int(stats.get("steals", 0)) + int(stats.get("tackles", 0)) * .25})
	rows.sort_custom(func(a, b): return a.score > b.score or (a.score == b.score and a.id < b.id))
	var mvp = rows[0] if not rows.is_empty() and float(rows[0].score) > 0 else {}
	var lines = PackedStringArray()
	for row in rows:
		lines.append("%s  ·  %d pts  ·  %d ast  ·  %d steals  ·  %d hits" % [row.name, row.points, row.assists, row.steals, row.hits])
	return {"rows": rows, "mvp": mvp, "text": "\n".join(lines)}

func build_overlay(parent: Node, result: bool) -> Control:
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	backdrop(overlay)
	var card = make_card(overlay, Vector2(280, 85) if result else Vector2(310, 205), Vector2(720, 640) if result else Vector2(660, 390))
	var column = make_column(card, 13 if not result else 9)
	var heading = make_label("Match over" if result else "Paused", column, 30, ORANGE)
	heading.name = "Heading"
	var note = make_label("" if result else "Move: WASD / left stick    Look: mouse / right stick\nJump twice: Space / A    Catch or pass: left click / X\nBlock dunks: jump toward the dunker, then tackle\nTackle or shoot: right click / RT (hold to charge)\nCatch: E    Tackle: Shift    Dunk: F / B\nHype: Q / Y    Request pass: middle click / RB\nBall camera: Ctrl / LB (look to release)\nRecenter: R / right stick press    Sound: M" + ("\nNetwork match continues while paused." if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer else ""), column, 18)
	note.name = "Note"
	if not result: note.set_meta("controller_text", note.text)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if result:
		var mvp = make_label("", column, 22, TEAL)
		mvp.name = "Mvp"
		var stats = make_label("", column, 16, Color("d2dde6"))
		stats.name = "Stats"
		stats.add_theme_font_override("font", ThemeDB.fallback_font)
		var series_note = make_label("", column, 19, TEAL)
		series_note.name = "Series"
		var options = HBoxContainer.new()
		column.add_child(options)
		var next_power = OptionButton.new()
		next_power.name = "NextPower"
		for power_name in POWER_NAMES: next_power.add_item("Next round: " + power_name)
		next_power.select(POWER_IDS.find(clean_power(selected_power)))
		next_power.custom_minimum_size.y = 40
		next_power.add_theme_font_size_override("font_size", 18)
		next_power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(next_power)
		if multiplayer.is_server(): make_difficulty_select(options)
		var power_tip = make_label("", column, 15, Color("d2dde6"))
		power_tip.name = "NextPowerStatus"
		var tips = ["Giant: break through pressure and sweepers.", "Jump pad: open an aerial route for either team.", "Homing ball: disrupt the nearest opponent."]
		power_tip.text = tips[next_power.selected]
		next_power.item_selected.connect(func(index): power_tip.text = tips[index])
		next_power.item_selected.connect(choose_next_power)
		if multiplayer.is_server():
			var play_row = HBoxContainer.new()
			column.add_child(play_row)
			if selected_mode != "versus":
				var series_button = make_button("Run it back · best of 3", runback_series, play_row, true)
				series_button.name = "SeriesButton"
			make_button("Rematch", single_rematch, play_row, selected_mode == "versus")
		else: make_label("Waiting for host…", column, 18, TEAL)
		result_bag_button = make_button("Open bag", func(): open_bag(), column)
		result_bag_button.visible = false
	else: make_button("Resume", func(): set_paused(false), column, true)
	make_button("Leave", func(): close_session(), column)
	overlay.visible = false
	return overlay

func update_time_scale() -> void:
	# Never let a local cinematic change authority, charge timing or packet cadence.
	Engine.time_scale = 1.0
	presentation_time_scale = 1.0
	if not cinematics_enabled or not presentation_enabled or phase != "match" or paused or _closing or state.is_empty():
		return
	var now = Time.get_ticks_msec() / 1000.0
	var scale = 1.0
	if now < hitstop_until: scale = .12
	elif now < slowmo_until:
		var remaining = slowmo_until - now
		scale = lerpf(slowmo_scale, 1.0, 1.0 - clampf(remaining / .25, 0.0, 1.0))
	presentation_time_scale = scale

func start_slowmo(duration: float, scale: float = .35) -> void:
	if not cinematics_enabled or not presentation_enabled: return
	slowmo_scale = scale
	slowmo_until = Time.get_ticks_msec() / 1000.0 + duration

func start_hitstop(duration: float = .09) -> void:
	if not cinematics_enabled or not presentation_enabled: return
	hitstop_until = Time.get_ticks_msec() / 1000.0 + duration

func _process(dt: float) -> void:
	update_time_scale()
	ui_clock += dt
	event_age += dt
	update_controller_labels()
	if not controller_neutral and controller_at_rest(): controller_neutral = true
	if controller_device >= 0:
		update_controller_focus()
		if is_instance_valid(controller_menu_root()):
			var stick = controller_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, 0.45)
			var navigation = Vector2.ZERO
			if stick.length() > 0.15:
				navigation = Vector2(signf(stick.x), 0) if absf(stick.x) > absf(stick.y) else Vector2(0, signf(stick.y))
			if navigation != controller_nav_direction:
				controller_nav_direction = navigation
				controller_nav_repeat = 0.35
				if navigation != Vector2.ZERO: controller_navigate(navigation)
			elif navigation != Vector2.ZERO:
				controller_nav_repeat -= dt
				if controller_nav_repeat <= 0:
					controller_navigate(navigation)
					controller_nav_repeat = 0.12
	if not pending_rewards.is_empty() and ui_clock - last_reward_attempt >= 1.0: retry_pending_rewards()
	if _closing: return
	if phase == "match" and not multiplayer_active():
		close_session("The host closed the court. Start practice or host a new game.")
		return
	if phase == "connecting" and ui_clock - connect_time > 12.0 and not _closing:
		close_session("No answer. Check the room code or LAN address, and keep the host open.")
	if phase == "match" and not state.is_empty():
		if _camera_spawn_pending and state.players.has(local_seat):
			yaw = PI if selected_mode != "versus" and int(state.players[local_seat].get("team", 0)) == 1 else 0.0
			_camera_spawn_pending = false
		if ball_camera and state.players.has(local_seat):
			var track_target: Vector3 = attack_hoop() if owns_ball() else state.ball.pos
			var to_target: Vector3 = track_target - state.players[local_seat].pos
			if Vector2(to_target.x, to_target.z).length() > 1.0:
				yaw = lerp_angle(yaw, atan2(-to_target.x, -to_target.z), 1.0 - exp(-10.0 * dt))
		if not presentation_enabled:
			# Keep input-facing orientation, HUD and reward state on headless peers.
			# Only skip invisible court animation, prediction and aiming geometry.
			update_hud(dt)
			return
		var shown: Dictionary = presentation_state()
		shown["names"] = display_names()
		shown["charging"] = charging
		shown["charge_power"] = charge_time / 1.15
		shown["aim_bad"] = charge_time > 1.15
		shown["cosmetics"] = cosmetics
		shown["aim_preview"] = trajectory_preview()
		shown["pass_target_preview"] = pass_target_preview()
		shown["ball_camera"] = ball_camera
		if ball_camera: shown["camera_focus"] = attack_hoop() if owns_ball() else shown.ball.pos
		shown["cinematic"] = cinematics_enabled and not paused and not scripted_session()
		world.present(shown, local_seat, dt * presentation_time_scale, yaw, pitch)
		update_hud(dt)
	else:
		if not presentation_enabled: return
		preview["names"] = {1: "You", 2: "Bot 2", 3: "Bot 3", 4: "Bot 4", 5: "Bot 5", 6: "Bot 6"}
		preview["cosmetics"] = {1: profile.outfit()} if phase == "menu" else cosmetics
		world.present(preview, 0, dt, -0.55, 0.7)

func display_names() -> Dictionary:
	var labels = names.duplicate()
	for id in state.players:
		if not labels.has(id): labels[id] = "Bot %d" % id
	return labels

func presentation_state() -> Dictionary:
	var shown: Dictionary = state.duplicate(false)
	if _closing or state.is_empty() or not multiplayer_active() or multiplayer.is_server(): return shown
	return predict_render_state(ui_clock - snapshot_received_at)

func predict_render_state(snapshot_age: float) -> Dictionary:
	var shown: Dictionary = state.duplicate(false)
	var age = clampf(snapshot_age, 0.0, 0.08)
	if float(state.get("celebration_time", 0)) <= 0 and (float(state.get("reset_time", 0)) > 0 or int(state.get("winner", -1)) >= 0):
		visual_jump_started = -1.0
		visual_y_correction = 0.0
		local_render_clock = -1.0
		player_render_history.clear()
		reset_ball_presentation()
		return shown
	# Moving obstacles use the same bounded presentation time as their players
	# and ball, instead of visibly stepping only when a20Hz snapshot arrives.
	if float(state.get("reset_time",0)) <= 0 and float(state.get("celebration_time",0)) <= 0 and int(state.get("winner",-1)) < 0:
		shown["snapshot_clock"] = float(state.get("clock",0))
		shown["clock"] = float(state.get("clock",0)) + age
	var rendered_players: Dictionary = {}
	for id in state.players:
		var player: Dictionary = state.players[id].duplicate(false)
		var velocity: Vector3 = player.vel
		var predicted: Vector3 = player.pos
		if id == local_seat and bool(player.grounded) and float(player.get("boost_time", 0)) <= 0 and float(player.stun) <= 0 and float(player.dive) <= 0 and float(player.dunk) <= 0:
			# Predict the same traction as authority, including the stopping distance
			# of a sharp turn. An instant velocity blend erased the ground skid.
			player["move"] = local_direction
			var remaining = age
			while remaining > .00001:
				var step = minf(remaining, 1.0 / 60)
				player["slide_time"] = maxf(0, float(player.get("slide_time", 0)) - step)
				player["giant"] = maxf(0, float(player.get("giant", 0)) - step)
				player["vel"] = velocity
				velocity = Sim.movement_velocity(player, int(state.ball.owner) == id, step)
				predicted += velocity * step
				var bounded = {"pos":predicted,"vel":velocity}
				Sim.constrain_player_bounds(bounded)
				predicted = bounded.pos
				velocity = bounded.vel
				remaining -= step
			# The local pose and held-ball copy must see the same current intent
			# and predicted momentum as this position, before its network ACK.
			player["move"] = local_direction
			player["vel"] = velocity
		else:
			predicted += velocity * age
		if not bool(player.grounded) and float(player.dunk) <= 0:
			predicted.y -= .5 * Sim.PLAYER_GRAVITY * age * age
		# Collision removes blocked momentum for remote, airborne and stunned copies too.
		var bounded = {"pos":predicted,"vel":velocity}
		Sim.constrain_player_bounds(bounded)
		predicted = bounded.pos
		velocity = bounded.vel
		player["vel"] = velocity
		var ground = Sim.surface_height(predicted, player.pos.y)
		predicted.y = maxf(predicted.y, ground)
		if id == local_seat: predicted.y = maxf(ground, local_visual_height(player, predicted.y))
		var render_velocity = velocity
		if not bool(player.grounded) and float(player.dunk) <= 0: render_velocity.y -= Sim.PLAYER_GRAVITY * age
		player["pos"] = reconcile_player_presentation(id, player, predicted, render_velocity, age)
		if id == local_seat and int(state.ball.owner) == local_seat and float(player.dunk) <= 0:
			player["aim"] = camera_forward() if manual_input_enabled else last_aim
		rendered_players[id] = player
	shown["players"] = rendered_players
	var shown_ball: Dictionary = state.ball.duplicate(false)
	var owner = int(shown_ball.owner)
	if owner > 0 and rendered_players.has(owner):
		presentation_sim.players = rendered_players
		presentation_sim.mode = selected_mode
		shown_ball["pos"] = presentation_sim.hand_position(owner)
		shown_ball["vel"] = rendered_players[owner].vel
	else:
		var velocity: Vector3 = shown_ball.vel
		var position: Vector3 = shown_ball.pos + velocity * age + Vector3.DOWN * .5 * Sim.BALL_GRAVITY * age * age
		position.x = clampf(position.x, -Sim.HALF_WIDTH + Sim.BALL_RADIUS, Sim.HALF_WIDTH - Sim.BALL_RADIUS)
		position.z = clampf(position.z, -Sim.HALF_LENGTH + Sim.BALL_RADIUS, Sim.HALF_LENGTH - Sim.BALL_RADIUS)
		position.y = maxf(position.y, Sim.surface_height(position - Vector3.UP * Sim.BALL_RADIUS, shown_ball.pos.y - Sim.BALL_RADIUS) + Sim.BALL_RADIUS)
		shown_ball["pos"] = position
		shown_ball["vel"] = velocity + Vector3.DOWN * Sim.BALL_GRAVITY * age
	shown_ball["pos"] = reconcile_ball_presentation(shown_ball.pos, shown_ball.vel, owner, age)
	shown["ball"] = shown_ball
	return shown

func reset_ball_presentation() -> void:
	ball_render_clock = -1.0
	ball_render_sequence = -1
	ball_render_round = ""
	ball_render_owner = -1
	ball_render_correction = Vector3.ZERO
	ball_render_sample.clear()
	ball_render_recovering = false

func continuous_snapshot_motion(previous: Dictionary, position: Vector3, velocity: Vector3, gravity: float) -> bool:
	# A long delivery gap is not itself permission to smooth an arbitrary warp.
	# Admit only motion consistent with the two authoritative samples, for at
	# most 600 ms. Collisions, takeoffs and genuine relocations fail this test.
	if previous.is_empty(): return false
	var elapsed = float(state.get("clock", 0)) - float(previous.clock)
	if elapsed <= 0 or elapsed > .6: return false
	var expected: Vector3 = previous.position + previous.velocity * elapsed + Vector3.DOWN * .5 * gravity * elapsed * elapsed
	var expected_velocity: Vector3 = previous.velocity + Vector3.DOWN * gravity * elapsed
	return expected.distance_to(position) <= .35 and expected_velocity.distance_to(velocity) <= 1.0

func retire_render_correction(correction: Vector3, dt: float) -> Vector3:
	# Keep the existing fast retirement for small jitter. A long-gap offset
	# must not retire several metres in its first frame after admission.
	var adjustment = correction * (1.0-exp(-18.0*dt))
	return correction-adjustment.limit_length(45.0*dt)

func reconcile_player_presentation(id: int, player: Dictionary, position: Vector3, velocity: Vector3, age: float) -> Vector3:
	var previous: Dictionary = player_render_history.get(id, {})
	var authority: Dictionary = state.players[id]
	var round_id = str(state.get("match_id", match_id))
	var correction = Vector3.ZERO
	var recovering = false
	var gravity = 0.0 if bool(player.grounded) or float(player.dunk) > 0 else Sim.PLAYER_GRAVITY
	var same_motion = not previous.is_empty() and str(previous.round_id) == round_id and ui_clock-float(previous.render_clock) <= .15
	if same_motion:
		# Never spread a tackle, dunk activation or booster impulse over a blend.
		same_motion = (float(player.stun) > 0) == bool(previous.stunned) and float(player.dunk) <= 0 and not bool(previous.dunking) and (float(player.get("boost_time",0)) > 0) == bool(previous.boosted) and int(player.jump_count) == int(previous.jumps)
		if float(player.get("hazard_cooldown",0)) > float(previous.get("hazard_cooldown",0))+.01: same_motion = false
	if same_motion:
		var dt = maxf(0,ui_clock-float(previous.render_clock))
		recovering = bool(previous.get("recovering",false))
		if snapshot_received_sequence >= 0 and snapshot_received_sequence != int(previous.sequence):
			# Fresh authority renews the horizon. If the prior render had not
			# frozen yet, include this whole frame rather than truncating at the
			# previous sample's cap (which loses motion at lower render rates).
			var forward_time = dt if float(previous.age) < .08-.00001 else 0.0
			var continued: Vector3 = previous.position + previous.velocity*forward_time + Vector3.DOWN*.5*gravity*forward_time*forward_time
			correction = continued-position
			if id == local_seat: correction.y = 0 # Jump acknowledgement owns local Y.
			var continuous = continuous_snapshot_motion(previous.sample,authority.pos,authority.vel,gravity)
			if correction.length() > 3.0 and not (correction.length() <= 16.0 and continuous):
				correction = Vector3.ZERO
				recovering = false
			else:
				recovering = continuous and (recovering or correction.length() > 3.0)
				if recovering: correction = retire_render_correction(correction,dt)
		else:
			correction = retire_render_correction(previous.correction,minf(dt,maxf(0,age-float(previous.age))))
	var shown = position+correction
	shown.x = clampf(shown.x,-Sim.HALF_WIDTH+.5,Sim.HALF_WIDTH-.5)
	shown.z = clampf(shown.z,-Sim.HALF_LENGTH+.5,Sim.HALF_LENGTH-.5)
	var surface = Sim.surface_height(shown,authority.pos.y)
	shown.y = maxf(shown.y,surface)
	# Horizontal recovery changes the point of contact on a bank. Recompute
	# grounded height there, while leaving pending local jump Y to its predictor.
	if bool(player.grounded) and (id != local_seat or (visual_jump_started < 0 and absf(visual_y_correction) < .001)):
		var previous_surface = Sim.surface_height(authority.pos, authority.pos.y)
		var on_raised_support = previous_surface > Sim.floor_height(authority.pos.x, authority.pos.z) + .01
		# A grounded packet can still describe the deck just before its edge.
		# Extrapolated XZ leaving that one-way support starts a fall; it must not
		# teleport Y to the distant floor before the airborne packet arrives.
		# Continuous banks keep their contact projection. The .4m contact limit
		# matches the simulation's grounded step-down rule.
		if not (on_raised_support and surface < previous_surface - .4): shown.y = surface
	player_render_history[id] = {"round_id":round_id,"sequence":snapshot_received_sequence,"position":shown,"velocity":velocity,"render_clock":ui_clock,"age":age,"correction":correction,"recovering":recovering and correction.length()>.001,"stunned":float(player.stun)>0,"dunking":float(player.dunk)>0,"boosted":float(player.get("boost_time",0))>0,"jumps":int(player.jump_count),"hazard_cooldown":float(player.get("hazard_cooldown",0)),"sample":{"position":authority.pos,"velocity":authority.vel,"clock":float(state.get("clock",0))}}
	return shown

func reconcile_ball_presentation(position: Vector3, velocity: Vector3, owner: int, age: float) -> Vector3:
	var round_id = str(state.get("match_id", match_id))
	var dt = maxf(0.0, ui_clock - ball_render_clock)
	var same_flight = owner == 0 and ball_render_owner == 0 and round_id == ball_render_round and ball_render_clock >= 0
	if not same_flight or dt > .15:
		ball_render_correction = Vector3.ZERO
		ball_render_recovering = false
	elif snapshot_received_sequence >= 0 and snapshot_received_sequence != ball_render_sequence:
		# Packet arrival may reset extrapolation to an earlier point on the same
		# flight. Continue from the previous rendered point, then retire only the
		# small correction; do not lerp every frame behind the moving ball.
		var forward_time = dt if ball_render_age < .08-.00001 else 0.0
		var continued = ball_render_position + ball_render_velocity * forward_time + Vector3.DOWN * .5 * Sim.BALL_GRAVITY * forward_time * forward_time
		var correction = continued - position
		var continuous = continuous_snapshot_motion(ball_render_sample,state.ball.pos,state.ball.vel,Sim.BALL_GRAVITY)
		ball_render_correction = correction if correction.length() <= 3.0 or (correction.length() <= 16.0 and continuous) else Vector3.ZERO
		ball_render_recovering = continuous and (ball_render_recovering or ball_render_correction.length() > 3.0) and ball_render_correction.length()>.001
		if ball_render_recovering: ball_render_correction = retire_render_correction(ball_render_correction,dt)
	else:
		# Once the bounded extrapolation is exhausted, freeze the correction too.
		# Decaying it against a stationary capped target would rewind the ball.
		ball_render_correction = retire_render_correction(ball_render_correction,minf(dt,maxf(0.0,age-ball_render_age)))
	var shown = position + ball_render_correction
	if owner == 0:
		shown.x = clampf(shown.x, -Sim.HALF_WIDTH + Sim.BALL_RADIUS, Sim.HALF_WIDTH - Sim.BALL_RADIUS)
		shown.z = clampf(shown.z, -Sim.HALF_LENGTH + Sim.BALL_RADIUS, Sim.HALF_LENGTH - Sim.BALL_RADIUS)
		shown.y = maxf(shown.y, Sim.surface_height(shown - Vector3.UP * Sim.BALL_RADIUS, state.ball.pos.y - Sim.BALL_RADIUS) + Sim.BALL_RADIUS)
	ball_render_position = shown
	ball_render_velocity = velocity
	ball_render_clock = ui_clock
	ball_render_sequence = snapshot_received_sequence
	ball_render_round = round_id
	ball_render_owner = owner
	ball_render_age = age
	ball_render_sample = {"position":state.ball.pos,"velocity":state.ball.vel,"clock":float(state.get("clock",0))}
	return shown

func update_event_sounds() -> bool:
	# The host can emit several actions between presentation/snapshot updates.
	# Consume bounded transient history once; never replay old sounds on join.
	if not state.has("recent_events"): return false
	var round_id = str(state.get("match_id", match_id))
	var event_clock = float(state.get("event_clock", 0.0))
	var newest = int(state.get("event_id", 0))
	if not is_finite(event_clock) or not state.recent_events is Array: return false
	if _sound_event_id < 0 or round_id != _sound_round or event_clock < _sound_event_clock:
		_sound_event_id = newest
		_sound_round = round_id
		_sound_event_clock = event_clock
		return false
	var pending: Array = []
	var seen: Dictionary = {}
	for entry in state.recent_events:
		if not entry is Array or entry.size() != 5: continue
		if not entry[0] is int or not entry[1] is String or not entry[2] is Vector3 or not entry[3] is int: continue
		if not typeof(entry[4]) in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(entry[4])) or not entry[2].is_finite(): continue
		if int(entry[0]) <= _sound_event_id or int(entry[0]) > newest or seen.has(entry[0]): continue
		if event_clock - float(entry[4]) > .35 or float(entry[4]) > event_clock: continue
		seen[entry[0]] = true
		pending.append(entry)
	_sound_event_id = maxi(_sound_event_id, newest)
	_sound_event_clock = event_clock
	if muted or paused: return false
	var local_catch = false
	# Give the player's own feedback first access to the finite impact voices.
	for local_pass in [true, false]:
		for entry in pending:
			var local = int(entry[3]) == local_seat
			if local != local_pass: continue
			var kind = str(entry[1])
			if kind in ["score", "basket"]: continue # Score changes have their own cue.
			var proximity = 1.0
			if not local and state.players.has(local_seat):
				proximity = clampf(1.0 - state.players[local_seat].pos.distance_to(entry[2]) / 32.0, 0, 1)
			if proximity < .045: continue
			sounds.play_event(kind, proximity, local)
			if local and kind == "grab": local_catch = true
	return local_catch

func update_hud(_dt: float) -> void:
	if not is_instance_valid(score_label): return
	var local_catch_sound = update_event_sounds()
	if is_instance_valid(hud_help):
		hud_help.modulate.a = clampf(hud_help_until - ui_clock, 0.0, 1.0)
		hud_help.visible = hud_help.modulate.a > 0
		controls_hint.modulate.a = 1.0 - hud_help.modulate.a
	var scores: Dictionary = state.scores
	if selected_mode != "versus":
		score_label.text = ("BLUE  %d   :   %d  ORANGE" if selected_mode == "teams" else "YOU  %d   :   %d  BOTS") % [scores.get(0, 0), scores.get(1, 0)]
	else:
		var values = PackedStringArray()
		for id in range(1, 4): values.append("%s %d" % [str(names.get(id, "BOT %d" % id)).substr(0, 6).to_upper(), scores.get(id, 0)])
		score_label.text = "    /    ".join(values)
	var remaining = maxi(0, ceili(float(state.time_left)))
	clock_label.text = "FINAL" if int(state.winner) >= 0 else "%d:%02d" % [remaining / 60, remaining % 60]
	clock_label.modulate = Color("ff8795") if remaining <= 30 and int(state.winner) < 0 else PAPER
	rule_label.text = "First to 7" if selected_mode == "versus" else "5 min  ·  Win by 4"
	if int(state.winner) >= 0: rule_label.text = "Full time"
	elif remaining == 0: rule_label.text = "Overtime"
	elif selected_mode != "versus" and absi(int(scores.get(0, 0)) - int(scores.get(1, 0))) == 3: rule_label.text = "Game point  ·  Win by 4"
	rule_label.text += "  ·  " + effective_difficulty().capitalize() + " bots"
	if state.get("series", {}).get("active", false): rule_label.text += "  ·  " + series_text()
	var owner = int(state.ball.owner)
	var previous_owner = _hud_owner
	possession_label.text = "Your ball" if owner == local_seat else ("Loose ball" if owner == 0 else "%s's ball" % str(names.get(owner, "Bot %d" % owner)).substr(0, 18))
	possession_label.modulate = TEAL if owner == local_seat else PAPER
	charge_bar.visible = charging and owner == local_seat and not paused
	charge_label.visible = charge_bar.visible
	charge_bar.value = charge_time / 1.15
	var sweet_spot = -1.0
	if charge_bar.visible and prepare_aim_sim(): sweet_spot = aim_sim.ideal_charge(local_seat)
	var in_window = sweet_spot >= 0 and absf(charge_time / 1.15 - sweet_spot) <= Sim.ASSIST_CHARGE_WINDOW * .6 and charge_time <= 1.15
	charge_marker.visible = charge_bar.visible and sweet_spot >= 0
	charge_marker.position.x = 485 + 310.0 * clampf(sweet_spot / 1.75, 0.0, 1.0) - 2
	if charge_time > 1.15: charge_label.text = "Overcharged"
	elif in_window: charge_label.text = "Release now  %s" % hud_key("RMB", "RT")
	else: charge_label.text = ("Hold for the mark" if sweet_spot >= 0 and charge_time / 1.15 < sweet_spot else "Release %s" % hud_key("RMB", "RT"))
	charge_label.text += "  ·  Loft %d°" % roundi(rad_to_deg(asin(clampf(shot_direction().y, -1.0, 1.0))))
	var fill = charge_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("ff6679") if charge_time > 1.15 else (Color("6df069") if in_window else TEAL)
	charge_label.add_theme_color_override("font_color", Color("ff8795") if charge_time > 1.15 else (Color("8ff58b") if in_window else PAPER))
	prompt_label.text = ""
	if state.players.has(local_seat):
		var player: Dictionary = state.players[local_seat]
		var extra_jump = not bool(player.grounded) and int(player.get("jump_count", 0)) < 2
		jump_label.text = "%s  Extra jump" % hud_key("Space", " / A") if extra_jump else ""
		jump_label.visible = extra_jump and float(player.stun) <= 0 and float(player.dunk) <= 0 and not paused and float(state.get("reset_time", 0)) <= 0
		update_hype_feedback(player)
		var feet: Vector3 = player.pos
		var target = attack_hoop()
		var distance = Vector2(feet.x - target.x, feet.z - target.z).length()
		target_label.text = "%s hoop  ·  %d m" % ["Orange" if target.z < 0 else "Blue", roundi(distance)]
		if float(player.stun) > 0: prompt_label.text = "Recovering"
		elif float(player.dunk) > 0: prompt_label.text = ""
		elif owner == local_seat:
			if can_dunk(): prompt_label.text = "%s  Dunk" % hud_key("F", " / B")
			elif distance < Sim.DUNK_RANGE: prompt_label.text = "%s  Jump to dunk" % hud_key("Space", " / A")
			elif not charging:
				var receiver = pass_target_preview()
				if receiver > 0: prompt_label.text = "%s  Pass to %s" % [hud_key("LMB", " / X"), str(names.get(receiver, "Bot %d" % receiver)).substr(0, 18)]
				elif ui_clock < hud_help_until: prompt_label.text = "Hold %s  Shoot" % hud_key("RMB", "RT")
		elif dunk_counter_hint_available(player, owner): prompt_label.text = "%s + %s  Jump + tackle to block" % [hud_key("Space", " / A"), hud_key("RMB", "RT")]
		elif owner == 0 and prepare_aim_sim() and aim_sim.can_catch(local_seat): prompt_label.text = "%s  Catch" % hud_key("LMB", " / X")
		elif owner > 0 and state.players.has(owner) and feet.distance_to(state.players[owner].pos) < 4.0:
			var same_team = selected_mode != "versus" and int(state.players[owner].team) == int(player.team)
			prompt_label.text = "%s  Call for ball" % hud_key("MMB", "RB") if same_team else ("%s  Tackle" % hud_key("RMB", "RT") if float(player.cooldown) <= 0 else "")
		# Local transitions survive unrelated remote events replacing the latest event.
		if _hud_owner >= 0 and _hud_owner != local_seat and owner == local_seat and not muted and not paused and not local_catch_sound: sounds.play_event("grab", 1.0, true)
		if not _hud_grounded and bool(player.grounded) and float(state.get("reset_time", 0)) <= 0 and not muted: sounds.play_event("land", .55)
		_hud_grounded = bool(player.grounded)
		if not muted and not paused and float(state.get("reset_time", 0)) <= 0:
			sounds.update_motion(player, _dt)
		update_ball_marker()
	_hud_owner = owner
	prompt_back.visible = not prompt_label.text.is_empty() and not paused
	prompt_label.visible = prompt_back.visible
	if prompt_back.visible:
		var text_width = prompt_label.get_theme_font("font").get_string_size(prompt_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var prompt_width = clampf(text_width + 40.0, 180.0, 792.0)
		prompt_back.position.x = (1280.0 - prompt_width) * .5
		prompt_back.size.x = prompt_width
		prompt_label.position.x = prompt_back.position.x + 16.0
		prompt_label.size.x = prompt_width - 32.0
	var score_feedback: Dictionary = HypeIndicator.score_feedback(_hud_scores, scores, selected_mode, names, int(state.winner))
	var scored = not score_feedback.is_empty()
	var banner_text = ""
	var banner_color = ORANGE
	if scored:
		# Score cam banner: announcer flavour up top, scorer and context below.
		var scorer = int(state.get("event_player", 0)) if str(state.get("event_kind", "")) in ["score", "win"] else 0
		var scorer_name = str(names.get(scorer, "Bot %d" % scorer)).substr(0, 14) if scorer > 0 and state.players.has(scorer) else ""
		var detail = str(score_feedback.text).get_slice("\n", 1)
		var flavour = str(state.get("score_text", "")).strip_edges()
		if flavour.is_empty(): flavour = "BUCKET!"
		banner_text = flavour
		banner_color = Color("7fd4f5") if int(score_feedback.side) == 0 and selected_mode != "versus" else ORANGE
		# Name the scorer when the snapshot still carries the score event; a newer
		# event in the same snapshot falls back to the team line.
		var who = scorer_name if not scorer_name.is_empty() else str(score_feedback.text).get_slice("\n", 0)
		_hud_announcement = who + "  ·  " + detail
		_hud_announcement_until = ui_clock + 2.3
		_hud_score_at = ui_clock
		goal_flash.color = Color(banner_color.r, banner_color.g, banner_color.b, 0)
		start_slowmo(.55, .3)
		if not muted and not paused: sounds.play_event(str(score_feedback.cue))
	_hud_scores = scores.duplicate()
	var clock_feedback: Dictionary = HypeIndicator.clock_feedback(_hud_remaining, remaining, int(state.winner))
	if not scored and not clock_feedback.is_empty() and ui_clock >= _hud_announcement_until:
		_hud_announcement = str(clock_feedback.text)
		_hud_announcement_until = ui_clock + 1.3
		if not muted and not paused: sounds.play_event(str(clock_feedback.cue))
	_hud_remaining = remaining
	var score_age = maxf(0.0, ui_clock - _hud_score_at)
	score_label.pivot_offset = score_label.size * .5
	score_label.scale = Vector2.ONE * (1.0 + .10 * exp(-score_age * 7.0) * sin(score_age * 14.0))
	var event = int(state.get("event_id", -1))
	if event != last_event:
		var first_event = last_event < 0
		last_event = event
		event_age = 0.0
		var kind = str(state.get("event_kind", ""))
		var actor = int(state.get("event_player", 0))
		if not first_event and not scored and ui_clock >= _hud_announcement_until and kind == "tackle" and state.players.has(local_seat) and float(state.players[local_seat].stun) > 0:
			_hud_announcement = "Ball lost" if previous_owner == local_seat and owner != local_seat else "Tackled"
			_hud_announcement_until = ui_clock + .6
			start_hitstop()
		elif not first_event and not scored and kind == "tackle" and actor == local_seat:
			_hud_announcement = "STEAL!" if str(state.get("message", "")) == "BALL LOOSE" else "BIG HIT!"
			_hud_announcement_until = ui_clock + .8
			start_hitstop()
		if not state.has("recent_events") and not first_event and not muted and kind not in ["score", "basket", "grab"]:
			var proximity = 1.0
			if state.players.has(local_seat): proximity = clampf(1.0 - state.players[local_seat].pos.distance_to(state.get("event_pos", Vector3.ZERO)) / 40.0, .12, 1.0)
			sounds.play_event(kind, proximity)
	event_label.text = _hud_announcement if ui_clock < _hud_announcement_until else ""
	event_label.modulate.a = clampf(_hud_announcement_until - ui_clock, 0, 1)
	goal_flash.color.a = maxf(0.0, .26 - score_age * .6)
	var final_celebration = int(state.winner) >= 0 and float(state.get("celebration_time", 0)) > 0
	if scored or (final_celebration and not _final_banner_shown):
		if final_celebration and not _final_banner_shown:
			_final_banner_shown = true
			if not scored:
				# Buzzer finish: the clock ran out rather than a winning basket.
				_hud_announcement = "Your team wins!" if selected_mode == "coop" and int(state.winner) == 0 else ("Bots win" if selected_mode == "coop" else ("Blue wins" if selected_mode == "teams" and int(state.winner) == 0 else ("Orange wins" if selected_mode == "teams" else "%s wins" % str(names.get(int(state.winner), "Bot %d" % int(state.winner))))))
				_hud_announcement_until = ui_clock + 3.4
				start_slowmo(.9, .3)
				if not muted and not paused: sounds.play_event("win")
			banner_text = "FULL TIME" if not scored else banner_text
		banner_label.text = banner_text
		banner_label.add_theme_color_override("font_color", banner_color)
		banner_label.visible = true
		_last_banner_event = int(state.get("event_id", -1))
		_cinematic_score_at = ui_clock
	var banner_age = ui_clock - _cinematic_score_at
	if banner_label.visible:
		banner_label.modulate.a = clampf((2.4 if not final_celebration else 3.4) - banner_age, 0, 1)
		banner_label.scale = Vector2.ONE * (1.0 + .35 * exp(-banner_age * 6.0))
		if banner_age > (2.4 if not final_celebration else 3.4): banner_label.visible = false
	# Flavour reads first; the scorer and context sit beneath it while it shows.
	event_label.position.y = 182 if banner_label.visible else 110
	var reset_remaining = float(state.get("reset_time", 0)) if int(state.winner) < 0 and float(state.get("celebration_time", 0)) <= 0 else 0.0
	var intro_showing = reset_remaining > 3.0 and float(state.get("intro_time", 0)) > 3.0
	var countdown = reset_remaining if reset_remaining <= 3.0 else 0.0
	if is_instance_valid(intro_card):
		if intro_showing and not intro_card.visible: fill_intro_card()
		intro_card.visible = intro_showing and not paused
		intro_card.modulate.a = clampf((reset_remaining - 3.0) * 1.6, 0, 1) if intro_showing else 1.0
	event_label.add_theme_font_size_override("font_size", 68 if countdown > 0 else 36 if "\n" in event_label.text else 44)
	if countdown > 0 or intro_showing:
		event_label.text = str(ceili(countdown)) if countdown > 0 else ""
		event_label.modulate.a = 1.0
		goal_flash.color.a = 0.0
		banner_label.visible = false
		prompt_label.visible = false
		prompt_back.visible = false
		charge_bar.visible = false
		charge_label.visible = false
		charge_marker.visible = false
	for cue in [possession_label, target_label, jump_label]:
		if is_instance_valid(cue) and intro_showing: cue.visible = false
		elif is_instance_valid(cue) and cue != jump_label and int(state.winner) < 0: cue.visible = true
	var countdown_tick = ceili(countdown)
	if _hud_countdown >= 0 and countdown_tick != _hud_countdown and countdown_tick <= 3 and not muted:
		sounds.play_event("go" if countdown_tick == 0 else "countdown", .65)
	_hud_countdown = countdown_tick
	if int(state.winner) >= 0:
		queue_current_win_reward()
	if int(state.winner) >= 0 and float(state.get("celebration_time", 0)) <= 0 and not _winner_shown:
		_winner_shown = true
		charging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		result_panel.visible = true
		pause_panel.visible = false
		var result_heading = result_panel.find_child("Heading", true, false) as Label
		var result_note = result_panel.find_child("Note", true, false) as Label
		if selected_mode == "teams": result_heading.text = "Blue wins" if int(state.winner) == 0 else "Orange wins"
		elif selected_mode == "coop": result_heading.text = "Your team wins" if int(state.winner) == 0 else "Bots win"
		else: result_heading.text = "%s wins" % str(names.get(int(state.winner), "Bot %d" % int(state.winner)))
		result_note.text = "+1 bag" if _earned_reward_round == str(state.get("match_id", "")) else (reward_error if not pending_rewards.is_empty() else "")
		result_bag_button.visible = int(profile.data.bags) > 0
		var summary = stats_summary()
		var mvp_label = result_panel.find_child("Mvp", true, false) as Label
		var stats_label = result_panel.find_child("Stats", true, false) as Label
		if is_instance_valid(mvp_label): mvp_label.text = ("MVP  ·  %s" % str(summary.mvp.name)) if not summary.mvp.is_empty() else ""
		if is_instance_valid(stats_label): stats_label.text = str(summary.text)
		var series_note = result_panel.find_child("Series", true, false) as Label
		series_note.text = series_text() if selected_mode != "versus" else "Try another power on your next match."
		var series_button = result_panel.find_child("SeriesButton", true, false) as Button
		if is_instance_valid(series_button) and state.get("series", {}).get("active", false):
			series_button.text = "New best of 3" if state.series.get("finished", false) else "Next round"
	if _winner_shown:
		event_label.visible = false
		banner_label.visible = false
		goal_flash.color.a = 0.0
	if int(state.winner) >= 0:
		for cue in [possession_label, target_label, jump_label, prompt_label, prompt_back, charge_bar, charge_label, controls_hint, hud_help]:
			if is_instance_valid(cue): cue.visible = false

func dunk_counter_hint_available(player: Dictionary, owner: int) -> bool:
	if paused or _winner_shown or int(state.winner)>=0 or float(state.get("reset_time",0))>0: return false
	if owner<=0 or owner==local_seat or not state.players.has(owner): return false
	if float(player.stun)>0 or float(player.dunk)>0 or float(player.dive)>0 or float(player.cooldown)>0: return false
	if not bool(player.grounded) and int(player.jump_count)>=2: return false
	var opponent: Dictionary = state.players[owner]
	if selected_mode!="versus" and int(opponent.team)==int(player.team): return false
	if float(opponent.get("guard",0))>0: return false
	# Offer a nearby opportunity early enough to react before the ball releases.
	var until_release = float(opponent.dunk)-float(opponent.get("dunk_duration",Sim.DUNK_DURATION))*(1.0-Sim.DUNK_RELEASE_PHASE)
	if until_release<.25: return false
	var offset: Vector3 = opponent.pos-player.pos
	return Vector2(offset.x,offset.z).length()<3.5 and offset.y>=-1.5 and offset.y<=3.5

func hud_key(keyboard: String, controller: String) -> String:
	return controller_labels(controller).trim_prefix(" / ") if controller_device >= 0 else keyboard

func update_hype_feedback(player: Dictionary) -> void:
	var amount = clampf(float(player.get("hype", 0)), 0, 100)
	var power = str(player.get("power", "giant"))
	if _hype_power != power:
		_hype_amount = -1.0
		_hype_notice_until = 0.0
	if _hype_amount >= 0 and amount > _hype_amount:
		_hype_notice = "+%d Hype" % roundi(amount - _hype_amount)
		_hype_notice_until = ui_clock + 1.1
	elif _hype_amount >= 100 and amount < 100:
		_hype_notice = "Activated"
		_hype_notice_until = ui_clock + 1.1
	if _hype_amount >= 0 and _hype_amount < 100 and amount >= 100 and not muted and not paused:
		sounds.play_event("power_ready", .8, true)
	_hype_amount = amount
	_hype_power = power
	# A live join keeps the replaced bot's active effects, even when the human
	# chooses another power. Keep that choice visible and name inherited timers.
	var active = {"giant":float(player.get("giant", 0)),"pad":0.0,"blast":0.0}
	for kind in ["pad","blast"]:
		for effect in state.get("power_pads" if kind == "pad" else "power_balls", []):
			if int(effect.get("owner", 0)) == local_seat: active[kind] = maxf(active[kind],float(effect.get("time", 0)))
	var active_labels: Array[String] = []
	var inherited = false
	for kind in POWER_IDS:
		if active[kind] <= 0: continue
		active_labels.append("%s %ds" % [{"giant":"Giant","pad":"Pad","blast":"Orb"}[kind],ceili(active[kind])])
		inherited = inherited or kind != power
	var status = "%d%%" % roundi(amount)
	if ui_clock < _hype_notice_until: status = _hype_notice
	if not active_labels.is_empty(): status = " · ".join(active_labels) if inherited else "Active %ds" % ceili(active[power])
	elif amount >= 100:
		status = "Recovering" if float(player.get("stun", 0)) > 0 else "Finish dunk" if float(player.get("dunk", 0)) > 0 else "Ready"
	var button_key = hud_key("Q", " / Y")
	if button_key == "Triangle": button_key = "△"
	hype_ring.set_status(amount / 100.0, power, controller_device >= 0, status, button_key)
	hype_ring.visible = not paused and not _winner_shown and int(state.get("winner", -1)) < 0 and float(state.get("reset_time", 0)) <= 0

func eligible_for_reward() -> bool:
	if _closing or not multiplayer_active() or state.is_empty() or int(state.get("winner", -1)) < 0: return false
	if not multiplayer.get_unique_id() in state.get("reward_peers", []): return false
	var local_team = int(state.players.get(local_seat, {}).get("team", -1))
	return (selected_mode != "versus" and int(state.winner) == local_team) or (selected_mode == "versus" and int(state.winner) == local_seat)

func queue_current_win_reward() -> bool:
	if not eligible_for_reward(): return false
	var round_id = str(state.get("match_id", ""))
	if round_id.is_empty() or round_id in profile.data.redeemed or pending_rewards.has(round_id): return false
	pending_rewards[round_id] = true
	return retry_pending_rewards() > 0

func retry_pending_rewards() -> int:
	last_reward_attempt = ui_clock
	var earned = 0
	for round_id in pending_rewards.keys():
		if round_id in profile.data.redeemed:
			pending_rewards.erase(round_id)
		elif profile.award_win(str(round_id)):
			pending_rewards.erase(round_id)
			_earned_reward_round = str(round_id)
			earned += 1
	reward_error = "" if pending_rewards.is_empty() else REWARD_SAVE_ERROR
	if not reward_error.is_empty(): status_message = reward_error
	elif status_message == REWARD_SAVE_ERROR: status_message = ""
	if phase == "menu" and is_instance_valid(menu_note):
		menu_note.text = status_message if not status_message.is_empty() else "Up to 3 players on the same network.\nEmpty seats use bots."
	if is_instance_valid(wardrobe_button): wardrobe_button.text = "Wardrobe  ·  %d bags" % int(profile.data.bags)
	if phase == "match" and _winner_shown and is_instance_valid(result_panel):
		var note = result_panel.find_child("Note", true, false) as Label
		if is_instance_valid(note): note.text = reward_error if not reward_error.is_empty() else ("+1 bag" if earned > 0 else note.text)
		if is_instance_valid(result_bag_button): result_bag_button.visible = int(profile.data.bags) > 0
	if earned > 0 and is_instance_valid(wardrobe_panel) and wardrobe_panel.is_inside_tree(): show_wardrobe()
	return earned

func update_ball_marker() -> void:
	ball_marker.visible = false
	if owns_ball() or paused: return
	var camera: Camera3D = world.get("camera")
	if not is_instance_valid(camera): return
	var position: Vector3 = state.ball.pos
	if camera.is_position_behind(position):
		ball_marker.text = "%s  Ball behind" % hud_key("Ctrl", "LB")
		ball_marker.position = Vector2(535, 567)
	else:
		var point = camera.unproject_position(position + Vector3(0, 0.9, 0))
		ball_marker.text = "◆"
		ball_marker.position = Vector2(clampf(point.x - 11, 32, 1220), clampf(point.y - 26, 105, 570))
	ball_marker.visible = true

func trajectory_preview() -> PackedVector3Array:
	var points = PackedVector3Array()
	if not charging or not owns_ball() or paused or not prepare_aim_sim(): return points
	var origin: Vector3 = aim_sim.hand_position(local_seat)
	var velocity: Vector3 = aim_sim.throw_velocity(local_seat, charge_time / 1.15)
	# Use the real ball integrator in a private forecast, without players/catches
	# or scoring authority. Stop at the first static contact, so the dots cannot
	# promise a basket through a board, rim, bank or rotating sweeper.
	trajectory_sim.players = {}
	trajectory_sim.mode = selected_mode
	trajectory_sim.clock = float(state.get("clock",0))
	trajectory_sim.ball = {"pos":origin,"vel":velocity,"owner":0,"last_touch":0,"pass_target":0,"lock":0.0}
	trajectory_sim.bounce_cooldown = 0.0
	var hoops: Array = [Sim.NORTH] if selected_mode == "versus" else [Sim.NORTH,Sim.SOUTH]
	var flight = PackedVector3Array()
	var step = 1.0/180
	for index in 720: # Four seconds maximum, matching the host's three substeps.
		if index%3 == 0: trajectory_sim.clock += 1.0/60
		var previous: Vector3 = trajectory_sim.ball.pos
		var free_velocity: Vector3 = trajectory_sim.ball.vel + Vector3.DOWN*Sim.BALL_GRAVITY*step
		var free_position = previous + free_velocity*step
		var clear_air = Sim.ball_above_arena(previous) and Sim.ball_above_arena(free_position)
		if clear_air or (Sim.ball_clear_of_static_colliders(previous) and Sim.ball_clear_of_static_colliders(free_position)):
			trajectory_sim.ball.pos = free_position
			trajectory_sim.ball.vel = free_velocity
		else: trajectory_sim.ball_step(step)
		var point: Vector3 = trajectory_sim.ball.pos
		flight.append(point)
		if point.distance_squared_to(free_position) > .00000001 or trajectory_sim.ball.vel.distance_squared_to(free_velocity) > .00000001: break
		var scored = false
		for hoop in hoops:
			if previous.y > hoop.y and point.y <= hoop.y:
				var crossing = previous.lerp(point,(previous.y-hoop.y)/(previous.y-point.y))
				if Vector2(crossing.x-hoop.x,crossing.z-hoop.z).length() < Sim.RIM_RADIUS-Sim.RIM_TUBE-Sim.BALL_RADIUS: scored = true
		if scored: break
	var count = mini(36,flight.size())
	for index in count:
		points.append(flight[ceili(float(index+1)*flight.size()/count)-1])
	return points

func attack_hoop() -> Vector3:
	if not state.is_empty() and state.players.has(local_seat):
		aim_sim.players = state.players
		aim_sim.mode = selected_mode
		return aim_sim.hoop(local_seat)
	return Sim.NORTH

func show_wardrobe() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if is_instance_valid(wardrobe_panel) and is_instance_valid(focused) and wardrobe_panel.is_ancestor_of(focused):
		wardrobe_focus_id = str(focused.get_meta("wardrobe_focus", wardrobe_focus_id))
	if is_instance_valid(wardrobe_panel):
		ui.remove_child(wardrobe_panel)
		wardrobe_panel.queue_free()
	wardrobe_panel = Control.new()
	wardrobe_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(wardrobe_panel)
	backdrop(wardrobe_panel)
	var card = make_card(wardrobe_panel, Vector2(36, 62), Vector2(1208, 676), Color(0.025, 0.055, 0.105, 0.98))
	var column = make_column(card, 9)
	var header = HBoxContainer.new()
	column.add_child(header)
	var title = make_label("Wardrobe", header, 32, ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_button = make_button("Back", func(): close_wardrobe(), header)
	back_button.set_meta("wardrobe_focus", "back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.custom_minimum_size.x = 120
	make_label("%d / 11 unlocked  ·  %d bags" % [maxi(0, profile.data.inventory.size() - 2), int(profile.data.bags)], column, 17, TEAL)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)
	var preview_column = make_column(body, 10)
	preview_column.custom_minimum_size.x = 250
	make_label("Character", preview_column, 18, Color("b8c8d7"))
	var character_select = OptionButton.new()
	character_select.name = "CharacterSelect"
	character_select.set_meta("wardrobe_focus", "character")
	character_select.custom_minimum_size = Vector2(250, 44)
	character_select.add_theme_font_size_override("font_size", 18)
	preview_column.add_child(character_select)
	var characters = Profile.characters()
	for index in characters.size():
		character_select.add_item(str(characters[index].name))
		if characters[index].id == profile.outfit().character: character_select.select(index)
	character_select.item_selected.connect(func(index: int):
		wardrobe_focus_id = "character"
		if profile.select_character(str(characters[index].id)):
			sync_equipment()
			if not muted: sounds.play_event("grab")
		else: status_message = profile.last_error
		show_wardrobe())
	make_bean_preview(preview_column, profile.outfit(), Vector2(250, 280))
	var open_button = make_button("Open bag  (%d)" % int(profile.data.bags), func(): open_bag(), preview_column, true)
	open_button.set_meta("wardrobe_focus", "bag")
	open_button.disabled = int(profile.data.bags) <= 0
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	for slot in ["outfit", "accessory"]:
		var item_column = make_column(columns, 5)
		item_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		make_label("Outfits" if slot == "outfit" else "Accessories", item_column, 18, Color("b8c8d7"))
		for item in Profile.catalog():
			if item.slot != slot: continue
			var owned: bool = item.id in profile.data.inventory
			var equipped: bool = profile.data.equipped[slot] == item.id
			var value = "%s%s" % [str(item.name), "  ✓" if equipped else ("" if owned else "  ·  Locked")]
			var item_button = make_button(value, func(): equip_item(str(item.id)); show_wardrobe(), item_column, equipped)
			item_button.set_meta("wardrobe_focus", str(item.id))
			item_button.add_theme_font_size_override("font_size", 16)
			item_button.custom_minimum_size.y = 48
			item_button.tooltip_text = str(item.rarity).capitalize()
			item_button.disabled = not owned
			if not equipped:
				item_button.add_theme_color_override("font_color", Profile.rarity_color(str(item.rarity)))
				item_button.add_theme_color_override("font_disabled_color", Color("6b7c90"))
	var rules = make_label("1 win = 1 bag. Cosmetic items only. No duplicates.\nCommon 50%  ·  Rare 30%  ·  Epic 15%  ·  Legendary 5%  (remaining items)", column, 16, Color("9eb1c4"))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restore_wardrobe_focus.call_deferred()

func restore_wardrobe_focus() -> void:
	if not is_instance_valid(wardrobe_panel) or not wardrobe_panel.is_inside_tree(): return
	if is_instance_valid(reveal_panel) and reveal_panel.is_inside_tree(): return
	update_controller_focus()
	var controls = focusable_controls(wardrobe_panel)
	for control in controls:
		if str(control.get_meta("wardrobe_focus", "")) == wardrobe_focus_id:
			control.grab_focus()
			return
	# Opening the last bag disables its button; return to the character selector.
	for control in controls:
		if str(control.get_meta("wardrobe_focus", "")) == "character":
			control.grab_focus()
			return

func close_wardrobe() -> void:
	if is_instance_valid(wardrobe_panel):
		ui.remove_child(wardrobe_panel)
		wardrobe_panel.queue_free()
	if phase == "menu": show_menu()

func equip_item(id: String) -> void:
	if profile.equip(id):
		sync_equipment()
		if not muted: sounds.play_event("grab")
	else: status_message = profile.last_error

func open_bag() -> void:
	if is_instance_valid(wardrobe_panel): wardrobe_focus_id = "bag"
	var item: Dictionary = profile.open_bag()
	if item.is_empty():
		status_message = profile.last_error if not profile.last_error.is_empty() else "Win a match to earn your next free blind bag."
		return
	if is_instance_valid(reveal_panel):
		ui.remove_child(reveal_panel)
		reveal_panel.queue_free()
	reveal_panel = Control.new()
	reveal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(reveal_panel)
	var wash = ColorRect.new()
	wash.color = Color(0.02, 0.025, 0.06, 0.88)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reveal_panel.add_child(wash)
	var complete = bool(item.get("complete", false))
	var rarity = str(item.get("rarity", "legendary"))
	var color: Color = Profile.rarity_color(rarity)
	var card = make_card(reveal_panel, Vector2(350, 90), Vector2(580, 620), Color("102237"))
	card.add_theme_stylebox_override("panel", box_style(Color("102237"), color, 24))
	var column = make_column(card, 12)
	var shown_equipment: Dictionary = profile.outfit()
	if not complete: shown_equipment[str(item.slot)] = str(item.id)
	make_bean_preview(column, shown_equipment, Vector2(540, 340))
	var rarity_label = make_label("Collection complete" if complete else rarity.capitalize(), column, 20, color)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label = make_label("11 / 11 items" if complete else str(item.get("name", "")), column, 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not complete: make_button("Equip", func(): equip_item(str(item.id)); close_reveal(), column, true)
	make_button("Close", close_reveal, column)
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.75, 0.75)
	card.modulate.a = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.22)
	if not muted: sounds.play_event("win")
	if is_instance_valid(result_bag_button): result_bag_button.visible = int(profile.data.bags) > 0

func close_reveal() -> void:
	if is_instance_valid(reveal_panel):
		ui.remove_child(reveal_panel)
		reveal_panel.queue_free()
	if is_instance_valid(wardrobe_panel): show_wardrobe()
	elif phase == "menu": show_menu()

func make_bean_preview(parent: Node, equipment: Dictionary, dimensions: Vector2) -> SubViewportContainer:
	var container = SubViewportContainer.new()
	container.custom_minimum_size = dimensions
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(dimensions)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	# One actor, a light and a camera; do not duplicate the arena for cosmetic previews.
	var model = Court.new()
	viewport.add_child(model)
	model.actor_root = Node3D.new()
	model.add_child(model.actor_root)
	var actor: Dictionary = model._make_actor(1)
	model._equip_actor(actor, 1, equipment)
	actor.root.rotation.y = PI + 0.22
	for key in ["label", "marker", "arrow"]: actor[key].hide()
	var environment = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_CLEAR_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bddcff")
	settings.ambient_light_energy = 0.30 if equipment.get("character", "blank") != "blank" else 0.65
	environment.environment = settings
	model.add_child(environment)
	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -25, 0)
	key_light.light_energy = 0.22 if equipment.get("character", "blank") != "blank" else 1.55
	model.add_child(key_light)
	var fill_light = OmniLight3D.new()
	fill_light.position = Vector3(1, 2, 3)
	fill_light.light_energy = 0.035 if equipment.get("character", "blank") != "blank" else 0.65
	fill_light.omni_range = 5
	model.add_child(fill_light)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.85 if equipment.get("character", "blank") != "blank" else 2.65
	camera.current = true
	model.add_child(camera)
	camera.position = Vector3(0, 1.35, 4)
	camera.look_at(Vector3(0, 1.05, 0))
	var turn = container.create_tween().set_loops()
	turn.tween_property(actor.root, "rotation:y", PI - 0.32, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(actor.root, "rotation:y", PI + 0.22, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return container
