extends CanvasLayer

signal host_requested(name: String)
signal join_requested(address: String, name: String)
signal leave_requested()
signal quit_requested()
signal resume_requested()
signal power_chosen(id: String)
signal restart_requested()
signal next_course_requested()
signal appearance_chosen(style: Dictionary)

const Rules = preload("res://prototypes/physics_party/party_rules.gd")
const Courses = preload("res://prototypes/physics_party/party_courses.gd")
const Cosmetics = preload("res://prototypes/physics_party/party_cosmetics.gd")
const Modes = preload("res://prototypes/physics_party/party_modes.gd")
const MenuArt = preload("res://prototypes/physics_party/party_menu_art.gd")
const NAVY: Color = Color("142536")
const PANEL: Color = Color("243d52")
const CREAM: Color = Color("eee8dc")
const MINT: Color = Color("43d6cf")
const CORAL: Color = Color("ff9c44")
const MUTED: Color = Color("a9bbc8")
const OUTLINE: Color = Color("3c596c")
const MENU_INK: Color = Color("24332f")
const MENU_PAPER: Color = Color("f6f0dc")
const MENU_ORANGE: Color = Color("ee7544")
const MENU_MINT: Color = Color("8ecab3")
const MENU_MUTED: Color = Color("536158")
const CREDITS_PATH: String = "res://prototypes/physics_party/licenses/NOTICE.txt"
const CARD_ODDS: String = "Per card: Common 60% · Rare 28% · Epic 10% · Legendary 2%."

class CosmeticPreview extends Control:
	var paint := Color("ff9c44")
	var accessory: String = "none"
	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.55)
		draw_ellipse_shadow(center + Vector2(0, 100))
		for side: float in [-1.0, 1.0]:
			_round_box(Rect2(center + Vector2(side * 24 - 15, 50), Vector2(30, 52)), paint.darkened(0.1), 15)
			_round_box(Rect2(center + Vector2(side * 48 - 13, -5), Vector2(26, 72)), paint, 13)
		_round_box(Rect2(center + Vector2(-36, -16), Vector2(72, 78)), paint, 24)
		_round_box(Rect2(center + Vector2(-32, -82), Vector2(64, 62)), paint.lightened(0.08), 25)
		var ink := Color("243d52")
		match accessory:
			"cap":
				_round_box(Rect2(center + Vector2(-35, -91), Vector2(70, 26)), ink, 12)
				_round_box(Rect2(center + Vector2(-12, -71), Vector2(58, 9)), ink, 4)
			"beanie":
				_round_box(Rect2(center + Vector2(-35, -98), Vector2(70, 34)), Color("b591ff"), 18)
				draw_circle(center + Vector2(0, -103), 9, Color("eee8dc"))
			"sprout":
				draw_line(center + Vector2(0, -80), center + Vector2(0, -112), Color("58bb82"), 5, true)
				draw_circle(center + Vector2(-9, -110), 10, Color("81d6a1"))
				draw_circle(center + Vector2(10, -117), 11, Color("58bb82"))
			"headphones":
				draw_arc(center + Vector2(0, -53), 36, PI, TAU, 24, ink, 8, true)
				for side: float in [-1.0, 1.0]:
					_round_box(Rect2(center + Vector2(side * 35 - 7, -58), Vector2(14, 26)), Color("43d6cf"), 6)
			"crown":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-29, -76), center + Vector2(-33, -105), center + Vector2(-14, -92), center + Vector2(0, -113), center + Vector2(14, -92), center + Vector2(33, -105), center + Vector2(29, -76)]), Color("f2c355"))
			"halo":
				draw_arc(center + Vector2(0, -108), 29, 0, TAU, 32, Color("f2c355"), 5, true)
	func _round_box(rect: Rect2, color: Color, radius: int) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		draw_style_box(style, rect)
	func draw_ellipse_shadow(at: Vector2) -> void:
		draw_set_transform(at, 0, Vector2(1, 0.2))
		draw_circle(Vector2.ZERO, 60, Color(0, 0, 0, 0.15))
		draw_set_transform(Vector2.ZERO)

class FoilShine extends Control:
	var tint := Color("69b6ff")
	var clock: float = 0.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree(): return
		clock = fmod(clock + delta * 0.18, 1.0)
		queue_redraw()
	func _draw() -> void:
		var x: float = lerpf(-size.y - 70, size.x + 70, clock)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 25, 0), Vector2(x + size.y + 25, size.y), Vector2(x + size.y, size.y)]), Color(tint, 0.13))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 34, 0), Vector2(x + 42, 0), Vector2(x + size.y + 42, size.y), Vector2(x + size.y + 34, size.y)]), Color.WHITE * Color(1, 1, 1, 0.09))

class PartyBackdrop extends Control:
	func _draw() -> void:
		draw_circle(Vector2(size.x * 0.12, size.y * 0.58), size.y * 0.68, Color("e9e6cd"))
		draw_circle(Vector2(size.x - 18, -34), 153, Color("8ecab3"))
		for index: int in range(7):
			var x: float = 18 + index * 17
			draw_line(Vector2(x, size.y - 17), Vector2(x + 7, size.y - 25), Color("24332f"), 3, true)
		draw_circle(Vector2(size.x - 28, size.y - 26), 5, Color("ee7544"))
		draw_circle(Vector2(size.x - 47, size.y - 26), 5, Color("8ecab3"))
		draw_circle(Vector2(size.x - 66, size.y - 26), 5, Color("aaa0d8"))

class GrappleReticle extends Control:
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		draw_circle(center, 5.0, Color("142536"), false, 4.5, true)
		draw_arc(center, 5.0, 0.3, PI - 0.3, 12, Color.WHITE, 1.5, true)
		draw_arc(center, 5.0, PI + 0.3, TAU - 0.3, 12, Color.WHITE, 1.5, true)
		draw_circle(center, 1.2, Color.WHITE)

