class_name GameHUD
extends CanvasLayer

signal host_requested(name: String)
signal join_requested(address: String, slot: int, name: String)
signal action_requested(action: String, payload: Dictionary)
signal leave_requested

const INK: Color = Color("202d3a")
const TEAL: Color = Color("285962")
const CREAM: Color = Color("e4d4af")
const AMBER: Color = Color("ffd071")
const CORAL: Color = Color("e67c61")
const MUTED: Color = Color("a8bec3")
const ROLE_IDS: Array[String] = ["scout", "keeper", "rigger"]
const SPECIES_NAMES: Dictionary = {"penny_perch": "Penny Perch", "bellgill": "Bellgill", "lantern_eel": "Lantern Eel"}

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_menu()
	_build_game()
	_build_panels()
	show_menu()

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
	if _overlay == null or _menu.visible:
		return
	if kind == "host" and not bool(_data.get("is_host", false)):
		toast("Lake Office is available on the host PC.")
		return
	if kind == _panel_kind:
		_close_panel()
		return
	if not _panels.has(kind):
		return
	_close_panel()
	_panel_kind = kind
	for key: String in _panels:
		_panels[key].visible = key == kind
	_panel_title.text = {"workshop": "BOAT WORKSHOP", "journal": "FIELD JOURNAL", "vote": "ONE BATTERY. TWO ROUTES.", "host": "LAKE OFFICE", "pause": "TAKE A BREATHER"}.get(kind, kind.to_upper())
	if kind == "workshop":
		var profiles: Dictionary = _data.get("progression", {}).get("profiles", {})
		var profile: Dictionary = profiles.get(_profile_id, {})
		_profile_name.text = str(profile.get("name", "Angler"))
		_role.select(maxi(0, ROLE_IDS.find(str(profile.get("role_id", "scout")))))
	if kind == "pause" and bool(_data.get("is_host", false)):
		action_requested.emit("pause", {"paused": true})
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
	_host_address.text = ("LAN: " + " · ".join(addresses) if not addresses.is_empty() else "LAN address unavailable") + "\nF8 · Lake Office"
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
	_controls.text = "LMB cast/reel/toss · T toggle reel · Hold P to pack\nE interact · Q tool · F lamp · R assist · V route vote · B ready\nK workshop · J journal · Esc menu"
	if departing:
		_controls.text = "J journal · Esc menu"
		if terminal:
			var saved: bool = str(run.get("run_id", "")) in progression.get("settled_run_ids", [])
			_context.text = "Trip saved. Dawn is on its way." if saved else "Departure save pending · " + ("Esc → Resume to retry" if bool(data.get("is_host", false)) else "waiting for the host")
		else:
			_context.text = "Heading for refuge · %ds to the mooring" % maxi(0, ceili(float(run.get("crossing_left", 0.0))))
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
	_equipment.text = "%s · light %ds   /   %s   /   Pouch %d%s" % [lamp.capitalize(), ceili(remaining_light), tool_text, pouch, "   /   WHOLE FISH: LMB toss · hold P to pack" if held else ""]
	if departing:
		_equipment.text = "The crew is returning to the mooring." if not terminal else "The island clock is stopped while this trip finishes."
	var fishing: Dictionary = data.get("fishing", {}).get(profile_id, {})
	_fish_card.visible = not fishing.is_empty() and not departing
	if not fishing.is_empty():
		_progress.value = float(fishing.get("progress", 0.0))
		_tension.value = float(fishing.get("tension", 0.0))
		_tension_fill.bg_color = CORAL if _tension.value > 0.7 else AMBER
		var pull: float = float(fishing.get("pull", 0.0))
		var direction_hint: String = "← Fish pulls LEFT · hold D" if pull < -0.05 else "→ Fish pulls RIGHT · hold A" if pull > 0.05 else "Fish is steady · keep the line loose"
		_fish_hint.text = direction_hint + "\nLMB reel · T toggle reel\nStop reeling to ease tension\nW/S cancels · A/D countersteer"
	_update_workshop(progression, current_profile)
	_update_journal(progression)
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

