class_name GameHUD
extends CanvasLayer

signal host_requested(name: String)
signal join_requested(address: String, slot: int, name: String)
signal action_requested(action: String, payload: Dictionary)
signal leave_requested
signal new_island_requested(name: String)
signal settings_changed(settings: Dictionary)

const INK: Color = Color("202d3a")
const TEAL: Color = Color("285962")
const CREAM: Color = Color("e4d4af")
const AMBER: Color = Color("ffd071")
const CORAL: Color = Color("e67c61")
const MUTED: Color = Color("a8bec3")
const ROLE_IDS: Array[String] = ["scout", "keeper", "rigger"]
const SpeciesModel = preload("res://game/fishing/species.gd")
const CatchModel = preload("res://game/fishing/catch_table.gd")
const GearModel = preload("res://game/progression/equipment.gd")
const CraftModel = preload("res://game/progression/crafting.gd")
const SettingsModel = preload("res://game/ui/settings_local.gd")
const HABITATS: Array[String] = ["jetty", "reeds", "terraces", "tidepools", "beacon"]
const TIME_BANDS: Array[String] = ["day", "dusk", "night", "storm"]

var _root: Control
var _menu: Control
var _game: Control
var _overlay: Control
var _menu_message: Label
var _menu_name: LineEdit
var _address: LineEdit
var _slot: OptionButton
var _stats: Label
var _host_address: Label
var _vote_notice: Label
var _crew_labels: Array[Label] = []
var _context: Label
var _equipment: Label
var _controls: Label
var _fish_box: VBoxContainer
var _fish_card: PanelContainer
var _progress: ProgressBar
var _tension: ProgressBar
var _tension_fill: StyleBoxFlat
var _fish_hint: Label
var _toast_label: Label
var _toast_card: PanelContainer
var _toast_until: float = 0.0
var _panel_kind: String = ""
var _panel_title: Label
var _panels: Dictionary = {}
var _data: Dictionary = {}
var _profile_id: String = ""
var _workshop_status: Label
var _craft_button: Button
var _gear_buttons: Dictionary = {}
var _profile_name: LineEdit
var _role: OptionButton
var _journal: Label
var _vote_status: Label
var _jetty: Button
var _reeds: Button
var _open_vote: Button
var _pause_status: Label
var _resume: Button
var _mute: CheckButton
var _objective: Label
var _campaign_details: Label
var _escape_status: Label
var _arm_escape: Button
var _signal_escape: Button
var _continue_island: Button
var _return_to_ending: Button
var _repair_buttons: Dictionary = {}
var _repairs_box: VBoxContainer
var _campaign_page: VBoxContainer
var _catches_page: VBoxContainer
var _ending_summary: Label
var _ending_seen: bool = false
var _recipe_buttons: Dictionary = {}
var _tool_status: Label
var _standard_tool: Button
var _alternate_tool: Button
var _journal_habitat: OptionButton
var _journal_time: OptionButton
var _new_island_confirmation: ConfirmationDialog
var _settings: RefCounted
var _setting_widgets: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _capture_action: String = ""
var _settings_status: Label
var _menu_controls: Label
var _panel_scroll: ScrollContainer
var _paused_by_menu: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings == null: _settings = SettingsModel.new()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_menu()
	_build_game()
	_build_panels()
	_sync_settings_widgets()
	show_menu()

func configure_settings(model: RefCounted) -> void:
	_settings = model
	if _root != null: _sync_settings_widgets()

func request_new_island() -> void:
	if not _menu.visible: return
	_new_island_confirmation.popup_centered(Vector2i(540, 220))

func show_menu(message: String = "") -> void:
	if _root == null:
		return
	_panel_kind = ""
	_overlay.hide()
	_game.hide()
	_menu.show()
	_menu_message.text = message

func show_game() -> void:
	if _root == null:
		return
	_menu.hide()
	_game.show()
	_overlay.hide()
	_panel_kind = ""

func panel_open() -> bool:
	return not _panel_kind.is_empty() or (_menu != null and _menu.visible)

func toggle_panel(kind: String) -> void:
	if _overlay == null or (_menu.visible and kind != "settings"):
		return
	if kind == "host" and not bool(_data.get("is_host", false)):
		toast("Lake Office is available on the host PC.")
		return
	if kind == _panel_kind:
		_close_panel()
		return
	if not _panels.has(kind):
		return
	_close_panel(false)
	_panel_kind = kind
	for key: String in _panels:
		_panels[key].visible = key == kind
	_panel_title.text = {"workshop": "BOAT WORKSHOP", "journal": "FIELD JOURNAL", "vote": "ONE BATTERY. TWO ROUTES.", "host": "LAKE OFFICE", "pause": "TAKE A BREATHER", "settings": "THIS PC · SETTINGS", "ending": "THE LIGHT BROUGHT YOU HOME"}.get(kind, kind.to_upper())
	_return_to_ending.visible = bool(_data.get("escape", {}).get("completed", false)) and kind != "ending"
	_panel_scroll.scroll_vertical = 0
	if kind == "workshop":
		var profiles: Dictionary = _data.get("progression", {}).get("profiles", {})
		var profile: Dictionary = profiles.get(_profile_id, {})
		_profile_name.text = str(profile.get("name", "Angler"))
		_role.select(maxi(0, ROLE_IDS.find(str(profile.get("role_id", "scout")))))
	if kind == "pause" and bool(_data.get("is_host", false)) and not _paused_by_menu:
		_paused_by_menu = true
		action_requested.emit("pause", {"paused": true})
	if kind == "settings": _sync_settings_widgets()
	_overlay.show()

func toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.show()
	_toast_card.show()
	_toast_until = float(Time.get_ticks_msec()) / 1000.0 + 4.5

func update_view(data: Dictionary, profile_id: String, context: String) -> void:
	_data = data
	_profile_id = profile_id
	if _root == null:
		return
	var run: Dictionary = data.get("run", {})
	var progression: Dictionary = data.get("progression", {})
	var profiles: Dictionary = progression.get("profiles", {})
	var players: Dictionary = run.get("players", {})
	var elapsed: float = float(run.get("elapsed_s", 0.0))
	var remaining: int = maxi(0, int(ceil(630.0 - elapsed)))
	var phase: String = str(run.get("phase", "day")).to_upper()
	var terminal: bool = bool(run.get("terminal", false))
	var departing: bool = terminal or phase == "REFUGE" or float(run.get("crossing_left", -1.0)) >= 0.0
	if bool(run.get("paused", false)):
		phase = "PAUSED"
	_stats.text = "DAY %d   /   %s   /   %02d:%02d\n%d crew coins" % [int(progression.get("day_index", 0)) + 1, phase, int(floor(remaining / 60.0)), remaining % 60, int(progression.get("coins", 0))]
	_host_address.visible = bool(data.get("is_host", false))
	var addresses: PackedStringArray = PackedStringArray(data.get("host_addresses", []))
	_host_address.text = ("LAN: " + " · ".join(addresses) if not addresses.is_empty() else "LAN address unavailable") + "\n%s · Lake Office" % _key("host_panel")
	for i: int in range(3):
		var id: String = "crew_%d" % (i + 1)
		var profile: Dictionary = profiles.get(id, {})
		var player: Dictionary = players.get(id, {})
		var status: String = str(profile.get("role_id", "scout")).capitalize()
		if not players.has(id):
			status = "Open crew slot"
		elif bool(player.get("downed", false)):
			status = "NEEDS HELP · %ds" % ceili(float(player.get("down_left", 25.0)))
		elif bool(player.get("ready", false)):
			status += " · Ready"
		_crew_labels[i].text = "%s%s\n%s" % [str(profile.get("name", "Angler %d" % (i + 1))), "  [you]" if id == profile_id else "", status]
		_crew_labels[i].modulate.a = 1.0 if players.has(id) else 0.55
	_context.text = context
	_controls.text = _control_text()
	if departing:
		_controls.text = "%s journal · %s menu" % [_key("journal"), _key("pause")]
		if terminal:
			var saved: bool = str(run.get("run_id", "")) in progression.get("settled_run_ids", [])
			_context.text = "Trip saved. Dawn is on its way." if saved else "Departure save pending · " + ((_key("pause") + " → Resume to retry") if bool(data.get("is_host", false)) else "waiting for the host")
			if bool(data.get("escape", {}).get("completed", false)):
				_context.text = "Island saved · %s journal → ending → Continue Island" % _key("journal")
		else:
			_context.text = ("Crossing the outer channel · %ds" if bool(data.get("escape", {}).get("departing", false)) or phase == "ESCAPE" else "Heading for refuge · %ds to the mooring") % maxi(0, ceili(float(run.get("crossing_left", 0.0))))
	var current_profile: Dictionary = profiles.get(profile_id, {})
	var lamp: String = str(current_profile.get("lamp_id", "flood"))
	var remaining_light: float = float(data.get("lights", {}).get("batteries", {}).get(profile_id, 45.0 if lamp == "surveyor" else 90.0))
	var ready_at: float = float(data.get("abilities", {}).get("ready_at", {}).get(profile_id, 0.0))
	var tool_text: String = "Tool ready" if ready_at <= elapsed else "Tool %ds" % ceili(ready_at - elapsed)
	var cargo: Dictionary = data.get("cargo", {})
	var pouch: int = 0
	var held: bool = false
	for entry: Dictionary in cargo.values():
		if entry.get("state", "") == "packed" and entry.get("pouch_profile_id", "") == profile_id:
			pouch += int(entry.get("catch_record", {}).get("catch_value", 0))
		if entry.get("state", "") == "whole_held" and entry.get("carrier_id", "") == profile_id:
			held = true
	_equipment.text = "%s · light %ds   /   %s   /   Pouch %d%s" % [lamp.capitalize(), ceili(remaining_light), tool_text, pouch, "   /   WHOLE FISH: LMB toss · hold %s to pack" % _key("pack") if held else ""]
	if departing:
		_equipment.text = ("The crew is leaving Last Light together." if phase=="ESCAPE" else "The crew is returning to the mooring.") if not terminal else ("Your collection and island improvements are saved." if bool(data.get("escape",{}).get("completed",false)) else "The island clock is stopped while this trip finishes.")
	var fishing: Dictionary = data.get("fishing", {}).get(profile_id, {})
	_fish_card.visible = not fishing.is_empty() and not departing
	if not fishing.is_empty():
		_progress.value = float(fishing.get("progress", 0.0))
		_tension.value = float(fishing.get("tension", 0.0))
		_tension_fill.bg_color = CORAL if _tension.value > 0.7 else AMBER
		var pull: float = float(fishing.get("pull", 0.0))
		var direction_hint: String = "← Fish pulls LEFT · hold %s" % _key("move_right") if pull < -0.05 else "→ Fish pulls RIGHT · hold %s" % _key("move_left") if pull > 0.05 else "Fish is steady · keep the line loose"
		_fish_hint.text = direction_hint + "\nLMB reel · %s toggle reel\nStop reeling to ease tension\n%s/%s cancels · %s/%s countersteer" % [_key("toggle_reel"), _key("move_forward"), _key("move_back"), _key("move_left"), _key("move_right")]
		if bool(fishing.get("surging", false)):
			_fish_hint.text = "RELEASE — SURGE!\nStop reeling until the rush ends.\n" + direction_hint
		elif fishing.get("behavior", "") == "surge" and float(fishing.get("surge_in", 10.0)) <= 1.0:
			_fish_hint.text = "Surge coming · prepare to release\n" + _fish_hint.text
	_update_workshop(progression, current_profile)
	_update_journal(progression)
	_update_campaign(data)
	_update_vote(data.get("choice", {}), elapsed)
	if departing:
		_vote_notice.hide()
	_pause_status.text = "The island clock is paused. Everyone can take a breather." if bool(run.get("paused", false)) else "Only the host can pause the whole island. This menu alone does not stop the night."
	_resume.text = "Resume expedition" if bool(data.get("is_host", false)) else "Back to expedition"
	if data.has("audio_muted"):
		_mute.set_pressed_no_signal(bool(data.audio_muted))