class PowerMark extends Control:
	var power_id: String = ""
	var ink: Color = Color("ff9c44")
	func _draw() -> void:
		var center: Vector2 = size * 0.5
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
var _course_restart: Button
var _leave: Button
var _name: LineEdit
var _address: LineEdit
var _course_selector: OptionButton
var _mode_buttons: Dictionary = {}
var _selected_mode: String = "coop"
var _active_mode: String = "coop"
var _mode_description: Label
var _menu_help: Label
var _menu_players: Label
var _menu_art: Control
var _controls: Label
var _status: Label
var _join_address: Label
var _join_address_row: HBoxContainer
var _copy_address: Button
var _host_address_to_copy: String = ""
var _course_title: Label
var _objective: Label
var _crew: Label
var _power: Label
var _note: Label
var _wind: Label
var _progress: Label
var _grapple_status: Label
var _grapple_reticle: Control
var _ending_detail: Label
var _ending_title: Label
var _ending_course: Label
var _restart: Button
var _next_course: Button
var _host_wait: Label
var _cards: HBoxContainer
var _offer_ids: Array[String] = []
var _collection: VBoxContainer
var _collected_buttons: HBoxContainer
var _owned_ids: Array[String] = []
var _in_session: bool = false
var _can_restart: bool = false
var _menu_customize: Button
var _draft_customize: Button
var _cosmetics: Control
var _credits: Control
var _credits_button: Button
var _credits_back: Button
var _credits_text: RichTextLabel
var _cosmetic_panel: Control
var _cosmetic_scroll: ScrollContainer
var _cosmetic_grid: GridContainer
var _cosmetic_preview: CosmeticPreview
var _cosmetic_description: Label
var _cosmetic_status: Label
var _cosmetic_owned: Array = []
var _cosmetic_kind: String = "color"
var _confirmed_appearance: Dictionary = {}
var _selected_appearance: Dictionary = {}
var _appearance_sent: bool = false
var _bag_button: Button
var _reward_row: HBoxContainer
var _reward_note: Label
var _reward_card_ids: Array = []
var _reward_duplicates: Array = []
var _reward_run_id: String = ""
var _bag_open: bool = false

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
	_build_cosmetics()
	_build_credits()
	show_menu()

func show_menu(status: String = "") -> void:
	if _root == null: return
	_menu.show()
	_game.hide()
	_draft.hide()
	_ending.hide()
	_cosmetics.hide()
	_credits.hide()
	_status.text = status
	_connection.visible = not _in_session
	_resume.visible = _in_session
	_course_restart.visible = _in_session and _can_restart
	_leave.visible = _in_session
	_menu_customize.visible = _in_session
	if not _in_session: _name.grab_focus()
	else: _resume.grab_focus()

func show_game() -> void:
	if _root == null: return
	_in_session = true
	_menu.hide()
	_cosmetics.hide()
	_credits.hide()
	_game.show()
	_refresh_grapple_visibility()

func reset_session(status: String = "") -> void:
	_in_session = false
	_can_restart = false
	_active_mode = _selected_mode
	_update_menu_copy(_selected_mode)
	_offer_ids.clear()
	_owned_ids.clear()
	_cosmetic_owned.clear()
	_confirmed_appearance.clear()
	_selected_appearance.clear()
	_reward_card_ids.clear()
	_reward_run_id = ""
	_bag_open = false
	if _collection != null: _collection.hide()
	if _join_address_row != null: _join_address_row.hide()
	_host_address_to_copy = ""
	show_menu(status)

func blocks_input() -> bool:
	return _menu == null or _menu.visible or _draft.visible or _ending.visible or (_cosmetics != null and _cosmetics.visible) or (_credits != null and _credits.visible)

func is_menu_open() -> bool:
	return (_menu != null and _menu.visible) or (_credits != null and _credits.visible)

func selected_course_id() -> String:
	if selected_mode_id() != "coop": return Courses.IDS[0]
	return Courses.IDS[_course_selector.selected] if _course_selector != null else Courses.IDS[0]

func selected_mode_id() -> String:
	return _selected_mode

func _select_mode(mode_id: String) -> void:
	if _in_session or mode_id not in Modes.IDS: return
	_selected_mode = mode_id
	for id: String in _mode_buttons:
		_mode_buttons[id].set_pressed_no_signal(id == mode_id)
	_course_selector.visible = mode_id == "coop"
	_update_menu_copy(mode_id)

func _update_menu_copy(mode_id: String) -> void:
	if _menu_art != null: _menu_art.mode_id = mode_id
	match mode_id:
		"knockout":
			_mode_description.text = "Stay on as sweepers speed up and the arena shrinks. Knock friends off. First to 3 wins."
			_menu_players.text = "2–3 PLAYERS TO COMPETE  /  SOLO PRACTICE"
			_menu_help.text = "WASD Move  ·  Mouse Look  ·  Space Jump\nLMB Swing  ·  Hold RMB Brace\nF Forfeit round  ·  M Mute  ·  Esc Menu\nJump the low sweeper. Avoid the high arm."
		"gladiator":
			_mode_description.text = "Padded sticks. Last one standing. First to 3 round wins."
			_menu_players.text = "2–3 PLAYERS TO COMPETE  /  SOLO PRACTICE"
			_menu_help.text = "WASD Move  ·  Mouse Look  ·  Space Jump\nLMB Swing  ·  Hold RMB Brace\nF Forfeit round  ·  M Mute  ·  Esc Menu\nKnock your friends off. Keep your balance."
		"wipeout":
			_mode_description.text = "Race the sweepers and balance beams. Fastest finish wins."
			_menu_players.text = "1–3 PLAYERS  /  SOLO RUN OR RACE FRIENDS"
			_menu_help.text = "WASD Move  ·  Mouse Look  ·  Space Jump\nF Return to checkpoint  ·  M Mute  ·  Esc Menu\nTime your jumps. Stay on the platforms.\nYour finish time and falls are recorded."
		_:
			_mode_description.text = "20 courses. 3 players required to clear. Solo exploration welcome."
			_menu_players.text = "EXPLORE SOLO  /  3 PLAYERS TO CLEAR LEVELS"
			_menu_help.text = "WASD Move  ·  Mouse Look  ·  Space Jump\nLMB / RMB Grab  ·  Q Grapple  ·  G Pull / Swing\nHold E Operate / E Fan  ·  R Flop  ·  F Recover\nM Mute  ·  Esc Menu"

func update_grapple(mode: String, active: bool, target_ready: bool = false) -> void:
	if _grapple_status == null: return
	var mode_name: String = "Swing" if mode == "swing" else "Pull"
	_grapple_status.text = "%s  /  %s  ·  G Switch" % [mode_name, "Release Q to detach" if active else "Hold Q Grapple"]
	_grapple_status.add_theme_color_override("font_color", CORAL if active else MINT)
	_grapple_reticle.modulate = CORAL if active else (MINT if target_ready else Color(CREAM, 0.65))
	_refresh_grapple_visibility()