func _close_panel() -> void:
	if _panel_kind == "pause" and bool(_data.get("is_host", false)):
		action_requested.emit("pause", {"paused": false})
	_panel_kind = ""
	_overlay.hide()

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
	var box: VBoxContainer = _column(card, 14)
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
	_add_label(box, "Three Windows PCs. One home network.\nThe host shares the LAN address shown in their game.", 16, MUTED, true)
	_add_label(box, "WASD move · Right mouse orbit · Left mouse cast/reel/toss\nWhile fishing: A/D countersteer · W/S cancels · T toggle reel\nE interact · Q tool · F lantern · Hold P to pack · Esc menu", 15, CREAM, true)
	_add_label(box, "Your name and role can be changed at the boat workshop (K).", 15, MUTED, true)

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
		_crew_labels.append(label)
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
	_toast_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_card.offset_left = -350
	_toast_card.offset_right = 350
	_toast_card.offset_top = 150
	_toast_card.offset_bottom = 208
	_toast_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _add_label(_toast_card, "", 21, AMBER, true)
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
	card.custom_minimum_size = Vector2(620, 0)
	var box: VBoxContainer = _column(card, 12)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	_panel_title = _add_label(header, "", 26, AMBER)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Close", _close_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body: VBoxContainer = _column(scroll, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind: String in ["workshop", "journal", "vote", "host", "pause"]:
		var section: VBoxContainer = _column(body, 12)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.hide()
		_panels[kind] = section
	_build_workshop(_panels.workshop)
	_journal = _add_label(_panels.journal, "", 18, CREAM, true)
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
	_add_label(_panels.pause, "Leave: banked rewards stay saved. Unbanked cargo follows the departure rules.", 17, MUTED, true)
	_button(_panels.pause, "Leave island", func() -> void: leave_requested.emit())
	_overlay.hide()

func _build_workshop(parent: VBoxContainer) -> void:
	_workshop_status = _add_label(parent, "Use at the boat workshop.", 17, MUTED, true)
	_craft_button = _button(parent, "Craft Surveyor · 30 coins + 1 glass lens", func() -> void: action_requested.emit("craft", {"recipe_id": "surveyor_lantern"}))
	_add_label(parent, "YOUR EQUIPMENT", 16, AMBER)
	for pair: Array in [["starter", "Starter rod · balanced"], ["soft_tip", "Soft-tip rod · easier tension, slower heavy catches"], ["flood", "Flood lamp · wide / 8 m / 90 s"], ["surveyor", "Surveyor lamp · narrow / 12 m / 45 s"]]:
		var id: String = pair[0]
		var action: String = "equip_rod" if id in ["starter", "soft_tip"] else "equip_lamp"
		var payload_key: String = "rod_id" if action == "equip_rod" else "lamp_id"
		var button: Button = _button(parent, pair[1], func() -> void: action_requested.emit(action, {payload_key: id}))
		button.set_meta("base_text", pair[1])
		_gear_buttons[id] = button
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
	var lens: int = int(progression.get("salvage", {}).get("glass_lens", 0))
	var known: bool = "surveyor_lantern" in progression.get("known_recipes", [])
	var owned: bool = "surveyor" in owned_lamps
	_craft_button.disabled = owned or not known or coins < 30 or lens < 1
	_craft_button.text = "Surveyor crafted for the whole crew" if owned else "Craft Surveyor · 30 coins + 1 glass lens"
	_workshop_status.text = "At the boat workshop · %d shared coins · %d glass lens\n%s" % [coins, lens, "Find the recipe and lens in the lido workshop cache." if not known else "A crafted item belongs to everyone. Choose your own loadout."]
	for id: String in _gear_buttons:
		var button: Button = _gear_buttons[id]
		var is_rod: bool = id in ["starter", "soft_tip"]
		var has_item: bool = id in (owned_rods if is_rod else owned_lamps)
		var selected: bool = profile.get("rod_id" if is_rod else "lamp_id", "") == id
		button.disabled = not has_item or selected
		button.text = str(button.get_meta("base_text")) + ("  [equipped]" if selected else "  [not found]" if not has_item else "")

func _update_journal(progression: Dictionary) -> void:
	var records: Dictionary = progression.get("specimen_records", {})
	var text: String = "THE CREW'S CATCHES\n"
	for id: String in SPECIES_NAMES:
		var record: Dictionary = records.get(id, {})
		text += "\n%s: %s" % [SPECIES_NAMES[id], "not discovered" if record.is_empty() else "%d caught · largest %.2f" % [int(record.get("count", 0)), float(record.get("largest_size", 0.0))]]
	var dry: int = int(progression.get("dry_streaks", {}).get("reeds", 0))
	text += "\n\nWHERE TO CAST\nJetty by day: Perch 70% · Bellgill 30%.\nReeds after dusk: Perch 60% · Bellgill 30% · Eel 10%.\nOversized: 10%, independent of species."
	text += "\n\nSHARED RARE STREAK: %d / 11\nAfter eleven eligible non-rare catches, the next new eligible cast offers an Eel. Failed casts do not reset it. Landing an Eel resets it; active casts keep their roll." % mini(dry, 11)
	text += "\n\nOversized: pack for 1.25× base, rounded down, or carry whole for 2×. Shared rewards; one payment per fish."
	_journal.text = text

func _update_vote(choice: Dictionary, elapsed: float) -> void:
	var committed: String = str(choice.get("committed", ""))
	var opened: bool = bool(choice.get("open", false))
	var votes: Dictionary = choice.get("votes", {})
	var voted: bool = votes.has(_profile_id)
	_vote_notice.visible = opened and committed.is_empty()
	_vote_notice.text = "BATTERY VOTE · Jetty %d / Reeds %d · %s" % [votes.values().count("jetty"), votes.values().count("reeds"), "Your vote is in · V to view" if voted else "Press V to choose"]
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