func _process(_delta: float) -> void:
	if _toast_label != null and _toast_label.visible and float(Time.get_ticks_msec()) / 1000.0 >= _toast_until:
		_toast_label.hide()
		_toast_card.hide()

func _close_panel(release_pause: bool = true) -> void:
	_capture_action = ""
	if release_pause and _paused_by_menu and bool(_data.get("is_host", false)):
		_paused_by_menu = false
		action_requested.emit("pause", {"paused": false})
	_panel_kind = ""
	_overlay.hide()
	_sync_binding_buttons()

func _build_menu() -> void:
	_menu = _full_control(_root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(INK, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var card: PanelContainer = _card(center)
	card.custom_minimum_size = Vector2(580, 0)
	var box: VBoxContainer = _column(card, 9)
	_add_label(box, "LAST LIGHT ISLAND", 14, AMBER)
	_add_label(box, "ONE MORE CAST", 42, CREAM)
	_add_label(box, "Catch something worth carrying home.", 19, MUTED)
	_menu_message = _add_label(box, "", 16, AMBER, true)
	_menu_name = _line_edit(box, "Your name", "Angler")
	_menu_name.max_length = 32
	_button(box, "HOST THE ISLAND", func() -> void: host_requested.emit(_menu_name.text.strip_edges()))
	var join_row: HBoxContainer = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	box.add_child(join_row)
	_address = _line_edit(join_row, "Host's LAN address · e.g. 192.168.1.20", "")
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot = OptionButton.new()
	_slot.add_item("Any free slot")
	_slot.add_item("Crew slot 2")
	_slot.add_item("Crew slot 3")
	_slot.custom_minimum_size.y = 42
	join_row.add_child(_slot)
	_button(box, "JOIN THE CREW", func() -> void: join_requested.emit(_address.text.strip_edges(), -1 if _slot.selected == 0 else _slot.selected, _menu_name.text.strip_edges()))
	var options: HBoxContainer = HBoxContainer.new()
	box.add_child(options)
	_button(options, "Settings & controls", func() -> void: toggle_panel("settings")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(options, "New Island…", request_new_island).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_island_confirmation = ConfirmationDialog.new()
	_new_island_confirmation.title = "Start a new household island?"
	_new_island_confirmation.dialog_text = "Your current island must be archived before a new one is created.\nThis starts new crew progress on this host PC.\n\nChoose Create New Island only if you want a fresh start."
	_new_island_confirmation.ok_button_text = "Create New Island"
	_new_island_confirmation.confirmed.connect(func() -> void:
		if _menu.visible: new_island_requested.emit(_menu_name.text.strip_edges()))
	add_child(_new_island_confirmation)
	_add_label(box, "Three Windows PCs. One home network.\nThe host shares the LAN address shown in their game.", 16, MUTED, true)
	_menu_controls = _add_label(box, "", 15, CREAM, true)
	_add_label(box, "Change your name, role and equipment at the boat workshop.", 15, MUTED, true)

func _build_game() -> void:
	_game = _full_control(_root)
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: MarginContainer = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 18
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var crew_box: VBoxContainer = _column(row, 10)
	crew_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = _add_label(crew_box, "ONE MORE CAST  /  LAST LIGHT", 18, AMBER)
	_outline(title)
	var permits: HBoxContainer = HBoxContainer.new()
	permits.add_theme_constant_override("separation", 12)
	crew_box.add_child(permits)
	var colors: Array[Color] = [Color("62b9db"), CORAL, Color("a28ad6")]
	for i: int in range(3):
		var permit: PanelContainer = _card(permits)
		permit.custom_minimum_size.x = 180
		permit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = _add_label(permit, "Angler %d\nOpen crew slot" % (i + 1), 16, colors[i])
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_crew_labels.append(label)
	_objective = _add_label(crew_box, "", 16, CREAM, true)
	_objective.max_lines_visible = 2
	_objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_outline(_objective)
	_vote_notice = _add_label(crew_box, "", 15, AMBER)
	_outline(_vote_notice)
	_vote_notice.hide()
	var session_card: PanelContainer = _card(row)
	session_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.9), TEAL, 10))
	session_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var session_box: VBoxContainer = _column(session_card, 6)
	session_box.custom_minimum_size.x = 300
	_stats = _add_label(session_box, "DAY 1 / DAY / 10:30\n0 crew coins", 19, CREAM)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_host_address = _add_label(session_box, "", 14, MUTED, true)
	_host_address.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_host_address.hide()
	var bottom_card: PanelContainer = _card(_game)
	bottom_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.94), TEAL, 10))
	bottom_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_card.offset_left = 14
	bottom_card.offset_right = -14
	bottom_card.offset_top = -151
	bottom_card.offset_bottom = -6
	bottom_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom: VBoxContainer = _column(bottom_card, 6)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context = _add_label(bottom, "", 21, AMBER, true)
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment = _add_label(bottom, "", 16, CREAM)
	_equipment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls = _add_label(bottom, "", 14, MUTED)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fish_card: PanelContainer = _card(_game)
	_fish_card = fish_card
	fish_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), TEAL.lightened(0.2), 12))
	fish_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fish_card.offset_left = -362
	fish_card.offset_right = -22
	fish_card.offset_top = -355
	fish_card.offset_bottom = -165
	_fish_box = _column(fish_card, 4)
	_add_label(_fish_box, "LAND THE CATCH", 14, CREAM)
	_progress = _bar(_fish_box, TEAL.lightened(0.3))
	_add_label(_fish_box, "LINE TENSION", 13, MUTED)
	_tension = _bar(_fish_box, AMBER)
	_tension_fill = _tension.get_theme_stylebox("fill") as StyleBoxFlat
	_fish_hint = _add_label(_fish_box, "", 13, CREAM)
	fish_card.hide()
	_toast_card = _card(_game)
	_toast_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.92), TEAL, 10))
	# Keep cast and rescue announcements away from the centre-line bobber/crew.
	_toast_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_toast_card.offset_left = 22
	_toast_card.offset_right = 440
	_toast_card.offset_top = 184
	_toast_card.offset_bottom = 250
	_toast_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _add_label(_toast_card, "", 18, AMBER, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.hide()
	_toast_card.hide()

func _build_panels() -> void:
	_overlay = _full_control(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card: PanelContainer = _card(center)
	card.custom_minimum_size = Vector2(740, 0)
	var box: VBoxContainer = _column(card, 12)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	_panel_title = _add_label(header, "", 26, AMBER)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Close", _close_panel).custom_minimum_size.x = 92
	var scroll: ScrollContainer = ScrollContainer.new()
	_panel_scroll = scroll
	scroll.custom_minimum_size = Vector2(700, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body: VBoxContainer = _column(scroll, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_return_to_ending = _button(body, "Return to the ending · Continue Island", func() -> void: toggle_panel("ending"))
	_return_to_ending.hide()
	for kind: String in ["workshop", "journal", "vote", "host", "pause", "settings", "ending"]:
		var section: VBoxContainer = _column(body, 12)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.hide()
		_panels[kind] = section
	_build_workshop(_panels.workshop)
	var journal_tabs := HBoxContainer.new()
	_panels.journal.add_child(journal_tabs)
	_button(journal_tabs, "Island progress", func() -> void: _journal_page(false)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(journal_tabs, "Fish collection & chances", func() -> void: _journal_page(true)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campaign_page = _column(_panels.journal, 12)
	_catches_page = _column(_panels.journal, 12)
	_catches_page.hide()
	_campaign_details = _add_label(_campaign_page, "", 17, CREAM, true)
	_repairs_box = _column(_campaign_page, 8)
	_escape_status = _add_label(_campaign_page, "", 17, AMBER, true)
	_arm_escape = _button(_campaign_page, "Arm Moth for the final night crossing", func() -> void: action_requested.emit("arm_escape", {}))
	_signal_escape = _button(_campaign_page, "Send the beacon signal", func() -> void: action_requested.emit("signal_escape", {}))
	var pool_options: HBoxContainer = HBoxContainer.new()
	_catches_page.add_child(pool_options)
	_journal_habitat = OptionButton.new()
	_journal_time = OptionButton.new()
	for habitat: String in HABITATS: _journal_habitat.add_item(habitat.capitalize())
	for band: String in TIME_BANDS: _journal_time.add_item(band.capitalize())
	pool_options.add_child(_journal_habitat)
	pool_options.add_child(_journal_time)
	_journal_habitat.item_selected.connect(func(_index: int) -> void: _update_journal(_data.get("progression", {})))
	_journal_time.item_selected.connect(func(_index: int) -> void: _update_journal(_data.get("progression", {})))
	_journal = _add_label(_catches_page, "", 17, CREAM, true)
	_build_vote(_panels.vote)
	_build_host(_panels.host)
	_pause_status = _add_label(_panels.pause, "", 19, CREAM, true)
	_resume = _button(_panels.pause, "Resume expedition", _close_panel)
	_mute = CheckButton.new()
	_mute.text = "Mute sound on this PC"
	_mute.custom_minimum_size.y = 42
	_mute.add_theme_color_override("font_color", CREAM)
	_mute.toggled.connect(func(muted: bool) -> void: action_requested.emit("set_audio", {"muted": muted}))
	_panels.pause.add_child(_mute)
	_button(_panels.pause, "Settings & controls on this PC", func() -> void: toggle_panel("settings"))
	_add_label(_panels.pause, "Leave: banked rewards stay saved. Unbanked cargo follows the departure rules.", 17, MUTED, true)
	_button(_panels.pause, "Leave island", func() -> void: leave_requested.emit())
	_build_settings(_panels.settings)
	_ending_summary = _add_label(_panels.ending, "", 21, CREAM, true)
	_continue_island = _button(_panels.ending, "Continue Island · keep everything you earned", func() -> void:
		if bool(_data.get("is_host", false)):
			action_requested.emit("continue_island", {})
			_close_panel())
	_button(_panels.ending, "Browse the field journal", func() -> void: toggle_panel("journal"))
	_button(_panels.ending, "Leave island", func() -> void: leave_requested.emit())
	_overlay.hide()

func _build_workshop(parent: VBoxContainer) -> void:
	_workshop_status = _add_label(parent, "Use at the boat workshop.", 17, MUTED, true)
	_button(parent, "Island repairs & final crossing", func() -> void:
		_journal_page(false)
		toggle_panel("journal"))
	_add_label(parent, "CREW RECIPES", 16, AMBER)
	for id: String in _recipes():
		var recipe: Dictionary = _recipes()[id]
		var button: Button = _button(parent, "Craft " + str(recipe.get("name", id.capitalize())), func() -> void: action_requested.emit("craft", {"recipe_id": id}))
		_recipe_buttons[id] = button
		_add_label(parent, _recipe_cost(recipe) + " · " + str(recipe.get("hint", "")), 15, MUTED, true)
	_add_label(parent, "YOUR EQUIPMENT", 16, AMBER)
	for kind: String in ["rod", "lamp"]:
		for id: String in _gear(kind):
			var metadata: Dictionary = _gear(kind)[id]
			var button: Button = _button(parent, str(metadata.get("name", id.capitalize())), func() -> void: action_requested.emit("equip_" + kind, {kind + "_id": id}))
			button.set_meta("base_text", button.text)
			button.set_meta("gear_kind", kind)
			_gear_buttons[id] = button
			_add_label(parent, str(metadata.get("description", "")) + "\n" + str(metadata.get("acquisition", "")), 15, MUTED, true)
	_add_label(parent, "YOUR ROLE TOOL", 16, AMBER)
	_tool_status = _add_label(parent, "", 16, CREAM, true)
	_standard_tool = _button(parent, "Use standard tool", func() -> void: action_requested.emit("set_tool", {"mode": "standard"}))
	_alternate_tool = _button(parent, "Use alternate tool", func() -> void: action_requested.emit("set_tool", {"mode": "alternate"}))
	_add_label(parent, "YOUR CREW PERMIT · edit your name and role at the boat", 16, AMBER)
	_profile_name = _line_edit(parent, "Crew name", "Angler")
	_profile_name.max_length = 32
	_role = OptionButton.new()
	_role.add_item("Scout · find fish and a safer approach")
	_role.add_item("Keeper · protect a short rescue window")
	_role.add_item("Rigger · haul a catch or pull a teammate")
	_role.custom_minimum_size.y = 40
	parent.add_child(_role)
	_button(parent, "Save crew permit", func() -> void: action_requested.emit("set_profile", {"name": _profile_name.text.strip_edges(), "role_id": ROLE_IDS[_role.selected]}))
	_button(parent, "I'm aboard and ready to leave", func() -> void: action_requested.emit("ready", {"ready": true}))

func _build_vote(parent: VBoxContainer) -> void:
	_vote_status = _add_label(parent, "", 18, CREAM, true)
	_add_label(parent, "JETTY: keeps the exposed return shelter lit.\nREEDS: keeps a refuge near valuable night fish lit.\nBoth routes stay open. The boat is always safe.", 18, MUTED, true)
	_open_vote = _button(parent, "Open crew decision", func() -> void: action_requested.emit("open_vote", {}))
	_jetty = _button(parent, "Keep the jetty lit", func() -> void: action_requested.emit("vote", {"choice": "jetty"}))
	_reeds = _button(parent, "Power the outer reeds", func() -> void: action_requested.emit("vote", {"choice": "reeds"}))
	_add_label(parent, "Two votes decide with three crew. No decision by dusk keeps the jetty lit.", 16, MUTED, true)

func _build_host(parent: VBoxContainer) -> void:
	_add_label(parent, "A little trouble. Always recoverable.\nOne event at a time; ordinary rewards stay intact.", 18, CREAM, true)
	for pair: Array in [["odd_catch", "Odd Catch · next fish looks ridiculous"], ["fog", "Fog · a brief 15-second bank"], ["sighting", "Suspicious Splash · a distant sighting"], ["clear_event", "Clear current event"], ["safe_return", "Return crew safely · end current risk"]]:
		var event_id: String = pair[0]
		_button(parent, pair[1], func() -> void: action_requested.emit("host_event", {"event_id": event_id}))

func _update_workshop(progression: Dictionary, profile: Dictionary) -> void:
	var owned_lamps: Array = progression.get("owned_lamps", [])
	var owned_rods: Array = progression.get("owned_rods", [])
	var coins: int = int(progression.get("coins", 0))
	var salvage: Dictionary = progression.get("salvage", {})
	var supply_text: PackedStringArray = []
	for supply: String in salvage: supply_text.append("%d %s" % [int(salvage[supply]), supply.replace("_", " ")])
	_workshop_status.text = "At the boat workshop · %d shared coins\n%s\nCrafted gear belongs to everyone. Choose your own loadout." % [coins, " · ".join(supply_text) if not supply_text.is_empty() else "Find supplies in the island caches."]
	for id: String in _recipe_buttons:
		var recipe: Dictionary = _recipes()[id]
		var owned: bool = str(recipe.output_id) in (owned_rods if recipe.output_kind == "rod" else owned_lamps)
		var known: bool = id in progression.get("known_recipes", [])
		var affordable: bool = coins >= int(recipe.coins)
		for supply: String in recipe.salvage:
			affordable = affordable and int(salvage.get(supply, 0)) >= int(recipe.salvage[supply])
		var button: Button = _recipe_buttons[id]
		button.disabled = owned or not known or not affordable
		button.text = str(recipe.name) + ("  [crafted for crew]" if owned else "  [find recipe]" if not known else "  [need supplies]" if not affordable else "  · Craft")
	for id: String in _gear_buttons:
		var button: Button = _gear_buttons[id]
		var is_rod: bool = button.get_meta("gear_kind") == "rod"
		var has_item: bool = id in (owned_rods if is_rod else owned_lamps)
		var selected: bool = profile.get("rod_id" if is_rod else "lamp_id", "") == id
		button.disabled = not has_item or selected
		button.text = str(button.get_meta("base_text")) + ("  [equipped]" if selected else "  [not found]" if not has_item else "")
	var tool: Dictionary = _data.get("campaign", {}).get("tools", {}).get(str(profile.get("role_id", "scout")), {})
	var alternate: bool = profile.get("tool_mode", "standard") == "alternate"
	_tool_status.text = str(tool.get("name", "Alternate tool")) + " · " + str(tool.get("hint", "Explore and restore the island to unlock a second tool."))
	if not str(tool.get("description", "")).is_empty(): _tool_status.text += "\n" + str(tool.description)
	_standard_tool.disabled = not alternate
	_alternate_tool.disabled = alternate or not bool(tool.get("unlocked", false))
	_alternate_tool.text = "Use " + str(tool.get("name", "alternate tool")) + ("  [equipped]" if alternate else "  [locked]" if not bool(tool.get("unlocked", false)) else "")

func _update_journal(progression: Dictionary) -> void:
	var records: Dictionary = progression.get("specimen_records", {})
	var catalog: Dictionary = SpeciesModel.catalog()
	var habitat: String = HABITATS[_journal_habitat.selected]
	var band: String = TIME_BANDS[_journal_time.selected]
	var text: String = "BASE CHANCES · %s / %s\n" % [habitat.capitalize(), band.capitalize()]
	var rare_pool: bool = false
	for entry: Dictionary in CatchModel.pool(habitat, band):
		text += "%s %.0f%%   " % [catalog[entry.species_id].name, float(entry.chance) * 100.0]
		rare_pool = rare_pool or SpeciesModel.is_rare(entry.species_id)
	if rare_pool:
		text += "\nShared dry streak here: %d / 11. After eleven eligible ordinary landings, the next new eligible cast offers this pool's rare fish. Failed casts keep the streak." % mini(int(progression.get("dry_streaks", {}).get(habitat, 0)), 11)
	text += "\n\nTHE CREW'S CATCHES · %d / %d discovered\n" % [progression.get("discoveries", []).size(), catalog.size()]
	for id: String in catalog:
		var fish: Dictionary = catalog[id]
		var record: Dictionary = records.get(id, {})
		text += "\n%s · %s\n%d coins base · %s · %s\n%s\n" % [fish.name, "not discovered" if record.is_empty() else "%d caught · best %.2f m" % [int(record.get("count", 0)), float(record.get("largest_size", 0.0))], int(fish.value), str(fish.behavior).capitalize(), str(fish.rarity).capitalize(), fish.habitat_hint]
		if not record.get("traits", []).is_empty(): text += "Traits found: " + ", ".join(PackedStringArray(record.traits)) + "\n"
	text += "\nTRAITS · one at a time\nOversized: 10% at any time; pack for 1.25× base or carry whole for 2×.\nMoonlit: 8% at dusk/night, worth 1.5×. Stormmarked: 10% in storms, worth 1.75×. Values round down.\n\nDart: countersteer. Heavy: sustained careful reeling. Surge: release during each rush.\nEvery fish is recorded when landed; shared coins arrive only when safely banked."
	_journal.text = text

func _journal_page(catches: bool) -> void:
	_campaign_page.visible = not catches
	_catches_page.visible = catches
	_panel_scroll.scroll_vertical = 0

func _recipes() -> Dictionary:
	return CraftModel.recipes_all()

func _gear(kind: String) -> Dictionary:
	return GearModel.rods_all() if kind == "rod" else GearModel.lamps_all()

func _recipe_cost(recipe: Dictionary) -> String:
	var parts: PackedStringArray = ["%d coins" % int(recipe.get("coins", 0))]
	for id: String in recipe.get("salvage", {}): parts.append("%d %s" % [int(recipe.salvage[id]), id.replace("_", " ")])
	return " + ".join(parts)

func _update_campaign(data: Dictionary) -> void:
	var campaign: Dictionary = data.get("campaign", {})
	var escape: Dictionary = data.get("escape", {})
	_objective.text = str(campaign.get("objective", "Explore the island, land a catch, and return it to Moth.")) + "  · %s journal" % _key("journal")
	var details: String = str(campaign.get("title", "RESTORE LAST LIGHT")).to_upper() + "\n" + str(campaign.get("objective", "Find the workshop supplies to begin."))
	for repair: Dictionary in campaign.get("repairs", []):
		details += "\n\n%s %s · %s" % ["✓" if bool(repair.get("complete", false)) else "○", repair.get("name", repair.get("id", "Repair")), repair.get("location", "")]
		if not bool(repair.get("complete", false)): details += "\n" + str(repair.get("requirements", "Explore the nearby caches."))
		var id: String = str(repair.get("id", ""))
		if not id.is_empty():
			if not _repair_buttons.has(id):
				_repair_buttons[id] = _button(_repairs_box, "", func() -> void: action_requested.emit("repair", {"repair_id": id}))
			_repair_buttons[id].text = "%s · at %s" % [repair.get("name", id), repair.get("location", "its repair marker")]
			_repair_buttons[id].disabled = bool(repair.get("complete", false)) or not bool(repair.get("available", false))
	_campaign_details.text = details
	_return_to_ending.visible = bool(escape.get("completed", false)) and _panel_kind != "ending"
	_escape_status.text = str(escape.get("description", "Restore the island before attempting the final night crossing."))
	_arm_escape.disabled = not bool(escape.get("can_arm", false))
	_signal_escape.disabled = not bool(escape.get("can_signal", false))
	_continue_island.disabled = not bool(data.get("is_host", false))
	var saved: Dictionary = data.get("progression", {})
	_ending_summary.text = "Moth followed your beacon out of the dark.\nYou repaired Last Light and brought the crew home.\n\n%d species discovered · %d coins banked across your trips.\n\nYour equipment, collection and restored paths remain. Continue Island starts another outing." % [saved.get("discoveries", []).size(), int(saved.get("lifetime_banked", 0))]
	if not bool(data.get("is_host", false)): _ending_summary.text += "\nThe host chooses when to continue."
	if bool(escape.get("completed", false)) and not _ending_seen:
		_ending_seen = true
		toggle_panel("ending")
	elif not bool(escape.get("completed", false)):
		_ending_seen = false
		if _panel_kind == "ending": _close_panel()

func _key(action: String) -> String:
	return _settings.key_label(action) if _settings != null else "?"

func _control_text() -> String:
	return "LMB cast/reel/toss · %s toggle reel · Hold %s to pack\n%s interact · %s tool · %s lamp · %s assist · %s vote · %s ready\n%s workshop · %s journal · %s menu" % [_key("toggle_reel"), _key("pack"), _key("interact"), _key("ability"), _key("toggle_lamp"), _key("assist"), _key("vote"), _key("ready"), _key("workshop"), _key("journal"), _key("pause")]

func _build_settings(parent: VBoxContainer) -> void:
	_add_label(parent, "Changes affect this PC only. The island and crew settings stay with the host.", 16, MUTED, true)
	_settings_status = _add_label(parent, "", 16, AMBER, true)
	for key: String in ["master_volume", "threat_volume", "mouse_sensitivity"]:
		var label: Label = _add_label(parent, "", 17, CREAM)
		var slider := HSlider.new()
		slider.min_value = 0.2 if key == "mouse_sensitivity" else 0.0
		slider.max_value = 3.0 if key == "mouse_sensitivity" else 1.0
		slider.step = 0.05
		slider.custom_minimum_size.y = 32
		slider.value_changed.connect(func(value: float) -> void: _set_local_setting(key, value))
		parent.add_child(slider)
		_setting_widgets[key] = {"control": slider, "label": label}
	for key: String in ["invert_y", "reduced_effects"]:
		var check := CheckButton.new()
		check.text = "Invert vertical mouse look" if key == "invert_y" else "Reduce visual effects and camera motion"
		check.custom_minimum_size.y = 42
		check.toggled.connect(func(enabled: bool) -> void: _set_local_setting(key, enabled))
		parent.add_child(check)
		_setting_widgets[key] = {"control": check}
	_add_label(parent, "Window mode", 17, CREAM)
	var modes := OptionButton.new()
	for mode: String in ["Windowed", "Borderless", "Fullscreen"]: modes.add_item(mode)
	modes.item_selected.connect(func(index: int) -> void: _set_local_setting("window_mode", ["windowed", "borderless", "fullscreen"][index]))
	parent.add_child(modes)
	_setting_widgets.window_mode = {"control": modes}
	_add_label(parent, "KEYBOARD · choose an action, then press a key\nEscape cancels capture. Conflicting keys swap actions.\nLeft mouse: cast/reel/toss · Right mouse: orbit", 16, AMBER, true)
	for action: String in SettingsModel.DEFAULT_BINDINGS:
		var button: Button = _button(parent, "", func() -> void:
			_capture_action = action
			_sync_binding_buttons())
		_binding_buttons[action] = button
	_button(parent, "Reset keyboard bindings", func() -> void:
		for action: String in SettingsModel.DEFAULT_BINDINGS: _settings.set_binding(action, SettingsModel.DEFAULT_BINDINGS[action])
		_commit_settings())

func _set_local_setting(key: String, value: Variant) -> void:
	if _settings.set_value(key, value): _commit_settings()

func _commit_settings() -> void:
	var error: Error = _settings.save_settings()
	_settings_status.text = "Saved on this PC." if error == OK else "Active for this session; settings could not be saved (error %d)." % error
	_sync_settings_widgets()
	settings_changed.emit(_settings.snapshot())

func _sync_settings_widgets() -> void:
	if _settings == null: return
	var values: Dictionary = _settings.snapshot()
	for key: String in _setting_widgets:
		var widget: Control = _setting_widgets[key].control
		if widget is HSlider:
			widget.set_value_no_signal(float(values[key]))
			_setting_widgets[key].label.text = "%s · %.2f%s" % [key.replace("_", " ").capitalize(), float(values[key]) if key == "mouse_sensitivity" else float(values[key]) * 100.0, "×" if key == "mouse_sensitivity" else "%"]
		elif widget is CheckButton: widget.set_pressed_no_signal(bool(values[key]))
		elif widget is OptionButton: widget.select(["windowed", "borderless", "fullscreen"].find(values[key]))
	_sync_binding_buttons()
	if _menu_controls != null: _menu_controls.text = "%s/%s/%s/%s move · Right mouse orbit\n" % [_key("move_forward"), _key("move_left"), _key("move_back"), _key("move_right")] + _control_text()

func _sync_binding_buttons() -> void:
	for action: String in _binding_buttons:
		_binding_buttons[action].text = str(SettingsModel.ACTION_NAMES[action]) + "  ·  " + ("Press a key…" if _capture_action == action else _key(action))

func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_capture_action = ""
		_sync_binding_buttons()
	elif _settings.set_binding(_capture_action, int(event.physical_keycode)):
		_capture_action = ""
		_commit_settings()

func _update_vote(choice: Dictionary, elapsed: float) -> void:
	var committed: String = str(choice.get("committed", ""))
	var opened: bool = bool(choice.get("open", false))
	var votes: Dictionary = choice.get("votes", {})
	var voted: bool = votes.has(_profile_id)
	_vote_notice.visible = opened and committed.is_empty()
	_vote_notice.text = "BATTERY VOTE · Jetty %d / Reeds %d · %s" % [votes.values().count("jetty"), votes.values().count("reeds"), "Your vote is in · V to view" if voted else "Press V to choose"]
	_vote_notice.text = _vote_notice.text.replace("V to", _key("vote") + " to").replace("Press V", "Press " + _key("vote"))
	_vote_status.text = "Battery committed to %s for tonight." % committed.capitalize() if not committed.is_empty() else "Jetty votes: %d   /   Reeds votes: %d\n%s" % [votes.values().count("jetty"), votes.values().count("reeds"), "Choose together; the clock keeps moving." if opened else "Open the decision at the dock before dusk."]
	_open_vote.disabled = opened or not committed.is_empty() or elapsed >= 180.0
	_jetty.disabled = not opened or voted or not committed.is_empty()
	_reeds.disabled = _jetty.disabled

func _full_control(parent: Node) -> Control:
	var control: Control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(control)
	return control

func _card(parent: Node) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), TEAL.lightened(0.2), 16))
	parent.add_child(card)
	return card

func _column(parent: Node, gap: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _add_label(parent: Node, text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)

func _line_edit(parent: Node, placeholder: String, text: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = text
	field.custom_minimum_size.y = 42
	parent.add_child(field)
	return field

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", _style(INK.lightened(0.12), INK, 0))
	bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	parent.add_child(bar)
	return bar

func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _make_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _style(TEAL, TEAL.lightened(0.25), 10))
		theme.set_stylebox("hover", type, _style(TEAL.lightened(0.12), AMBER, 10))
		theme.set_stylebox("pressed", type, _style(INK, AMBER, 10))
		theme.set_stylebox("disabled", type, _style(INK.lightened(0.05), TEAL, 10))
		theme.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), AMBER, 0))
		theme.set_color("font_color", type, CREAM)
		theme.set_color("font_hover_color", type, AMBER)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.2))
	theme.set_stylebox("normal", "LineEdit", _style(INK.lightened(0.06), TEAL.lightened(0.2), 10))
	theme.set_stylebox("focus", "LineEdit", _style(Color(0, 0, 0, 0), AMBER, 0))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("caret_color", "LineEdit", AMBER)
	return theme