func _refresh_grapple_visibility() -> void:
	if _grapple_reticle != null:
		_grapple_reticle.visible = _active_mode == "coop" and not blocks_input()
	if _grapple_status != null:
		_grapple_status.visible = _active_mode == "coop"

func update_view(data: Dictionary, local_id: String, is_host: bool) -> void:
	if _root == null: return
	_active_mode = str(data.get("mode_id", "coop"))
	if _active_mode not in Modes.IDS: _active_mode = "coop"
	var is_coop: bool = _active_mode == "coop"
	_update_menu_copy(_active_mode)
	var course_id: String = str(data.get("course_id", Courses.IDS[0]))
	var course_name: String = str(data.get("course_name", Courses.course_name(course_id)))
	var numbered_name: String = "%02d / %d · %s" % [Courses.number(course_id), Courses.IDS.size(), course_name]
	_course_title.text = numbered_name if is_coop else Modes.mode_name(_active_mode)
	_ending_course.text = _course_title.text
	var players: Dictionary = data.get("players", {})
	var address: String = str(data.get("join_address", "")).strip_edges()
	_join_address.text = "Join: " + address
	_join_address_row.visible = is_host and _in_session and not address.is_empty()
	var first_address: String = address.get_slice("/", 0).strip_edges()
	_host_address_to_copy = first_address if is_host and _in_session and first_address.is_valid_ip_address() else ""
	_copy_address.visible = not _host_address_to_copy.is_empty()
	_copy_address.tooltip_text = "Copy " + _host_address_to_copy
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
	if data.has("teamwork_text"):
		_objective.text = str(data.teamwork_text)
	if not is_coop: _objective.text = str(data.get("mode_text", "Stay on the platform" if _active_mode in ["gladiator", "knockout"] else "Reach the finish"))
	_objective.tooltip_text = _objective.text
	_wind.text = "WIND →" if int(data.get("wind", 1)) > 0 else "← WIND"
	_wind.add_theme_color_override("font_color", CORAL if int(data.get("wind", 0)) > 0 else MINT)
	var owned: Array[String] = []
	for id: String in data.get("unlocked_power_ids", []):
		if not Rules.power_info(id).is_empty() and id not in owned:
			owned.append(id)
	if owned != _owned_ids:
		_owned_ids = owned
		_rebuild_collected()
	_collection.visible = is_coop and not owned.is_empty()
	var clear_count: int = int(data.get("completions", 0))
	var clears_text: String = "%d %s" % [clear_count, "clear" if clear_count == 1 else "clears"]
	_progress.text = "%d/5 powers collected · %s" % [owned.size(), clears_text]
	_note.text = str(data.get("teamwork_hint", data.get("note", ""))) if is_coop else str(data.get("mode_hint", ""))
	var power_id: String = str(me.get("power", ""))
	var info: Dictionary = Rules.power_info(power_id)
	_power.text = str(info.get("name", "PICK YOUR POWER"))
	_power.visible = is_coop
	_controls.text = "WASD Move   SPACE Jump   LMB / RMB Grab   Hold E Operate / E Fan   F Recover   ESC Menu"
	_course_restart.text = "Restart course" if is_coop else "Restart match" if _active_mode in ["gladiator", "knockout"] else "Restart race"
	_course_restart.tooltip_text = "Starts this course again for everyone." if is_coop else "Starts a new match for everyone." if _active_mode in ["gladiator", "knockout"] else "Starts a new race for everyone."
	if _active_mode in ["gladiator", "knockout"]:
		var match_data: Dictionary = data.get("match", {})
		_wind.text = "ROUND %d · FIRST TO 3" % maxi(1, int(match_data.get("round", 1)))
		_progress.text = _score_lines(players, match_data.get("scores", {}), "   ")
		_controls.text = "WASD Move   SPACE Jump   LMB Swing   Hold RMB Brace   F Forfeit round   ESC Menu"
		var match_phase: String = str(match_data.get("phase", "practice"))
		if str(data.get("phase", "play")) != "complete" and match_phase in ["fight", "intermission"]:
			if local_id not in match_data.get("alive", []):
				_note.text = "Watching — back next round.\nYou'll rejoin automatically."
				_controls.text = "M Mute   ESC Menu"
			elif match_phase == "intermission":
				_note.text = "Round won — next round starts automatically." if str(match_data.get("round_winner", "")) == local_id else "Next round starts automatically."
				_controls.text = "M Mute   ESC Menu"
	elif _active_mode == "wipeout":
		var challenge: Dictionary = data.get("challenge", {})
		var runner: Dictionary = challenge.get("runners", {}).get(local_id, {})
		var shown_time: float = float(runner.get("time", 0.0)) if bool(runner.get("finished", false)) else float(challenge.get("elapsed", 0.0))
		_wind.text = "TIME " + _race_time(shown_time)
		_progress.text = "Checkpoint %d · %d falls" % [int(runner.get("checkpoint", 0)), int(runner.get("falls", 0))]
		_controls.text = "WASD Move   SPACE Jump   F Return to checkpoint   ESC Menu"
	var complete: bool = str(data.get("phase", "play")) == "complete"
	_can_restart = is_host and not complete
	_course_restart.visible = _in_session and _can_restart
	var choices: Array[String] = []
	for id: String in data.get("offers", {}).get(local_id, []):
		if not Rules.power_info(id).is_empty() and id not in choices:
			choices.append(id)
	if choices != _offer_ids:
		_offer_ids = choices
		_rebuild_cards()
	_draft.visible = is_coop and not _menu.visible and not complete and power_id.is_empty() and (not choices.is_empty() or not owned.is_empty())
	_ending.visible = not _menu.visible and complete
	_refresh_grapple_visibility()
	_restart.visible = is_host
	_host_wait.visible = not is_host
	var save_failed: bool = bool(data.get("save_failed", false))
	var next_name: String = str(data.get("next_course_name", Courses.course_name(Courses.next_id(course_id))))
	_next_course.visible = is_coop and is_host and not save_failed and not next_name.is_empty()
	_next_course.text = "Next course · " + next_name
	_restart.text = "Retry save" if save_failed else "Play again"
	_host_wait.text = "Waiting for the host to retry saving…" if save_failed else "Waiting for the host…"
	_ending_detail.text = "Progress not saved.\nRetry to keep this clear." if save_failed else "%d/5 powers collected\n%s · Crew level %d" % [owned.size(), clears_text, int(data.get("level", 1))]
	_ending_title.text = "EVERYONE MADE IT"
	if _active_mode in ["gladiator", "knockout"]:
		var match_data: Dictionary = data.get("match", {})
		var winner: String = str(match_data.get("winner", ""))
		_ending_title.text = (_player_name(players, winner) + " WINS") if not winner.is_empty() else "MATCH COMPLETE"
		if not save_failed: _ending_detail.text = _score_lines(players, match_data.get("scores", {}), "\n")
	elif _active_mode == "wipeout":
		_ending_title.text = "COURSE COMPLETE"
		if not save_failed: _ending_detail.text = _race_results(players, data.get("challenge", {}).get("results", {}))
	_ending_detail.add_theme_color_override("font_color", CORAL if save_failed else CREAM)
	_update_cosmetics(data, me)
	# The server awards bags. A later disconnect cannot revoke a committed reward.
	_update_rewards(data, complete and not save_failed)

func _player_name(players: Dictionary, id: String) -> String:
	return str(players.get(id, {}).get("name", "Player")).left(24)

func _score_lines(players: Dictionary, scores: Dictionary, separator: String) -> String:
	var lines: PackedStringArray = []
	for id: String in players:
		lines.append("%s · %d" % [_player_name(players, id), int(scores.get(id, 0))])
	return separator.join(lines)

func _race_time(seconds: float) -> String:
	var centiseconds: int = maxi(0, int(roundf(seconds * 100.0)))
	return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func _race_results(players: Dictionary, results: Dictionary) -> String:
	var lines: PackedStringArray = []
	for id: String in players:
		var result: Dictionary = results.get(id, {})
		var finish_time: String = _race_time(float(result.get("time", 0.0))) if bool(result.get("finished", not result.is_empty())) else "DNF"
		var falls: int = int(result.get("falls", 0))
		lines.append("%s · %s · %d %s" % [_player_name(players, id), finish_time, falls, "fall" if falls == 1 else "falls"])
	return "\n".join(lines)

func _unhandled_key_input(event: InputEvent) -> void:
	if _credits != null and _credits.visible and event is InputEventKey and event.pressed:
		var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if key == KEY_ESCAPE:
			_close_credits()
			get_viewport().set_input_as_handled()
			return
		var scroll := _credits_text.get_v_scroll_bar()
		match key:
			KEY_PAGEDOWN: scroll.value += scroll.page * 0.85
			KEY_PAGEUP: scroll.value -= scroll.page * 0.85
			KEY_HOME: scroll.value = scroll.min_value
			KEY_END: scroll.value = scroll.max_value
			_: return
		get_viewport().set_input_as_handled()
		return
	if _cosmetics.visible or not _draft.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = int(event.physical_keycode) - KEY_1
	if index >= 0 and index < _offer_ids.size():
		power_chosen.emit(_offer_ids[index])
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	_menu = _scrim(MENU_PAPER)
	_menu.theme = _menu_theme()
	var backdrop := PartyBackdrop.new()
	_full(backdrop)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.resized.connect(backdrop.queue_redraw)
	_menu.add_child(backdrop)
	var center := CenterContainer.new()
	_full(center)
	_menu.add_child(center)
	var split := HBoxContainer.new()
	split.custom_minimum_size.x = 870
	split.add_theme_constant_override("separation", 36)
	center.add_child(split)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 420
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_theme_constant_override("separation", 0)
	split.add_child(brand)
	_label(brand, "SMALL CREW. BIG TROUBLE.", 12, MENU_INK)
	var title := _label(brand, "HANDS FULL", 52, MENU_INK)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Arial Black", "Arial"])
	title_font.font_weight = 900
	title.add_theme_font_override("font", title_font)
	_label(brand, "Bad balance. Good company.", 21, MENU_INK)
	_menu_art = MenuArt.new()
	_menu_art.name = "PartyTheatre"
	_menu_art.custom_minimum_size = Vector2(420, 228)
	_menu_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(_menu_art)
	_menu_players = _label(brand, "", 12, MENU_INK)
	_menu_help = _label(brand, "", 12, MENU_MUTED)
	_menu_help.add_theme_constant_override("line_spacing", 4)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 414
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := _style(Color("fff9e9"), MENU_INK)
	panel_style.set_corner_radius_all(14)
	panel_style.set_border_width_all(2)
	panel_style.shadow_color = Color(MENU_INK, 0.17)
	panel_style.shadow_size = 0
	panel_style.shadow_offset = Vector2(6, 7)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 17
	panel_style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	split.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_label(box, "LET'S PLAY", 25, MENU_INK)
	_mode_description = _label(box, "", 14, MENU_MUTED)
	_mode_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_description.custom_minimum_size.y = 36
	_connection = VBoxContainer.new()
	_connection.add_theme_constant_override("separation", 7)
	box.add_child(_connection)
	var mode_row := GridContainer.new()
	mode_row.columns = 2
	mode_row.add_theme_constant_override("h_separation", 6)
	mode_row.add_theme_constant_override("v_separation", 6)
	_connection.add_child(mode_row)
	for mode_id: String in Modes.IDS:
		var mode_button := _menu_button(mode_row, Modes.mode_name(mode_id), Color("f1ecd9"))
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = 32
		mode_button.add_theme_font_size_override("font_size", 14)
		mode_button.toggle_mode = true
		mode_button.add_theme_stylebox_override("pressed", _menu_style(MENU_MINT, MENU_INK))
		mode_button.set_pressed_no_signal(mode_id == _selected_mode)
		mode_button.pressed.connect(_select_mode.bind(mode_id))
		_mode_buttons[mode_id] = mode_button
	_label(_connection, "YOUR NAME", 11, MENU_MUTED)
	_name = LineEdit.new()
	_name.placeholder_text = "What should we call you?"
	_name.max_length = 24
	_name.custom_minimum_size.y = 34
	_connection.add_child(_name)
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 7)
	_connection.add_child(host_row)
	_course_selector = OptionButton.new()
	_course_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_course_selector.custom_minimum_size.y = 38
	_course_selector.tooltip_text = "Choose any of the 20 levels. Joining uses the host's level."
	_course_selector.fit_to_longest_item = false
	_course_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_course_selector.get_popup().max_size = Vector2i(640, 360)
	for id: String in Courses.IDS:
		_course_selector.add_item("%02d · %s" % [Courses.number(id), Courses.course_name(id)])
	host_row.add_child(_course_selector)
	var host: Button = _menu_button(host_row, "Host game", MENU_ORANGE)
	host.custom_minimum_size.x = 126
	host.custom_minimum_size.y = 38
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.tooltip_text = "Start on this PC. Your friends join using the address shown in the game menu."
	host.pressed.connect(_host_from_menu)
	_name.text_submitted.connect(func(_text: String) -> void: _host_from_menu())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_connection.add_child(row)
	_address = LineEdit.new()
	_address.placeholder_text = "Friend's host IP address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.custom_minimum_size.y = 36
	_address.tooltip_text = "Ask the host for the Join address in their Esc menu. Use the same home network."
	row.add_child(_address)
	var join: Button = _menu_button(row, "Join", MENU_MINT)
	join.custom_minimum_size.x = 82
	join.custom_minimum_size.y = 36
	join.pressed.connect(_join)
	_address.text_submitted.connect(func(_text: String) -> void: _join())
	_join_address_row = HBoxContainer.new()
	_join_address_row.add_theme_constant_override("separation", 7)
	box.add_child(_join_address_row)
	_join_address = _label(_join_address_row, "", 14, MENU_INK)
	_join_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_address = _menu_button(_join_address_row, "Copy address", Color("f1ecd9"))
	_copy_address.custom_minimum_size.y = 28
	_copy_address.add_theme_font_size_override("font_size", 12)
	_copy_address.pressed.connect(func() -> void:
		if _host_address_to_copy.is_empty(): return
		DisplayServer.clipboard_set(_host_address_to_copy)
		_status.text = "Address copied. Share it with the other PCs.")
	_join_address_row.hide()
	_resume = _menu_button(box, "Back to game", MENU_ORANGE)
	_resume.pressed.connect(func() -> void:
		show_game()
		resume_requested.emit())
	_menu_customize = _menu_button(box, "Customize character", MENU_MINT)
	_menu_customize.pressed.connect(show_cosmetics)
	_course_restart = _menu_button(box, "Restart course", Color("f1ecd9"))
	_course_restart.tooltip_text = "Restarts for everyone. Collected powers stay saved."
	_course_restart.pressed.connect(func() -> void: restart_requested.emit())
	_leave = _menu_button(box, "Leave game", Color("f1ecd9"))
	_leave.pressed.connect(func() -> void: leave_requested.emit())
	_status = _label(box, "", 13, Color("9b331a"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 30
	_label(box, "One PC hosts. Same Wi-Fi. Everyone piles in.", 12, MENU_MUTED)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 7)
	box.add_child(footer)
	_credits_button = _menu_button(footer, "Credits", Color("fff9e9"))
	_credits_button.custom_minimum_size.y = 29
	_credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_button.add_theme_font_size_override("font_size", 13)
	_credits_button.pressed.connect(show_credits)
	var quit: Button = _menu_button(footer, "Quit game", Color("fff9e9"))
	quit.custom_minimum_size.y = 29
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.add_theme_font_size_override("font_size", 13)
	quit.pressed.connect(func() -> void: quit_requested.emit())
	_update_menu_copy(_selected_mode)

func _build_credits() -> void:
	_credits = _scrim(MENU_PAPER)
	_credits.theme = _menu_theme()
	var box := _center_box(_credits, 820)
	box.add_theme_constant_override("separation", 10)
	_label(box, "HANDS FULL / CREDITS", 26, MENU_INK)
	_label(box, "The people and tools behind the chaos.", 14, MENU_MUTED)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _menu_style(Color("fffdf5"), Color("8d9887")))
	box.add_child(panel)
	_credits_text = RichTextLabel.new()
	_credits_text.custom_minimum_size = Vector2(0, 324)
	_credits_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_text.bbcode_enabled = false
	_credits_text.selection_enabled = true
	_credits_text.scroll_active = true
	_credits_text.focus_mode = Control.FOCUS_ALL
	_credits_text.add_theme_color_override("default_color", MENU_INK)
	_credits_text.add_theme_font_size_override("normal_font_size", 14)
	_credits_text.text = FileAccess.get_file_as_string(CREDITS_PATH) if FileAccess.file_exists(CREDITS_PATH) else "Hands Full\nCredits unavailable in this build."
	panel.add_child(_credits_text)
	_label(box, "Scroll or use Page Up / Page Down. Esc goes back.", 12, MENU_MUTED)
	_credits_back = _menu_button(box, "Back to menu", MENU_MINT)
	_credits_back.custom_minimum_size.y = 36
	_credits_back.pressed.connect(_close_credits)
	_credits_text.focus_next = _credits_text.get_path_to(_credits_back)
	_credits_text.focus_previous = _credits_text.focus_next
	_credits_back.focus_next = _credits_back.get_path_to(_credits_text)
	_credits_back.focus_previous = _credits_back.focus_next
	_credits.hide()

func show_credits() -> void:
	_menu.hide()
	_credits.show()
	_credits_back.grab_focus()
	_refresh_grapple_visibility()

func _close_credits() -> void:
	show_menu(_status.text)
	_credits_button.grab_focus()

func _host_from_menu() -> void:
	if _name.text.strip_edges().is_empty():
		_status.text = "Enter your name."
		_name.grab_focus()
	else:
		_status.text = "Starting…"
		host_requested.emit(_name.text.strip_edges())

func _menu_style(color: Color, border: Color = MENU_INK) -> StyleBoxFlat:
	var style := _style(color, border)
	style.set_corner_radius_all(7)
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.set_border_width_all(1)
	return style

func _menu_button(parent: Node, text: String, color: Color) -> Button:
	var button := _button(parent, text, color)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, MENU_INK)
	button.add_theme_stylebox_override("normal", _menu_style(color))
	button.add_theme_stylebox_override("hover", _menu_style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _menu_style(color.darkened(0.06)))
	var focus := _menu_style(Color.TRANSPARENT, Color("9b331a"))
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _menu_theme() -> Theme:
	var theme := _theme()
	for type: String in ["LineEdit", "OptionButton"]:
		theme.set_stylebox("normal", type, _menu_style(Color("fffdf5"), Color("8d9887")))
		theme.set_stylebox("focus", type, _menu_style(Color("fffdf5"), MENU_INK))
		theme.set_stylebox("hover", type, _menu_style(Color("ffffff"), MENU_INK))
		theme.set_stylebox("pressed", type, _menu_style(MENU_MINT))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, MENU_INK)
	theme.set_color("font_placeholder_color", "LineEdit", MENU_MUTED)
	theme.set_color("caret_color", "LineEdit", MENU_INK)
	theme.set_color("selection_color", "LineEdit", MENU_MINT)
	theme.set_stylebox("panel", "PopupMenu", _menu_style(Color("fffdf5")))
	theme.set_stylebox("hover", "PopupMenu", _menu_style(MENU_MINT))
	theme.set_color("font_color", "PopupMenu", MENU_INK)
	theme.set_color("font_hover_color", "PopupMenu", MENU_INK)
	return theme

func _join() -> void:
	if _name.text.strip_edges().is_empty():
		_status.text = "Enter your name."
		_name.grab_focus()
	elif _address.text.strip_edges().is_empty():
		_status.text = "Enter the host's IP address."
		_address.grab_focus()
	else:
		_status.text = "Joining…"
		join_requested.emit(_address.text.strip_edges(), _name.text.strip_edges())

func _build_game() -> void:
	_game = Control.new()
	_full(_game)
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_game)
	_grapple_reticle = GrappleReticle.new()
	_grapple_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grapple_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_grapple_reticle.offset_left = -11
	_grapple_reticle.offset_right = 11
	_grapple_reticle.offset_top = -11
	_grapple_reticle.offset_bottom = 11
	_game.add_child(_grapple_reticle)
	var top: MarginContainer = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_margin(top, 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var left_plate: PanelContainer = _backplate(row)
	left_plate.custom_minimum_size.x = 330
	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_plate.add_child(left)
	left.add_theme_constant_override("separation", 3)
	_course_title = _label(left, Courses.course_name(Courses.IDS[0]), 12, CORAL)
	_objective = _label(left, "Get everyone across", 19, CREAM)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.max_lines_visible = 2
	_objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_crew = _label(left, "", 12, MUTED)
	_crew.clip_text = true
	_crew.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var right_plate: PanelContainer = _backplate(row)
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_plate.add_child(right)
	_wind = _label(right, "WIND →", 13, MINT)
	_progress = _label(right, "0/5 powers collected · 0 clears", 12, MUTED)
	_progress.custom_minimum_size.x = 238
	_progress.clip_text = true
	_progress.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_wind.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bottom_plate: PanelContainer = _backplate(_game)
	bottom_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bottom_plate.offset_left = 20
	bottom_plate.offset_right = 350
	bottom_plate.offset_top = 124
	bottom_plate.offset_bottom = 124
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	bottom_plate.add_child(bottom)
	_power = _label(bottom, "", 12, CORAL)
	_grapple_status = _label(bottom, "Pull  /  Hold Q Grapple  ·  G Switch", 12, MINT)
	_note = _label(bottom, "", 13, CREAM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := MarginContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -44
	_margin(footer, 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(footer)
	_controls = _label(footer, "WASD Move   SPACE Jump   LMB / RMB Grab   Hold E Operate / E Fan   F Recover   ESC Menu", 12, CREAM)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_color_override("font_shadow_color", Color(NAVY, 0.95))
	_controls.add_theme_constant_override("shadow_offset_x", 1)
	_controls.add_theme_constant_override("shadow_offset_y", 1)

func _build_draft() -> void:
	_draft = _scrim(Color(NAVY, 0.95))
	var box: VBoxContainer = _center_box(_draft, 740)
	box.add_theme_constant_override("separation", 14)
	var eyebrow := _label(box, "CREW EQUIPMENT / CHOOSE YOUR EDGE", 12, CORAL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title: Label = _label(box, "PICK A POWER", 34, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(box, "Press 1, 2 or 3. Get everyone across to keep it.", 14, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	box.add_child(_cards)
	_collection = VBoxContainer.new()
	_collection.add_theme_constant_override("separation", 8)
	box.add_child(_collection)
	var heading: Label = _label(_collection, "YOUR COLLECTION / PICK ANY", 12, MINT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collected_buttons = HBoxContainer.new()
	_collected_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_collected_buttons.add_theme_constant_override("separation", 8)
	_collection.add_child(_collected_buttons)
	_collection.hide()
	_draft_customize = _button(box, "Customize character", PANEL)
	_draft_customize.pressed.connect(show_cosmetics)

func _rebuild_collected() -> void:
	for child: Node in _collected_buttons.get_children():
		_collected_buttons.remove_child(child)
		child.queue_free()
	for id: String in _owned_ids:
		var info: Dictionary = Rules.power_info(id)
		var button: Button = _button(_collected_buttons, str(info.name), PANEL)
		button.custom_minimum_size.y = 38
		button.add_theme_font_size_override("font_size", 13)
		button.tooltip_text = str(info.description)
		button.pressed.connect(func() -> void: power_chosen.emit(id))

func _rebuild_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for index: int in range(_offer_ids.size()):
		var id: String = _offer_ids[index]
		var info: Dictionary = Rules.power_info(id)
		var accent: Color = [CORAL, MINT, Color("f2c355")][index % 3]
		var card: Button = _button(_cards, "", PANEL)
		card.custom_minimum_size = Vector2(230, 234)
		var card_style := _style(Color("1b3043"), OUTLINE)
		card_style.border_width_top = 3
		card_style.border_color = accent
		card.add_theme_stylebox_override("normal", card_style)
		card.add_theme_stylebox_override("hover", _style(PANEL.lightened(0.08), accent))
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
		_label(box, "%02d / SELECT" % (index + 1), 12, accent)
		var mark: PowerMark = PowerMark.new()
		mark.power_id = id
		mark.ink = accent
		mark.custom_minimum_size.y = 66
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mark)
		_label(box, str(info.name), 19, CREAM)
		var description: Label = _label(box, str(info.description), 14, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(func() -> void: power_chosen.emit(id))

func _build_ending() -> void:
	_ending = _scrim(Color(NAVY, 0.97))
	var box: VBoxContainer = _center_box(_ending, 740)
	box.add_theme_constant_override("separation", 9)
	_ending_title = _label(box, "EVERYONE MADE IT", 32, CREAM)
	_ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_title.clip_text = true
	_ending_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ending_course = _label(box, "", 14, MINT)
	_ending_course.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_detail = _label(box, "", 15, CREAM)
	_ending_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_detail.clip_text = true
	_bag_button = _button(box, "Open surprise bag", MINT)
	_bag_button.pressed.connect(_open_reward_bag)
	_bag_button.hide()
	_reward_note = _label(box, "One clear, three surprise cards.\n" + CARD_ODDS, 13, MUTED)
	_reward_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_note.hide()
	_reward_row = HBoxContainer.new()
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", 14)
	box.add_child(_reward_row)
	_reward_row.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_next_course = _button(actions, "Next course", CORAL)
	_next_course.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_course.pressed.connect(func() -> void: next_course_requested.emit())
	_restart = _button(actions, "Play again", PANEL)
	_restart.custom_minimum_size.x = 132
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_host_wait = _label(box, "Waiting for the host…", 17, MUTED)
	_host_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var leave: Button = _button(actions, "Leave game", PANEL)
	leave.custom_minimum_size.x = 132
	leave.pressed.connect(func() -> void: leave_requested.emit())

func _build_cosmetics() -> void:
	_cosmetics = _scrim(Color(NAVY, 0.98))
	var center := CenterContainer.new()
	_full(center)
	_cosmetics.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(846, 460)
	var panel_style := _style(Color("20374a"), OUTLINE)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	_cosmetic_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label(heading, "MAKE IT YOURS", 26, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(heading, "Done", PANEL)
	close.custom_minimum_size.x = 90
	close.pressed.connect(hide_cosmetics)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size.x = 210
	body.add_child(preview_column)
	_cosmetic_preview = CosmeticPreview.new()
	_cosmetic_preview.custom_minimum_size = Vector2(210, 256)
	_cosmetic_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_column.add_child(_cosmetic_preview)
	_cosmetic_description = _label(preview_column, "", 14, CREAM)
	_cosmetic_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cosmetic_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 10)
	body.add_child(options)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	options.add_child(tabs)
	for kind: String in ["color", "accessory"]:
		var tab := _button(tabs, "Colors" if kind == "color" else "Accessories", PANEL)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_cosmetic_kind.bind(kind))
	_cosmetic_scroll = ScrollContainer.new()
	_cosmetic_scroll.custom_minimum_size = Vector2(548, 258)
	_cosmetic_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cosmetic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options.add_child(_cosmetic_scroll)
	_cosmetic_grid = GridContainer.new()
	_cosmetic_grid.columns = 3
	_cosmetic_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cosmetic_grid.add_theme_constant_override("h_separation", 8)
	_cosmetic_grid.add_theme_constant_override("v_separation", 8)
	_cosmetic_scroll.add_child(_cosmetic_grid)
	_cosmetic_status = _label(box, "Finish courses or multiplayer matches for surprise bags.\n" + CARD_ODDS, 13, MUTED)
	_cosmetic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var apply := _button(box, "Apply look", MINT)
	apply.pressed.connect(_apply_appearance)
	_cosmetics.hide()


func show_cosmetics() -> void:
	if not _in_session: return
	_selected_appearance = _confirmed_appearance.duplicate()
	if _selected_appearance.is_empty(): _selected_appearance = Cosmetics.default_style(0)
	_appearance_sent = false
	_cosmetic_status.text = "Finish courses or multiplayer matches for surprise bags.\n" + CARD_ODDS
	_cosmetics.show()
	_show_cosmetic_kind("color")
	_refresh_grapple_visibility()


func hide_cosmetics() -> void:
	_cosmetics.hide()
	_refresh_grapple_visibility()


func _show_cosmetic_kind(kind: String) -> void:
	_cosmetic_kind = kind
	_cosmetic_scroll.scroll_vertical = 0
	_rebuild_cosmetic_choices()


func _update_cosmetics(data: Dictionary, me: Dictionary) -> void:
	var owned: Array = data.get("cosmetic_cards", [])
	var appearance: Dictionary = me.get("appearance", Cosmetics.default_style(0))
	var owned_changed: bool = owned != _cosmetic_owned
	_cosmetic_owned = owned.duplicate()
	_confirmed_appearance = appearance.duplicate()
	if not _cosmetics.visible:
		_selected_appearance = _confirmed_appearance.duplicate()
	elif _appearance_sent and _selected_appearance == _confirmed_appearance:
		_appearance_sent = false
		_cosmetic_status.text = "Your look is ready."
	var error: String = str(data.get("appearance_error", ""))
	if not error.is_empty():
		_cosmetic_status.text = error
		_cosmetic_status.add_theme_color_override("font_color", CORAL)
	else:
		_cosmetic_status.add_theme_color_override("font_color", MUTED)
	if owned_changed and _cosmetics.visible: _rebuild_cosmetic_choices()


func _rebuild_cosmetic_choices() -> void:
	for child: Node in _cosmetic_grid.get_children():
		_cosmetic_grid.remove_child(child)
		child.queue_free()
	var choices: Array = Cosmetics.colors(_cosmetic_owned) if _cosmetic_kind == "color" else Cosmetics.accessories(_cosmetic_owned)
	for option: Dictionary in choices:
		var id: String = str(option.id)
		var unlocked: bool = bool(option.unlocked)
		var rarity: String = str(option.get("rarity", "common"))
		var selected: bool = _selected_appearance.get(_cosmetic_kind, "") == id
		var name_text: String = str(option.name)
		var detail: String = rarity.capitalize() + (" · Selected" if selected else ("" if unlocked else " · Locked"))
		var button := _button(_cosmetic_grid, name_text + "\n" + detail, Color("29465b"))
		button.custom_minimum_size = Vector2(168, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = not unlocked
		button.tooltip_text = "Found in surprise bags" if not unlocked else "Choose " + name_text
		button.set_meta("cosmetic_kind", _cosmetic_kind)
		button.set_meta("cosmetic_value", id)
		button.set_meta("rarity", rarity)
		var border: Color = MINT if selected else _rarity_color(rarity)
		var normal := _style(Color("29465b"), Color(border, 0.8))
		normal.set_corner_radius_all(12)
		button.add_theme_stylebox_override("normal", normal)
		var disabled := _style(Color("203246"), Color(border, 0.35))
		disabled.set_corner_radius_all(12)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_color_override("font_disabled_color", Color("8799a8"))
		button.pressed.connect(_choose_cosmetic.bind(_cosmetic_kind, id, unlocked))
	_refresh_cosmetic_preview()


func _choose_cosmetic(kind: String, id: String, unlocked: bool) -> void:
	if not unlocked: return
	_selected_appearance[kind] = id
	_appearance_sent = false
	_cosmetic_status.text = "Like this look? Apply it when you’re ready."
	_rebuild_cosmetic_choices()


func _apply_appearance() -> void:
	if _selected_appearance.is_empty(): return
	_appearance_sent = true
	_cosmetic_status.text = "Updating your look…"
	appearance_chosen.emit(_selected_appearance.duplicate())


func _refresh_cosmetic_preview() -> void:
	var color_id: String = str(_selected_appearance.get("color", "orange"))
	var accessory_id: String = str(_selected_appearance.get("accessory", "none"))
	_cosmetic_preview.paint = Cosmetics.color_for(color_id)
	_cosmetic_preview.accessory = accessory_id
	_cosmetic_preview.queue_redraw()
	var color_name: String = color_id.capitalize()
	var accessory_name: String = "No accessory" if accessory_id == "none" else accessory_id.capitalize()
	for option: Dictionary in Cosmetics.colors(_cosmetic_owned):
		if option.id == color_id: color_name = str(option.name)
	for option: Dictionary in Cosmetics.accessories(_cosmetic_owned):
		if option.id == accessory_id: accessory_name = str(option.name)
	_cosmetic_description.text = color_name + "\n" + accessory_name


func _update_rewards(data: Dictionary, available: bool) -> void:
	var cards: Array = []
	for card_id: Variant in data.get("reward_cards", []):
		if card_id is String and not Cosmetics.card_info(card_id).is_empty() and cards.size() < 3:
			cards.append(card_id)
	var reward_id: String = str(data.get("reward_run_id", ""))
	if reward_id != _reward_run_id or cards != _reward_card_ids:
		_reward_run_id = reward_id
		_reward_card_ids = cards
		_reward_duplicates = data.get("reward_duplicates", []).duplicate()
		_bag_open = false
		_rebuild_reward_cards()
	_bag_button.visible = available and not cards.is_empty() and not _bag_open
	_reward_note.visible = available and not cards.is_empty()
	_reward_row.visible = available and _bag_open


func _open_reward_bag() -> void:
	if _reward_card_ids.is_empty(): return
	_bag_open = true
	_bag_button.hide()
	_reward_row.show()
	_reward_note.text = "Your cards are saved. Tap each one to reveal it.\n" + CARD_ODDS


func _rebuild_reward_cards() -> void:
	for child: Node in _reward_row.get_children():
		_reward_row.remove_child(child)
		child.queue_free()
	_reward_note.text = "One clear, three surprise cards. Open your bag to see what you found.\n" + CARD_ODDS
	for index in _reward_card_ids.size():
		var card_id: String = str(_reward_card_ids[index])
		var info: Dictionary = Cosmetics.card_info(card_id)
		var card := _button(_reward_row, "?\nTap to reveal", PANEL)
		card.custom_minimum_size = Vector2(220, 194)
		card.clip_contents = true
		card.set_meta("reward_card_id", card_id)
		card.set_meta("revealed", false)
		card.set_meta("rarity", str(info.rarity))
		card.set_meta("duplicate", card_id in _reward_duplicates or card_id in _reward_card_ids.slice(0, index))
		card.set_meta("foil", str(info.rarity) != "common")
		card.add_theme_font_size_override("font_size", 20)
		var card_style := _style(Color("314b62"), Color("658299"))
		card_style.set_corner_radius_all(16)
		card.add_theme_stylebox_override("normal", card_style)
		card.pressed.connect(_reveal_reward_card.bind(card, info))


func _reveal_reward_card(card: Button, info: Dictionary) -> void:
	if bool(card.get_meta("revealed", false)): return
	card.set_meta("revealed", true)
	var rarity: String = str(info.rarity)
	var accent: Color = _rarity_color(rarity)
	card.text = ""
	var card_style := _style(Color("263b51"), accent)
	card_style.set_corner_radius_all(16)
	card_style.set_border_width_all(2)
	card.add_theme_stylebox_override("normal", card_style)
	card.add_theme_stylebox_override("hover", card_style)
	var inset := MarginContainer.new()
	_full(inset)
	_margin(inset, 14)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	inset.add_child(box)
	var rarity_label := _label(box, rarity.to_upper() + (" · FOIL" if rarity != "common" else ""), 12, accent)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mark := _label(box, "●" if info.kind == "color" else "✦", 36, Cosmetics.color_for(str(info.value)) if info.kind == "color" else accent)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(box, str(info.name), 18, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail := _label(box, "Already collected" if card.get_meta("duplicate", false) else "New color!" if info.kind == "color" else "New accessory!", 12, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if rarity != "common":
		var foil := FoilShine.new()
		foil.name = "FoilShine"
		foil.tint = accent
		foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_full(foil)
		card.add_child(foil)
	card.pivot_offset = card.size * 0.5
	card.scale.x = 0.08
	card.create_tween().tween_property(card, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare": return Color("69b6ff")
		"epic": return Color("b591ff")
		"legendary": return Color("f2c355")
	return Color("bdc8d0")


func _scrim(color: Color) -> Control:
	var layer: ColorRect = ColorRect.new()
	layer.color = color
	_full(layer)
	_root.add_child(layer)
	return layer

func _backplate(parent: Node) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := _style(Color(NAVY, 0.91), Color(OUTLINE, 0.65))
	plate_style.border_width_left = 3
	plate_style.border_color = Color(OUTLINE, 0.8)
	plate.add_theme_stylebox_override("panel", plate_style)
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
	if font_size >= 19:
		var heading_font := SystemFont.new()
		heading_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
		heading_font.font_weight = 700
		label.add_theme_font_override("font", heading_font)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 15)
	var text_color: Color = NAVY if color.get_luminance() > 0.4 else CREAM
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	var border: Color = OUTLINE if color == PANEL or color == NAVY else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _style(color, border))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.10), MINT if border.a > 0 else Color.TRANSPARENT))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), border))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, MINT))
	parent.add_child(button)
	return button

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	return style

func _theme() -> Theme:
	var theme: Theme = Theme.new()
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	theme.default_font = ui_font
	theme.default_font_size = 15
	theme.set_stylebox("normal", "LineEdit", _style(NAVY, OUTLINE))
	theme.set_stylebox("focus", "LineEdit", _style(NAVY, MINT))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", MINT)
	theme.set_color("selection_color", "LineEdit", Color(MINT, 0.25))
	theme.set_stylebox("normal", "OptionButton", _style(NAVY, OUTLINE))
	theme.set_stylebox("hover", "OptionButton", _style(PANEL, MINT))
	theme.set_stylebox("pressed", "OptionButton", _style(NAVY, MINT))
	theme.set_stylebox("focus", "OptionButton", _style(Color.TRANSPARENT, MINT))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "OptionButton", CREAM)
	theme.set_stylebox("panel", "PopupMenu", _style(NAVY, OUTLINE))
	theme.set_stylebox("hover", "PopupMenu", _style(PANEL))
	theme.set_color("font_color", "PopupMenu", CREAM)
	theme.set_color("font_hover_color", "PopupMenu", MINT)
	return theme
